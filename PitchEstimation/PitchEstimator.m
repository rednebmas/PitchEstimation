//
//  PitchEstimator.m
//  PitchEstimation
//
//  Created by Sam Bender on 11/10/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <EZAudio/EZAudio.h>
#import "PitchEstimator.h"

@interface PitchEstimator()

@property (nonatomic, readwrite) float loudness;
@property (nonatomic, readwrite) float fundamentalFrequency;

@end

@implementation PitchEstimator

#pragma mark - Public methods

- (void) processAudioBuffer:(float**)buffer ofSize:(UInt32)size
{
    self.loudness = [PitchEstimator loudness:buffer ofSize:size];
    [PitchEstimator hann:buffer length:size];
}


- (void) processFFT:(EZAudioFFTRolling*)fft withFFTData:(float*)fftData ofSize:(vDSP_Length)size
{
    // make the fft taller
    for (int i = 0; i < size; i++)
    {
        fftData[i] *= 20.0;
    }
    
    // estimate actual frequency from bin with max freq
    self.fundamentalFrequency = [PitchEstimator ratioEstimatedFrequencyOf:fft
                                                                   ofSize:size
                                                                  atIndex:[fft maxFrequencyIndex]];
}

#pragma mark - FFT

+ (float) ratioEstimatedFrequencyOf:(EZAudioFFT*)fft ofSize:(vDSP_Length)size atIndex:(vDSP_Length)index
{
    vDSP_Length neighborIndex;
    if ([fft frequencyMagnitudeAtIndex:index-1] > [fft frequencyMagnitudeAtIndex:index+1])
    {
        neighborIndex = index - 1;
    }
    else
    {
        neighborIndex = index + 1;
    }
    
    float df = [fft frequencyAtIndex:neighborIndex] - [fft frequencyAtIndex:index];
    float ratio = [fft frequencyMagnitudeAtIndex:neighborIndex] / [fft frequencyMagnitudeAtIndex:index];
    
    // ratio will be .5 if the peak is exactly on bin
    // ratio will be 1.0 if peak is in between bins
    float adjusted_ratio = (ratio - .5) * 2;
    float estimated = (adjusted_ratio) * (df * .5) + [fft frequencyAtIndex:index];
    
    return estimated;
}

#pragma mark - Audio

/**
 * http://stackoverflow.com/a/28734550/337934
 */
+ (float) loudness:(float**)buffer ofSize:(UInt32)bufferSize
{
    double sumSquared = 0;
    for (int i = 0 ; i < bufferSize ; i++)
    {
        sumSquared += buffer[0][i]*buffer[0][i];
    }
    double rms = sumSquared/bufferSize;
    double dBvalue = 20*log10(rms);
    
    return dBvalue;
}

/**
 * Hanning window function which improves results of FFT
 */
+ (void) hann:(float**)buffer length:(UInt32)length
{
    float factor = 0;
    for (float i = 0; i < length; i++)
    {
        factor = .5 * (1 - cosf((2*M_PI*i)/(length-1)));
        buffer[0][(int)i] = buffer[0][(int)i] * factor;
    }
}

@end
