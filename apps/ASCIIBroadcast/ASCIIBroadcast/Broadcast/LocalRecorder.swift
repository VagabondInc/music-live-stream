//
//  LocalRecorder.swift
//  ASCII Broadcast
//
//  Writes the same program image to disk as an MP4. Recording is independent
//  of the network link: if the destination drops, the file keeps going, which
//  is the difference between a lost session and a recoverable one.
//

import Foundation
import AVFoundation
import CoreMedia
import CoreVideo

final class LocalRecorder {

    private(set) var isRecording = false
    private(set) var outputURL: URL?
    private(set) var startedAt: Date?
    private(set) var appendFailures = 0

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStarted = false

    private var audioConverter: AVAudioConverter?
    private var recordFormat: AVAudioFormat?
    private var audioSamplesWritten: Int64 = 0
    private var pendingInput: AVAudioPCMBuffer?
    private let lock = NSLock()

    var onError: ((String) -> Void)?

    var fileSizeBytes: Int {
        guard let outputURL else { return 0 }
        let values = try? outputURL.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize ?? 0
    }

    var elapsed: TimeInterval { startedAt.map { Date().timeIntervalSince($0) } ?? 0 }

    // MARK: - Lifecycle

    func start(url: URL, profile: OutputProfile, inputFormat: AVAudioFormat) throws {
        stopImmediately()
        try? FileManager.default.removeItem(at: url)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw BroadcastError.recorderUnavailable(error.localizedDescription)
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: profile.width,
            AVVideoHeightKey: profile.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: profile.videoBitrate,
                AVVideoMaxKeyFrameIntervalKey: Int(profile.keyframeIntervalSeconds * Double(profile.frameRate)),
                AVVideoAllowFrameReorderingKey: false,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: profile.audioSampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: profile.audioBitrate
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: profile.width,
            kCVPixelBufferHeightKey as String: profile.height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput,
                                                           sourcePixelBufferAttributes: attributes)

        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
            throw BroadcastError.recorderUnavailable("the writer rejected its inputs")
        }
        writer.add(videoInput)
        writer.add(audioInput)
        guard writer.startWriting() else {
            throw BroadcastError.recorderUnavailable(writer.error?.localizedDescription ?? "the writer refused to start")
        }

        guard let target = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: profile.audioSampleRate,
                                         channels: 2,
                                         interleaved: true),
              let converter = AVAudioConverter(from: inputFormat, to: target) else {
            throw BroadcastError.recorderUnavailable("the audio format could not be prepared")
        }

        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.adaptor = adaptor
        self.recordFormat = target
        self.audioConverter = converter
        self.audioSamplesWritten = 0
        self.sessionStarted = false
        self.appendFailures = 0
        self.outputURL = url
        self.startedAt = Date()
        self.isRecording = true
    }

    func finish(completion: @escaping (URL?) -> Void) {
        guard isRecording, let writer else { completion(nil); return }
        isRecording = false
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        let url = outputURL
        writer.finishWriting { [weak self] in
            self?.writer = nil
            self?.videoInput = nil
            self?.audioInput = nil
            self?.adaptor = nil
            DispatchQueue.main.async { completion(url) }
        }
    }

    private func stopImmediately() {
        if isRecording {
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            writer?.cancelWriting()
        }
        writer = nil
        videoInput = nil
        audioInput = nil
        adaptor = nil
        isRecording = false
    }

    // MARK: - Appending

    func append(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard isRecording, let writer, let adaptor, let videoInput else { return }
        if writer.status == .failed {
            reportWriterFailure(writer)
            return
        }
        if !sessionStarted {
            writer.startSession(atSourceTime: presentationTime)
            sessionStarted = true
        }
        guard videoInput.isReadyForMoreMediaData else {
            appendFailures += 1
            return
        }
        if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
            appendFailures += 1
            reportWriterFailure(writer)
        }
    }

    func append(pcm buffer: AVAudioPCMBuffer) {
        guard isRecording, sessionStarted,
              let writer, let audioInput, let converter = audioConverter,
              let target = recordFormat else { return }
        guard audioInput.isReadyForMoreMediaData else { return }

        lock.lock()
        pendingInput = buffer
        lock.unlock()

        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { [weak self] _, outStatus in
            guard let self else { outStatus.pointee = .noDataNow; return nil }
            self.lock.lock()
            let next = self.pendingInput
            self.pendingInput = nil
            self.lock.unlock()
            if let next {
                outStatus.pointee = .haveData
                return next
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        guard status == .haveData || status == .inputRanDry, output.frameLength > 0 else { return }

        let presentationTime = CMTime(value: audioSamplesWritten, timescale: CMTimeScale(target.sampleRate))
        audioSamplesWritten += Int64(output.frameLength)

        guard let sampleBuffer = LocalRecorder.sampleBuffer(from: output, presentationTime: presentationTime) else { return }
        if !audioInput.append(sampleBuffer) {
            appendFailures += 1
            reportWriterFailure(writer)
        }
    }

    private func reportWriterFailure(_ writer: AVAssetWriter) {
        guard writer.status == .failed else { return }
        let reason = writer.error?.localizedDescription ?? "unknown"
        isRecording = false
        onError?("The local recording stopped (\(reason)). The stream is unaffected.")
    }

    // MARK: - Helpers

    static func sampleBuffer(from pcm: AVAudioPCMBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        var asbd = pcm.format.streamDescription.pointee
        var formatDescription: CMAudioFormatDescription?
        var status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                    asbd: &asbd,
                                                    layoutSize: 0,
                                                    layout: nil,
                                                    magicCookieSize: 0,
                                                    magicCookie: nil,
                                                    extensions: nil,
                                                    formatDescriptionOut: &formatDescription)
        guard status == noErr, let description = formatDescription else { return nil }

        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(pcm.format.sampleRate)),
                                        presentationTimeStamp: presentationTime,
                                        decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                      dataBuffer: nil,
                                      dataReady: false,
                                      makeDataReadyCallback: nil,
                                      refcon: nil,
                                      formatDescription: description,
                                      sampleCount: CMItemCount(pcm.frameLength),
                                      sampleTimingEntryCount: 1,
                                      sampleTimingArray: &timing,
                                      sampleSizeEntryCount: 0,
                                      sampleSizeArray: nil,
                                      sampleBufferOut: &sampleBuffer)
        guard status == noErr, let buffer = sampleBuffer else { return nil }

        status = CMSampleBufferSetDataBufferFromAudioBufferList(buffer,
                                                               blockBufferAllocator: kCFAllocatorDefault,
                                                               blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                               flags: 0,
                                                               bufferList: pcm.audioBufferList)
        guard status == noErr else { return nil }
        return buffer
    }

    /// Default recording location: Movies on macOS, Documents on iOS.
    static func defaultRecordingURL(sessionName: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let stamp = formatter.string(from: Date())
        let safeName = sessionName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        #if os(macOS)
        let directory = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #else
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #endif
        return directory.appendingPathComponent("\(safeName) \(stamp).mp4")
    }
}
