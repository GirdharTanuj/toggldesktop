//
//  DesktopLibraryBridge.h
//  TogglDesktop
//
//  Created by Nghia Tran on 4/2/19.
//  Copyright © 2019 Alari. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DesktopLibraryBridge : NSObject

+ (instancetype)shared;

- (NSString *)createClientWithWorkspaceID:(uint64_t)workspaceID
							   clientName:(NSString *)clientName;

- (NSString *)createProjectWithTimeEntryGUID:(NSString *)timeEntryGUID
								 workspaceID:(uint64_t)workspaceID
									clientID:(uint64_t)clientID
								  clientGUID:(NSString *)clientGUID
								 projectName:(NSString *)projectName
									colorHex:(NSString *)colorHex
									isPublic:(BOOL)isPublic;

- (void)setBillableForTimeEntryWithTimeEntryGUID:(NSString *)timeEntryGUID
									  isBillable:(BOOL)isBillable;

@end

NS_ASSUME_NONNULL_END
