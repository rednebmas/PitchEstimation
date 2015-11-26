//
//  Note.swift
//  PitchPerfect
//
//  Created by Sam Bender on 11/23/15.
//  Copyright © 2015 Sam Bender. All rights reserved.
//

import Foundation
import EZAudio

//
// Note: note name is not completely implemented! Should work for notes in C major
// All properties on this class are immutable
//
class Note : CustomStringConvertible {
    
    // MARK: Constants
    
    static let HALF_STEPS_AWAY_FROM_A4_TO_NOTE_IN_4TH_OCTAVE: [Int] = [0, 2, -9, -7, -5, -4, -2]
    static let TUNER_CALIBRATION: Double = 440.0 // frequency of A4
    static let TWO_TO_THE_ONE_OVER_TWELVE: Double =  1.05946309435
    static let A_CHAR_CODE: UInt32 = ("A" as Character).unicodeScalarCodePoint()
    
    // MARK: Public properties
    
    let fullNameWithOctave: String // e.g. C#4
    let fullNameWithoutOctave: String // e.g. C#
    let frequency: Double // hz
    let duration: Double // seconds
    let octave: Int
    let accidental: Int
    let differenceInCentsToNote: Double
    
    var description: String {
        return self.fullNameWithOctave
    }
    
    // MARK: Initializers
    
    // not finished
    init(frequency: Double) {
        self.frequency = frequency
        self.duration = 1.0
        
        self.fullNameWithOctave = EZAudioUtilities.noteNameStringForFrequency(Float(frequency), includeOctave: true)
        self.fullNameWithoutOctave = EZAudioUtilities.noteNameStringForFrequency(Float(frequency), includeOctave: false)
        self.accidental = Note.parseAccidental(self.fullNameWithOctave)
        
        if self.accidental != 0 {
            // e.g. C#4
            self.octave = Int(self.fullNameWithOctave[2])!
        } else {
            // e.g. C4
            self.octave = Int(self.fullNameWithOctave[1])!
        }
        
        // calculate frequency of pure note, then find difference in cents
        let pureNoteFrequency = Note.calculateFrequency(fullNameWithOctave[0], accidental: accidental, octave: self.octave)
        self.differenceInCentsToNote = 1200 * log2( self.frequency / pureNoteFrequency )
    }
    
    convenience init(noteName: String, duration: Double) {
        let accidental = Note.parseAccidental(noteName)
        self.init(noteName: noteName[0], accidental: accidental, octave: 4, duration: duration)
    }
    
    convenience init(noteName: String, octave: Int, duration: Double) {
        let accidental = Note.parseAccidental(noteName)
        self.init(noteName: noteName[0], accidental: accidental, octave: octave, duration: duration)
    }
    
    init(noteName: Character, accidental: Int, octave: Int, duration: Double) {
        self.octave = octave
        self.accidental = accidental
        self.duration = duration
        self.frequency = Note.calculateFrequency(noteName, accidental: accidental, octave: octave)
        self.differenceInCentsToNote = 0.0
        
        let accidentalString = Note.accidentalIntToString(accidental)
        self.fullNameWithOctave = String(noteName) + accidentalString + octave.description
        self.fullNameWithoutOctave = String(noteName) + accidentalString
    }
    
    private static func parseAccidental(noteName: String) -> Int {
        var accidental = 0
        if noteName.characters.count > 1 {
            if noteName[1] == "#" {
                accidental = 1
            } else if noteName[1] == "b" {
                accidental = -1
            }
        }
        
        return accidental
    }
    
    private static func accidentalIntToString(accidental: Int) -> String {
        if accidental == 1 {
            return "#"
        } else if accidental == 0 {
            return ""
        } else {
            return "b"
        }
    }
    
    // MARK: Misc
    
    static func calculateFrequency(letter: Character, accidental: Int, octave: Int) -> Double {
        let characterDiff = Int(letter.unicodeScalarCodePoint() - A_CHAR_CODE)
        var halfStepsFromA4 = HALF_STEPS_AWAY_FROM_A4_TO_NOTE_IN_4TH_OCTAVE[characterDiff] + 12 * (octave - 4)
        halfStepsFromA4 += accidental
        let halfStepsFromA4Double = Double(halfStepsFromA4)
        
        let frequency = TUNER_CALIBRATION * pow(TWO_TO_THE_ONE_OVER_TWELVE, halfStepsFromA4Double)
        return frequency
    }
}

// http://stackoverflow.com/a/24144365/337934
extension String {
    
    subscript (i: Int) -> Character {
        return self[self.startIndex.advancedBy(i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        return substringWithRange(Range(start: startIndex.advancedBy(r.startIndex), end: startIndex.advancedBy(r.endIndex)))
    }
}

// http://stackoverflow.com/a/24102584/337934
extension Character
{
    func unicodeScalarCodePoint() -> UInt32
    {
        let characterString = String(self)
        let scalars = characterString.unicodeScalars
        
        return scalars[scalars.startIndex].value
    }
}