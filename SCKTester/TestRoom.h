//
//  TestRoom.h
//  ScheduleKit
//
//  Created by Joseph on 26/11/2015.
//  Copyright © 2015 Guillem Servera. All rights reserved.
//

@import Foundation;
@import ScheduleKit;

@interface TestRoom : NSObject <SCKRoom>

+ (NSArray*)sampleRooms:(NSArray*)roomArray;
- (instancetype)initWithRoomNumber:(NSNumber *)roomNumber
                        labelColor:(NSColor *)color
                      capabilities:(NSArray*)capabilitiesArray
                             title:(NSString *)title;

@property (strong) NSString *title;
@property (strong) NSColor *labelColor;
@property (strong) NSArray *capabilities;
@property (strong) NSNumber *roomNumber;

@end
