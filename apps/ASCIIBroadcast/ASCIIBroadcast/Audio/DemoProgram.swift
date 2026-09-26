//
//  DemoProgram.swift
//  ASCII Broadcast
//
//  A bundled, generated demonstration programme so a new creator can reach a
//  convincing preview before connecting anything (Phase 2 §3, onboarding).
//
//  The audio is synthesised by this file, so there is no third-party
//  recording, composition, or artwork involved and the demo is broadcast
//  eligible by construction.
//

import Foundation

struct DemoTrack {
    var title: String
    var artist: String
    var duration: Double
    var bpm: Double
    var root: Double          // root frequency
    var brightness: Double    // 0...1, drives filter and pad register
    var drive: Double         // 0...1, drives percussion density
}

enum DemoProgram {

    /// Nine pieces with deliberately different energy and tempo so playlist
    /// level direction has something real to read.
    static let tracks: [DemoTrack] = [
        DemoTrack(title: "Glass Cities",     artist: "Tyler Jay", duration: 246, bpm: 122, root: 55.00, brightness: 0.62, drive: 0.75),
        DemoTrack(title: "Paper Satellites", artist: "Tyler Jay", duration: 321, bpm: 104, root: 49.00, brightness: 0.48, drive: 0.55),
        DemoTrack(title: "Neon Fields",      artist: "Tyler Jay", duration: 278, bpm: 128, root: 61.74, brightness: 0.78, drive: 0.88),
        DemoTrack(title: "Rain Archive",     artist: "Tyler Jay", duration: 232, bpm: 92,  root: 43.65, brightness: 0.32, drive: 0.35),
        DemoTrack(title: "Folded Maps",      artist: "Tyler Jay", duration: 374, bpm: 110, root: 51.91, brightness: 0.55, drive: 0.6),
        DemoTrack(title: "Lossless Days",    artist: "Tyler Jay", duration: 267, bpm: 118, root: 58.27, brightness: 0.68, drive: 0.7),
        DemoTrack(title: "Signal Drift",     artist: "Tyler Jay", duration: 303, bpm: 136, root: 65.41, brightness: 0.85, drive: 0.92),
        DemoTrack(title: "The Way Out",      artist: "Tyler Jay", duration: 251, bpm: 98,  root: 46.25, brightness: 0.4,  drive: 0.45),
        DemoTrack(title: "Afterglow",        artist: "Tyler Jay", duration: 368, bpm: 86,  root: 41.20, brightness: 0.28, drive: 0.25)
    ]

    static var totalDuration: Double { tracks.reduce(0) { $0 + $1.duration } }
}

/// Deterministic synthesiser. Given the same track and sample position it
/// always produces the same audio, which keeps the demo reproducible.
final class DemoSynthesizer {

    private let sampleRate: Double
    private var track: DemoTrack
    private var noiseState: UInt32 = 0x1234_5678
    private var lowpassState: Double = 0
    private var padPhase: [Double] = [0, 0, 0]
    private var bassPhase: Double = 0
    private var arpPhase: Double = 0

    init(sampleRate: Double, track: DemoTrack) {
        self.sampleRate = sampleRate
        self.track = track
    }

    func setTrack(_ newTrack: DemoTrack) {
        track = newTrack
        lowpassState = 0
        bassPhase = 0
        arpPhase = 0
        padPhase = [0, 0, 0]
    }

    /// Structure: 8-bar phrases arranged intro / verse / chorus / breakdown /
    /// chorus / outro, so the analyser has real boundaries to find.
    private func sectionEnergy(at time: Double) -> (energy: Double, isChorus: Bool, isBreak: Bool) {
        let barSeconds = 240.0 / track.bpm          // 4 beats
        let bar = time / barSeconds
        let phrase = Int(bar / 8) % 8
        switch phrase {
        case 0:  return (0.35, false, false)        // intro
        case 1:  return (0.55, false, false)        // verse
        case 2:  return (0.9, true, false)          // chorus
        case 3:  return (0.6, false, false)         // verse
        case 4:  return (0.2, false, true)          // breakdown
        case 5:  return (0.75, false, false)        // build
        case 6:  return (1.0, true, false)          // chorus
        default: return (0.4, false, false)         // outro
        }
    }

    private func noise() -> Double {
        noiseState ^= noiseState << 13
        noiseState ^= noiseState >> 17
        noiseState ^= noiseState << 5
        return Double(Int32(bitPattern: noiseState)) / Double(Int32.max)
    }

    /// Render `count` interleaved-by-channel frames starting at `startFrame`.
    func render(left: UnsafeMutablePointer<Float>,
                right: UnsafeMutablePointer<Float>,
                count: Int,
                startFrame: Int64) {

        let beatSeconds = 60.0 / track.bpm
        let sixteenth = beatSeconds / 4

        for index in 0..<count {
            let frame = startFrame + Int64(index)
            let time = Double(frame) / sampleRate
            let (energy, isChorus, isBreak) = sectionEnergy(at: time)

            let beatPosition = time / beatSeconds
            let beatPhase = beatPosition - floor(beatPosition)
            let beatIndex = Int(floor(beatPosition))
            let sixteenthIndex = Int(floor(time / sixteenth))

            var sample = 0.0

            // Kick: sine with a fast pitch drop.
            if !isBreak {
                let decay = exp(-beatPhase * 9.0)
                let pitch = 52.0 + 90.0 * exp(-beatPhase * 26.0)
                sample += sin(2 * .pi * pitch * beatPhase * beatSeconds) * decay * 0.55 * (0.5 + energy * 0.5)
            }

            // Snare on beats 2 and 4.
            if beatIndex % 4 == 2 || beatIndex % 4 == 0 && beatIndex % 8 == 4 {
                let decay = exp(-beatPhase * 18.0)
                sample += noise() * decay * 0.22 * energy
            }

            // Hats on sixteenths, thinned during quiet passages.
            let hatPhase = (time / sixteenth) - floor(time / sixteenth)
            if Double(sixteenthIndex % 2) < 1.0 + track.drive {
                let decay = exp(-hatPhase * 42.0)
                sample += noise() * decay * 0.07 * (0.3 + track.drive * 0.7) * energy
            }

            // Bass: saw through a one-pole low pass.
            let scaleSteps: [Double] = [0, 3, 5, 7, 10]
            let bassStep = scaleSteps[(beatIndex / 4) % scaleSteps.count]
            let bassFrequency = track.root * pow(2.0, bassStep / 12.0)
            bassPhase += bassFrequency / sampleRate
            if bassPhase > 1 { bassPhase -= 1 }
            let saw = bassPhase * 2 - 1
            let cutoff = 0.04 + track.brightness * 0.22 * (isBreak ? 0.4 : 1.0)
            lowpassState += (saw - lowpassState) * cutoff
            sample += lowpassState * 0.35 * (0.6 + energy * 0.4)

            // Pad: three detuned partials, one octave up in choruses.
            let padOctave = isChorus ? 4.0 : 2.0
            for voice in 0..<3 {
                let detune = 1.0 + Double(voice - 1) * 0.004
                let interval = [0.0, 3.0, 7.0][voice]
                let frequency = track.root * padOctave * pow(2.0, interval / 12.0) * detune
                padPhase[voice] += frequency / sampleRate
                if padPhase[voice] > 1 { padPhase[voice] -= 1 }
                sample += sin(2 * .pi * padPhase[voice]) * 0.055 * (0.35 + energy * 0.65)
            }

            // Arp in choruses: sixteenth-note motion at the top of the mix.
            if isChorus {
                let arpStep = scaleSteps[(sixteenthIndex) % scaleSteps.count]
                let frequency = track.root * 8 * pow(2.0, arpStep / 12.0)
                arpPhase += frequency / sampleRate
                if arpPhase > 1 { arpPhase -= 1 }
                let decay = exp(-hatPhase * 10.0)
                sample += sin(2 * .pi * arpPhase) * decay * 0.1
            }

            // Soft clip and a gentle stereo spread.
            let clipped = tanh(sample * 1.25) * 0.72
            let spread = sin(time * 0.31) * 0.06
            left[index] = Float(clipped * (1 - spread))
            right[index] = Float(clipped * (1 + spread))
        }
    }
}
