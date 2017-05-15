//
//  RCTSearchApiManager.m
//  RCTSearchApi
//
//  Created by Daniil Konoplev on 17/11/2016.
//  Copyright © 2016 Ombori AB. All rights reserved.
//

@import CoreSpotlight;
@import MobileCoreServices;

#import "RCTSearchApiManager.h"
#import "NSDictionary+RCTSearchApi.h"
#import <React/RCTUtils.h>

static NSString *const kHandleContinueUserActivityNotification = @"handleContinueUserActivity";
static NSString *const kUserActivityKey = @"userActivity";
static NSString *const kSpotlightSearchItemTapped = @"spotlightSearchItemTapped";
static NSString *const kAppHistorySearchItemTapped = @"appHistorySearchItemTapped";

@interface RCTSearchApiManager ()

@property (nonatomic, strong) id<NSObject> continueUserActivityObserver;
@property (nonatomic, strong) id<NSObject> bundleDidLoadObserver;
@property (nonatomic, strong) NSMutableArray *userActivities;

@end

@implementation RCTSearchApiManager

RCT_EXPORT_MODULE();

#pragma mark - Initialization

- (instancetype)init {
    if ((self = [super init])) {
        __weak typeof(self) weakSelf = self;
        _continueUserActivityObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kHandleContinueUserActivityNotification
                                                                                          object:nil
                                                                                           queue:[NSOperationQueue mainQueue]
                                                                                      usingBlock:^(NSNotification * _Nonnull note) {
                                                                                          [weakSelf handleContinueUserActivity:note.userInfo[kUserActivityKey]];
                                                                                      }];
        _bundleDidLoadObserver = [[NSNotificationCenter defaultCenter] addObserverForName:RCTJavaScriptDidLoadNotification
                                                                                   object:nil
                                                                                    queue:[NSOperationQueue mainQueue]
                                                                               usingBlock:^(NSNotification * _Nonnull note) {
                                                                                   [weakSelf drainActivityQueue];
                                                                               }];
        _userActivities = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.continueUserActivityObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.bundleDidLoadObserver];
}

#pragma mark - Properties

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (NSArray<NSString *> *)supportedEvents {
    return @[kSpotlightSearchItemTapped, kAppHistorySearchItemTapped];
}

+ (NSMutableArray *)activityQueue {
    static NSMutableArray *activityQueue;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        activityQueue = [NSMutableArray array];
    });
    
    return activityQueue;
}

#pragma mark - Public API

+ (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *))restorationHandler {
    if (![userActivity.activityType isEqualToString:CSSearchableItemActionType] &&
        ![userActivity.activityType containsString:[NSBundle mainBundle].bundleIdentifier])
        return NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:kHandleContinueUserActivityNotification
                                                        object:nil
                                                      userInfo:@{kUserActivityKey: userActivity}];
    [[[self class] activityQueue] addObject:userActivity];
    return YES;
}

#pragma mark - Exported API

RCT_EXPORT_METHOD(indexItem:(NSDictionary *)item resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    return [self indexItems:@[item] resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(indexItems:(NSArray *)items resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    NSMutableArray *itemsToIndex = [NSMutableArray array];
    [items enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL * _Nonnull stop) {
        CSSearchableItem *searchableItem = [[CSSearchableItem alloc] initWithUniqueIdentifier:item.rctsa_uniqueIdentifier
                                                                             domainIdentifier:item.rctsa_domain
                                                                                 attributeSet:[self contentAttributeSetFromItem:item]];
        [itemsToIndex addObject:searchableItem];
    }];
    [[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:itemsToIndex completionHandler:[self completionBlockWithResolve:resolve reject:reject]];  
}

RCT_EXPORT_METHOD(deleteItemsWithIdentifiers:(NSArray *)identifiers resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [[CSSearchableIndex defaultSearchableIndex] deleteSearchableItemsWithIdentifiers:identifiers completionHandler:[self completionBlockWithResolve:resolve reject:reject]];
}

RCT_EXPORT_METHOD(deleteItemsInDomains:(NSArray *)identifiers resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [[CSSearchableIndex defaultSearchableIndex] deleteSearchableItemsWithDomainIdentifiers:identifiers completionHandler:[self completionBlockWithResolve:resolve reject:reject]];
}

RCT_REMAP_METHOD(deleteAllItems, resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [[CSSearchableIndex defaultSearchableIndex] deleteAllSearchableItemsWithCompletionHandler:[self completionBlockWithResolve:resolve reject:reject]];
}

RCT_EXPORT_METHOD(createUserActivity:(NSDictionary *)item resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:[NSBundle mainBundle].bundleIdentifier];
    userActivity.title = item.rctsa_title;
    userActivity.userInfo = item.rctsa_userInfo;
    userActivity.eligibleForPublicIndexing = item.rctsa_eligibleForPublicIndexing;
    userActivity.expirationDate = item.rctsa_expirationDate;
    userActivity.webpageURL = item.rctsa_webpageURL;
    userActivity.contentAttributeSet = [self contentAttributeSetFromItem:item];
    userActivity.eligibleForSearch = YES;
    userActivity.eligibleForHandoff = NO;
    [userActivity becomeCurrent];
    [self.userActivities addObject:userActivity];
    resolve(nil);
}

#pragma mark - Private API

- (void)drainActivityQueue {
    NSMutableArray *activityQueue = [[self class] activityQueue];
    
    for (NSUserActivity *userActivity in activityQueue) {
        [self handleContinueUserActivity:userActivity];
    }
    
    [activityQueue removeAllObjects];
}

- (void)handleContinueUserActivity:(NSUserActivity *)userActivity {
    if ([userActivity.activityType isEqualToString:CSSearchableItemActionType]) {
        NSString *uniqueItemIdentifier = userActivity.userInfo[CSSearchableItemActivityIdentifier];
        if (!uniqueItemIdentifier)
            return;
        [self sendEventWithName:kSpotlightSearchItemTapped body:uniqueItemIdentifier];
    } else {
        [self sendEventWithName:kAppHistorySearchItemTapped body:userActivity.userInfo];
    }
    
}

- (void (^)(NSError * _Nullable error))completionBlockWithResolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    return ^(NSError * _Nullable error) {
        if (error) {
            reject(RCTErrorUnspecified, error.localizedDescription, error);
        } else {
            resolve(nil);
        }
    };
}

- (CSSearchableItemAttributeSet *)contentAttributeSetFromItem:(NSDictionary *)item {
    CSSearchableItemAttributeSet *attributeSet = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:(NSString *)kUTTypeJSON];
    attributeSet.title = item.rctsa_title;
    attributeSet.contentDescription = item.rctsa_contentDescription;
    attributeSet.keywords = item.rctsa_keywords;
    attributeSet.thumbnailURL = item.rctsa_thumbnailURL;
    return attributeSet;
}

@end

