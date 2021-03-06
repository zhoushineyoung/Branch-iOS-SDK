//
//  BranchApplyReferralCodeRequest.h
//  Branch-TestBed
//
//  Created by Graham Mueller on 5/26/15.
//  Copyright (c) 2015 Branch Metrics. All rights reserved.
//

#import "BNCServerRequest.h"
#import "Branch.h"

@interface BranchApplyReferralCodeRequest : BNCServerRequest

- (id)initWithCode:(NSString *)code callback:(callbackWithParams)callback;

@end
