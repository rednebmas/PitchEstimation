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
    float fftAudioPlotScale;
    CGFloat beingPinchedScale;
}

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
static float const FFTGain = 40.0;

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
    [self.audioPlot addGestureRecognizer:singleFingerTap];
    
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
    self.audioPlot.shouldFill = YES;
    self.audioPlot.plotType = EZPlotTypeBuffer;
    self.audioPlot.shouldCenterYAxis = NO;
    self.audioPlot.gain = FFTGain;
    
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
    
    //
    // Pinch gesture recognizer for fft
    //
    fftAudioPlotScale = 10.0;
    beingPinchedScale = 1.0;
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinched:)];
    [self.audioPlot addGestureRecognizer:pinchGestureRecognizer];
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
        self.audioPlot.plotType = EZPlotTypeBuffer;
        self.audioPlot.shouldFill = NO;
        self.audioPlot.shouldCenterYAxis = YES;
        self.audioPlot.shouldMirror = NO;
        self.audioPlot.gain = 1.0;
        
        self.fftHighFrequencyLabel.hidden = YES;
        
        audioPlotType = AudioPlotTypeTimeNoFillBuffer;
    }
    else if (audioPlotType == AudioPlotTypeTimeNoFillBuffer) // switch to fill rolling
    {
        self.audioPlot.shouldFill = YES;
        self.audioPlot.plotType = EZPlotTypeRolling;
        self.audioPlot.shouldCenterYAxis = YES;
        self.audioPlot.shouldMirror = YES;
        self.audioPlot.gain = 1.0;
        
        audioPlotType = AudioPlotTypeTimeFillRolling;
    }
    else // switch to fft
    {
        self.audioPlot.shouldFill = YES;
        self.audioPlot.plotType = EZPlotTypeBuffer;
        self.audioPlot.shouldCenterYAxis = NO;
        self.audioPlot.shouldMirror = NO;
        self.audioPlot.gain = FFTGain;
        [self.audioPlot clear];
        
        self.fftHighFrequencyLabel.hidden = NO;
        
        audioPlotType = AudioPlotTypeFFT;
    }
}

- (void) pinched:(UIPinchGestureRecognizer*)pinchRecognizer
{
    if (pinchRecognizer.scale * fftAudioPlotScale < 1)
        return;
    
    beingPinchedScale = pinchRecognizer.scale;
    
    if (pinchRecognizer.state == UIGestureRecognizerStateEnded) {
        fftAudioPlotScale *= beingPinchedScale;
        beingPinchedScale = 1.0;
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
    
    // do some of our own processing
    [pitchEstimator processAudioBuffer:buffer ofSize:bufferSize];
    
    //
    // Calculate the FFT, will trigger EZAudioFFTDelegate
    //
    [self.fft computeFFTWithBuffer:buffer[0] withBufferSize:bufferSize];

    // draw
    dispatch_async(dispatch_get_main_queue(), ^{
        if (audioPlotType == AudioPlotTypeTimeFillRolling
            || audioPlotType == AudioPlotTypeTimeNoFillBuffer)
        {
            [weakSelf.audioPlot updateBuffer:buffer[0]
                                  withBufferSize:bufferSize];
        }
    });
    
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
    
    float fundamentalFrequency = pitchEstimator.fundamentalFrequency;
    vDSP_Length fundamentalFrequencyIndex = pitchEstimator.fundamentalFrequencyIndex;
    NSString *noteName = [EZAudioUtilities noteNameStringForFrequency:fundamentalFrequency
                                                        includeOctave:YES];
    // create debug string
    NSString *debugString;
    if (pitchEstimator.loudness < -90)
    {
        debugString = [NSString
                       stringWithFormat:@"Note: %@\n"
                                         "Frequency: %@\n"
                                         "Estimator diff: %@\n"
                                         "Loudness: %.0f\n"
                                         "Bin size: %.2f",
                       @"--",
                       @"--",
                       @"--",
                       pitchEstimator.loudness,
                       pitchEstimator.binSize];
    }
    else
    {
        debugString = [NSString
                       stringWithFormat:@"Note: %@\n"
                                         "Frequency: %.0f\n"
                                         "Estimator diff: %.1f\n"
                                         "Loudness: %.0f\n"
                                         "Bin size: %.2f",
                       noteName,
                       fundamentalFrequency,
                       fabsf(fundamentalFrequency - [fft frequencyAtIndex:fundamentalFrequencyIndex]),
                       pitchEstimator.loudness,
                       pitchEstimator.binSize];
    }
    
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.maxFrequencyLabel.text = debugString;
        
        if (audioPlotType == AudioPlotTypeFFT) {
            UInt32 scaledBufferSize = (UInt32)(bufferSize/(fftAudioPlotScale*beingPinchedScale));
            weakSelf.fftHighFrequencyLabel.text = [NSString stringWithFormat:@"%.1f Hz", [fft frequencyAtIndex:scaledBufferSize]];
            [weakSelf.audioPlot updateBuffer:fftData withBufferSize:scaledBufferSize];
        }
    });
}

//------------------------------------------------------------------------------


@end
