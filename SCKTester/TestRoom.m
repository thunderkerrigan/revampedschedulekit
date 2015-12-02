//
//  TestRoom.m
//  ScheduleKit
//
//  Created by Joseph on 26/11/2015.
//  Copyright © 2015 Guillem Servera. All rights reserved.
//

#import "TestRoom.h"

@implementation TestRoom

- (instancetype)initWithRoomNumber:(NSNumber *)roomNumber
                        labelColor:(NSColor *)color
                      capabilities:(NSArray*)capabilitiesArray
                             title:(NSString *)title
{
    self = [self init];
    if (self)
    {
        _roomNumber = roomNumber;
        _labelColor = color;
        _title = title;
        _capabilities = capabilitiesArray;
    }
    return self;
}

+(NSArray *)sampleRooms:(NSArray *)roomArray
{
    return @[];
}

- (id)copyWithZone:(NSZone *)zone
{
    TestRoom *newTestroom = [[[self class] allocWithZone:zone] init];
    if(newTestroom)
    {
        [newTestroom setRoomNumber:[self roomNumber]];
        [newTestroom setLabelColor:[self labelColor]];
        [newTestroom setTitle:[self title]];
        [newTestroom setCapabilities:[self capabilities]];
    }
    return newTestroom;
}

@end
