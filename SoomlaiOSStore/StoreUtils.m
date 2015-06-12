//
//  StoreUtils.m
//  SoomlaiOSStore
//
//  Created by Tom Jenkins on 6/12/15.
//  Copyright (c) 2015 SOOMLA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StoreUtils.h"

@implementation StoreUtils


+ (NSURL *)getReceiptUrl {
    float version = [[[UIDevice currentDevice] systemVersion] floatValue];
    
    NSURL* receiptUrl = [NSURL URLWithString:@"file:///"];
    if (version >= 7) {
        receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    }
    return receiptUrl;
}

+ (NSString *)getReceiptUrlAsString {
    NSURL* receiptUrl = [self getReceiptUrl];
    NSString* receiptUrlStr = @"";
    if (receiptUrl) {
        receiptUrlStr = [receiptUrl absoluteString];
    }
    return receiptUrlStr;
}

+ (NSString *)getReceipt {
    NSString *receiptString = @"";
    NSURL *receiptUrl = [self getReceiptUrl];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[receiptUrl path]]) {
        
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
        
        receiptString = [self convertToBase64:receiptData];
        if (receiptString == nil) {
            receiptString = @"";
        }
    }
    return receiptString;
}

// from http://stackoverflow.com/questions/2197362/converting-nsdata-to-base64
+ (NSString*)convertToBase64:(NSData*)theData {
    const uint8_t* input = (const uint8_t*)[theData bytes];
    NSInteger length = [theData length];
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;
    NSInteger i;
    for (i=0; i < length; i += 3) {
        NSInteger value = 0;
        NSInteger j;
        for (j = i; j < (i + 3); j++) {
            value <<= 8;
            
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
        NSInteger theIndex = (i / 3) * 4;
        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }
    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

+ (NSString*)stringFromDate:(NSDate *)date {
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    NSString* dateStr = [dateFormatter stringFromDate:date];
    return dateStr;
}

@end

