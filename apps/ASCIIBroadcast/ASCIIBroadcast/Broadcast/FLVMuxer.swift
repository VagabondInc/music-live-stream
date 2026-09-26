//
//  FLVMuxer.swift
//  ASCII Broadcast
//
//  FLV tag bodies for RTMP audio (type 8) and video (type 9) messages.
//  Codec configuration is always written before media, and timestamps stay
//  monotonic within a publishing epoch.
//

import Foundation

enum FLV {

    // MARK: - Audio (AAC)

    /// 0xAF = AAC, 44 kHz flag, 16-bit, stereo. RTMP ignores the rate bits for
    /// AAC and reads the real rate from the AudioSpecificConfig.
    private static let aacTagHeader: UInt8 = 0xAF

    static func audioSequenceHeader(audioSpecificConfig: Data) -> Data {
        var data = Data([aacTagHeader, 0x00])
        data.append(audioSpecificConfig)
        return data
    }

    static func audioFrame(_ raw: Data) -> Data {
        var data = Data([aacTagHeader, 0x01])
        data.append(raw)
        return data
    }

    /// Two-byte AudioSpecificConfig for AAC-LC.
    static func audioSpecificConfig(sampleRate: Double, channels: Int) -> Data {
        let rates: [Double] = [96000, 88200, 64000, 48000, 44100, 32000,
                               24000, 22050, 16000, 12000, 11025, 8000, 7350]
        let index = rates.firstIndex(where: { abs($0 - sampleRate) < 1 }) ?? 4
        let objectType: UInt8 = 2                       // AAC-LC
        let channelConfiguration = UInt8(clamp(channels, 1, 7))
        let first = (objectType << 3) | UInt8((index >> 1) & 0x07)
        let second = UInt8((index & 0x01) << 7) | (channelConfiguration << 3)
        return Data([first, second])
    }

    // MARK: - Video (H.264)

    static func videoSequenceHeader(avcC: Data) -> Data {
        var data = Data([0x17, 0x00, 0x00, 0x00, 0x00])  // keyframe, AVC, seq header, cts 0
        data.append(avcC)
        return data
    }

    static func videoFrame(_ avccData: Data, isKeyframe: Bool, compositionTimeMilliseconds: Int32 = 0) -> Data {
        var data = Data([isKeyframe ? 0x17 : 0x27, 0x01])
        let cts = UInt32(bitPattern: compositionTimeMilliseconds) & 0x00FF_FFFF
        data.append(AMF0.bigEndian24(cts))
        data.append(avccData)
        return data
    }

    /// `avcC` decoder configuration record built from the encoder's parameter sets.
    static func avcDecoderConfigurationRecord(sps: [Data], pps: [Data]) -> Data? {
        guard let firstSPS = sps.first, firstSPS.count >= 4 else { return nil }
        var data = Data()
        data.append(0x01)                        // configuration version
        data.append(firstSPS[1])                 // AVCProfileIndication
        data.append(firstSPS[2])                 // profile compatibility
        data.append(firstSPS[3])                 // AVCLevelIndication
        data.append(0xFF)                        // 6 bits reserved + 4-byte NAL length
        data.append(UInt8(0xE0 | (sps.count & 0x1F)))
        for set in sps {
            data.append(AMF0.bigEndian(UInt16(set.count)))
            data.append(set)
        }
        data.append(UInt8(pps.count & 0xFF))
        for set in pps {
            data.append(AMF0.bigEndian(UInt16(set.count)))
            data.append(set)
        }
        return data
    }

    // MARK: - Metadata

    static func onMetaData(width: Int, height: Int, frameRate: Int,
                           videoBitrate: Int, audioBitrate: Int,
                           audioSampleRate: Double, encoder: String) -> Data {
        let properties: [(String, AMF0Value)] = [
            ("duration", .number(0)),
            ("width", .number(Double(width))),
            ("height", .number(Double(height))),
            ("videocodecid", .number(7)),            // AVC
            ("videodatarate", .number(Double(videoBitrate) / 1000.0)),
            ("framerate", .number(Double(frameRate))),
            ("audiocodecid", .number(10)),           // AAC
            ("audiodatarate", .number(Double(audioBitrate) / 1000.0)),
            ("audiosamplerate", .number(audioSampleRate)),
            ("audiosamplesize", .number(16)),
            ("stereo", .boolean(true)),
            ("encoder", .string(encoder))
        ]
        return AMF0.encodeSequence([
            .string("@setDataFrame"),
            .string("onMetaData"),
            .ecmaArray(properties)
        ])
    }
}
