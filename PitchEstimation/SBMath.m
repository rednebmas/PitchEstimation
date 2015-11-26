//
//  SBMath.m
//  PitchEstimation
//
//  Created by Sam Bender on 11/26/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import "SBMath.h"

@implementation SBMath

+ (float) standardDeviationOf:(float*)values ofSize:(UInt32)size
{
    float mean = [SBMath meanOf:values ofSize:size];
    
    float sumOfMeanDifference = 0;
    for (int i = 0 ; i < size; i++)
    {
        sumOfMeanDifference += powf(values[i] - mean, 2);
    }
    
    float standardDeviation = sqrt(sumOfMeanDifference / (size - 1));
    return standardDeviation;
}

+ (float) meanOf:(float*)values ofSize:(UInt32)size
{
    float sum = 0;
    for (int i = 0 ; i < size; i++)
    {
        sum += values[i];
    }
    float mean = sum / (float)size;
    return mean;
}

@end
