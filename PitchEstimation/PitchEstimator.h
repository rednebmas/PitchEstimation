//
//  PitchEstimator.h
//  PitchEstimation
//
//  Created by Sam Bender on 11/10/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PitchEstimatorWindowingMethod) {
    PitchEstimatorWindowingMethodHanning,
    PitchEstimatorWindowingMethodBlackmanHarris,
    PitchEstimatorWindowingMethodGaussian,
    PitchEstimatorWindowingMethodNone
};

typedef NS_ENUM(NSInteger, PitchEstimatorBinInterpolationMethod) {
    PitchEstimatorBinInterpolationMethodQuadratic,
    PitchEstimatorBinInterpolationMethodGaussian,
    PitchEstimatorBinInterpolationMethodNone
};

@class Note;

@interface PitchEstimator : NSObject

@property (nonatomic) PitchEstimatorBinInterpolationMethod binInterpolationMethod;
@property (nonatomic) PitchEstimatorWindowingMethod windowingMethod;
@property (nonatomic, readonly) float loudness;
@property (nonatomic, readonly) float fundamentalFrequency;
@property (nonatomic, retain) Note *note;
@property (nonatomic, readonly) vDSP_Length fundamentalFrequencyIndex;
// delta frequency between bins
@property (nonatomic, readonly) float binSize;

+ (float) loudness:(float**)buffer ofSize:(UInt32)size;

- (void) processAudioBuffer:(float**)buffer ofSize:(UInt32)size;
- (void) processFFT:(EZAudioFFTRolling*)fft withFFTData:(float*)fftData ofSize:(vDSP_Length)size;

@end
