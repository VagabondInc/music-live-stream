//
//  OffscreenFrameRenderer.swift
//  ASCII Broadcast
//
//  Renders the authoritative program frame into a CVPixelBuffer for the video
//  encoder and the local recorder. Buffers come from a bounded pool so a slow
//  consumer cannot accumulate frames.
//

import Foundation
import CoreGraphics
import CoreVideo

final class OffscreenFrameRenderer {

    private(set) var width: Int
    private(set) var height: Int
    private var pool: CVPixelBufferPool?
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        makePool()
    }

    func resize(width newWidth: Int, height newHeight: Int) {
        guard newWidth != width || newHeight != height else { return }
        width = newWidth
        height = newHeight
        makePool()
    }

    private func makePool() {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        // Bounded pool: at most four in flight.
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        var created: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                poolAttributes as CFDictionary,
                                attributes as CFDictionary,
                                &created)
        pool = created
    }

    /// Draw one frame. Returns nil when the pool is exhausted, which the caller
    /// must treat as a dropped frame rather than a reason to stall audio.
    func render(frame: GlyphFrame, using renderer: ProgramRenderer) -> CVPixelBuffer? {
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(data: base,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else { return nil }

        renderer.draw(into: context, size: CGSize(width: width, height: height), frame: frame)
        return pixelBuffer
    }
}
