//
//  AudioEncoder.swift
//  ASCII Broadcast
//
//  The program bus runs at 48 kHz because that is what the analysis and the
//  device graph want. The broadcast ladder wants 44.1 kHz AAC-LC. One
//  AVAudioConverter does the sample-rate conversion and the encode together,
//  and the conversion happens once, here, on the way out.
//

import Foundation
import AVFoundation

final class AudioEncoder {

    struct Packet {
        let data: Data                      // raw AAC frame, no ADTS header
        let timestampMilliseconds: UInt32
    }

    var onPacket: ((Packet) -> Void)?
    var onError: ((String) -> Void)?

    private(set) var isRunning = false
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?
    private let queue = DispatchQueue(label: "com.vagabond.asciibroadcast.aac")
    private var pending: [AVAudioPCMBuffer] = []
    private var encodedPackets = 0
    private var sampleRate: Double = 44_100
    private(set) var audioSpecificConfig = Data()

    private let framesPerPacket = 1024

    // MARK: - Lifecycle

    func start(inputFormat: AVAudioFormat, profile: OutputProfile) throws {
        stop()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: profile.audioSampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: profile.audioBitrate
        ]
        guard let output = AVAudioFormat(settings: settings),
              let converter = AVAudioConverter(from: inputFormat, to: output) else {
            throw BroadcastError.audioEncoderUnavailable
        }
        converter.bitRate = profile.audioBitrate
        self.converter = converter
        self.inputFormat = inputFormat
        self.outputFormat = output
        self.sampleRate = profile.audioSampleRate
        self.encodedPackets = 0
        self.pending.removeAll()
        self.audioSpecificConfig = FLV.audioSpecificConfig(sampleRate: profile.audioSampleRate, channels: 2)
        self.isRunning = true
    }

    func stop() {
        queue.sync {
            converter?.reset()
            converter = nil
            pending.removeAll()
            isRunning = false
        }
    }

    // MARK: - Feeding

    /// Called from the audio tap. Copies the buffer — the tap's storage is
    /// reused as soon as this returns.
    func append(_ buffer: AVAudioPCMBuffer) {
        guard isRunning, let inputFormat, buffer.frameLength > 0 else { return }
        guard let copy = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: buffer.frameLength) else { return }
        copy.frameLength = buffer.frameLength

        let channels = Int(inputFormat.channelCount)
        if let source = buffer.floatChannelData, let destination = copy.floatChannelData {
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: Int(buffer.frameLength))
            }
        } else if let source = buffer.int16ChannelData, let destination = copy.int16ChannelData {
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: Int(buffer.frameLength))
            }
        } else {
            return
        }

        queue.async { [weak self] in
            guard let self, self.isRunning else { return }
            // Bounded queue: if the encoder ever falls behind, drop the oldest
            // audio rather than growing latency without limit.
            self.pending.append(copy)
            if self.pending.count > 48 { self.pending.removeFirst(self.pending.count - 48) }
            self.drain()
        }
    }

    private func nextInputBuffer() -> AVAudioPCMBuffer? {
        guard !pending.isEmpty else { return nil }
        return pending.removeFirst()
    }

    private func drain() {
        guard let converter, let outputFormat else { return }
        while !pending.isEmpty {
            let output = AVAudioCompressedBuffer(format: outputFormat,
                                                 packetCapacity: 1,
                                                 maximumPacketSize: converter.maximumOutputPacketSize)
            var conversionError: NSError?
            var suppliedAnything = false
            let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
                if let buffer = self.nextInputBuffer() {
                    suppliedAnything = true
                    outStatus.pointee = .haveData
                    return buffer
                }
                outStatus.pointee = .noDataNow
                return nil
            }

            switch status {
            case .haveData:
                emit(output)
            case .inputRanDry:
                if !suppliedAnything { return }
            case .endOfStream, .error:
                if let conversionError {
                    onError?("The audio encoder reported an error: \(conversionError.localizedDescription)")
                }
                return
            @unknown default:
                return
            }
        }
    }

    private func emit(_ buffer: AVAudioCompressedBuffer) {
        let byteLength = Int(buffer.byteLength)
        guard byteLength > 0 else { return }
        let data = Data(bytes: buffer.data, count: byteLength)
        let seconds = Double(encodedPackets * framesPerPacket) / sampleRate
        encodedPackets += 1
        onPacket?(Packet(data: data, timestampMilliseconds: UInt32(max(0, (seconds * 1000).rounded()))))
    }
}
