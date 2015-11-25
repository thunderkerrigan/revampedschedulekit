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

@interface SCKTheaterDayView : SCKGridView
{
    SCKDayPoint *_dayStartPoint;
    SCKDayPoint *_dayEndPoint;
    NSInteger *_roomCount;
}

@property (nonatomic, weak) id <SCKTheaterDayViewDelegate> delegate;

@end
