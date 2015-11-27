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

@end
