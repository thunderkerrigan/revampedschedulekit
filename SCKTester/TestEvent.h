//
//  TestEvent.h
//  ScheduleKit
//
//  Created by Guillem on 14/1/15.
//  Copyright (c) 2015 Guillem Servera. All rights reserved.
//

@import Foundation;
@import ScheduleKit;

@interface TestEvent : NSObject <SCKEvent>

+ (NSArray*)sampleEvents:(NSArray*)userArray andRooms:(NSArray*)roomArray;
- (instancetype)initWithType:(SCKEventType)type
                        user:(id <SCKUser>)user
                        room:(id <SCKRoom>)room
                       title:(NSString*)title
                    duration:(NSInteger)duration
                        date:(NSDate*)date;

@property (assign) SCKEventType eventType;
@property (strong) id <SCKUser> user;
@property (strong) id <SCKRoom> room;
@property (copy)   NSString * title;
@property (strong) NSNumber * duration;
@property (strong) NSDate * scheduledDate;
@property (strong) NSColor * backgroundColor;
@end
