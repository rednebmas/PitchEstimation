//
//  PitchEstimator.m
//  PitchEstimation
//
//  Created by Sam Bender on 11/10/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <EZAudio/EZAudio.h>
#import "PitchEstimator.h"
#import "SBMath.h"

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

- (id) init
{
    self = [super init];
    if (self)
    {
        self.binInterpolationMethod = PitchEstimatorBinInterpolationMethodGaussian;
        self.windowingMethod = PitchEstimatorWindowingMethodBlackmanHarris;
    }
    return self;
}

#pragma mark - Public methods

- (void) processAudioBuffer:(float**)buffer ofSize:(UInt32)size
{
    self.loudness = [PitchEstimator loudness:buffer ofSize:size];
    
    if (self.windowingMethod == PitchEstimatorWindowingMethodHanning)
    {
        [PitchEstimator hann:buffer length:size];
    }
    else if (self.windowingMethod == PitchEstimatorWindowingMethodBlackmanHarris)
    {
        [PitchEstimator blackmanHarris:buffer length:size];
    }
    else if (self.windowingMethod == PitchEstimatorWindowingMethodGaussian)
    {
        [PitchEstimator gaussianWindow:buffer length:size];
    }
}


- (void) processFFT:(EZAudioFFTRolling*)fft withFFTData:(float*)fftData ofSize:(vDSP_Length)size
{
    // estimate actual frequency from bin with max freq
    self.fundamentalFrequencyIndex = [self findFundamentalIndex:fft withBufferSize:size];
    
    if (self.binInterpolationMethod == PitchEstimatorBinInterpolationMethodQuadratic)
    {
        self.fundamentalFrequency = [PitchEstimator
                                     quadraticEstimatedFrequencyOf:fft
                                     ofSize:size
                                     atIndex:self.fundamentalFrequencyIndex];
    }
    else if (self.binInterpolationMethod == PitchEstimatorBinInterpolationMethodGaussian)
    {
        self.fundamentalFrequency = [PitchEstimator
                                     gaussianEstimatedFrequencyOf:fft
                                     ofSize:size
                                     atIndex:self.fundamentalFrequencyIndex];
    }
    else
    {
        self.fundamentalFrequency = [fft frequencyAtIndex:self.fundamentalFrequencyIndex];
    }
    
    // set df
    self.binSize = [fft frequencyAtIndex:1] - [fft frequencyAtIndex:0];
}

#pragma mark - FFT

/**
 * Something I came up with from playing with matlab... Doesn't work paticularly well
 */
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

/**
 * More information can be found:
 * https://ccrma.stanford.edu/~jos/sasp/Quadratic_Interpolation_Spectral_Peaks.html
 */
+ (float) quadraticEstimatedFrequencyOf:(EZAudioFFT*)fft ofSize:(vDSP_Length)size atIndex:(vDSP_Length)index
{
    if (index == 0)
        return [fft frequencyAtIndex:0];
    
    float alpha = logf([fft frequencyMagnitudeAtIndex:index-1]);
    float beta = logf([fft frequencyMagnitudeAtIndex:index]);
    float gamma = logf([fft frequencyMagnitudeAtIndex:index+1]);
    
    // shoud be between -.5 and .5
    float binDifference = .5 * ((alpha - gamma) / (alpha - 2 * beta + gamma));
    
    float binSize = [fft frequencyAtIndex:1] - [fft frequencyAtIndex:0];
    float estimated = [fft frequencyAtIndex:index] + binSize * binDifference;
    
    return estimated;
}

/**
 * More information can be found:
 * https://mgasior.web.cern.ch/mgasior/pap/FFT_resol_note.pdf
 */
+ (float) gaussianEstimatedFrequencyOf:(EZAudioFFT*)fft ofSize:(vDSP_Length)size atIndex:(vDSP_Length)index
{
    if (index == 0)
        return [fft frequencyAtIndex:0];
    
    float alpha = [fft frequencyMagnitudeAtIndex:index-1];
    float beta = [fft frequencyMagnitudeAtIndex:index];
    float gamma = [fft frequencyMagnitudeAtIndex:index+1];
    
    // shoud be between -.5 and .5
    float numerator = logf(gamma / alpha);
    float denominator = 2.0 * logf((beta * beta) / (gamma * alpha));
    float binDifference = numerator / denominator;
    
    float binSize = [fft frequencyAtIndex:1] - [fft frequencyAtIndex:0];
    float estimated = [fft frequencyAtIndex:index] + binSize * binDifference;
    
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
    double rms = sumSquared/(double)bufferSize;
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

+ (void) blackmanHarris:(float**)buffer length:(UInt32)length
{
    float factor = 0;
    float a0 = 0.355768;
    float a1 = 0.487396;
    float a2 = 0.144232;
    float a3 = 0.012604;
    float lMinusOne = (float)length;
    
    for (float i = 0; i < length; i++)
    {
        factor = a0
                 - a1 * cosf(2 * M_PI * i / lMinusOne)
                 + a2 * cosf(4 * M_PI * i / lMinusOne)
                 - a3 * cosf(6 * M_PI * i / lMinusOne);
        
        int intI = (int)i;
        buffer[0][intI] = buffer[0][intI] * factor;
    }
}

+ (void) gaussianWindow:(float**)buffer length:(UInt32)length
{
//    float stdDeviation = [SBMath standardDeviationOf:buffer[0] ofSize:length];
//    float stdDeviationSquared = stdDeviation * stdDeviation;
    
    /*
     * Method 1
     *
     
    float factor;
    float n;
    float lengthOverTwo = length / 2;
    float lengthMinusOneOverTwo = (length - 1) / 2;
    float toSquare;
    for (float i = 0; i < length; i++)
    {
        n = i - lengthOverTwo;
        toSquare = 6 * n / lengthMinusOneOverTwo;
        factor = powf(M_E, -.5 * toSquare * toSquare);
        
        int intI = (int)i;
        buffer[0][intI] = buffer[0][intI] * factor;
    }
     */
    
    float factor;
    float n;
    float sigma = (length - 1) / (2 * 3);
    float lengthOverTwo = length / 2;
    for (float i = 0; i < length; i++)
    {
        n = i - lengthOverTwo;
        factor = powf(M_E, (- (n * n)) / (2 * sigma * sigma));
        
        int intI = (int)i;
        buffer[0][intI] = buffer[0][intI] * factor;
    }
}

@end
