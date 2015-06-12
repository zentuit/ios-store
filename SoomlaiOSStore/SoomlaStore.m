/*
 Copyright (C) 2012-2014 Soomla Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "SoomlaStore.h"
#import "StoreConfig.h"
#import "StorageManager.h"
#import "StoreInfo.h"
#import "StoreEventHandling.h"
#import "VirtualGood.h"
#import "VirtualCategory.h"
#import "VirtualCurrency.h"
#import "VirtualCurrencyPack.h"
#import "VirtualCurrencyStorage.h"
#import "VirtualGoodStorage.h"
#import "InsufficientFundsException.h"
#import "NotEnoughGoodsException.h"
#import "VirtualItemNotFoundException.h"
#import "MarketItem.h"
#import "SoomlaUtils.h"
#import "PurchaseWithMarket.h"
#import "StoreUtils.h"
#import "SoomlaVerification.h"

@interface SoomlaStore (){
    NSMutableArray* verifications;
}
@end


@implementation SoomlaStore

@synthesize initialized;

static NSString* TAG = @"SOOMLA SoomlaStore";

+ (SoomlaStore*)getInstance{
    static SoomlaStore* _instance = nil;

    @synchronized( self ) {
        if( _instance == nil ) {
            _instance = [[SoomlaStore alloc] init];
        }
    }

    return _instance;
}

- (BOOL)initializeWithStoreAssets:(id<IStoreAssets>)storeAssets {
    if (self.initialized) {
        LogDebug(TAG, @"SoomlaStore already initialized.");
        return NO;
    }
    
    LogDebug(TAG, @"SoomlaStore Initializing ...");
    
    [StorageManager getInstance];
    [[StoreInfo getInstance] setStoreAssets:storeAssets];

    [self loadBillingService];

    [self refreshMarketItemsDetails];

    self.initialized = YES;
    [StoreEventHandling postSoomlaStoreInitialized];

    return YES;
}

- (void)loadBillingService {
    if ([SKPaymentQueue canMakePayments]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        [StoreEventHandling postBillingSupported];
        if (!verifications) {
            verifications = [NSMutableArray array];
        }
        [self retryUnfinishedTransactions];
    } else {
        [StoreEventHandling postBillingNotSupported];
    }
}

- (void)retryUnfinishedTransactions {
    NSArray* transactions = [[SKPaymentQueue defaultQueue] transactions];
    LogDebug(TAG, ([NSString stringWithFormat:@"Retrying any unfinished transactions: %lu", (unsigned long)transactions.count]));
    [self paymentQueue:[SKPaymentQueue defaultQueue] updatedTransactions:transactions];
}

static NSString* developerPayload = NULL;
- (BOOL)buyInMarketWithMarketItem:(MarketItem*)marketItem andPayload:(NSString*)payload{

    if ([SKPaymentQueue canMakePayments]) {
        SKMutablePayment *payment = [[SKMutablePayment alloc] init] ;
        payment.productIdentifier = marketItem.productId;
        payment.quantity = 1;
        developerPayload = payload;
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        @try {
            PurchasableVirtualItem* pvi = [[StoreInfo getInstance] purchasableItemWithProductId:marketItem.productId];
            [StoreEventHandling postMarketPurchaseStarted:pvi];
        }
        @catch (NSException *exception) {
            LogError(TAG, ([NSString stringWithFormat:@"Couldn't find a purchasable item with productId: %@", marketItem.productId]));
        }
    } else {
        LogError(TAG, @"Can't make purchases. Parental control is probably enabled.");
        return NO;
    }

    return YES;
}

- (void) refreshInventory {
    [self restoreTransactions];
    [self refreshMarketItemsDetails];
}

- (void)restoreTransactions {

    LogDebug(TAG, @"Sending restore transaction request");
    if ([SKPaymentQueue canMakePayments]) {
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    }

    [StoreEventHandling postRestoreTransactionsStarted];
}

- (BOOL)transactionsAlreadyRestored {
    
    // Defaults to NO
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"RESTORED"];
}

#pragma mark -
#pragma mark SKPaymentTransactionObserver methods

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    }
}

//// from http://stackoverflow.com/questions/2197362/converting-nsdata-to-base64
//- (NSString*)base64forData:(NSData*)theData {
//    const uint8_t* input = (const uint8_t*)[theData bytes];
//    NSInteger length = [theData length];
//    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
//    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
//    uint8_t* output = (uint8_t*)data.mutableBytes;
//    NSInteger i;
//    for (i=0; i < length; i += 3) {
//        NSInteger value = 0;
//        NSInteger j;
//        for (j = i; j < (i + 3); j++) {
//            value <<= 8;
//            
//            if (j < length) {
//                value |= (0xFF & input[j]);
//            }
//        }
//        NSInteger theIndex = (i / 3) * 4;
//        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
//        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
//        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
//        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
//    }
//    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
//}

//- (NSURL *)getReceiptUrl {
//    float version = [[[UIDevice currentDevice] systemVersion] floatValue];
//    
//    NSURL* receiptUrl = [NSURL URLWithString:@"file:///"];
//    if (version >= 7) {
//        receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
//    }
//    return receiptUrl;
//}


- (void)finalizeTransaction:(SKPaymentTransaction *)transaction forPurchasable:(PurchasableVirtualItem*)pvi {
    if ([StoreInfo isItemNonConsumable:pvi]){
        int balance = [[[StorageManager getInstance] virtualItemStorage:pvi] balanceForItem:pvi.itemId];
        if (balance == 1){
            // Remove the transaction from the payment queue.
            [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
            return;
        }
    }

//    NSURL* receiptUrl = [self getReceiptUrl];
//    NSString* receiptUrlStr = @"";
//    if (receiptUrl) {
//        receiptUrlStr = [receiptUrl absoluteString];
//    }

    
//    NSString *receiptString = @"";
//    if ([[NSFileManager defaultManager] fileExistsAtPath:[receiptUrl path]]) {
//        
//        NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
//        
//        receiptString = [self base64forData:receiptData];
//        if (receiptString == nil) {
//            receiptString = @"";
//        }
//    }

    NSString* receiptUrlStr = [StoreUtils getReceiptUrlAsString];
    NSString* receiptString = [StoreUtils getReceipt];
    NSString* transactionDateStr = [StoreUtils stringFromDate:transaction.transactionDate];
    NSString* originalDateStr = transaction.originalTransaction ?
                                    [StoreUtils stringFromDate:transaction.originalTransaction.transactionDate] :
                                    transactionDateStr;

    [StoreEventHandling postMarketPurchase:pvi withExtraInfo:@{
                                                               PURCHASE_ELEMENT_RECEIPT_URL: receiptUrlStr,
                                                               PURCHASE_ELEMENT_TRANSACTION_ID: transaction.transactionIdentifier,
                                                               PURCHASE_ELEMENT_RECEIPT: receiptString,
                                                               PURCHASE_ELEMENT_TRANSACTION_DATE: transactionDateStr,
                                                               PURCHASE_ELEMENT_ORIG_TRANSACTION_DATE: originalDateStr,
                                                               PURCHASE_ELEMENT_ORIG_TRANSACTION_ID: transaction.originalTransaction ? transaction.originalTransaction.transactionIdentifier : transaction.transactionIdentifier
                                                               }
                                andPayload:developerPayload];
    [pvi giveAmount:1];
    [StoreEventHandling postItemPurchased:pvi.itemId withPayload:developerPayload];
    developerPayload = NULL;

    // Remove the transaction from the payment queue.
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)purchaseVerified:(NSNotification*)notification{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EVENT_MARKET_PURCHASE_VERIF object:notification.object];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EVENT_VERIFICATION_ERROR object:notification.object];
    
    NSDictionary* userInfo = notification.userInfo;
    PurchasableVirtualItem* purchasable = [userInfo objectForKey:DICT_ELEMENT_PURCHASABLE];
    BOOL verified = [(NSNumber*)[userInfo objectForKey:DICT_ELEMENT_VERIFIED] boolValue];
    SKPaymentTransaction* transaction = [userInfo objectForKey:DICT_ELEMENT_TRANSACTION];

    if (verified) {
        [self finalizeTransaction:transaction forPurchasable:purchasable];
    } else {
        LogError(TAG, @"Failed to verify transaction receipt. The user will not get what he just bought.");
        [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
        [StoreEventHandling postVerificationFailed:purchasable andPayload:developerPayload];
    }
    
    [verifications removeObject:notification.object];
}

- (void)unexpectedVerificationError:(NSNotification*)notification{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EVENT_MARKET_PURCHASE_VERIF object:notification.object];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EVENT_VERIFICATION_ERROR object:notification.object];
    [verifications removeObject:notification.object];
}

- (void)givePurchasedItem:(SKPaymentTransaction *)transaction
{
    @try {
        PurchasableVirtualItem* pvi = [[StoreInfo getInstance] purchasableItemWithProductId:transaction.payment.productIdentifier];

        if (VERIFY_PURCHASES) {
            SoomlaVerification *sv = [[SoomlaVerification alloc] initWithTransaction:transaction andPurchasable:pvi];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseVerified:) name:EVENT_MARKET_PURCHASE_VERIF object:sv];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unexpectedVerificationError:) name:EVENT_VERIFICATION_ERROR object:sv];

            [sv verifyData];
            
            NSString* receiptUrlStr = [StoreUtils getReceiptUrlAsString];
            NSString* receiptString = [StoreUtils getReceipt];
            NSString* transactionDateStr = [StoreUtils stringFromDate:transaction.transactionDate];
            NSString* originalDateStr = transaction.originalTransaction ?
            [StoreUtils stringFromDate:transaction.originalTransaction.transactionDate] :
            transactionDateStr;
            
            [StoreEventHandling postVerificationStarted:pvi withExtraInfo:@{
                                                                            PURCHASE_ELEMENT_RECEIPT_URL: receiptUrlStr,
                                                                            PURCHASE_ELEMENT_TRANSACTION_ID: transaction.transactionIdentifier,
                                                                            PURCHASE_ELEMENT_RECEIPT: receiptString,
                                                                            PURCHASE_ELEMENT_TRANSACTION_DATE: transactionDateStr,
                                                                            PURCHASE_ELEMENT_ORIG_TRANSACTION_DATE: originalDateStr,
                                                                            PURCHASE_ELEMENT_ORIG_TRANSACTION_ID: transaction.originalTransaction ? transaction.originalTransaction.transactionIdentifier : transaction.transactionIdentifier
                                                                            }
                                             andPayload:developerPayload];
            [verifications addObject:sv];
        } else {
            [self finalizeTransaction:transaction forPurchasable:pvi];
        }

    } @catch (VirtualItemNotFoundException* e) {
        LogError(TAG, ([NSString stringWithFormat:@"An error occured when handling copmleted purchase for PurchasableVirtualItem with productId: %@"
                        @". It's unexpected so an unexpected error is being emitted.", transaction.payment.productIdentifier]));
        [StoreEventHandling postUnexpectedError:ERR_PURCHASE_FAIL forObject:self];
        [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    }
}

- (void) completeTransaction: (SKPaymentTransaction *)transaction
{
    LogDebug(TAG, ([NSString stringWithFormat:@"Transaction completed for product: %@", transaction.payment.productIdentifier]));
    [self givePurchasedItem:transaction];
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
    LogDebug(TAG, @"removedTransactions was called");
}

- (void) restoreTransaction: (SKPaymentTransaction *)transaction
{
    LogDebug(TAG, ([NSString stringWithFormat:@"Restore transaction for product: %@", transaction.payment.productIdentifier]));
    [self givePurchasedItem:transaction];
}

- (void) failedTransaction: (SKPaymentTransaction *)transaction
{
    if (transaction.error.code != SKErrorPaymentCancelled) {
        LogError(TAG, ([NSString stringWithFormat:@"An error occured for product id \"%@\" with code \"%ld\" and description \"%@\"", transaction.payment.productIdentifier, (long)transaction.error.code, transaction.error.debugDescription]));

        [StoreEventHandling postUnexpectedError:ERR_PURCHASE_FAIL forObject:self];
    }
    else{

        @try {
            PurchasableVirtualItem* pvi = [[StoreInfo getInstance] purchasableItemWithProductId:transaction.payment.productIdentifier];

            [StoreEventHandling postMarketPurchaseCancelled:pvi];
        }
        @catch (VirtualItemNotFoundException* e) {
            LogError(TAG, ([NSString stringWithFormat:@"Couldn't find the CANCELLED VirtualCurrencyPack OR MarketItem with productId: %@"
                            @". It's unexpected so an unexpected error is being emitted.", transaction.payment.productIdentifier]));
            [StoreEventHandling postUnexpectedError:ERR_GENERAL forObject:self];
        }

    }
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:@"RESTORED"];
    [defaults synchronize];
    
    [StoreEventHandling postRestoreTransactionsFinished:YES];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    [StoreEventHandling postRestoreTransactionsFinished:NO];
}


- (void)refreshMarketItemsDetails {
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[[NSSet alloc] initWithArray:[[StoreInfo getInstance] allProductIds]]];
    productsRequest.delegate = self;
    [productsRequest start];
    [StoreEventHandling postMarketItemsRefreshStarted];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSMutableArray* virtualItems = [NSMutableArray array];
    NSMutableArray* marketItems = [NSMutableArray array];
    NSArray *products = response.products;
    for(SKProduct* product in products) {
        NSString* title = product.localizedTitle;
        NSString* description = product.localizedDescription;
        NSDecimalNumber* price = product.price;
        NSLocale* locale = product.priceLocale;
        NSString* productId = product.productIdentifier;
        LogDebug(TAG, ([NSString stringWithFormat:@"title: %@  price: %@  productId: %@  desc: %@",title,[price descriptionWithLocale:locale],productId,description]));

        @try {
            PurchasableVirtualItem* pvi = [[StoreInfo getInstance] purchasableItemWithProductId:productId];

            PurchaseType* purchaseType = pvi.purchaseType;
            if ([purchaseType isKindOfClass:[PurchaseWithMarket class]]) {
                MarketItem* mi = ((PurchaseWithMarket*)purchaseType).marketItem;
                [mi setMarketInformation:[MarketItem priceWithCurrencySymbol:locale andPrice:price andBackupPrice:mi.price]
                          andTitle:title
                          andDescription:description
                          andCurrencyCode:[locale objectForKey:NSLocaleCurrencyCode]
                          andPriceMicros:(product.price.floatValue * 1000000)];

                [marketItems addObject:mi];
                [virtualItems addObject:pvi];
            }
        }
        @catch (VirtualItemNotFoundException* e) {
            LogError(TAG, ([NSString stringWithFormat:@"Couldn't find the PurchasableVirtualItem with productId: %@"
                            @". It's unexpected so an unexpected error is being emitted.", productId]));
            [StoreEventHandling postUnexpectedError:ERR_GENERAL forObject:self];
        }
    }

    for (NSString *invalidProductId in response.invalidProductIdentifiers)
    {
        LogError(TAG, ([NSString stringWithFormat: @"Invalid product id (when trying to fetch item details): %@" , invalidProductId]));
    }

    NSUInteger idsCount = [[[StoreInfo getInstance] allProductIds] count];
    NSUInteger productsCount = [products count];
    if (idsCount != productsCount)
    {
        LogError(TAG, ([NSString stringWithFormat: @"Expecting %d products but only fetched %d from iTunes Store" , (int)idsCount, (int)productsCount]));
    }
    
    if (virtualItems.count > 0) {
        [[StoreInfo getInstance] saveWithVirtualItems:virtualItems];
    }

    [StoreEventHandling postMarketItemsRefreshFinished:marketItems];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    LogError(TAG, ([NSString stringWithFormat:@"Market items details failed to refresh: %@", error.localizedDescription]));
    
    [StoreEventHandling postMarketItemsRefreshFailed:error.localizedDescription];
}


@end
