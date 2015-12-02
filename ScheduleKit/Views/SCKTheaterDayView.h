//
//  SCKTheaterDayView.h
//  ScheduleKit
//
//  Created by Joseph on 01/10/2015.
//  Copyright © 2015 Guillem Servera. All rights reserved.
//

#import "SCKGridView.h"

@class SCKTheaterDayView, SCKDayPoint;

@protocol SCKTheaterDayViewDelegate <SCKGridViewDelegate>
- (NSInteger)dayStartHourForTheaterDayView:(SCKTheaterDayView*)tView;
- (NSInteger)dayEndHourForTheaterDayView:(SCKTheaterDayView*)tView;
@optional
- (NSInteger)dayCountForTheaterDayView:(SCKTheaterDayView*)tView;
@end

/** The SCKTheaterDayViewDataSource protocol includes two methods that can be used by an event
 * manager to retrieve its contents from an auxiliary object. The method that will be invoked
 * depends on the value of the `loadsEventsAsynchronously` property. */
@protocol SCKTheaterDayViewDataSource <NSObject>
@required
- (NSArray *)requestsRooms;
@end

@interface SCKTheaterDayView : SCKGridView
{
    SCKDayPoint *_dayStartPoint;
    SCKDayPoint *_dayEndPoint;
    NSArray *_roomsArray;
    NSInteger _roomsCount;
}

@property (nonatomic, weak) id <SCKTheaterDayViewDelegate> delegate;
@property (nonatomic, weak) id <SCKTheaterDayViewDataSource> datasource;

- (NSDate*)calculateDateForRelativeTimeLocation:(SCKRelativeTimeLocation)offset andRoomNumber:(NSInteger)roomNumber;
- (SCKRelativeTimeLocation)calculateRelativeTimeLocationForDate:(NSDate *)date andRoomNumber:(NSInteger)roomNumber;
- (void)setDelegate:(id<SCKTheaterDayViewDelegate>)delegate andDatasource:(id<SCKTheaterDayViewDataSource>)datasource;
- (id<SCKRoom>)roomWithRoomNumber:(NSInteger)roomNumber;
- (id<SCKRoom>)roomWithLocation:(CGPoint)location;
- (id<SCKRoom>)roomWithRelativeLocation:(SCKRelativeTimeLocation)location;
@end
