//
//  ViewController.h
//  PitchEstimation
//
//  Created by Sam Bender on 11/10/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <EZAudio/EZAudio.h>

@interface ViewController : UIViewController <EZMicrophoneDelegate, EZAudioFFTDelegate>

/**
 EZAudioPlot for frequency plot
 */
@property (nonatomic,weak) IBOutlet EZAudioPlot *audioPlot;

/**
 A label used to display the maximum frequency (i.e. the frequency with the highest energy) calculated from the FFT.
 */
@property (nonatomic, weak) IBOutlet UILabel *maxFrequencyLabel;

@property (weak, nonatomic) IBOutlet UILabel *fftHighFrequencyLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *loudnessProgressBar;

@end

