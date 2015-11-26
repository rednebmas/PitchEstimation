//
//  SBMath.h
//  PitchEstimation
//
//  Created by Sam Bender on 11/26/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SBMath : NSObject

+ (float) meanOf:(float*)values ofSize:(UInt32)size;
+ (float) standardDeviationOf:(float*)values ofSize:(UInt32)size;

@end
