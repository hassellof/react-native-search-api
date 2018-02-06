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
#import <React/RCTImageLoader.h>

static NSString *const kHandleContinueUserActivityNotification = @"handleContinueUserActivity";
static NSString *const kUserActivityKey = @"userActivity";
static NSString *const kSpotlightSearchItemTapped = @"spotlightSearchItemTapped";
static NSString *const kAppHistorySearchItemTapped = @"appHistorySearchItemTapped";
static NSString *const kApplicationLaunchOptionsUserActivityKey = @"UIApplicationLaunchOptionsUserActivityKey";

typedef void (^ContentAttributeSetCreationCompletion)(CSSearchableItemAttributeSet *set, NSError *error);

@interface RCTSearchApiManager ()

@property (nonatomic, strong) NSMutableArray *userActivities;

@end

@implementation RCTSearchApiManager

RCT_EXPORT_MODULE();

#pragma mark - Initialization

- (instancetype)init {
    if ((self = [super init])) {
        _userActivities = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Properties

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

- (NSArray<NSString *> *)supportedEvents {
    return @[kSpotlightSearchItemTapped, kAppHistorySearchItemTapped];
}

#pragma mark - Public API

+ (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *))restorationHandler {
    if (![userActivity.activityType isEqualToString:CSSearchableItemActionType] &&
        ![userActivity.activityType containsString:[NSBundle mainBundle].bundleIdentifier])
        return NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:kHandleContinueUserActivityNotification
                                                        object:nil
                                                      userInfo:@{kUserActivityKey: userActivity}];
    return YES;
}

- (void)startObserving {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleContinueUserActivity:) name:kHandleContinueUserActivityNotification object:nil];
}

- (void)stopObserving {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Exported API

RCT_REMAP_METHOD(getInitialSpotlightItem, retrieveInitialSpotlightItemWithResolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [self retrieveInitialSearchItemOfType:CSSearchableItemActionType bodyBlock:^id(NSUserActivity *activity) {
        return activity.userInfo[CSSearchableItemActivityIdentifier];
    } resolve:resolve];
}

RCT_REMAP_METHOD(getInitialAppHistoryItem, retrieveInitialAppHistoryItemWithResolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [self retrieveInitialSearchItemOfType:[NSBundle mainBundle].bundleIdentifier bodyBlock:^id(NSUserActivity *activity) {
        return activity.userInfo;
    } resolve:resolve];
}

RCT_EXPORT_METHOD(indexItems:(NSArray *)items resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    if (items.count == 0)
        return resolve(nil);
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray *itemsToIndex = [NSMutableArray array];
    [items enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_enter(group);
        [self createContentAttributeSetFromItem:item withCompletion:^(CSSearchableItemAttributeSet *set, NSError *error) {
            if (set && !error) {
                CSSearchableItem *searchableItem = [[CSSearchableItem alloc] initWithUniqueIdentifier:item.rctsa_uniqueIdentifier
                                                                                     domainIdentifier:item.rctsa_domain
                                                                                         attributeSet:set];
                [itemsToIndex addObject:searchableItem];
            }
            dispatch_group_leave(group);
        }];
    }];
    dispatch_group_notify(group, self.methodQueue, ^{
        if (itemsToIndex.count == items.count) {
            return [[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:itemsToIndex completionHandler:[self completionBlockWithResolve:resolve reject:reject]];
        } else {
            NSError *e = RCTErrorWithMessage(@"Failed to create one or more content attribute sets");
            reject(RCTErrorUnspecified, e.localizedDescription, e);
        }
    });
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
    [self createContentAttributeSetFromItem:item withCompletion:^(CSSearchableItemAttributeSet *set, NSError *error) {
        dispatch_async(self.methodQueue, ^{
            if (error || !set) {
                NSError *e = error ?: RCTErrorWithMessage(@"Could not create a content attribute set");
                reject(RCTErrorUnspecified, e.localizedDescription, e);
            } else {
                NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:[NSBundle mainBundle].bundleIdentifier];
                userActivity.contentAttributeSet = set;
                userActivity.title = item.rctsa_title;
                userActivity.userInfo = item.rctsa_userInfo;
                userActivity.eligibleForPublicIndexing = item.rctsa_eligibleForPublicIndexing;
                userActivity.expirationDate = item.rctsa_expirationDate;
                userActivity.webpageURL = item.rctsa_webpageURL;
                userActivity.eligibleForSearch = YES;
                userActivity.eligibleForHandoff = NO;
                [userActivity becomeCurrent];
                [self.userActivities addObject:userActivity];
                resolve(nil);
            }
        });
    }];
}

#pragma mark - Private API

- (void)handleContinueUserActivity:(NSNotification *)notification {
    NSUserActivity *userActivity = notification.userInfo[kUserActivityKey];
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

- (void)retrieveInitialSearchItemOfType:(NSString *)type bodyBlock:(id (^)(NSUserActivity *))block resolve:(RCTPromiseResolveBlock)resolve {
    NSDictionary *userActivityDictionary = self.bridge.launchOptions[UIApplicationLaunchOptionsUserActivityDictionaryKey];
    if (!userActivityDictionary)
        return resolve([NSNull null]);
    NSString *userActivityType = userActivityDictionary[UIApplicationLaunchOptionsUserActivityTypeKey];
    if (![userActivityType isEqualToString:type])
        return resolve([NSNull null]);
    NSUserActivity *userActivity = userActivityDictionary[kApplicationLaunchOptionsUserActivityKey];
    resolve(RCTNullIfNil(block(userActivity)));
}

- (void)createContentAttributeSetFromItem:(NSDictionary *)item withCompletion:(ContentAttributeSetCreationCompletion)completionBlock {
    CSSearchableItemAttributeSet *attributeSet = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:(NSString *)kUTTypeJSON];
    attributeSet.title = item.rctsa_title;
    attributeSet.contentDescription = item.rctsa_contentDescription;
    attributeSet.keywords = item.rctsa_keywords;
    if (item.rctsa_thumbnail) {
        [self loadImageFromSource:item.rctsa_thumbnail withCompletion:^(NSError *error, UIImage *image) {
            if (error || !image) {
                return completionBlock(nil, error ?: RCTErrorWithMessage(@"Could not load an image"));
            }
            attributeSet.thumbnailData = UIImagePNGRepresentation(image);
            completionBlock(attributeSet, nil);
        }];
    } else {
        completionBlock(attributeSet, nil);
    }
}

- (void)loadImageFromSource:(RCTImageSource *)source withCompletion:(RCTImageLoaderCompletionBlock)completionBlock {
    [self.bridge.imageLoader loadImageWithURLRequest:source.request
                                                size:source.size
                                               scale:source.scale
                                             clipped:YES
                                          resizeMode:RCTResizeModeStretch
                                       progressBlock:NULL
                                    partialLoadBlock:NULL
                                     completionBlock:completionBlock];
}

@end

