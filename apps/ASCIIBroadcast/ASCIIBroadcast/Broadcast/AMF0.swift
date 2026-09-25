//
//  AMF0.swift
//  ASCII Broadcast
//
//  The subset of AMF0 an RTMP publisher actually needs. Values that arrive
//  from the server are decoded defensively: a malformed payload must fail the
//  connection cleanly, never read out of bounds.
//

import Foundation

enum AMF0Value {
    case number(Double)
    case boolean(Bool)
    case string(String)
    case object([(String, AMF0Value)])
    case null
    case undefined
    case ecmaArray([(String, AMF0Value)])
    case strictArray([AMF0Value])
    case unsupported

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var objectEntries: [(String, AMF0Value)]? {
        switch self {
        case .object(let entries), .ecmaArray(let entries): return entries
        default: return nil
        }
    }

    func property(_ key: String) -> AMF0Value? {
        objectEntries?.first(where: { $0.0 == key })?.1
    }
}

enum AMF0 {

    // MARK: - Encoding

    static func encode(_ value: AMF0Value, into data: inout Data) {
        switch value {
        case .number(let number):
            data.append(0x00)
            data.append(bigEndian(number.bitPattern))
        case .boolean(let flag):
            data.append(0x01)
            data.append(flag ? 0x01 : 0x00)
        case .string(let string):
            let bytes = Array(string.utf8)
            if bytes.count > 0xFFFF {
                data.append(0x0C)                       // long string
                data.append(bigEndian(UInt32(bytes.count)))
            } else {
                data.append(0x02)
                data.append(bigEndian(UInt16(bytes.count)))
            }
            data.append(contentsOf: bytes)
        case .object(let entries):
            data.append(0x03)
            appendProperties(entries, into: &data)
        case .ecmaArray(let entries):
            data.append(0x08)
            data.append(bigEndian(UInt32(entries.count)))
            appendProperties(entries, into: &data)
        case .strictArray(let values):
            data.append(0x0A)
            data.append(bigEndian(UInt32(values.count)))
            for item in values { encode(item, into: &data) }
        case .null, .unsupported:
            data.append(0x05)
        case .undefined:
            data.append(0x06)
        }
    }

    private static func appendProperties(_ entries: [(String, AMF0Value)], into data: inout Data) {
        for (key, value) in entries {
            let keyBytes = Array(key.utf8)
            data.append(bigEndian(UInt16(keyBytes.count)))
            data.append(contentsOf: keyBytes)
            encode(value, into: &data)
        }
        data.append(contentsOf: [0x00, 0x00, 0x09])     // object end marker
    }

    static func encodeSequence(_ values: [AMF0Value]) -> Data {
        var data = Data()
        for value in values { encode(value, into: &data) }
        return data
    }

    // MARK: - Decoding

    struct Reader {
        let bytes: [UInt8]
        var cursor: Int = 0

        init(_ data: Data) { bytes = Array(data) }

        var remaining: Int { bytes.count - cursor }

        mutating func readByte() -> UInt8? {
            guard cursor < bytes.count else { return nil }
            defer { cursor += 1 }
            return bytes[cursor]
        }

        mutating func read(_ count: Int) -> [UInt8]? {
            guard count >= 0, cursor + count <= bytes.count else { return nil }
            defer { cursor += count }
            return Array(bytes[cursor..<(cursor + count)])
        }

        mutating func readUInt16() -> UInt16? {
            guard let chunk = read(2) else { return nil }
            return (UInt16(chunk[0]) << 8) | UInt16(chunk[1])
        }

        mutating func readUInt32() -> UInt32? {
            guard let chunk = read(4) else { return nil }
            return (UInt32(chunk[0]) << 24) | (UInt32(chunk[1]) << 16)
                | (UInt32(chunk[2]) << 8) | UInt32(chunk[3])
        }

        mutating func readDouble() -> Double? {
            guard let chunk = read(8) else { return nil }
            var pattern: UInt64 = 0
            for byte in chunk { pattern = (pattern << 8) | UInt64(byte) }
            return Double(bitPattern: pattern)
        }

        mutating func readString(length: Int) -> String? {
            guard let chunk = read(length) else { return nil }
            return String(bytes: chunk, encoding: .utf8) ?? ""
        }

        mutating func readValue(depth: Int = 0) -> AMF0Value? {
            guard depth < 16, let marker = readByte() else { return nil }
            switch marker {
            case 0x00:
                return readDouble().map { AMF0Value.number($0) }
            case 0x01:
                return readByte().map { AMF0Value.boolean($0 != 0) }
            case 0x02:
                guard let length = readUInt16(), let string = readString(length: Int(length)) else { return nil }
                return .string(string)
            case 0x03:
                guard let entries = readProperties(depth: depth) else { return nil }
                return .object(entries)
            case 0x05:
                return .null
            case 0x06:
                return .undefined
            case 0x08:
                guard readUInt32() != nil, let entries = readProperties(depth: depth) else { return nil }
                return .ecmaArray(entries)
            case 0x0A:
                guard let count = readUInt32() else { return nil }
                var values: [AMF0Value] = []
                for _ in 0..<min(count, 4096) {
                    guard let value = readValue(depth: depth + 1) else { return nil }
                    values.append(value)
                }
                return .strictArray(values)
            case 0x0C:
                guard let length = readUInt32(), let string = readString(length: Int(length)) else { return nil }
                return .string(string)
            default:
                return .unsupported
            }
        }

        private mutating func readProperties(depth: Int) -> [(String, AMF0Value)]? {
            var entries: [(String, AMF0Value)] = []
            var iterations = 0
            while iterations < 512 {
                iterations += 1
                guard let length = readUInt16() else { return nil }
                if length == 0 {
                    // Object end: expect the 0x09 marker.
                    guard let marker = readByte(), marker == 0x09 else { return entries }
                    return entries
                }
                guard let key = readString(length: Int(length)),
                      let value = readValue(depth: depth + 1) else { return nil }
                entries.append((key, value))
            }
            return entries
        }
    }

    static func decodeSequence(_ data: Data, limit: Int = 8) -> [AMF0Value] {
        var reader = Reader(data)
        var values: [AMF0Value] = []
        while values.count < limit, reader.remaining > 0 {
            guard let value = reader.readValue() else { break }
            values.append(value)
        }
        return values
    }

    // MARK: - Byte helpers

    static func bigEndian(_ value: UInt16) -> Data {
        Data([UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)])
    }

    static func bigEndian(_ value: UInt32) -> Data {
        Data([UInt8(truncatingIfNeeded: value >> 24),
              UInt8(truncatingIfNeeded: value >> 16),
              UInt8(truncatingIfNeeded: value >> 8),
              UInt8(truncatingIfNeeded: value)])
    }

    static func bigEndian(_ value: UInt64) -> Data {
        var data = Data()
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
        return data
    }

    static func bigEndian24(_ value: UInt32) -> Data {
        Data([UInt8(truncatingIfNeeded: value >> 16),
              UInt8(truncatingIfNeeded: value >> 8),
              UInt8(truncatingIfNeeded: value)])
    }
}
