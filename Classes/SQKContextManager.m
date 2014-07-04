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
@property (nonatomic, strong, readwrite) NSMutableArray *managedObjectContextsToMerge;
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
        _storeType = storeType;
        _managedObjectModel = managedObjectModel;
        _persistentStoreCoordinator = [NSPersistentStoreCoordinator sqk_storeCoordinatorWithStoreType:storeType managedObjectModel:managedObjectModel];
        _managedObjectContextsToMerge = [NSMutableArray array];
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

- (void)contextSaveNotificationReceived:(NSNotification *)notification {
    /**
     *  Ensure mainContext is accessed on the main thread.
     */
    [_mainContext performBlock:^{
        NSManagedObjectContext *managedObjectContext = [notification object];
        if ([self.managedObjectContextsToMerge containsObject:managedObjectContext]) {
            [managedObjectContext performBlock:^{
                /**
                 *  If NSManagedObjectContext from the notitification is a private context
                 *	then merge the changes into the main context.
                 */
                
                [_mainContext mergeChangesFromContextDidSaveNotification:notification];
                
                /**
                 *  This loop is needed for 'correct' behaviour of NSFetchedResultsControllers.
                 *
                 *  NSManagedObjectContext doesn't event fire NSManagedObjectContextObjectsDidChangeNotification for updated objects on merge, only inserted.
                 *
                 *  SEE: http://stackoverflow.com/questions/3923826/nsfetchedresultscontroller-with-predicate-ignores-changes-merged-from-different
                 *  May also have memory implications.
                 */
                for (NSManagedObject *object in [[notification userInfo] objectForKey:NSUpdatedObjectsKey]) {
                    [[_mainContext objectWithID:[object objectID]] willAccessValueForKey:nil];
                }
                
            }];
        }
    }];
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

- (NSManagedObjectContext*)newMergingPrivateContext {
    NSManagedObjectContext* privateContext = [self newPrivateContext];
    [self.managedObjectContextsToMerge addObject:privateContext];
    return privateContext;
}

- (NSManagedObjectContext*)newUnmergingPrivateContext {
    return [self newPrivateContext];
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
