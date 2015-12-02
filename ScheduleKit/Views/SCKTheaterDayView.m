//
//  SCKTheaterDayView.m
//  ScheduleKit
//
//  Created by Joseph on 01/10/2015.
//  Copyright © 2015 Guillem Servera. All rights reserved.
//

#import "SCKDayPoint.h"
#import "SCKEventHolder.h"
#import "SCKEventManager.h"
#import "SCKEventView.h"
#import "SCKTheaterDayView.h"
#import "SCKViewPrivate.h"

#define kHourLabelWidth 56.0
#define kDayLabelHeight 36.0
#define kMaxHourHeight 300.0
#define kMinRoomWidth  200.0

@implementation SCKTheaterDayView

static NSDictionary * __dayLabelAttrs = nil;
static NSDictionary * __monthLabelAttrs = nil;
static NSDictionary * __hourLabelAttrs = nil;
static NSDictionary * __subHourLabelAttrs = nil;

+ (void)initialize {
    if (self == [SCKGridView self]) {
        NSMutableParagraphStyle *cStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        NSMutableParagraphStyle *rStyle = [cStyle mutableCopy];
        cStyle.alignment = NSCenterTextAlignment;
        rStyle.alignment = NSRightTextAlignment;
        __hourLabelAttrs = @{NSParagraphStyleAttributeName:  cStyle,
                             NSForegroundColorAttributeName: [NSColor darkGrayColor],
                             NSFontAttributeName: [NSFont systemFontOfSize:11.0]};
        __subHourLabelAttrs = @{NSParagraphStyleAttributeName: rStyle,
                                NSForegroundColorAttributeName: [NSColor lightGrayColor],
                                NSFontAttributeName: [NSFont systemFontOfSize:10.0]};
    }
}

- (void)customInit
{
    [super customInit];
}

- (void)setStartDate:(NSDate *)startDate
{
    [super setStartDate:startDate];
}

- (void)setEndDate:(NSDate *)endDate
{
    [super setEndDate:endDate];
}

- (void)setDelegate:(id<SCKTheaterDayViewDelegate>)delegate andDatasource:(id<SCKTheaterDayViewDataSource>)datasource
{
    self.delegate = delegate;
    self.datasource = datasource;
    [self readDefaultsFromDelegate];
}

- (void)readDefaultsFromDelegate
{
    [super readDefaultsFromDelegate]; // Sets up unavailable ranges and marks as needing display
    if (self.datasource != nil)
    {
        if ([self.datasource respondsToSelector:@selector(requestsRooms)])
        {
            _roomsArray = [self.datasource requestsRooms];
            _roomsCount = [_roomsArray count];
        }
    }
    if (self.delegate != nil)
    {
        _dayStartPoint = [[SCKDayPoint alloc] initWithHour:[self.delegate dayStartHourForTheaterDayView:self] minute:0 second:0];
        _dayEndPoint = [[SCKDayPoint alloc] initWithHour:[self.delegate dayEndHourForTheaterDayView:self] minute:0 second:0];
        _firstHour = _dayStartPoint.hour;
        _hourCount = _dayEndPoint.hour - _dayStartPoint.hour;
        [self invalidateIntrinsicContentSize];
        [self triggerRelayoutForAllEventViews]; //Trigger this even if we call reloadData because it may not reload anything
    }
}

#pragma mark - Event layout calculations

- (CGFloat)yForHour:(NSInteger)h minute:(NSInteger)m
{
    NSRect canvas = [self contentRect];
    return NSMinY(canvas) + NSHeight(canvas) * ((CGFloat)(h-_firstHour) + (CGFloat)m/60.0) / (CGFloat)_hourCount;
}

- (NSRect)rectForUnavailableTimeRange:(SCKUnavailableTimeRange *)rng
{
    NSRect canvasRect = [self contentRect];
    CGFloat roomWidth = NSWidth(canvasRect)/(CGFloat)_roomsCount;
    NSDate *sDate = [_calendar dateBySettingHour:rng.startHour minute:rng.startMinute second:0 ofDate:self.startDate options:0];
    SCKRelativeTimeLocation sOffset = [self calculateRelativeTimeLocationForDate:sDate];
    if (sOffset != SCKRelativeTimeLocationNotFound)
    {
        NSDate *eDate = [sDate dateByAddingTimeInterval:(rng.endMinute*60+rng.endHour*3600)-(rng.startMinute*60+rng.startHour*3600)];
        SCKRelativeTimeLocation eOffset = [self calculateRelativeTimeLocationForDate:eDate];
        CGFloat yOrigin, yLength;
        if (eOffset != SCKRelativeTimeLocationNotFound)
        {
            yOrigin = [self yForHour:rng.startHour minute:rng.startMinute];
            yLength = [self yForHour:rng.endHour minute:rng.endMinute] - yOrigin;
        }
        else
        {
            yOrigin = [self yForHour:rng.startHour minute:rng.startMinute];
            yLength = NSMaxY(self.frame) - yOrigin;
        }
        return NSMakeRect(NSMinX(canvasRect), yOrigin, roomWidth* _roomsCount, yLength);
    }
    else
    {
        return NSZeroRect;
    }
    
}

- (void)relayoutEventView:(SCKEventView*)eventView animated:(BOOL)animation
{
    NSParameterAssert([eventView isKindOfClass:[SCKEventView class]]);
    NSRect canvasRect = [self contentRect];
    NSRect oldFrame = eventView.frame;
    
    NSAssert1(_roomsCount > 0, @"Room count must be greater than zero. %lu found instead.",_roomsCount);
    SCKRelativeTimeLocation startOffset = eventView.eventHolder.cachedRelativeStart;
    NSAssert1(startOffset != SCKRelativeTimeLocationNotFound, @"Expected relativeStart to be set for holder: %@", eventView.eventHolder);
//    NSInteger room = (NSInteger)ceil(startOffset/_roomsCount);
    NSInteger roomIndex = trunc(startOffset);
    CGFloat roomWidth = NSWidth(canvasRect)/(CGFloat)_roomsCount;
    NSRect newFrame = NSZeroRect;
    
    NSDate *scheduledDate = eventView.eventHolder.cachedScheduleDate;
    SCKDayPoint *sPoint = [[SCKDayPoint alloc] initWithDate:scheduledDate];
    SCKDayPoint *ePoint = [[SCKDayPoint alloc] initWithHour:sPoint.hour minute:sPoint.minute+eventView.eventHolder.cachedDuration second:sPoint.second];
    newFrame.origin.y = [self yForHour:sPoint.hour minute:sPoint.minute];
    newFrame.size.height = [self yForHour:ePoint.hour minute: ePoint.minute]-newFrame.origin.y;
    
    NSArray *conflicts = nil;
    NSInteger idx = [[self eventManager] positionInConflictForEventHolder:eventView.eventHolder holdersInConflict:&conflicts];
    if ([conflicts count] > 0)
    {
        newFrame.size.width = roomWidth / (CGFloat)[conflicts count];
    }
    else
    {
        newFrame.size.width = roomWidth;
    }
    newFrame.origin.x = canvasRect.origin.x + (CGFloat)roomIndex * roomWidth + (newFrame.size.width * (CGFloat)idx);
    if (eventView.eventHolder.cachedRoomIndex != roomIndex)
    {
        id<SCKEvent> e = (id<SCKEvent>)eventView.eventHolder.representedObject;
        
        [e setRoom:[self roomWithRoomNumber:roomIndex]];
    }
    if (!NSEqualRects(oldFrame, newFrame))
    {
        if (animation)
        {
            eventView.animator.frame = newFrame;
        }
        else
        {
            eventView.frame = newFrame;
        }
    }
}

- (id<SCKRoom>)roomWithRoomNumber:(NSInteger)roomNumber
{
    if ([_roomsArray count]> roomNumber)
    {
        return _roomsArray[roomNumber];
    }
    else
    {
        return nil;
    }

}

- (id<SCKRoom>)roomWithLocation:(CGPoint)location
{
    NSRect canvasRect = [self contentRect];
    if (NSPointInRect(location, canvasRect))
    {
        //column's width of a represented room total width divided by number of room
        CGFloat roomWidth = NSWidth(canvasRect)/(CGFloat)_roomsCount;
        
        //true position of x on current view
        CGFloat trueX = location.x-NSMinX(canvasRect);
        
        //room
        NSInteger roomNumber = (NSInteger)trunc(trueX / roomWidth);
        return _roomsArray[roomNumber];
    }
    else
    {
        return nil;
    }
}

- (id<SCKRoom>)roomWithRelativeLocation:(SCKRelativeTimeLocation)location
{
    NSInteger roomNumber = ceil(floor(location));
    if (roomNumber < [_roomsArray count])
    {
        return _roomsArray[roomNumber];
    }
    else
    {
        return nil;
    }
}

- (SCKRelativeTimeLocation)relativeTimeLocationForPoint:(NSPoint)location
{
    NSRect canvasRect = [self contentRect];
    if (NSPointInRect(location, canvasRect))
    {
        //column's width of a represented room total width divided by number of room
        CGFloat roomWidth = NSWidth(canvasRect)/(CGFloat)_roomsCount;
        
        //true position of x on current view
        CGFloat trueX = location.x-NSMinX(canvasRect);
        
        //room
        NSInteger roomIndex = (NSInteger)trunc(trueX / roomWidth);
        SCKRelativeTimeLocation roomOffset = (double)roomIndex;
        SCKRelativeTimeLocation offsetPerMin = [self calculateRelativeTimeLocationForDate:[self.startDate dateByAddingTimeInterval:60]];
        SCKRelativeTimeLocation offsetPerHour = 60.0 * offsetPerMin;
        CGFloat totalMinutes = (double)(60*_hourCount);
        CGFloat minute = totalMinutes * (location.y-NSMinY(canvasRect)) / NSHeight(canvasRect);
        SCKRelativeTimeLocation minuteOffset = offsetPerMin * minute;
        SCKRelativeTimeLocation pointOffset = roomOffset + offsetPerHour * (double)_firstHour + minuteOffset;
        return pointOffset;
    }
    else
    {
        return SCKRelativeTimeLocationNotFound;
    }
}



/**
 *  overridden method 
 *  this view is not drawed on the same pattern as day and week presentation
 *
 *  @param dirtyRect rect to draw in
 */
- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect]; // Fills background
    [[NSColor whiteColor] setFill];
    NSRectFill(dirtyRect);
    if ((_absoluteStartTimeRef < _absoluteEndTimeRef) &&
        (_hourCount > 0))
    {
        [self drawUnavailableTimeRanges];
        [self drawRoomLabelRect];
        [self drawHourDelimiters];
        if (_eventViewBeingDragged)
        {
            [self drawDraggingGuides];
        }
        else
        {
            [self drawHourLabels];
        }
    } 
}

- (void)drawRoomLabelRect
{
    //private
    NSMutableParagraphStyle *cStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    cStyle.alignment = NSCenterTextAlignment;
    __dayLabelAttrs = @{NSParagraphStyleAttributeName:  cStyle,
                        NSForegroundColorAttributeName: [NSColor darkGrayColor],
                        NSFontAttributeName: [NSFont systemFontOfSize:14.0]};
    __monthLabelAttrs = @{NSParagraphStyleAttributeName:  cStyle,
                          NSForegroundColorAttributeName: [NSColor lightGrayColor],
                          NSFontAttributeName: [NSFont systemFontOfSize:12.0]};
    NSRect RoomLabelingRect = NSMakeRect(kHourLabelWidth,
                                        self.bounds.origin.y,
                                        self.frame.size.width - kHourLabelWidth,
                                        kDayLabelHeight);
    [[NSColor colorWithCalibratedWhite:0.95 alpha:1.0] set];
    NSRectFill(RoomLabelingRect);
    CGFloat roomWidth = (NSWidth(self.frame) - kHourLabelWidth) / (CGFloat)_roomsCount;
    for (NSInteger d = 0; d < _roomsCount; d++)
    {
        id<SCKRoom> room = _roomsArray[d];
        NSString *roomLabel = [[room title] uppercaseString];
        NSSize roomLabelSize = [roomLabel sizeWithAttributes:__dayLabelAttrs];
        NSRect roomLabelRect = NSMakeRect(NSMinX(RoomLabelingRect)+roomWidth*(CGFloat)d,
                                         kDayLabelHeight/2.0-roomLabelSize.height/2.0,
                                         roomWidth,
                                         roomLabelSize.height);
        roomLabelRect.origin.y -= 8.0;
        NSString *capabilitiesLabel = [[[room capabilities] componentsJoinedByString:@" "] uppercaseString];
        NSSize capabilitiesLabelSize = [capabilitiesLabel sizeWithAttributes:__monthLabelAttrs];
        NSRect capabilitiesLabelRect = NSMakeRect(roomLabelRect.origin.x,
                                                  kDayLabelHeight/2.0-roomLabelSize.height/2.0 + 7.0,
                                                  roomLabelRect.size.width,
                                                  capabilitiesLabelSize.height);
        [capabilitiesLabel drawInRect:capabilitiesLabelRect withAttributes:__monthLabelAttrs];
        [roomLabel drawInRect:roomLabelRect withAttributes:__dayLabelAttrs];
        [[NSColor colorWithCalibratedWhite:0.85 alpha:1.0] set];
        NSRectFill(NSMakeRect(NSMinX(roomLabelRect)-0.5, 0.0, 1.0, NSHeight(self.frame)));
    }
    NSRectFill(NSMakeRect(kHourLabelWidth-8.0, kDayLabelHeight-0.5, self.frame.size.width, 1.0));
}

- (void)drawHourDelimiters { //Private
    NSRect canvas = [self contentRect];
    [[NSColor colorWithCalibratedWhite:0.95 alpha:1.0] set];
    for (int h = 0; h < _hourCount; h++) {
        NSRect r = NSMakeRect(canvas.origin.x-8.0, canvas.origin.y + self.hourHeight*(CGFloat)h - 0.4, NSWidth(canvas) + 8.0, 0.8);
        NSRectFill(r);
    }
}

- (void)drawHourLabels {
    NSRect canvas = [self contentRect];
    for (int h = 0; h < _hourCount; h++) {
        NSRect r = NSMakeRect(NSMinX(canvas)-8.0, NSMinY(canvas) + self.hourHeight*(CGFloat)h-0.4, NSWidth(canvas)+8.0, 0.8);
        NSString *hourLabel = [NSString stringWithFormat:@"%ld:00",_firstHour+h]; //"\(firstHour + h):00"
        CGFloat hourLabelHeight = [hourLabel sizeWithAttributes:__hourLabelAttrs].height;
        NSRect hourLabelRect = NSMakeRect(0.0, NSMidY(r)-hourLabelHeight/2.0-0.5,kHourLabelWidth-12.0,hourLabelHeight);
        [hourLabel drawInRect:hourLabelRect withAttributes:__hourLabelAttrs];
        
        // Draw half hours if space available
        if (self.hourHeight > 40.0) {
            NSString *midHourLabel = [NSString stringWithFormat:@"%ld:30   -",_firstHour+h];
            CGFloat midHourLabelHeight = [midHourLabel sizeWithAttributes:__subHourLabelAttrs].height;
            NSRect midHourLabelRect = NSMakeRect(0.0, NSMidY(r)+self.hourHeight/2.0-midHourLabelHeight/2.0-0.5, kHourLabelWidth, midHourLabelHeight);
            [midHourLabel drawInRect:midHourLabelRect withAttributes:__subHourLabelAttrs];
            
            if (self.hourHeight > 120.0) { // Draw 10ths
                for (int min = 10; min <= 50; min += 10) {
                    NSString *minLabel = [NSString stringWithFormat:@"%ld:%d   -",_firstHour+h,min];
                    CGFloat minLabelHeight = [minLabel sizeWithAttributes:__subHourLabelAttrs].height;
                    NSRect minLabelRect = NSMakeRect(0.0, NSMidY(r)+self.hourHeight/60.0*(CGFloat)min-minLabelHeight/2.0-0.5, kHourLabelWidth, minLabelHeight);
                    [minLabel drawInRect:minLabelRect withAttributes:__subHourLabelAttrs];
                }
            } else if (self.hourHeight > 80.0) { // Draw 15ths
                for (int min = 15; min <= 45; min += 15) {
                    NSString *minLabel = [NSString stringWithFormat:@"%ld:%d   -",_firstHour+h,min];
                    CGFloat minLabelHeight = [minLabel sizeWithAttributes:__subHourLabelAttrs].height;
                    NSRect minLabelRect = NSMakeRect(0.0, NSMidY(r)+self.hourHeight/60.0*(CGFloat)min-minLabelHeight/2.0-0.5, kHourLabelWidth, minLabelHeight);
                    [minLabel drawInRect:minLabelRect withAttributes:__subHourLabelAttrs];
                }
            }
        }
    }
}

- (void)drawUnavailableTimeRanges {
    [[NSColor colorWithCalibratedWhite:0.975 alpha:1.0] set];
    for (SCKUnavailableTimeRange *range in _unavailableTimeRanges) {
        NSRectFill([self rectForUnavailableTimeRange:range]);
    }
}

#define fill(x,y,w,h) NSRectFill(NSMakeRect(x,y,w,h))

- (void)drawDraggingGuides {
    SCKEventView *eV = _eventViewBeingDragged;
    if (self.colorMode == SCKEventColorModeByEventType) {
        [[SCKEventView strokeColorForEventType:[eV.eventHolder.representedObject eventType]] setFill];
    } else if ([eV.eventHolder cachedUserLabelColor] != nil) {
        [[eV.eventHolder cachedUserLabelColor] setFill];
    } else {
        [[NSColor darkGrayColor] setFill];
    }
    
    NSRect canvasRect = [self contentRect];
    NSRect eventRect = eV.frame;
    
    //Left guide
    fill(NSMinX(canvasRect), NSMidY(eventRect)-1.0, NSMinX(eventRect)-NSMinX(canvasRect), 2.0);
    //Right guide
    fill(NSMaxX(eventRect), NSMidY(eventRect)-1.0, NSWidth(self.frame)-NSMaxX(eventRect), 2.0);
    fill(NSMinX(canvasRect)-10.0, NSMinY(eventRect), 10.0, 2.0);
    fill(NSMinX(canvasRect)-10.0, NSMaxY(eventRect)-2.0, 10.0, 2.0);
    fill(NSMinX(canvasRect)-2, NSMinY(eventRect), 2.0, NSHeight(eventRect));
    //Top guide
    fill(NSMidX(eventRect)-1.0, NSMinY(canvasRect), 2.0, NSMinY(eventRect)-NSMinY(canvasRect));
    //Bottom guide
    fill(NSMidX(eventRect)-1.0, NSMaxY(eventRect), 2.0, NSHeight(self.frame)-NSMaxY(eventRect));
    
    CGFloat roomWidth = NSWidth(canvasRect) / (CGFloat)_roomsCount;
    SCKRelativeTimeLocation startOffset = [self relativeTimeLocationForPoint:NSMakePoint(NSMidX(eV.frame), NSMinY(eV.frame))];
    if (startOffset != SCKRelativeTimeLocationNotFound)
    {
        fill(NSMinX(canvasRect)+roomWidth*trunc(startOffset), NSMinY(canvasRect), roomWidth, 2.0);
        
        NSDate *startDate = [self calculateDateForRelativeTimeLocation:startOffset];
        SCKDayPoint *sPoint = [[SCKDayPoint alloc] initWithDate:startDate];
        SCKDayPoint *ePoint = [[SCKDayPoint alloc] initWithDate:[startDate dateByAddingTimeInterval:eV.eventHolder.cachedDuration*60.0]];
        NSString *sHourLabel = [NSString stringWithFormat:@"%ld:%02ld",sPoint.hour,sPoint.minute];
        NSString *eHourLabel = [NSString stringWithFormat:@"%ld:%02ld",ePoint.hour,ePoint.minute];
        CGFloat height = [sHourLabel sizeWithAttributes:__hourLabelAttrs].height;
        NSRect sHourLabelRect = NSMakeRect(0.0, NSMinY(eventRect)-height/2.0, NSMinX(canvasRect)-12, height);
        NSRect eHourLabelRect = NSMakeRect(0.0, NSMaxY(eventRect)-height/2.0, NSMinX(canvasRect)-12, height);
        [sHourLabel drawInRect:sHourLabelRect withAttributes:__hourLabelAttrs];
        [eHourLabel drawInRect:eHourLabelRect withAttributes:__hourLabelAttrs];
        
        NSString *durationLabel = [NSString stringWithFormat:@"%ld min",eV.eventHolder.cachedDuration];
        NSRect durationRect = NSMakeRect(0.0, NSMidY(eventRect)-height/2.0, NSMinX(canvasRect)-12, height);
        [durationLabel drawInRect:durationRect withAttributes:__hourLabelAttrs];
    }
}

# pragma mark - calculateRelativeTime


- (NSDate *)calculateDateForRelativeTimeLocation:(SCKRelativeTimeLocation)offset
{
    if (offset == SCKRelativeTimeLocationNotFound) {
        return nil;
    } else {
        double flooredOffset = offset - floor(offset);
        int interval = (int)(_absoluteStartTimeRef + flooredOffset * [self absoluteTimeInterval]);
        while ((interval % 60) > 0) {
            interval++;
        }
        return [NSDate dateWithTimeIntervalSinceReferenceDate:(double)interval];
    }
}

//- (SCKRelativeTimeLocation)calculateRelativeTimeLocationForDate:(NSDate *)date
//{
//    NSLog(@"SHOULD NOT BE TRIGGERED!!!!");
//    return 0.0f;
//}

- (NSDate*)calculateDateForRelativeTimeLocation:(SCKRelativeTimeLocation)offset andRoomNumber:(NSInteger)roomNumber
{
    return [self calculateDateForRelativeTimeLocation:offset];
//    if (offset == SCKRelativeTimeLocationNotFound)
//    {
//        return nil;
//    }
//    else
//    {
//        CGFloat timeOffset = offset -roomNumber;
//        int interval = (int)(_absoluteStartTimeRef + timeOffset * [self absoluteTimeInterval]);
//        while ((interval % 60) > 0)
//        {
//            interval++;
//        }
//        NSLog(@" offset %f for room %ld is at date : %@", offset, roomNumber, [NSDate dateWithTimeIntervalSinceReferenceDate:(double)interval]);
//        return [NSDate dateWithTimeIntervalSinceReferenceDate:(double)interval];
//    }
}

- (SCKRelativeTimeLocation)calculateRelativeTimeLocationForDate:(NSDate *)date andRoomNumber:(NSInteger)roomNumber
{
    if (date == nil)
    {
        NSParameterAssert(date);
        return SCKRelativeTimeLocationNotFound;
    }
    NSTimeInterval timeRef = [date timeIntervalSinceReferenceDate];
    if (timeRef < _absoluteStartTimeRef || timeRef > _absoluteEndTimeRef)
    {
        return SCKRelativeTimeLocationNotFound;
    }
    else
    {
        SCKRelativeTimeLocation percentageLocation = (timeRef - _absoluteStartTimeRef) / [self absoluteTimeInterval];
        return percentageLocation + roomNumber;
    }
}

@dynamic delegate, datasource;
@end
