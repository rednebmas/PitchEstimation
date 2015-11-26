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
{
    float previousFundamentalFrequency;
}

@property (nonatomic, readwrite) float loudness;
@property (nonatomic, readwrite) float fundamentalFrequency;
@property (nonatomic, readwrite) vDSP_Length fundamentalFrequencyIndex;
@property (nonatomic, readwrite) float binSize;

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
    // estimate actual frequency from bin with max freq
    self.fundamentalFrequencyIndex = [self findFundamentalIndex:fft withBufferSize:size];
    self.fundamentalFrequency = [PitchEstimator ratioEstimatedFrequencyOf:fft
                                                                   ofSize:size
                                                                  atIndex:self.fundamentalFrequencyIndex];
    // set df
    self.binSize = [fft frequencyAtIndex:1] - [fft frequencyAtIndex:0];
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

- (int) findFundamentalIndex:(EZAudioFFTRolling*)fft withBufferSize:(vDSP_Length)bufferSize
{
    // Find the top 3 indicies with the highest magnitude
    // { highest, lower, lowest }
    float highestFrequencyMagnitudes[3] = { 0 };
    int highestFrequencyIndicies[3] = { 0 };
    for (int i = 0; i < bufferSize; i++)
    {
        float magnitude = [fft frequencyMagnitudeAtIndex:i];
        
        if (magnitude > highestFrequencyMagnitudes[2])
        {
            if (magnitude > highestFrequencyMagnitudes[1])
            {
                if (magnitude > highestFrequencyMagnitudes[0])
                {
                    highestFrequencyIndicies[0] = i;
                    highestFrequencyMagnitudes[0] = magnitude;
                }
                else
                {
                    highestFrequencyIndicies[1] = i;
                    highestFrequencyMagnitudes[1] = magnitude;
                }
            }
            else
            {
                highestFrequencyIndicies[2] = i;
                highestFrequencyMagnitudes[2] = magnitude;
            }
        }
    }
    
    float fundamentalIndex = highestFrequencyIndicies[0];
    if ([fft frequencyAtIndex:highestFrequencyIndicies[1]] == previousFundamentalFrequency)
    {
        fundamentalIndex = highestFrequencyIndicies[1];
    }
    else if ([fft frequencyAtIndex:highestFrequencyIndicies[2]] == previousFundamentalFrequency)
    {
        fundamentalIndex = highestFrequencyIndicies[2];
    }
    
    previousFundamentalFrequency = [fft frequencyAtIndex:fundamentalIndex];
    
    return fundamentalIndex;
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
