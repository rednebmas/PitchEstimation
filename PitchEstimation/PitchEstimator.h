//
//  PitchEstimator.h
//  PitchEstimation
//
//  Created by Sam Bender on 11/10/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PitchEstimator : NSObject

@property (nonatomic, readonly) float loudness;
@property (nonatomic, readonly) float fundamentalFrequency;
// delta frequency between bins
@property (nonatomic, readonly) float binSize;

+ (float) loudness:(float**)buffer ofSize:(UInt32)size;

- (void) processAudioBuffer:(float**)buffer ofSize:(UInt32)size;
- (void) processFFT:(EZAudioFFTRolling*)fft withFFTData:(float*)fftData ofSize:(vDSP_Length)size;

@end
