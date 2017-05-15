//
//  NSDictionary+RCTSearchApi.m
//  RCTSearchApi
//
//  Created by Daniil Konoplev on 17/11/2016.
//  Copyright © 2016 Ombori AB. All rights reserved.
//

#import "NSDictionary+RCTSearchApi.h"

@implementation NSDictionary (RCTSearchApi)

- (NSString *)rctsa_title {
    return self[@"title"];
}

- (NSString *)rctsa_contentDescription {
    return self[@"contentDescription"];
}

- (NSArray *)rctsa_keywords {
    return self[@"keywords"];
}

- (NSURL *)rctsa_thumbnailURL {
    NSString *uri = self[@"thumbnailUri"];
    if (!uri)
        return nil;
    return [NSURL URLWithString:uri];
}

- (NSString *)rctsa_uniqueIdentifier {
    return self[@"uniqueIdentifier"];
}

- (NSString *)rctsa_domain {
    return self[@"domain"];
}

- (NSDictionary *)rctsa_userInfo {
    return self[@"userInfo"];
}

- (BOOL)rctsa_eligibleForPublicIndexing {
    return [self[@"eligibleForPublicIndexing"] boolValue];
}

- (NSDate *)rctsa_expirationDate {
    return self[@"expirationDate"];
}

- (NSURL *)rctsa_webpageURL {
    NSString *uri = self[@"webpageURL"];
    if (!uri)
        return nil;
    return [NSURL URLWithString:uri];
}

@end
