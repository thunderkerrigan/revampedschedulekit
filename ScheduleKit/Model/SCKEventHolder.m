/*
 *  SCKEventHolder.m
 *  ScheduleKit
 *
 *  Created:    Guillem Servera on 24/12/2014.
 *  Copyright:  © 2014-2015 Guillem Servera (http://github.com/gservera)
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */

#import "SCKEventHolder.h"
#import "SCKEventView.h"
#import "SCKView.h"
#import "SCKTheaterDayView.h"
#import "SCKEventManager.h"

/*  DISCUSSION:
 *  - We're not initializing @c _observing, @c _lockBalance, @c _ready or @c _locked (defaults to 0/false)
 */

@implementation SCKEventHolder { 
    /// A set to track holders in conflict before a change in either @c representedObject 's @c scheduledDate or @c duration takes place, since that info won't be accessible afterwards. Set when a prior KVO notification for these properties is triggered and set back to @c nil after KVO parsing. @discussion We use NSSet instead of NSArray to prevent objects being included multiple times when combining with conflicts after the change.
    NSSet* _previousConflicts;
    
    BOOL            _observing; // Indicates wether we're observing changes in represented object or not.
    __weak id       _cachedUser; // A weak reference to @c representedObject's user (to safely parse labelColor changes)
    __weak id       _cachedRoom; // A weak reference to @c representedObject's user (to safely parse labelColor changes)
    __weak id       _eventManager; // A convenience reference to the event manager.
    __weak SCKView* _rootView; // A convenience reference to owningView's superview.
    NSInteger       _lockBalance; // The number of times @c lock: has been called over @c unlock:
    
    BOOL            _shouldIgnoreChanges; // Set to YES when dragging to prevent observing our own changes.
    BOOL            _changedWhileLocked; // Set to YES if we recieve changes while the event holder is locked.
    NSMutableArray* _changesWhileLocked; // The array of changes observed while the object was locked.
}

- (instancetype)init {
    NSLog(@"Invalid initializer -[SCKEventHolder init]. Use designated initializer instead.");
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithEvent:(id)self owner:(id)self];
}

- (instancetype)initWithEvent:(id <SCKEvent>)e owner:(SCKEventView*)v {
    NSParameterAssert([e conformsToProtocol:@protocol(SCKEvent)]);
    NSParameterAssert([v isKindOfClass:[SCKEventView class]]);
    self = [super init];
    if (self) {
        _cachedUser = [e user];
        _cachedUserLabelColor = [[_cachedUser labelColor] copy];
        _cachedBackgroundEventColor = [[e backgroundColor] copy];
        _cachedTitle = [[e title] copy];
        _cachedScheduleDate = [[e scheduledDate] copy];
        _cachedDuration = [[e duration] integerValue];
        _cachedRoom = [e room];
        _owningView = v;
        _rootView = (SCKView*)_owningView.superview;
        _eventManager = [_rootView eventManager];
        _representedObject = e;
        [self recalculateRelativeValues];
        NSAssert(_ready,@"Should be ready");
        [self startObservingRepresentedObject];
    }
    return self;
}

/** We stop observing @c representedObject's properties at this point. */
- (void)dealloc {
    [self stopObservingRepresentedObject];
}

/** Stops observing @c representedObject properties. Called from @c dealloc: */
- (void)stopObservingRepresentedObject {
    if (_representedObject != nil && _observing) {
        id obj = _representedObject;
        [obj removeObserver:self forKeyPath:NSStringFromSelector(@selector(scheduledDate))];
        [obj removeObserver:self forKeyPath:NSStringFromSelector(@selector(duration))];
        [obj removeObserver:self forKeyPath:NSStringFromSelector(@selector(title))];
        [obj removeObserver:self forKeyPath:NSStringFromSelector(@selector(user))];
    }
    _observing = NO;
}

/** Begins or resumes observing @c representedObject properties. Called during initialization */
- (void)startObservingRepresentedObject {
    if (_representedObject != nil && !_observing) {
        id obj = _representedObject;
        [obj addObserver:self forKeyPath:NSStringFromSelector(@selector(scheduledDate))
                 options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionPrior context:NULL];
        [obj addObserver:self forKeyPath:NSStringFromSelector(@selector(duration))
                 options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionPrior context:NULL];
        [obj addObserver:self forKeyPath:NSStringFromSelector(@selector(title))
                 options:NSKeyValueObservingOptionNew context:NULL];
        [obj addObserver:self forKeyPath:NSStringFromSelector(@selector(user))
                 options:NSKeyValueObservingOptionNew context:NULL];
        _observing = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)o change:(NSDictionary *)change context:(void *)cx {
    NSAssert(o == _representedObject,@"Recieved a KVO notification from an unexpected object");
    if (change[NSKeyValueChangeNotificationIsPriorKey] != nil) { // Track conflicts before value change (KVO-prior)
        NSArray *conflictsBefore;
        (void)[_eventManager positionInConflictForEventHolder:self holdersInConflict:&conflictsBefore];
        _previousConflicts = [NSSet setWithArray:conflictsBefore];
    } else { // Notification is not prior
        if (_locked && !_shouldIgnoreChanges) {
            _changedWhileLocked = YES;
            if (!_changesWhileLocked) {
                _changesWhileLocked = [[NSMutableArray alloc] init];
            }
            [_changesWhileLocked addObject:@{@"keyPath":keyPath,@"object":o,@"change":[change copy]}];
            return;
        } else if (_locked) { // Change was made by the event view, we'll ignore it.
            return;
        }
        
        id theNewValue = change[NSKeyValueChangeNewKey];
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(duration))]) {
            _cachedDuration = [theNewValue integerValue];
            [self recalculateRelativeValues];
            NSArray *conflictsNow;
            (void)[_eventManager positionInConflictForEventHolder:self holdersInConflict:&conflictsNow];
            NSArray *updatingHolders = [[_previousConflicts setByAddingObjectsFromArray:conflictsNow] allObjects];
            NSArray *updatingViews = [updatingHolders valueForKey:NSStringFromSelector(@selector(owningView))];
            [_rootView triggerRelayoutForEventViews:updatingViews animated:YES];
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(scheduledDate))]) {
            _cachedScheduleDate = [theNewValue copy];
            if ([_cachedScheduleDate isLessThan:_rootView.startDate] || [_cachedScheduleDate isGreaterThan:_rootView.endDate]) {
                [_eventManager reloadData];
                return;
            } else {
                [self recalculateRelativeValues];
                NSArray *conflictsNow;
                (void)[_eventManager positionInConflictForEventHolder:self holdersInConflict:&conflictsNow];
                NSArray *updatingHolders = [[_previousConflicts setByAddingObjectsFromArray:conflictsNow] allObjects];
                NSArray *updatingViews = [updatingHolders valueForKey:NSStringFromSelector(@selector(owningView))];
                [_rootView triggerRelayoutForEventViews:updatingViews animated:YES];
            }
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(title))]) {
            _cachedTitle = [theNewValue copy];
            _owningView.innerLabel.stringValue = _cachedTitle;
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(user))]) {
            if (_cachedUser != theNewValue) {
                _cachedUser = theNewValue;
                _cachedUserLabelColor = [_cachedUser labelColor];
                _owningView.needsDisplay = YES;
            }
        }
    }
}

- (void)stopObservingRepresentedObjectChanges {
    _shouldIgnoreChanges = YES;
}

- (void)resumeObservingRepresentedObjectChanges {
    _shouldIgnoreChanges = NO;
}

- (void)lock {
    _lockBalance++;
    NSAssert1(_lockBalance == 1, @"Overlocked (%ld times)",_lockBalance);
    _changedWhileLocked = NO;
    _locked = YES;
}

- (void)unlock {
    _lockBalance--;
    NSAssert1(_lockBalance == 0, @"Overunlocked (+%ld times)",-_lockBalance);
    _locked = NO;
    if (_changesWhileLocked) {
        [_changesWhileLocked sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"keyPath" ascending:NO]]];
        for (NSDictionary *change in _changesWhileLocked) {
            [self observeValueForKeyPath:change[@"keyPath"]
                                ofObject:change[@"object"]
                                  change:change[@"change"] context:nil];
        }
    }
    _changesWhileLocked = nil;
}

- (void)recalculateRelativeValues
{
    _ready = NO;
    _cachedRelativeStart = SCKRelativeTimeLocationNotFound;
    _cachedRelativeEnd = SCKRelativeTimeLocationNotFound;
    _cachedRelativeLength = 0;
    if (_cachedScheduleDate != nil)
    {
        if ([_rootView isKindOfClass:[SCKTheaterDayView class]] && _cachedRoom)
        {
            _cachedRelativeStart = [(SCKTheaterDayView *)_rootView calculateRelativeTimeLocationForDate:_cachedScheduleDate andRoom:_cachedRoom];
        }
        else
        {
            _cachedRelativeStart = [_rootView calculateRelativeTimeLocationForDate:_cachedScheduleDate];
        }
        if (_cachedRelativeStart != SCKRelativeTimeLocationNotFound)
        {
            if (_cachedDuration > 0.0)
            {
                NSDate *endDate = [_cachedScheduleDate dateByAddingTimeInterval:_cachedDuration * 60.0];
                if ([_rootView isKindOfClass:[SCKTheaterDayView class]] && _cachedRoom)
                {
                    _cachedRelativeEnd = [(SCKTheaterDayView *)_rootView calculateRelativeTimeLocationForDate:endDate andRoom:_cachedRoom];
                }
                else
                {
                    _cachedRelativeEnd = [_rootView calculateRelativeTimeLocationForDate:endDate];
                }

                if (_cachedRelativeEnd == SCKRelativeTimeLocationNotFound)
                {
                    _cachedRelativeEnd = 1.0;
                }
                _cachedRelativeLength = _cachedRelativeEnd - _cachedRelativeStart;
                _ready = YES;
            }
        }
    }
}

@end