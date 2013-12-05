//
//  SQKContextManagerTests.m
//  SQKDataKit
//
//  Created by Luke Stringer on 04/12/2013.
//  Copyright (c) 2013 3Squared. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "SQKContextManager.h"

@interface SQKContextManagerTests : XCTestCase
// sut is the "System Under Tets"
@property (nonatomic, retain) SQKContextManager *sut;
@property (nonatomic, retain) id mockMainContextWithChanges;
@property (nonatomic, retain) id mockMainContextWithoutChanges;
@property (nonatomic, retain) NSManagedObjectModel *managedObjectModel;
@end

@implementation SQKContextManagerTests

#pragma mark - Helpers

- (void)setUp {
    [super setUp];
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle mainBundle]]];
    _sut = [[SQKContextManager alloc] initWithStoreType:NSInMemoryStoreType managedObjectModel:_managedObjectModel];
}

- (id)mockMainContextWithChanges {
    if (!_mockMainContextWithChanges) {
        _mockMainContextWithChanges = [self mockMainContextWithHasChangesBoolean:YES];
    }
    return _mockMainContextWithChanges;
}

- (id)mockMainContextWithoutChanges {
    if (!_mockMainContextWithoutChanges) {
        _mockMainContextWithoutChanges = [self mockMainContextWithHasChangesBoolean:NO];
    }
    return _mockMainContextWithoutChanges;
}

- (id)mockMainContextWithHasChangesBoolean:(BOOL)hasChanges {
    id mock = [OCMockObject mockForClass:[NSManagedObjectContext class]];
    [[[mock stub] andReturnValue:OCMOCK_VALUE(hasChanges)] hasChanges];
    return mock;
}

#pragma mark - Initialisation

- (void)testInitialisesWithAStoreTypeAndMangedObjectModel {
    XCTAssertNotNil(_sut, @"");
    XCTAssertEqualObjects(_sut.storeType, NSInMemoryStoreType, @"");
    XCTAssertEqualObjects(_sut.managedObjectModel, _managedObjectModel, @"");
}

#pragma mark - Contexts

- (void)testProvidesMainContext {
    XCTAssertNotNil([_sut mainContext], @"");
}

- (void)testProvidesSameMainContext {

    NSManagedObjectContext *firstContext = [_sut mainContext];
    NSManagedObjectContext *secondContext = [_sut mainContext];
    XCTAssertEqualObjects(firstContext, secondContext, @"");
}

- (void)testProvidesANewPrivateContext {

    NSManagedObjectContext *privateContext = [_sut newPrivateContext];
    XCTAssertNotNil(privateContext, @"");
    XCTAssertEqual((NSInteger)privateContext.concurrencyType, (NSInteger)NSPrivateQueueConcurrencyType, @"");
}


#pragma mark - Saving

- (void)testSavesWhenThereAreChanges {

    id sutMock = [OCMockObject partialMockForObject:_sut];
    [[[sutMock stub] andCall:@selector(mockMainContextWithChanges) onObject:self] mainContext];
    
    [[self.mockMainContextWithChanges expect] save:(NSError * __autoreleasing *)[OCMArg anyPointer]];
    
    NSError *saveError = nil;
    BOOL didSave = [sutMock saveMainContext:&saveError];
    
    XCTAssertTrue(didSave, @"");
    [self.mockMainContextWithChanges verify];
}

- (void)testDoesNotSaveWhenNoChanges {

    id sutMock = [OCMockObject partialMockForObject:_sut];
    [[[sutMock stub] andCall:@selector(mockMainContextWithoutChanges) onObject:self] mainContext];
    
    [[self.mockMainContextWithoutChanges reject] save:(NSError * __autoreleasing *)[OCMArg anyPointer]];
    
    NSError *saveError = nil;
    BOOL didSave = [sutMock saveMainContext:&saveError];
    
    XCTAssertFalse(didSave, @"");
    [self.mockMainContextWithoutChanges verify];
}


@end
