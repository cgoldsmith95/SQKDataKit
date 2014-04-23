//
//  SQKContextManager.m
//  SQKDataKit
//
//  Created by Luke Stringer on 04/12/2013.
//  Copyright (c) 2013 3Squared. All rights reserved.
//

#import "SQKContextManager.h"
#import "NSPersistentStoreCoordinator+SQKAdditions.h"

@interface SQKContextManager ()
@property (nonatomic, strong, readwrite) NSString *storeType;
@property (nonatomic, strong, readwrite) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readwrite) NSManagedObjectContext* mainContext;
@property (nonatomic, strong, readwrite) NSPersistentStoreCoordinator* persistentStoreCoordinator;
@end

@implementation SQKContextManager

- (instancetype)initWithStoreType:(NSString *)storeType managedObjectModel:(NSManagedObjectModel *)managedObjectModel {
    if (!storeType || !managedObjectModel) {
        return nil;
    }
    
    if (![[SQKContextManager validStoreTypes] containsObject:storeType]) {
        return nil;
    }
    
    
    self = [super init];
    if (self) {
        self.storeType = storeType;
        self.managedObjectModel = managedObjectModel;
        self.persistentStoreCoordinator = [NSPersistentStoreCoordinator SQK_storeCoordinatorWithStoreType:storeType managedObjectModel:managedObjectModel];
        [self observeForSavedNotification];
    }
    return self;
}

+ (NSArray *)validStoreTypes {
    NSArray *validStoreTypes = nil;
    if (!validStoreTypes) {
        validStoreTypes = @[NSSQLiteStoreType, NSInMemoryStoreType, NSBinaryStoreType];
    }
    return validStoreTypes;
}

- (void)observeForSavedNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contextSaveNotificationReceived:)
												 name:NSManagedObjectContextDidSaveNotification
											   object:nil];
}

- (void)contextSaveNotificationReceived:(NSNotification *)notifcation {
    /**
     *  Ensure mainContext is accessed on the main thread.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        /**
         *  If NSManagedObjectContext from the notitification is a private context
         *	then merge the changes into the main context.
         */
        NSManagedObjectContext *managedObjectContext = [notifcation object];
        if (managedObjectContext.concurrencyType == NSPrivateQueueConcurrencyType) {
            
            for (NSManagedObject *object in [[notifcation userInfo] objectForKey:NSUpdatedObjectsKey]) {
                [[managedObjectContext objectWithID:[object objectID]] willAccessValueForKey:nil];
            }
            
            [self.mainContext mergeChangesFromContextDidSaveNotification:notifcation];
        }
    });
}

- (NSManagedObjectContext *)mainContext {
    if (![NSThread isMainThread]) {
        @throw [NSException exceptionWithName:NSObjectInaccessibleException reason:@"mainContext is only accessible from the main thread!" userInfo:nil];
    }

    if (_mainContext != nil) {
        return _mainContext;
    }
    
    _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    _mainContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
    return _mainContext;
}

- (NSManagedObjectContext*)newPrivateContext {
    NSManagedObjectContext* context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    context.persistentStoreCoordinator = self.persistentStoreCoordinator;
    return context;
}

- (BOOL)saveMainContext:(NSError **)error {
    if ([self.mainContext hasChanges]) {
        [self.mainContext save:error];
        return YES;
    }
    return NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
}

@end
