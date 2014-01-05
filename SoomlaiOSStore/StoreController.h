/*
 * Copyright (C) 2012 Soomla Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "IStoreAssets.h"

@class AppStoreItem;
@class PurchasableVirtualItem;
@class SoomlaVerification;

/**
 * This class holds the most basic assets needed to operate the Store.
 * You can use it to purchase products from the App Store.
 *
 * This is the only class you need to initialize in order to use the SOOMLA SDK.
 *
 */
@interface StoreController : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>{
    @private
    BOOL initialized;
    SoomlaVerification* sv;
}

@property BOOL initialized;

+ (StoreController*)getInstance;

/**
 * This initializer also initializes StoreInfo.
 * storeAssets is the definition of your application specific assets.
 * customSecret is your encryption secret (it's used to encrypt your data in the database)
 */
- (BOOL)initializeWithStoreAssets:(id<IStoreAssets>)storeAssets andCustomSecret:(NSString*)secret;
/**
 * Start an in app purchase process in the App Store.
 * appStoreItem is the item to purchase. This item has to be defined EXACTLY the same in iTunes Connect.
 */
- (BOOL)buyInAppStoreWithAppStoreItem:(AppStoreItem*)appStoreItem;
/**
 * Initiate the restoreTransactions process
 */
- (void)restoreTransactions;
/**
 * Answers the question: "Were transactions already restored for this game?"
 */
- (BOOL)transactionsAlreadyRestored;
@end
