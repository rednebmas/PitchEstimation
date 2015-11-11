//
//  ViewController.m
//  PitchEstimation
//
//  Created by Sam Bender on 11/10/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import "ViewController.h"
#import "PitchEstimator.h"

typedef NS_ENUM(NSInteger, AudioPlotType) {
    AudioPlotTypeFFT,
    AudioPlotTypeTimeNoFillBuffer,
    AudioPlotTypeTimeFillRolling
};

@interface ViewController ()
{
    PitchEstimator *pitchEstimator;
    AudioPlotType audioPlotType;
}

/**
 EZAudioPlot for time plot
 */
@property (nonatomic,weak) IBOutlet EZAudioPlot *audioPlotTime;

/**
 The microphone used to get input.
 */
@property (nonatomic,strong) EZMicrophone *microphone;

/**
 Used to calculate a rolling FFT of the incoming audio data.
 */
@property (nonatomic, strong) EZAudioFFTRolling *fft;

@end


static vDSP_Length const FFTViewControllerFFTWindowSize = 4096 * 2 * 2;

@implementation ViewController

- (UIStatusBarStyle) preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // setup gesture recognizer
    audioPlotType = AudioPlotTypeFFT;
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(switchPlotType)];
    [self.audioPlotFreq addGestureRecognizer:singleFingerTap];
    
    //
    // Setup the AVAudioSession. EZMicrophone will not work properly on iOS
    // if you don't do this!
    //
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error)
    {
        NSLog(@"Error setting up audio session category: %@", error.localizedDescription);
    }
    [session setActive:YES error:&error];
    if (error)
    {
        NSLog(@"Error setting up audio session active: %@", error.localizedDescription);
    }
    
    // setup pitch estimator
    pitchEstimator = [[PitchEstimator alloc] init];
    
    //
    // Setup time domain audio plot
    //
    
    //
    // Setup frequency domain audio plot
    //
    self.audioPlotFreq.shouldFill = YES;
    self.audioPlotFreq.plotType = EZPlotTypeBuffer;
    self.audioPlotFreq.shouldCenterYAxis = NO;
    
    //
    // Create an instance of the microphone and tell it to use this view controller instance as the delegate
    //
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    
    //
    // Create an instance of the EZAudioFFTRolling to keep a history of the incoming audio data and calculate the FFT.
    //
    self.fft = [EZAudioFFTRolling fftWithWindowSize:FFTViewControllerFFTWindowSize
                                         sampleRate:self.microphone.audioStreamBasicDescription.mSampleRate
                                           delegate:self];
    
    //
    // Start the mic
    //
    [self.microphone startFetchingAudio];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (void) switchPlotType
{
    if (audioPlotType == AudioPlotTypeFFT) // switch to no fill buffer
    {
        self.audioPlotFreq.plotType = EZPlotTypeBuffer;
        self.audioPlotFreq.shouldFill = NO;
        self.audioPlotFreq.shouldCenterYAxis = YES;
        self.audioPlotFreq.shouldMirror = NO;
        
        audioPlotType = AudioPlotTypeTimeNoFillBuffer;
    }
    else if (audioPlotType == AudioPlotTypeTimeNoFillBuffer) // switch to fill rolling
    {
        self.audioPlotFreq.shouldFill = YES;
        self.audioPlotFreq.plotType = EZPlotTypeRolling;
        self.audioPlotFreq.shouldCenterYAxis = YES;
        self.audioPlotFreq.shouldMirror = YES;
        
        audioPlotType = AudioPlotTypeTimeFillRolling;
    }
    else // switch to fft
    {
        self.audioPlotFreq.shouldFill = YES;
        self.audioPlotFreq.plotType = EZPlotTypeBuffer;
        self.audioPlotFreq.shouldCenterYAxis = NO;
        self.audioPlotFreq.shouldMirror = NO;
        
        audioPlotType = AudioPlotTypeFFT;
    }
}

//------------------------------------------------------------------------------
#pragma mark - EZMicrophoneDelegate
//------------------------------------------------------------------------------

-(void)    microphone:(EZMicrophone *)microphone
     hasAudioReceived:(float **)buffer
       withBufferSize:(UInt32)bufferSize
 withNumberOfChannels:(UInt32)numberOfChannels
{
    __weak typeof (self) weakSelf = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (audioPlotType == AudioPlotTypeTimeFillRolling
            || audioPlotType == AudioPlotTypeTimeNoFillBuffer)
        {
            [weakSelf.audioPlotFreq updateBuffer:buffer[0]
                                  withBufferSize:bufferSize];
        }
    });
    
    // do some of our own processing
    [pitchEstimator processAudioBuffer:buffer ofSize:bufferSize];
    
    //
    // Calculate the FFT, will trigger EZAudioFFTDelegate
    //
    [self.fft computeFFTWithBuffer:buffer[0] withBufferSize:bufferSize];

}

//------------------------------------------------------------------------------
#pragma mark - EZAudioFFTDelegate
//------------------------------------------------------------------------------

- (void)        fft:(EZAudioFFTRolling *)fft
 updatedWithFFTData:(float *)fftData
         bufferSize:(vDSP_Length)bufferSize
{
    // process
    [pitchEstimator processFFT:fft withFFTData:fftData ofSize:bufferSize];
    
    float maxFrequency = pitchEstimator.fundamentalFrequency;
    NSString *noteName = [EZAudioUtilities noteNameStringForFrequency:maxFrequency
                                                        includeOctave:YES];
    
    
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.maxFrequencyLabel.text = [NSString stringWithFormat:@"Highest Note: %@\nFrequency: %.2f\nLoudness: %.0f", noteName, maxFrequency, pitchEstimator.loudness];
        
        if (audioPlotType == AudioPlotTypeFFT) {
            [weakSelf.audioPlotFreq updateBuffer:fftData withBufferSize:(UInt32)bufferSize/10];
        }
    });
}

//------------------------------------------------------------------------------


@end
