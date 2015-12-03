//
//  AudioPlayer.m
//  PitchPerfect
//
//  Created by Sam Bender on 11/27/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import "AudioPlayer.h"
#import "PitchEstimation-Swift.h"

@interface AudioPlayer()

@property (nonatomic, retain) Note *note;
@property BOOL playForDuration;

@end

@implementation AudioPlayer

#pragma mark - Initialization

+ (AudioPlayer*) sharedInstance
{
    static dispatch_once_t pred;
    static id sharedInstance = nil;
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Public

- (void) play:(Note*)note
{
    if (self.note != nil && self.note.isPlaying)
    {
        [self.note stop];
    }
    
    self.note = note;
    self.playForDuration = NO;
    
    [self startOutput];
}

- (void) playForDuration:(Note*)note
{
    self.note = note;
    self.note.toneStart = [NSDate date];
    self.playForDuration = YES;
    
    [self startOutput];
}

- (void) stop
{
    if (self.note != nil)
    {
        self.note.isPlaying = NO;
    }
    else
    {
        NSLog(@"Called 'stop' on AudioPlayer when not had not been set");
    }
    
    [[EZOutput sharedOutput] stopPlayback];
}

#pragma mark - Private

- (void) startOutput
{
    self.note.isPlaying = YES;
    
    EZOutput *sharedOutput = [EZOutput sharedOutput];
    if ([sharedOutput isPlaying])
    {
        return;
    }
    
    [sharedOutput setDataSource:self];
    [sharedOutput startPlayback];
}

- (OSStatus)        output:(EZOutput *)output
 shouldFillAudioBufferList:(AudioBufferList *)audioBufferList
        withNumberOfFrames:(UInt32)frames
                 timestamp:(const AudioTimeStamp *)timestamp
{
    /**
     * The following code fills the audio buffer list with sine wave data for the frequency
     * of this note.
     */
    Float32 *bufferLeft = audioBufferList->mBuffers[0].mData;
    Float32 *bufferRight = audioBufferList->mBuffers[1].mData;
    for (int frame = 0; frame < frames; frame++)
    {
        bufferLeft[frame] = sin(self.note.positionInSineWave);
        bufferRight[frame] = bufferLeft[frame];
        self.note.positionInSineWave += self.note.thetaIncrement;
    }
    
    // determine if we are done playing
    if (self.playForDuration)
    {
        NSDate *now = [NSDate date];
        NSTimeInterval executionTime = [now timeIntervalSinceDate:self.note.toneStart];
        NSTimeInterval lengthOfThisAudioBufferList = frames / Note.SAMPLE_RATE;
        if (executionTime + lengthOfThisAudioBufferList > self.note.duration)
        {
            [self stop];
        }
    }
    
    return 0;
}

@end
