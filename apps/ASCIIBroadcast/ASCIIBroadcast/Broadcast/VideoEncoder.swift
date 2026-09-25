//
//  VideoEncoder.swift
//  ASCII Broadcast
//
//  H.264 via VideoToolbox. Configured for live: real-time mode, no frame
//  reordering (so DTS == PTS and RTMP composition time is always zero), and a
//  keyframe every two seconds as YouTube's ingest expects.
//

import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo

final class VideoEncoder {

    struct Packet {
        let data: Data              // AVCC, 4-byte length prefixed
        let timestampMilliseconds: UInt32
        let isKeyframe: Bool
    }

    /// Called on the encoder's callback queue.
    var onPacket: ((Packet) -> Void)?
    /// Emitted once when the first parameter sets arrive, and again if they change.
    var onDecoderConfiguration: ((Data) -> Void)?
    var onError: ((String) -> Void)?

    private(set) var isRunning = false
    private var session: VTCompressionSession?
    private var width: Int = 0
    private var height: Int = 0
    private var startTime: CMTime?
    private var lastConfiguration: Data?
    private(set) var encodedFrames = 0
    private(set) var droppedFrames = 0

    // MARK: - Lifecycle

    func start(profile: OutputProfile) throws {
        stop()
        width = profile.width
        height = profile.height

        var created: VTCompressionSession?
        let status = VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                width: Int32(profile.width),
                                                height: Int32(profile.height),
                                                codecType: kCMVideoCodecType_H264,
                                                encoderSpecification: nil,
                                                imageBufferAttributes: nil,
                                                compressedDataAllocator: nil,
                                                outputCallback: nil,
                                                refcon: nil,
                                                compressionSessionOut: &created)
        guard status == noErr, let session = created else {
            throw BroadcastError.encoderUnavailable(Int(status))
        }
        self.session = session

        func set(_ key: CFString, _ value: CFTypeRef) {
            VTSessionSetProperty(session, key: key, value: value)
        }
        set(kVTCompressionPropertyKey_RealTime, kCFBooleanTrue)
        set(kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse)
        set(kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel)
        set(kVTCompressionPropertyKey_AverageBitRate, NSNumber(value: profile.videoBitrate))
        set(kVTCompressionPropertyKey_ExpectedFrameRate, NSNumber(value: profile.frameRate))
        set(kVTCompressionPropertyKey_MaxKeyFrameInterval,
            NSNumber(value: Int(profile.keyframeIntervalSeconds * Double(profile.frameRate))))
        set(kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
            NSNumber(value: profile.keyframeIntervalSeconds))
        // A hard cap keeps a glitchy scene from spiking past the ingest budget.
        let cap: [Any] = [NSNumber(value: profile.videoBitrate / 8 * 2), NSNumber(value: 1.0)]
        set(kVTCompressionPropertyKey_DataRateLimits, cap as CFArray)

        VTCompressionSessionPrepareToEncodeFrames(session)
        startTime = nil
        encodedFrames = 0
        droppedFrames = 0
        lastConfiguration = nil
        isRunning = true
    }

    func stop() {
        guard let session else { isRunning = false; return }
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        VTCompressionSessionInvalidate(session)
        self.session = nil
        isRunning = false
    }

    func requestKeyframe() {
        // Applied to the next frame via frameProperties.
        forceKeyframeOnNextFrame = true
    }

    private var forceKeyframeOnNextFrame = false

    // MARK: - Encoding

    func encode(pixelBuffer: CVPixelBuffer, presentationTime: CMTime, duration: CMTime) {
        guard isRunning, let session else { return }
        if startTime == nil { startTime = presentationTime }

        var properties: CFDictionary?
        if forceKeyframeOnNextFrame {
            properties = [kVTEncodeFrameOptionKey_ForceKeyFrame as String: true] as CFDictionary
            forceKeyframeOnNextFrame = false
        }

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: duration,
            frameProperties: properties,
            infoFlagsOut: nil
        ) { [weak self] status, infoFlags, sampleBuffer in
            guard let self else { return }
            if status != noErr {
                self.droppedFrames += 1
                self.onError?("The video encoder dropped a frame (status \(status)).")
                return
            }
            if infoFlags.contains(.frameDropped) {
                self.droppedFrames += 1
                return
            }
            guard let sampleBuffer else { return }
            self.handle(sampleBuffer: sampleBuffer)
        }

        if status != noErr {
            droppedFrames += 1
            onError?("The video encoder rejected a frame (status \(status)).")
        }
    }

    private func handle(sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        // Parameter sets: emit avcC before the first media packet.
        if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
            if let configuration = VideoEncoder.decoderConfiguration(from: formatDescription),
               configuration != lastConfiguration {
                lastConfiguration = configuration
                onDecoderConfiguration?(configuration)
            }
        }

        var isKeyframe = true
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
            as? [[CFString: Any]], let first = attachments.first {
            let notSync = (first[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false
            isKeyframe = !notSync
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var totalLength = 0
        var pointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer,
                                                 atOffset: 0,
                                                 lengthAtOffsetOut: nil,
                                                 totalLengthOut: &totalLength,
                                                 dataPointerOut: &pointer)
        guard status == kCMBlockBufferNoErr, let base = pointer, totalLength > 0 else { return }

        let data = Data(bytes: base, count: totalLength)
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let origin = startTime ?? presentation
        let elapsed = CMTimeGetSeconds(CMTimeSubtract(presentation, origin))
        let milliseconds = UInt32(max(0, (elapsed * 1000).rounded()))

        encodedFrames += 1
        onPacket?(Packet(data: data, timestampMilliseconds: milliseconds, isKeyframe: isKeyframe))
    }

    static func decoderConfiguration(from formatDescription: CMFormatDescription) -> Data? {
        var parameterSetCount = 0
        let countStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: nil)
        guard countStatus == noErr, parameterSetCount >= 2 else { return nil }

        var sets: [Data] = []
        for index in 0..<parameterSetCount {
            var pointer: UnsafePointer<UInt8>?
            var size = 0
            let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDescription,
                parameterSetIndex: index,
                parameterSetPointerOut: &pointer,
                parameterSetSizeOut: &size,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil)
            guard status == noErr, let base = pointer, size > 0 else { continue }
            sets.append(Data(bytes: base, count: size))
        }
        guard sets.count >= 2 else { return nil }
        return FLV.avcDecoderConfigurationRecord(sps: [sets[0]], pps: Array(sets.dropFirst()))
    }
}

enum BroadcastError: LocalizedError {
    case encoderUnavailable(Int)
    case audioEncoderUnavailable
    case recorderUnavailable(String)
    case missingStreamKey
    case destinationInvalid(String)

    var errorDescription: String? {
        switch self {
        case .encoderUnavailable(let status):
            return "The video encoder could not start (status \(status)). Close other apps that may be using the hardware encoder and try again."
        case .audioEncoderUnavailable:
            return "The audio encoder could not start. Check that no other app has taken exclusive use of the audio hardware."
        case .recorderUnavailable(let reason):
            return "The local recording could not start: \(reason)"
        case .missingStreamKey:
            return "No stream key is stored for this destination. Paste a key in Output settings; it is written to the keychain, never to the session file."
        case .destinationInvalid(let reason):
            return reason
        }
    }
}
