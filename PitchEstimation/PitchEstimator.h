//
//  PitchEstimator.h
//  PitchEstimation
//
//  Created by Sam Bender on 11/10/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PitchEstimatorMethod) {
    PitchEstimatorMethodRatio,
    PitchEstimatorMethodQuadratic
};

@interface PitchEstimator : NSObject

@property (nonatomic) PitchEstimatorMethod pitchEstimatorMethod;
@property (nonatomic, readonly) float loudness;
@property (nonatomic, readonly) float fundamentalFrequency;
@property (nonatomic, readonly) vDSP_Length fundamentalFrequencyIndex;
// delta frequency between bins
@property (nonatomic, readonly) float binSize;

+ (float) loudness:(float**)buffer ofSize:(UInt32)size;

- (void) processAudioBuffer:(float**)buffer ofSize:(UInt32)size;
- (void) processFFT:(EZAudioFFTRolling*)fft withFFTData:(float*)fftData ofSize:(vDSP_Length)size;

@end
