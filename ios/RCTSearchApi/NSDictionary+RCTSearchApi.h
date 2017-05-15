//
//  NSDictionary+RCTSearchApi.h
//  RCTSearchApi
//
//  Created by Daniil Konoplev on 17/11/2016.
//  Copyright © 2016 Ombori AB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (RCTSearchApi)

@property (nonatomic, readonly) NSString *rctsa_title;
@property (nonatomic, readonly) NSString *rctsa_contentDescription;
@property (nonatomic, readonly) NSArray *rctsa_keywords;
@property (nonatomic, readonly) NSURL *rctsa_thumbnailURL;
@property (nonatomic, readonly) NSString *rctsa_uniqueIdentifier;
@property (nonatomic, readonly) NSString *rctsa_domain;
@property (nonatomic, readonly) NSDictionary *rctsa_userInfo;
@property (nonatomic, readonly) BOOL rctsa_eligibleForPublicIndexing;
@property (nonatomic, readonly) NSDate *rctsa_expirationDate;
@property (nonatomic, readonly) NSURL *rctsa_webpageURL;

@end
