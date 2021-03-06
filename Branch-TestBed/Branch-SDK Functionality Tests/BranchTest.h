//
//  BranchTest.h
//  Branch-TestBed
//
//  Created by Graham Mueller on 4/27/15.
//  Copyright (c) 2015 Branch Metrics. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface BranchTest : XCTestCase

- (void)safelyFulfillExpectation:(XCTestExpectation *)expectation;
- (void)awaitExpectations;
- (void)resetExpectations;

@end
