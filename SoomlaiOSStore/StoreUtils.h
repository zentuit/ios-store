//
//  StoreUtils.h
//  SoomlaiOSStore
//
//  Created by Tom Jenkins on 6/12/15.
//  Copyright (c) 2015 SOOMLA. All rights reserved.
//

#ifndef SoomlaiOSStore_StoreUtils_h
#define SoomlaiOSStore_StoreUtils_h

/**
 This class handles various SoomlaStore specific utility methods
 */
@interface StoreUtils : NSObject

+ (NSURL *)getReceiptUrl;
+ (NSString *)getReceiptUrlAsString;
+ (NSString *)getReceipt;
+ (NSString*)convertToBase64:(NSData*)data;
+ (NSString*)stringFromDate:(NSDate*)date;

@end



#endif
