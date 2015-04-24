//
//  Branch_SDK.m
//  Branch-SDK
//
//  Created by Alex Austin on 6/5/14.
//  Copyright (c) 2014 Branch Metrics. All rights reserved.
//

#import "Branch.h"
#import "BranchServerInterface.h"
#import "BNCPreferenceHelper.h"
#import "BNCServerRequest.h"
#import "BNCServerResponse.h"
#import "BNCSystemObserver.h"
#import "BNCServerRequestQueue.h"
#import "BNCConfig.h"
#import "BNCError.h"
#import "BNCLinkData.h"
#import "BNCLinkCache.h"
#import "BNCEncodingUtils.h"

NSString * const BRANCH_FEATURE_TAG_SHARE = @"share";
NSString * const BRANCH_FEATURE_TAG_REFERRAL = @"referral";
NSString * const BRANCH_FEATURE_TAG_INVITE = @"invite";
NSString * const BRANCH_FEATURE_TAG_DEAL = @"deal";
NSString * const BRANCH_FEATURE_TAG_GIFT = @"gift";

NSString * const TAGS = @"tags";
NSString * const LINK_TYPE = @"type";
NSString * const ALIAS = @"alias";
NSString * const CHANNEL = @"channel";
NSString * const FEATURE = @"feature";
NSString * const STAGE = @"stage";
NSString * const DURATION = @"duration";
NSString * const DATA = @"data";
NSString * const IGNORE_UA_STRING = @"ignore_ua_string";

NSString * const IDENTITY = @"identity";
NSString * const IDENTITY_ID = @"identity_id";
NSString * const SESSION_ID = @"session_id";
NSString * const BUCKET = @"bucket";
NSString * const AMOUNT = @"amount";
NSString * const EVENT = @"event";
NSString * const METADATA = @"metadata";
NSString * const TOTAL = @"total";
NSString * const UNIQUE = @"unique";
NSString * const MESSAGE = @"message";
NSString * const ERROR = @"error";
NSString * const DEVICE_FINGERPRINT_ID = @"device_fingerprint_id";
NSString * const LINK = @"link";
NSString * const LINK_CLICK_ID = @"link_click_id";
NSString * const URL = @"url";
NSString * const REFERRING_DATA = @"referring_data";
NSString * const REFERRER = @"referrer";
NSString * const REFERREE = @"referree";
NSString * const CREDIT = @"credit";

NSString * const LENGTH = @"length";
NSString * const BEGIN_AFTER_ID = @"begin_after_id";
NSString * const DIRECTION = @"direction";

NSString * const REDEEM_CODE = @"$redeem_code";
NSString * const REFERRAL_CODE = @"referral_code";
NSString * const REFERRAL_CODE_CALCULATION_TYPE = @"calculation_type";
NSString * const REFERRAL_CODE_LOCATION = @"location";
NSString * const REFERRAL_CODE_TYPE = @"type";
NSString * const REFERRAL_CODE_PREFIX = @"prefix";
NSString * const REFERRAL_CODE_CREATION_SOURCE = @"creation_source";
NSString * const REFERRAL_CODE_EXPIRATION = @"expiration";

NSInteger REFERRAL_CREATION_SOURCE_SDK = 2;

static int BNCDebugTriggerDuration = 3;
static int BNCDebugTriggerFingers = 4;
static int BNCDebugTriggerFingersSimulator = 2;
static dispatch_queue_t bnc_asyncDebugQueue = nil;
static NSTimer *bnc_debugTimer = nil;
static UILongPressGestureRecognizer *BNCLongPress = nil;


#define DIRECTIONS @[@"desc", @"asc"]



@interface Branch() <BNCDebugConnectionDelegate, UIGestureRecognizerDelegate, BNCTestDelegate>

@property (strong, nonatomic) BranchServerInterface *bServerInterface;

@property (strong, nonatomic) NSTimer *sessionTimer;
@property (strong, nonatomic) BNCServerRequestQueue *requestQueue;
@property (strong, nonatomic) dispatch_semaphore_t processing_sema;
@property (strong, nonatomic) callbackWithParams sessionInitWithParamsCallback;
@property (assign, nonatomic) NSInteger networkCount;
@property (assign, nonatomic) BOOL isInitialized;
@property (assign, nonatomic) BOOL shouldCallSessionInitCallback;
@property (strong, nonatomic) BNCLinkCache *linkCache;

@end

@implementation Branch

#pragma mark - Public methods


#pragma mark - GetInstance methods

+ (Branch *)getInstance {
    NSString *branchKey = [BNCPreferenceHelper getBranchKey:YES];
    if (!branchKey || [branchKey isEqualToString:NO_STRING_VALUE]) {
        NSLog(@"Branch Warning: Please enter your branch_key in the plist!");
    }

    return [Branch getInstanceInternal];
}

+ (Branch *)getTestInstance {
    NSString *branchKey = [BNCPreferenceHelper getBranchKey:NO];
    if (!branchKey || [branchKey isEqualToString:NO_STRING_VALUE]) {
        NSLog(@"Branch Warning: Please enter your branch_key in the plist!");
    }

    return [Branch getInstanceInternal];
}

+ (Branch *)getInstance:(NSString *)branchKey {
    if ([branchKey rangeOfString:@"key_"].location != NSNotFound) {
        [BNCPreferenceHelper setBranchKey:branchKey];
    }
    else {
        [BNCPreferenceHelper setAppKey:branchKey];
    }
    
    return [Branch getInstanceInternal];
}

- (id)initWithInterface:(BranchServerInterface *)interface queue:(BNCServerRequestQueue *)queue cache:(BNCLinkCache *)cache {
    if (self = [super init]) {
        _bServerInterface = interface;
        _requestQueue = queue;
        _linkCache = cache;
        
        _isInitialized = NO;
        _shouldCallSessionInitCallback = YES;
        _processing_sema = dispatch_semaphore_create(1);
        _networkCount = 0;
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    }

    return self;
}


#pragma mark - BrachActivityItemProvider methods

+ (BranchActivityItemProvider *)getBranchActivityItemWithParams:(NSDictionary *)params
                                                     andTags:(NSArray *)tags
                                                  andFeature:(NSString *)feature
                                                    andStage:(NSString *)stage
                                                    andAlias:(NSString *)alias {
    return [[BranchActivityItemProvider alloc] initWithParams:params andTags:tags andFeature:feature andStage:stage andAlias:alias];
}

+ (BranchActivityItemProvider *)getBranchActivityItemWithParams:(NSDictionary *)params {
    
    return [[BranchActivityItemProvider alloc] initWithParams:params andTags:nil andFeature:nil andStage:nil andAlias:nil];
}

+ (BranchActivityItemProvider *)getBranchActivityItemWithParams:(NSDictionary *)params
                                                         andFeature:(NSString *)feature {
    
    return [[BranchActivityItemProvider alloc] initWithParams:params andTags:nil andFeature:feature andStage:nil andAlias:nil];
}

+ (BranchActivityItemProvider *)getBranchActivityItemWithParams:(NSDictionary *)params
                                                         andFeature:(NSString *)feature
                                                           andStage:(NSString *)stage {
    
    return [[BranchActivityItemProvider alloc] initWithParams:params andTags:nil andFeature:feature andStage:stage andAlias:nil];
}

+ (BranchActivityItemProvider *)getBranchActivityItemWithParams:(NSDictionary *)params
                                                         andFeature:(NSString *)feature
                                                           andStage:(NSString *)stage
                                                            andTags:(NSArray *)tags {
    
    return [[BranchActivityItemProvider alloc] initWithParams:params andTags:tags andFeature:feature andStage:stage andAlias:nil];
}

+ (BranchActivityItemProvider *)getBranchActivityItemWithParams:(NSDictionary *)params
                                                            andFeature:(NSString *)feature
                                                           andStage:(NSString *)stage
                                                           andAlias:(NSString *)alias {
    
    return [[BranchActivityItemProvider alloc] initWithParams:params andTags:nil andFeature:feature andStage:stage andAlias:alias];
}


#pragma mark - Configuration methods

+ (void)setDebug {
    [BNCPreferenceHelper setDevDebug];
}

- (void)resetUserSession {
    self.isInitialized = NO;
}

- (void)setNetworkTimeout:(NSInteger)timeout {
    [BNCPreferenceHelper setTimeout:timeout];
}

- (void)setMaxRetries:(NSInteger)maxRetries {
    [BNCPreferenceHelper setRetryCount:maxRetries];
}

- (void)setRetryInterval:(NSInteger)retryInterval {
    [BNCPreferenceHelper setRetryInterval:retryInterval];
}


#pragma mark - InitSession methods

- (void)initSession {
    [self initSessionAndRegisterDeepLinkHandler:nil];
}

- (void)initSessionWithLaunchOptions:(NSDictionary *)options {
    if (![options objectForKey:UIApplicationLaunchOptionsURLKey]) {
        [self initSessionAndRegisterDeepLinkHandler:nil];
    }
}

- (void)initSession:(BOOL)isReferrable {
    [self initSession:isReferrable andRegisterDeepLinkHandler:nil];
}

- (void)initSessionWithLaunchOptions:(NSDictionary *)options andRegisterDeepLinkHandler:(callbackWithParams)callback {
    self.sessionInitWithParamsCallback = callback;

    if (![BNCSystemObserver getUpdateState] && ![self hasUser]) {
        [BNCPreferenceHelper setIsReferrable];
    } else {
        [BNCPreferenceHelper clearIsReferrable];
    }
    
    if (![options objectForKey:UIApplicationLaunchOptionsURLKey]) {
        [self initUserSessionAndCallCallback:YES];
    }
}

- (void)initSessionWithLaunchOptions:(NSDictionary *)options isReferrable:(BOOL)isReferrable {
    if (![options objectForKey:UIApplicationLaunchOptionsURLKey]) {
        [self initSession:isReferrable andRegisterDeepLinkHandler:nil];
    }
}

- (void)initSession:(BOOL)isReferrable andRegisterDeepLinkHandler:(callbackWithParams)callback {
    self.sessionInitWithParamsCallback = callback;

    if (isReferrable) {
        [BNCPreferenceHelper setIsReferrable];
    } else {
        [BNCPreferenceHelper clearIsReferrable];
    }
    
    [self initUserSessionAndCallCallback:YES];
}

- (void)initSessionWithLaunchOptions:(NSDictionary *)options isReferrable:(BOOL)isReferrable andRegisterDeepLinkHandler:(callbackWithParams)callback {
    self.sessionInitWithParamsCallback = callback;

    if (![options objectForKey:UIApplicationLaunchOptionsURLKey]) {
        [self initSession:isReferrable andRegisterDeepLinkHandler:callback];
    }
}

- (void)initSessionAndRegisterDeepLinkHandler:(callbackWithParams)callback {
    self.sessionInitWithParamsCallback = callback;

    if (![BNCSystemObserver getUpdateState] && ![self hasUser]) {
        [BNCPreferenceHelper setIsReferrable];
    } else {
        [BNCPreferenceHelper clearIsReferrable];
    }
    
    [self initUserSessionAndCallCallback:YES];
}

- (BOOL)handleDeepLink:(NSURL *)url {
    BOOL handled = NO;
    if (url) {
        NSString *query = [url fragment];
        if (!query) {
            query = [url query];
        }

        NSDictionary *params = [BNCEncodingUtils decodeQueryStringToDictionary:query];
        if ([params objectForKey:@"link_click_id"]) {
            handled = YES;
            [BNCPreferenceHelper setLinkClickIdentifier:[params objectForKey:@"link_click_id"]];
        }
    }
 
    [BNCPreferenceHelper setIsReferrable];

    [self initUserSessionAndCallCallback:YES];

    return handled;
}


#pragma mark - Identity methods

- (void)setIdentity:(NSString *)userId {
    [self setIdentity:userId withCallback:NULL];
}

- (void)setIdentity:(NSString *)userId withCallback:(callbackWithParams)callback {
    if (!userId || [[BNCPreferenceHelper getUserIdentity] isEqualToString:userId]) {
        if (callback) {
            callback([self getFirstReferringParams], nil);
        }
        return;
    }
    
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }
    
    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_IDENTIFY;
    NSMutableDictionary *post = [[NSMutableDictionary alloc] initWithObjects:@[
                                                                               userId,
                                                                               [BNCPreferenceHelper getDeviceFingerprintID],
                                                                               [BNCPreferenceHelper getSessionID],
                                                                               [BNCPreferenceHelper getIdentityID]]
                                                                     forKeys:@[
                                                                               IDENTITY,
                                                                               DEVICE_FINGERPRINT_ID,
                                                                               SESSION_ID,
                                                                               IDENTITY_ID]];
    req.postData = post;
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];

        if (error) {
            if (callback) {
                callback(nil, error);
            }
            
            // Re-enqueue requests that failed, but are valid (not 400s)
            if (error.code < 400 || error.code >= 500) {
                [self setIdentity:userId withCallback:NULL];
            }
            
            [self processNextQueueItem];
            return;
        }

        [BNCPreferenceHelper setIdentityID:[response.data objectForKey:IDENTITY_ID]];
        [BNCPreferenceHelper setUserURL:[response.data objectForKey:LINK]];
        
        if ([response.data objectForKey:REFERRING_DATA]) {
            [BNCPreferenceHelper setInstallParams:[response.data objectForKey:REFERRING_DATA]];
        }
        
        if (self.requestQueue.size > 0) {
            BNCServerRequest *req = [self.requestQueue peek];
            if (req && req.postData && [req.postData objectForKey:IDENTITY]) {
                [BNCPreferenceHelper setUserIdentity:[req.postData objectForKey:IDENTITY]];
            }
        }
        
        if (callback) {
            callback([self getFirstReferringParams], nil);
        }
        
        [self processNextQueueItem];
    };

    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}

- (void)logout {
    if (!self.isInitialized) {
        NSLog(@"Branch is not initialized, cannot logout");
        return;
    }

    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_LOGOUT;
    NSMutableDictionary *post = [[NSMutableDictionary alloc] initWithObjects:@[
                                                                               [BNCPreferenceHelper getDeviceFingerprintID],
                                                                               [BNCPreferenceHelper getSessionID],
                                                                               [BNCPreferenceHelper getIdentityID]]
                                                                     forKeys:@[
                                                                               DEVICE_FINGERPRINT_ID,
                                                                               SESSION_ID,
                                                                               IDENTITY_ID]];
    req.postData = post;
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [BNCPreferenceHelper setSessionID:[response.data objectForKey:SESSION_ID]];
        [BNCPreferenceHelper setIdentityID:[response.data objectForKey:IDENTITY_ID]];
        [BNCPreferenceHelper setUserURL:[response.data objectForKey:LINK]];
        
        [BNCPreferenceHelper setUserIdentity:NO_STRING_VALUE];
        [BNCPreferenceHelper setInstallParams:NO_STRING_VALUE];
        [BNCPreferenceHelper setSessionParams:NO_STRING_VALUE];
        [BNCPreferenceHelper clearUserCreditsAndCounts];
        
        [self completeRequest];
        [self processNextQueueItem];
    };

    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}


#pragma mark - User Action methods

- (void)loadActionCountsWithCallback:(callbackWithStatus)callback {
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }

    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_GET_REFERRAL_COUNTS;
    req.postData = [[NSMutableDictionary alloc] init];
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];
        if (error) {
            if (callback) {
                callback(NO, error);
            }
            [self processNextQueueItem];
            return;
        }

        BOOL hasUpdated = NO;
        for (NSString *key in response.data) {
            NSDictionary *counts = [response.data objectForKey:key];
            NSInteger total = [[counts objectForKey:TOTAL] integerValue];
            NSInteger unique = [[counts objectForKey:UNIQUE] integerValue];
            
            if (total != [BNCPreferenceHelper getActionTotalCount:key] || unique != [BNCPreferenceHelper getActionUniqueCount:key]) {
                hasUpdated = YES;
            }
            
            [BNCPreferenceHelper setActionTotalCount:key withCount:total];
            [BNCPreferenceHelper setActionUniqueCount:key withCount:unique];
        }
        
        if (callback) {
            callback(hasUpdated, nil);
        }
        
        [self processNextQueueItem];
    };
    
    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}

- (NSInteger)getTotalCountsForAction:(NSString *)action {
    return [BNCPreferenceHelper getActionTotalCount:action];
}

- (NSInteger)getUniqueCountsForAction:(NSString *)action {
    return [BNCPreferenceHelper getActionUniqueCount:action];
}

- (void)userCompletedAction:(NSString *)action {
    [self userCompletedAction:action withState:nil];
}

- (void)userCompletedAction:(NSString *)action withState:(NSDictionary *)state {
    if (!action) {
        return;
    }
    
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }
    
    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_COMPLETE_ACTION;
    
    NSMutableDictionary *post = [@{
        EVENT: action,
        METADATA: state ?: [NSNull null],
        DEVICE_FINGERPRINT_ID: [BNCPreferenceHelper getDeviceFingerprintID],
        IDENTITY_ID: [BNCPreferenceHelper getIdentityID],
        SESSION_ID: [BNCPreferenceHelper getSessionID],
    } mutableCopy];
    
    req.postData = post;
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];

        // Re-enqueue requests that failed, but are valid (not 400s)
        if (error && (error.code < 400 || error.code >= 500)) {
            [self userCompletedAction:action withState:state];
        }

        [self processNextQueueItem];
    };

    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}


#pragma mark - Credit methods

- (void)loadRewardsWithCallback:(callbackWithStatus)callback {
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }

    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.postData = [[NSMutableDictionary alloc] init];
    req.tag = REQ_TAG_GET_REWARDS;
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];
        if (error) {
            if (callback) {
                callback(NO, error);
            }
            [self processNextQueueItem];
            return;
        }

        BOOL hasUpdated = NO;
        for (NSString *key in response.data) {
            NSInteger credits = [[response.data objectForKey:key] integerValue];
            
            if (credits != [BNCPreferenceHelper getCreditCountForBucket:key]) {
                hasUpdated = YES;
            }
            
            [BNCPreferenceHelper setCreditCount:credits forBucket:key];
        }
        
        if (callback) {
            callback(hasUpdated, nil);
        }
        
        [self processNextQueueItem];
    };
    
    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}

- (NSInteger)getCredits {
    return [BNCPreferenceHelper getCreditCount];
}

- (void)redeemRewards:(NSInteger)count {
    [self redeemRewards:count forBucket:@"default"];
}

- (NSInteger)getCreditsForBucket:(NSString *)bucket {
    return [BNCPreferenceHelper getCreditCountForBucket:bucket];
}

- (void)redeemRewards:(NSInteger)count forBucket:(NSString *)bucket {
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }

    NSInteger amountToRedeem = count;
    NSInteger totalAvailableCredits = [BNCPreferenceHelper getCreditCountForBucket:bucket];

    if (count > totalAvailableCredits) {
        NSLog(@"Branch Warning: You're trying to redeem more credits than are available. Have you updated loaded rewards?");
        return;
    }
    
    if (amountToRedeem > 0) {
        BNCServerRequest *req = [[BNCServerRequest alloc] init];
        req.tag = REQ_TAG_REDEEM_REWARDS;
        NSMutableDictionary *post = [[NSMutableDictionary alloc] initWithObjects:@[
                                                                                   bucket,
                                                                                   [NSNumber numberWithInteger:amountToRedeem],
                                                                                   [BNCPreferenceHelper getDeviceFingerprintID],
                                                                                   [BNCPreferenceHelper getIdentityID],
                                                                                   [BNCPreferenceHelper getSessionID]]
                                                                         forKeys:@[
                                                                                   BUCKET,
                                                                                   AMOUNT,
                                                                                   DEVICE_FINGERPRINT_ID,
                                                                                   IDENTITY_ID,
                                                                                   SESSION_ID]];
        req.postData = post;
        req.callback = ^(BNCServerResponse *response, NSError *error) {
            if (!error) {
                // Update local balance
                NSInteger updatedBalance = totalAvailableCredits - amountToRedeem;
                [BNCPreferenceHelper setCreditCount:updatedBalance forBucket:bucket];
            }
            
            [self completeRequest];
            [self processNextQueueItem];
        };

        [self.requestQueue enqueue:req];
        [self processNextQueueItem];
    }
}

- (void)getCreditHistoryWithCallback:(callbackWithList)callback {
    [self getCreditHistoryForBucket:nil after:nil number:100 order:BranchMostRecentFirst andCallback:callback];
}

- (void)getCreditHistoryForBucket:(NSString *)bucket andCallback:(callbackWithList)callback {
    [self getCreditHistoryForBucket:bucket after:nil number:100 order:BranchMostRecentFirst andCallback:callback];
}

- (void)getCreditHistoryAfter:(NSString *)creditTransactionId number:(NSInteger)length order:(CreditHistoryOrder)order andCallback:(callbackWithList)callback {
    [self getCreditHistoryForBucket:nil after:creditTransactionId number:length order:order andCallback:callback];
}

- (void)getCreditHistoryForBucket:(NSString *)bucket after:(NSString *)creditTransactionId number:(NSInteger)length order:(CreditHistoryOrder)order andCallback:(callbackWithList)callback {
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }

    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_GET_REWARD_HISTORY;
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjects:@[
                                                                             [BNCPreferenceHelper getDeviceFingerprintID],
                                                                             [BNCPreferenceHelper getIdentityID],
                                                                             [BNCPreferenceHelper getSessionID],
                                                                             [NSNumber numberWithLong:length],
                                                                             DIRECTIONS[order]
                                                                             ]
                                                                   forKeys:@[DEVICE_FINGERPRINT_ID,
                                                                             IDENTITY_ID,
                                                                             SESSION_ID,
                                                                             LENGTH,
                                                                             DIRECTION]];
    if (bucket) {
        [data setObject:bucket forKey:BUCKET];
    }

    if (creditTransactionId) {
        [data setObject:creditTransactionId forKey:BEGIN_AFTER_ID];
    }

    req.postData = data;
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];
        if (error) {
            if (callback) {
                callback(nil, error);
            }
            [self processNextQueueItem];
            return;
        }
        for (NSMutableDictionary *transaction in response.data) {
            if ([transaction objectForKey:REFERRER] == [NSNull null]) {
                [transaction removeObjectForKey:REFERRER];
            }
            if ([transaction objectForKey:REFERREE] == [NSNull null]) {
                [transaction removeObjectForKey:REFERREE];
            }
        }
        
        if (callback) {
            callback(response.data, nil);
        }
        
        [self processNextQueueItem];
    };

    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}

- (NSDictionary *)getFirstReferringParams {
    NSString *storedParam = [BNCPreferenceHelper getInstallParams];
    return [BNCEncodingUtils decodeJsonStringToDictionary:storedParam];
}

- (NSDictionary *)getLatestReferringParams {
    NSString *storedParam = [BNCPreferenceHelper getSessionParams];
    return [BNCEncodingUtils decodeJsonStringToDictionary:storedParam];
}


#pragma mark - ContentUrl methods

- (NSString *)getContentUrlWithParams:(NSDictionary *)params andChannel:(NSString *)channel {
    return [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:BRANCH_FEATURE_TAG_SHARE andStage:nil andParams:params ignoreUAString:nil];
}

- (NSString *)getContentUrlWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel {
    return [self generateShortUrl:tags andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:BRANCH_FEATURE_TAG_SHARE andStage:nil andParams:params ignoreUAString:nil];
}

- (void)getContentUrlWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:tags andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:BRANCH_FEATURE_TAG_SHARE andStage:nil andParams:params andCallback:callback];
}

- (void)getContentUrlWithParams:(NSDictionary *)params andChannel:(NSString *)channel andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:BRANCH_FEATURE_TAG_SHARE andStage:nil andParams:params andCallback:callback];
}


#pragma mark - ShortUrl methods

- (NSString *)getShortURL {
    return [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:nil andFeature:nil andStage:nil andParams:nil ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params {
    return [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:nil andFeature:nil andStage:nil andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage {
    return [self generateShortUrl:tags andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andAlias:(NSString *)alias {
    return [self generateShortUrl:tags andAlias:alias andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andAlias:(NSString *)alias ignoreUAString:(NSString *)ignoreUAString {
    return [self generateShortUrl:tags andAlias:alias andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:ignoreUAString];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andType:(BranchLinkType)type {
    return [self generateShortUrl:tags andAlias:nil andType:type andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andMatchDuration:(NSUInteger)duration {
    return [self generateShortUrl:tags andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:duration andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage {
    return [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andAlias:(NSString *)alias {
    return [self generateShortUrl:nil andAlias:alias andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andType:(BranchLinkType)type {
    return [self generateShortUrl:nil andAlias:nil andType:type andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andMatchDuration:(NSUInteger)duration {
    return [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:duration andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
}

- (NSString *)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature {
    return [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:nil andParams:params ignoreUAString:nil];
}

- (void)getShortURLWithCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:nil andFeature:nil andStage:nil andParams:nil andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:nil andFeature:nil andStage:nil andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:tags andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andAlias:(NSString *)alias andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:tags andAlias:alias andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andType:(BranchLinkType)type andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:tags andAlias:nil andType:type andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andMatchDuration:(NSUInteger)duration andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:tags andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:duration andChannel:channel andFeature:feature andStage:stage andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andAlias:(NSString *)alias andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:alias andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andType:(BranchLinkType)type andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:nil andType:type andMatchDuration:0 andChannel:channel andFeature:feature andStage:stage andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andMatchDuration:(NSUInteger)duration andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:duration andChannel:channel andFeature:feature andStage:stage andParams:params andCallback:callback];
}

- (void)getShortURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andFeature:(NSString *)feature andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:feature andStage:nil andParams:params andCallback:callback];
}

#pragma mark - LongUrl methods
- (NSString *)getLongURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andTags:(NSArray *)tags andFeature:(NSString *)feature andStage:(NSString *)stage andAlias:(NSString *)alias {
    return [self generateLongURLWithParams:params andChannel:channel andTags:tags andFeature:feature andStage:stage andAlias:alias];
}

- (NSString *)getLongURLWithParams:(NSDictionary *)params {
    return [self generateLongURLWithParams:params andChannel:nil andTags:nil andFeature:nil andStage:nil andAlias:nil];
}

- (NSString *)getLongURLWithParams:(NSDictionary *)params andFeature:(NSString *)feature {
    return [self generateLongURLWithParams:params andChannel:nil andTags:nil andFeature:feature andStage:nil andAlias:nil];
}

- (NSString *)getLongURLWithParams:(NSDictionary *)params andFeature:(NSString *)feature andStage:(NSString *)stage {
    return [self generateLongURLWithParams:params andChannel:nil andTags:nil andFeature:feature andStage:stage andAlias:nil];
}

- (NSString *)getLongURLWithParams:(NSDictionary *)params andFeature:(NSString *)feature andStage:(NSString *)stage andTags:(NSArray *)tags {
    return [self generateLongURLWithParams:params andChannel:nil andTags:tags andFeature:feature andStage:stage andAlias:nil];
}

- (NSString *)getLongURLWithParams:(NSDictionary *)params andFeature:(NSString *)feature andStage:(NSString *)stage andAlias:(NSString *)alias {
    return [self generateLongURLWithParams:params andChannel:nil andTags:nil andFeature:feature andStage:stage andAlias:alias];
}

#pragma mark - Referral methods

- (NSString *)getReferralUrlWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel {
    return [self generateShortUrl:tags andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:BRANCH_FEATURE_TAG_REFERRAL andStage:nil andParams:params ignoreUAString:nil];
}

- (NSString *)getReferralUrlWithParams:(NSDictionary *)params andChannel:(NSString *)channel {
    return [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:BRANCH_FEATURE_TAG_REFERRAL andStage:nil andParams:params ignoreUAString:nil];
}

- (void)getReferralUrlWithParams:(NSDictionary *)params andTags:(NSArray *)tags andChannel:(NSString *)channel andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:tags andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:BRANCH_FEATURE_TAG_REFERRAL andStage:nil andParams:params andCallback:callback];
}

- (void)getReferralUrlWithParams:(NSDictionary *)params andChannel:(NSString *)channel andCallback:(callbackWithUrl)callback {
    [self generateShortUrl:nil andAlias:nil andType:BranchLinkTypeUnlimitedUse andMatchDuration:0 andChannel:channel andFeature:BRANCH_FEATURE_TAG_REFERRAL andStage:nil andParams:params andCallback:callback];
}

- (void)getReferralCodeWithCallback:(callbackWithParams)callback {
    [self getReferralCodeWithPrefix:nil amount:0 expiration:nil bucket:nil calculationType:BranchUnlimitedRewards location:BranchReferringUser andCallback:callback];
}

- (void)getReferralCodeWithAmount:(NSInteger)amount andCallback:(callbackWithParams)callback {
    [self getReferralCodeWithPrefix:nil amount:amount expiration:nil bucket:@"default" calculationType:BranchUnlimitedRewards location:BranchReferringUser andCallback:callback];
}

- (void)getReferralCodeWithPrefix:(NSString *)prefix amount:(NSInteger)amount andCallback:(callbackWithParams)callback {
    [self getReferralCodeWithPrefix:prefix amount:amount expiration:nil bucket:@"default" calculationType:BranchUnlimitedRewards location:BranchReferringUser andCallback:callback];
}

- (void)getReferralCodeWithAmount:(NSInteger)amount expiration:(NSDate *)expiration andCallback:(callbackWithParams)callback {
    [self getReferralCodeWithPrefix:nil amount:amount expiration:expiration bucket:@"default" calculationType:BranchUnlimitedRewards location:BranchReferringUser andCallback:callback];
}

- (void)getReferralCodeWithPrefix:(NSString *)prefix amount:(NSInteger)amount expiration:(NSDate *)expiration andCallback:(callbackWithParams)callback {
    [self getReferralCodeWithPrefix:prefix amount:amount expiration:expiration bucket:@"default" calculationType:BranchUnlimitedRewards location:BranchReferringUser andCallback:callback];
}

- (void)getReferralCodeWithPrefix:(NSString *)prefix amount:(NSInteger)amount expiration:(NSDate *)expiration bucket:(NSString *)bucket calculationType:(ReferralCodeCalculation)calcType location:(ReferralCodeLocation)location andCallback:(callbackWithParams)callback {
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }

    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_GET_REFERRAL_CODE;
    NSMutableArray *keys = [NSMutableArray arrayWithArray:@[DEVICE_FINGERPRINT_ID,
                                                            IDENTITY_ID,
                                                            SESSION_ID,
                                                            REFERRAL_CODE_CALCULATION_TYPE,
                                                            REFERRAL_CODE_LOCATION,
                                                            REFERRAL_CODE_TYPE,
                                                            REFERRAL_CODE_CREATION_SOURCE,
                                                            AMOUNT,
                                                            BUCKET]];
    NSMutableArray *values = [NSMutableArray arrayWithArray:@[[BNCPreferenceHelper getDeviceFingerprintID],
                                                              [BNCPreferenceHelper getIdentityID],
                                                              [BNCPreferenceHelper getSessionID],
                                                              [NSNumber numberWithLong:calcType],
                                                              [NSNumber numberWithLong:location],
                                                              CREDIT,
                                                              [NSNumber numberWithLong:REFERRAL_CREATION_SOURCE_SDK],
                                                              [NSNumber numberWithLong:amount],
                                                              bucket]];
    if (prefix && prefix.length > 0) {
        [keys addObject:REFERRAL_CODE_PREFIX];
        [values addObject:prefix];
    }

    if (expiration) {
        [keys addObject:REFERRAL_CODE_EXPIRATION];
        [values addObject:expiration];
    }
    
    NSMutableDictionary *post = [NSMutableDictionary dictionaryWithObjects:values forKeys:keys];
    req.postData = post;
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];
        if (error) {
            if (callback) {
                callback(nil, error);
            }
            [self processNextQueueItem];
            return;
        }
        
        if (![response.data objectForKey:REFERRAL_CODE]) {
            error = [NSError errorWithDomain:BNCErrorDomain code:BNCInvalidReferralCodeError userInfo:@{ NSLocalizedDescriptionKey: @"Referral code with specified parameter set is already taken for a different user" }];
        }
        
        if (callback) {
            callback(response.data, error);
        }
        
        [self processNextQueueItem];
    };

    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}

- (void)validateReferralCode:(NSString *)code andCallback:(callbackWithParams)callback {
    if (!code) {
        if (callback) {
            callback(nil, [NSError errorWithDomain:BNCErrorDomain code:BNCInvalidReferralCodeError userInfo:@{ NSLocalizedDescriptionKey: @"No code specified" }]);
        }
        return;
    }

    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }
    
    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_VALIDATE_REFERRAL_CODE;
    NSMutableDictionary *post = [NSMutableDictionary dictionaryWithObjects:@[code,
                                                                             [BNCPreferenceHelper getIdentityID],
                                                                             [BNCPreferenceHelper getDeviceFingerprintID],
                                                                             [BNCPreferenceHelper getSessionID]]
                                                                   forKeys:@[REFERRAL_CODE,
                                                                             IDENTITY_ID,
                                                                             DEVICE_FINGERPRINT_ID,
                                                                             SESSION_ID]];
    req.postData = post;
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];
        if (error) {
            if (callback) {
                callback(nil, error);
            }
            [self processNextQueueItem];
            return;
        }
        
        if (![response.data objectForKey:REFERRAL_CODE]) {
            error = [NSError errorWithDomain:BNCErrorDomain code:BNCInvalidReferralCodeError userInfo:@{ NSLocalizedDescriptionKey: @"Referral code is invalid - it may have already been used or the code might not exist" }];
        }
        
        if (callback) {
            callback(response.data, error);
        }
        
        [self processNextQueueItem];
    };
    
    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}

- (void)applyReferralCode:(NSString *)code andCallback:(callbackWithParams)callback {
    if (!code) {
        if (callback) {
            callback(nil, [NSError errorWithDomain:BNCErrorDomain code:BNCInvalidReferralCodeError userInfo:@{ NSLocalizedDescriptionKey: @"No code specified" }]);
        }
        return;
    }
    
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }
    
    
    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_APPLY_REFERRAL_CODE;
    NSMutableDictionary *post = [NSMutableDictionary dictionaryWithObjects:@[code,
                                                                             [BNCPreferenceHelper getIdentityID],
                                                                             [BNCPreferenceHelper getSessionID],
                                                                             [BNCPreferenceHelper getDeviceFingerprintID]]
                                                                   forKeys:@[REFERRAL_CODE,
                                                                             IDENTITY_ID,
                                                                             SESSION_ID,
                                                                             DEVICE_FINGERPRINT_ID]];
    req.postData = post;
    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];
        if (error) {
            if (callback) {
                callback(nil, error);
            }
            [self processNextQueueItem];
            return;
        }

        if (![response.data objectForKey:REFERRAL_CODE]) {
            error = [NSError errorWithDomain:BNCErrorDomain code:BNCInvalidReferralCodeError userInfo:@{ NSLocalizedDescriptionKey: @"Referral code is invalid - it may have already been used or the code might not exist" }];
        }
        
        if (callback) {
            callback(response.data, error);
        }
        
        [self processNextQueueItem];
    };

    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}


#pragma mark - Private methods

+ (Branch *)getInstanceInternal {
    static Branch *branch;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        branch = [[Branch alloc] initWithInterface:[[BranchServerInterface alloc] init] queue:[BNCServerRequestQueue getInstance] cache:[[BNCLinkCache alloc] init]];
    });

    return branch;
}


#pragma mark - URL Generation methods

- (void)generateShortUrl:(NSArray *)tags andAlias:(NSString *)alias andType:(BranchLinkType)type andMatchDuration:(NSUInteger)duration andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andParams:(NSDictionary *)params andCallback:(callbackWithUrl)callback {
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:NO];
    }
    
    BNCLinkData *linkData = [self prepareLinkDataFor:tags andAlias:alias andType:type andMatchDuration:duration andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:nil];
    
    if ([self.linkCache objectForKey:linkData]) {
        if (callback) {
            callback([self.linkCache objectForKey:linkData], nil);
        }
        return;
    }

    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_GET_CUSTOM_URL;
    req.postData = linkData.data;

    req.callback = ^(BNCServerResponse *response, NSError *error) {
        [self completeRequest];
        if (error) {
            if (callback) {
                NSString *failedUrl = nil;
                NSString *userUrl = [BNCPreferenceHelper getUserURL];
                if (![userUrl isEqualToString:NO_STRING_VALUE]) {
                    failedUrl = [self longUrlWithBaseUrl:userUrl params:params tags:tags feature:feature channel:channel stage:stage alias:alias duration:duration type:type];
                }

                callback(failedUrl, error);
            }
            [self processNextQueueItem];
            return;
        }
        
        NSString *url = [response.data objectForKey:URL];
        
        // cache the link
        if (url) {
            [self.linkCache setObject:url forKey:linkData];
        }

        if (callback) {
            callback(url, nil);
        }
        
        [self processNextQueueItem];
    };
    
    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}

- (NSString *)generateShortUrl:(NSArray *)tags andAlias:(NSString *)alias andType:(BranchLinkType)type andMatchDuration:(NSUInteger)duration andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andParams:(NSDictionary *)params ignoreUAString:(NSString *)ignoreUAString {
    NSString *shortURL = nil;
    
    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_GET_CUSTOM_URL;
    BNCLinkData *linkData = [self prepareLinkDataFor:tags andAlias:alias andType:type andMatchDuration:duration andChannel:channel andFeature:feature andStage:stage andParams:params ignoreUAString:ignoreUAString];
    
    // If an ignore UA string is present, we always get a new url. Otherwise, if we've already seen this request, use the cached version
    if (!ignoreUAString && [self.linkCache objectForKey:linkData]) {
        shortURL = [self.linkCache objectForKey:linkData];
    }
    else {
        req.postData = linkData.data;
        
        if (self.isInitialized) {
            [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"Created custom url synchronously"];
            BNCServerResponse *serverResponse = [self.bServerInterface createCustomUrl:req];
            shortURL = [serverResponse.data objectForKey:URL];
            
            // cache the link
            if (shortURL) {
                [self.linkCache setObject:shortURL forKey:linkData];
            }
        }
        else {
            NSLog(@"Branch SDK Error: making request before init succeeded!");
        }
    }
    
    return shortURL;
}

- (NSString *)generateLongURLWithParams:(NSDictionary *)params andChannel:(NSString *)channel andTags:(NSArray *)tags andFeature:(NSString *)feature andStage:(NSString *)stage andAlias:(NSString *)alias {
    NSString *appIdentifier = [BNCPreferenceHelper getBranchKey];
    if ([appIdentifier isEqualToString:NO_STRING_VALUE]) {
        appIdentifier = [BNCPreferenceHelper getAppKey];
    }
    
    if ([appIdentifier isEqualToString:NO_STRING_VALUE]) {
        NSLog(@"No Branch Key specified, cannot create a long url");
        return nil;
    }
    
    NSString *baseLongUrl = [NSString stringWithFormat:@"%@/a/%@", BNC_LINK_URL, appIdentifier];

    return [self longUrlWithBaseUrl:baseLongUrl params:params tags:tags feature:feature channel:nil stage:stage alias:alias duration:0 type:BranchLinkTypeUnlimitedUse];
}

- (NSString *)longUrlWithBaseUrl:(NSString *)baseUrl params:(NSDictionary *)params tags:(NSArray *)tags feature:(NSString *)feature channel:(NSString *)channel stage:(NSString *)stage alias:(NSString *)alias duration:(NSUInteger)duration type:(BranchLinkType)type {
    NSMutableString *longUrl = [[NSMutableString alloc] initWithFormat:@"%@?", baseUrl];
    
    for (NSString *tag in tags) {
        [longUrl appendFormat:@"tags=%@&", tag];
    }
    
    if ([alias length]) {
        [longUrl appendFormat:@"alias=%@&", alias];
    }
    
    if ([channel length]) {
        [longUrl appendFormat:@"channel=%@&", channel];
    }
    
    if ([feature length]) {
        [longUrl appendFormat:@"feature=%@&", feature];
    }
    
    if ([stage length]) {
        [longUrl appendFormat:@"stage=%@&", stage];
    }
    
    [longUrl appendFormat:@"type=%ld&", (long)type];
    [longUrl appendFormat:@"matchDuration=%ld&", (long)duration];
    
    NSData *jsonData = [BNCEncodingUtils encodeDictionaryToJsonData:params];
    NSString *base64EncodedParams = [BNCEncodingUtils base64EncodeData:jsonData];
    [longUrl appendFormat:@"data=%@", base64EncodedParams];
    
    return longUrl;
}

- (BNCLinkData *)prepareLinkDataFor:(NSArray *)tags andAlias:(NSString *)alias andType:(BranchLinkType)type andMatchDuration:(NSUInteger)duration andChannel:(NSString *)channel andFeature:(NSString *)feature andStage:(NSString *)stage andParams:(NSDictionary *)params ignoreUAString:(NSString *)ignoreUAString {
    BNCLinkData *post = [[BNCLinkData alloc] init];
    [post setObject:[BNCPreferenceHelper getDeviceFingerprintID] forKey:DEVICE_FINGERPRINT_ID];
    [post setObject:[BNCPreferenceHelper getIdentityID] forKey:IDENTITY_ID];
    [post setObject:[BNCPreferenceHelper getSessionID] forKey:SESSION_ID];
    
    [post setupType:type];
    [post setupTags:tags];
    [post setupChannel:channel];
    [post setupFeature:feature];
    [post setupStage:stage];
    [post setupAlias:alias];
    [post setupMatchDuration:duration];
    [post setupIgnoreUAString:ignoreUAString];
    
    NSString *args = @"{\"source\":\"ios\"}";
    if (params) {
        args = [BNCEncodingUtils encodeDictionaryToJsonString:params];
    }
    
    [post setupParams:args];
    return post;
}


#pragma mark - Application State Change methods

- (void)applicationDidBecomeActive {
    if (!self.isInitialized) {
        [self initUserSessionAndCallCallback:YES];
    }
    
    [self bnc_addDebugGestureRecognizer];
}

- (void)applicationWillResignActive {
    [self clearTimer];
    self.sessionTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(callClose) userInfo:nil repeats:NO];
    [self.requestQueue persistImmediately];
    
    if (BNCLongPress) {
        [[UIApplication sharedApplication].keyWindow removeGestureRecognizer:BNCLongPress];
    }
}

- (void)clearTimer {
    [self.sessionTimer invalidate];
}

- (void)callClose {
    self.isInitialized = NO;

    if (![self.requestQueue containsClose]) {
        BNCServerRequest *req = [[BNCServerRequest alloc] initWithTag:REQ_TAG_REGISTER_CLOSE];
        req.postData = [[NSMutableDictionary alloc] init];

        [self.requestQueue enqueue:req];
    }
    
    [self processNextQueueItem];
}

- (void)getAppList {
    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_GET_LIST_OF_APPS;
    req.callback = ^(BNCServerResponse *serverResponse, NSError *error) {
        [self completeRequest];
        if (error) {
            [self processNextQueueItem];
            return;
        }

        [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"returned from app check with %@", serverResponse.data];

        NSArray *apps = [serverResponse.data objectForKey:@"potential_apps"];
        NSDictionary *appList = [BNCSystemObserver getOpenableAppDictFromList:apps];
        [self processListOfApps:appList];
        [self processNextQueueItem];
    };
    
    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}

- (void)processListOfApps:(NSDictionary *)appList {
    BNCServerRequest *req = [[BNCServerRequest alloc] init];
    req.tag = REQ_TAG_UPLOAD_LIST_OF_APPS;
    req.postData = [@{
        DEVICE_FINGERPRINT_ID: [BNCPreferenceHelper getDeviceFingerprintID],
        @"os": [BNCSystemObserver getOS],
        @"apps_data": appList
    } mutableCopy];

    req.callback = ^(BNCServerResponse *response, NSError *error) {
        if (!error) {
            [BNCPreferenceHelper setAppListCheckDone];
        }

        [self completeRequest];
        [self processNextQueueItem];
    };
    
    [self.requestQueue enqueue:req];
    [self processNextQueueItem];
}


#pragma mark - Queue management

- (void)insertRequestAtFront:(BNCServerRequest *)req {
    if (self.networkCount == 0) {
        [self.requestQueue insert:req at:0];
    }
    else {
        [self.requestQueue insert:req at:1];
    }
}

- (void)processNextQueueItem {
    dispatch_semaphore_wait(self.processing_sema, DISPATCH_TIME_FOREVER);
    
    if (self.networkCount == 0 && self.requestQueue.size > 0) {
        self.networkCount = 1;
        dispatch_semaphore_signal(self.processing_sema);
        
        BNCServerRequest *req = [self.requestQueue peek];
        
        if (req) {
            if (!req.callback) {
                req.callback = ^(BNCServerResponse *response, NSError *error) {
                    [self completeRequest];
                    [self processNextQueueItem];
                };
            }

            if (![req.tag isEqualToString:REQ_TAG_REGISTER_INSTALL] && ![self hasUser]) {
                NSLog(@"Branch Error: User session has not been initialized!");
                req.callback(nil, [NSError errorWithDomain:BNCErrorDomain code:BNCInitError userInfo:@{ NSLocalizedDescriptionKey: @"Branch User Session has not been initialized" }]);
                return;
            }
            
            if (![req.tag isEqualToString:REQ_TAG_REGISTER_CLOSE]) {
                [self clearTimer];
            }
            
            if ([req.tag isEqualToString:REQ_TAG_REGISTER_INSTALL]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling register install"];
                [self.bServerInterface registerInstall:[BNCPreferenceHelper isDebug] callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_REGISTER_OPEN]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling register open"];
                [self.bServerInterface registerOpen:[BNCPreferenceHelper isDebug] callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_GET_REFERRAL_COUNTS] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling get referrals"];
                [self.bServerInterface getReferralCountsWithCallback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_GET_REWARDS] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling get rewards"];
                [self.bServerInterface getRewardsWithCallback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_REDEEM_REWARDS] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling redeem rewards"];
                [self.bServerInterface redeemRewards:req.postData callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_COMPLETE_ACTION] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling completed action"];
                [self.bServerInterface userCompletedAction:req.postData callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_GET_CUSTOM_URL] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling create custom url"];
                [self.bServerInterface createCustomUrl:req callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_IDENTIFY] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling identify user"];
                [self.bServerInterface identifyUser:req.postData callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_LOGOUT] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling logout"];
                [self.bServerInterface logoutUser:req.postData callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_REGISTER_CLOSE] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling close"];
                [self.bServerInterface registerCloseWithCallback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_GET_REWARD_HISTORY] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling get reward history"];
                [self.bServerInterface getCreditHistory:req.postData callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_GET_REFERRAL_CODE] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling get/create referral code"];
                [self.bServerInterface getReferralCode:req.postData callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_VALIDATE_REFERRAL_CODE] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling validate referral code"];
                [self.bServerInterface validateReferralCode:req.postData callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_APPLY_REFERRAL_CODE] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling apply referral code"];
                [self.bServerInterface applyReferralCode:req.postData callback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_GET_LIST_OF_APPS] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling get apps"];
                [self.bServerInterface retrieveAppsToCheckWithCallback:req.callback];
            }
            else if ([req.tag isEqualToString:REQ_TAG_UPLOAD_LIST_OF_APPS] && [self hasSession]) {
                [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"calling upload apps"];
                [self.bServerInterface uploadListOfApps:req.postData callback:req.callback];
            }
        }
    } else {
        dispatch_semaphore_signal(self.processing_sema);
    }
}

- (void)updateAllRequestsInQueue {
    for (int i = 0; i < self.requestQueue.size; i++) {
        BNCServerRequest *request = [self.requestQueue peekAt:i];
        

        for (NSString *key in [request.postData allKeys]) {
            if ([key isEqualToString:SESSION_ID]) {
                [request.postData setObject:[BNCPreferenceHelper getSessionID] forKey:SESSION_ID];
            }
            else if ([key isEqualToString:IDENTITY_ID]) {
                [request.postData setObject:[BNCPreferenceHelper getIdentityID] forKey:IDENTITY_ID];
            }
        }
    }

    [self.requestQueue persistEventually];
}

- (void)completeRequest {
    self.networkCount = 0;
    [self.requestQueue dequeue];
}


#pragma mark - Branch State checks

- (BOOL)hasIdentity {
    return ![[BNCPreferenceHelper getUserIdentity] isEqualToString:NO_STRING_VALUE];
}

- (BOOL)hasUser {
    return ![[BNCPreferenceHelper getIdentityID] isEqualToString:NO_STRING_VALUE];
}

- (BOOL)hasSession {
    return ![[BNCPreferenceHelper getSessionID] isEqualToString:NO_STRING_VALUE];
}

- (BOOL)hasBranchKey {
    return ![[BNCPreferenceHelper getBranchKey] isEqualToString:NO_STRING_VALUE];
}

- (BOOL)hasAppKey {
    return ![[BNCPreferenceHelper getAppKey] isEqualToString:NO_STRING_VALUE];
}

#pragma mark - Session Initialization

- (void)initUserSessionAndCallCallback:(BOOL)callCallback {
    self.shouldCallSessionInitCallback = callCallback;
    
    // If the session is not yet initialized
    if (!self.isInitialized) {
        // If the open/install request hasn't been added, do so.
        if (![self.requestQueue containsInstallOrOpen]) {
            [self initializeSession];
        }
    }
    // If the session was initialized, but callCallback was specified, do so.
    else if (callCallback) {
        if (self.sessionInitWithParamsCallback) {
            self.sessionInitWithParamsCallback([self getLatestReferringParams], nil);
        }
    }
}

- (void)initializeSession {
    if (![self hasBranchKey] && ![self hasAppKey]) {
        NSLog(@"Branch Warning: Please enter your branch_key in the plist!");
        return;
    }
    else if ([self hasBranchKey] && [[BNCPreferenceHelper getBranchKey] rangeOfString:@"key_test_"].location != NSNotFound) {
        NSLog(@"Branch Warning: You are using your test app's Branch Key. Remember to change it to live Branch Key for deployment.");
    }
    
    if ([self hasUser]) {
        [self registerOpen];
    }
    else {
        [self registerInstall];
    }
}

- (void)registerInstall {
    if (![self.requestQueue containsInstallOrOpen]) {
        BNCServerRequest *req = [[BNCServerRequest alloc] initWithTag:REQ_TAG_REGISTER_INSTALL];
        req.callback = ^(BNCServerResponse *response, NSError *error) {
            if (error) {
                [self handleInitFailure:error];
            }
            else {
                [self processInitSuccess:response.data allowNoStringInstallParams:YES];
            }
        };

        [self insertRequestAtFront:req];
    }
    else {
        [self.requestQueue moveInstallOrOpen:REQ_TAG_REGISTER_INSTALL ToFront:self.networkCount];
    }
    
    [self processNextQueueItem];
}

- (void)registerOpen {
    if (![self.requestQueue containsInstallOrOpen]) {
        BNCServerRequest *req = [[BNCServerRequest alloc] initWithTag:REQ_TAG_REGISTER_OPEN];
        req.callback = ^(BNCServerResponse *response, NSError *error) {
            if (error) {
                [self handleInitFailure:error];
            }
            else {
                [self processInitSuccess:response.data allowNoStringInstallParams:NO];
            }
        };

        [self insertRequestAtFront:req];
    }
    else {
        [self.requestQueue moveInstallOrOpen:REQ_TAG_REGISTER_OPEN ToFront:self.networkCount];
    }
    
    [self processNextQueueItem];
}

- (void)processInitSuccess:(NSDictionary *)data allowNoStringInstallParams:(BOOL)allowNoStringInstallParams {
    [BNCPreferenceHelper setDeviceFingerprintID:[data objectForKey:DEVICE_FINGERPRINT_ID]];
    [BNCPreferenceHelper setUserURL:[data objectForKey:LINK]];
    [BNCPreferenceHelper setSessionID:[data objectForKey:SESSION_ID]];
    [BNCSystemObserver setUpdateState];
    
    if ([BNCPreferenceHelper getIsReferrable]) {
        if ([data objectForKey:DATA]) {
            [BNCPreferenceHelper setInstallParams:[data objectForKey:DATA]];
        }
        else if (allowNoStringInstallParams) {
            [BNCPreferenceHelper setInstallParams:NO_STRING_VALUE];
        }
    }
    
    [BNCPreferenceHelper setLinkClickIdentifier:NO_STRING_VALUE];
    
    if ([data objectForKey:LINK_CLICK_ID]) {
        [BNCPreferenceHelper setLinkClickID:[data objectForKey:LINK_CLICK_ID]];
    }
    else {
        [BNCPreferenceHelper setLinkClickID:NO_STRING_VALUE];
    }
    
    if ([data objectForKey:DATA]) {
        [BNCPreferenceHelper setSessionParams:[data objectForKey:DATA]];
    }
    else {
        [BNCPreferenceHelper setSessionParams:NO_STRING_VALUE];
    }
    
    if ([BNCPreferenceHelper getNeedAppListCheck]) {
        [self getAppList];
    }
    
    if ([data objectForKey:IDENTITY_ID]) {
        [BNCPreferenceHelper setIdentityID:[data objectForKey:IDENTITY_ID]];
    }
    
    [self updateAllRequestsInQueue];
    
    self.isInitialized = YES;
    [self completeRequest];
    
    if (self.shouldCallSessionInitCallback && self.sessionInitWithParamsCallback) {
        self.sessionInitWithParamsCallback([self getLatestReferringParams], nil);
    }
    
    // this is default, it's only cleared to handle the case of losing connectivity.
    // after connectivity is restored, this should be brought back.
    self.shouldCallSessionInitCallback = YES;

    [self processNextQueueItem];
}

- (void)handleInitFailure:(NSError *)error {
    self.isInitialized = NO;
    
    // Complete the request, but don't trigger another.
    [self completeRequest];
    
    NSError *initError = [NSError errorWithDomain:BNCErrorDomain code:BNCInitError userInfo:@{
        NSLocalizedDescriptionKey: @"Init Session failed, pending requests marked as failures",
        NSUnderlyingErrorKey: error
    }];
    
    // Fail all pending requests :(
    // Note that we need to build up a separate array of items to fail here, because the process
    // of failing them may or may not dequeue them, causing the loop to become out of sync...
    NSMutableArray *requestsToFail = [[NSMutableArray alloc] init];
    for (int i = 0; i < self.requestQueue.size; i++) {
        [requestsToFail addObject:[self.requestQueue peekAt:i]];
    }
    
    for (BNCServerRequest *request in requestsToFail) {
        request.callback(nil, initError);
    }

    if (self.shouldCallSessionInitCallback && self.sessionInitWithParamsCallback) {
        self.sessionInitWithParamsCallback(nil, error);
    }
    
    // this is default, it's only cleared to handle the case of losing connectivity.
    // after connectivity is restored, this should be brought back.
    self.shouldCallSessionInitCallback = YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Debugger functions

- (void)bnc_addDebugGestureRecognizer {
    [self bnc_addGesterRecognizer:@selector(bnc_connectToDebug:)];
}

- (void)bnc_addCancelDebugGestureRecognizer {
    [self bnc_addGesterRecognizer:@selector(bnc_endDebug:)];
}

- (void)bnc_addGesterRecognizer:(SEL)action {
    BNCLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:action];
    BNCLongPress.delegate = self;
    BNCLongPress.minimumPressDuration = BNCDebugTriggerDuration;
    if ([BNCSystemObserver isSimulator]) {
        BNCLongPress.numberOfTouchesRequired = BNCDebugTriggerFingersSimulator;
    } else {
        BNCLongPress.numberOfTouchesRequired = BNCDebugTriggerFingers;
    }
    [[UIApplication sharedApplication].keyWindow addGestureRecognizer:BNCLongPress];
}

- (void)bnc_connectToDebug:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan){
        NSLog(@"======= Start Debug Session =======");
        [BNCPreferenceHelper setDebugConnectionDelegate:self];
        [BNCPreferenceHelper setDebug];
    }
}

- (void)bnc_startDebug {
    NSLog(@"======= Connected to Branch Remote Debugger =======");
    
    if (!bnc_asyncDebugQueue) {
        bnc_asyncDebugQueue = dispatch_queue_create("bnc_debug_queue", NULL);
    }
    
    [[UIApplication sharedApplication].keyWindow removeGestureRecognizer:BNCLongPress];
    [self bnc_addCancelDebugGestureRecognizer];
    
    //TODO: change to send screenshots instead in future
    if (!bnc_debugTimer || !bnc_debugTimer.isValid) {
        bnc_debugTimer = [NSTimer scheduledTimerWithTimeInterval:20.0f
                                                          target:self
                                                        selector:@selector(bnc_keepDebugAlive)     //change to @selector(bnc_takeScreenshot)
                                                        userInfo:nil
                                                         repeats:YES];
    }
}

- (void)bnc_endDebug:(UILongPressGestureRecognizer *)sender {
    NSLog(@"======= End Debug Session =======");
    
    [[UIApplication sharedApplication].keyWindow removeGestureRecognizer:sender];
    [BNCPreferenceHelper clearDebug];
    bnc_asyncDebugQueue = nil;
    [bnc_debugTimer invalidate];
    [self bnc_addDebugGestureRecognizer];
}

- (void)bnc_keepDebugAlive {
    if (bnc_asyncDebugQueue) {
        dispatch_async(bnc_asyncDebugQueue, ^{
            [BNCPreferenceHelper keepDebugAlive];
        });
    }
}

#pragma mark - BNCDebugConnectionDelegate

- (void)bnc_debugConnectionEstablished {
    [self bnc_startDebug];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
        return YES;
}

#pragma mark - BNCTestDelagate

- (void)simulateInitFinished {
    self.isInitialized = YES;
}

@end
