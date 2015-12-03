//
//  AudioPlayer.h
//  PitchPerfect
//
//  Created by Sam Bender on 11/27/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EZAudio/EZAudio.h>

@class Note;

@interface AudioPlayer : NSObject <EZOutputDataSource>

+ (AudioPlayer*) sharedInstance;
- (void) play:(Note*)note;
- (void) playForDuration:(Note*)note;
- (void) stop;

@end
