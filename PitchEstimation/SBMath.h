//
//  SBMath.h
//  PitchEstimation
//
//  Created by Sam Bender on 11/26/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct FloatRange {
    float start;
    float end;
} FloatRange;

@interface SBMath : NSObject

+ (float) meanOf:(float*)values ofSize:(UInt32)size;
+ (float) standardDeviationOf:(float*)values ofSize:(UInt32)size;
+ (float) convertValue:(float)value inRangeToNormal:(FloatRange)range;
+ (float) convertValue:(float)value inRangeToNormalLogarithmicValue:(FloatRange)range;

@end
