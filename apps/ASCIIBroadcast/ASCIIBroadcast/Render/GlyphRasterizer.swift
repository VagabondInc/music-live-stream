//
//  GlyphRasterizer.swift
//  ASCII Broadcast
//
//  Turns a character field into pixels. Cells are batched by colour so a
//  240x68 grid costs a few dozen CoreText draw calls instead of sixteen
//  thousand.
//
//  MVP note: this is a CoreGraphics/CoreText path. The Phase 1 pipeline calls
//  for a Metal glyph-atlas renderer; `FrameRenderer` is the boundary where that
//  implementation drops in without changing the engine or the encoder.
//

import Foundation
import CoreGraphics
import CoreText

protocol FrameRenderer: AnyObject {
    func draw(frame: GlyphFrame, in context: CGContext, size: CGSize)
}

final class GlyphRasterizer: FrameRenderer {

    /// Quantising intensity keeps the batch count bounded and stops tiny
    /// numeric drift from producing a new colour every frame.
    private static let intensitySteps = 6

    private var fontSize: CGFloat = 0
    private var font: CTFont
    private var ascent: CGFloat = 0
    private var advanceRatio: CGFloat = 0.6
    private var glyphCache: [UInt16: CGGlyph] = [:]

    /// Broadcast finish: a faint scanline grid. Off under Reduce Motion or
    /// when the safety profile asks for a flatter field.
    var drawsScanlines = true

    init() {
        font = GlyphRasterizer.makeFont(size: 12)
        measure()
    }

    private static func makeFont(size: CGFloat) -> CTFont {
        // Menlo ships on macOS, iOS and iPadOS, and its metrics are stable,
        // which matters because the atlas profile is part of replay fidelity.
        let candidates = ["Menlo-Regular", "Menlo", "SFMono-Regular", "Courier"]
        for name in candidates {
            let font = CTFontCreateWithName(name as CFString, size, nil)
            let resolved = CTFontCopyPostScriptName(font) as String
            if resolved.lowercased().contains("menlo")
                || resolved.lowercased().contains("mono")
                || resolved.lowercased().contains("courier") {
                return font
            }
        }
        return CTFontCreateUIFontForLanguage(.userFixedPitch, size, nil)
            ?? CTFontCreateWithName("Courier" as CFString, size, nil)
    }

    private func measure() {
        ascent = CTFontGetAscent(font)
        var glyph = CGGlyph(0)
        var character: UniChar = 77           // "M"
        if CTFontGetGlyphsForCharacters(font, &character, &glyph, 1) {
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
            if advance.width > 0 {
                advanceRatio = advance.width / CTFontGetSize(font)
            }
        }
    }

    private func ensureFont(cellWidth: CGFloat, cellHeight: CGFloat) {
        // Fit the advance to the cell width, then cap by cell height so
        // descenders do not collide between rows.
        let byWidth = cellWidth / max(0.1, advanceRatio)
        let target = min(byWidth, cellHeight * 1.06)
        guard abs(target - fontSize) > 0.25 else { return }
        fontSize = max(1, target)
        font = GlyphRasterizer.makeFont(size: fontSize)
        ascent = CTFontGetAscent(font)
        glyphCache.removeAll(keepingCapacity: true)
    }

    private func glyph(for scalar: UInt16) -> CGGlyph {
        if let cached = glyphCache[scalar] { return cached }
        var character = UniChar(scalar)
        var result = CGGlyph(0)
        if !CTFontGetGlyphsForCharacters(font, &character, &result, 1) {
            // Missing art glyph: fall back to a full stop rather than a box.
            var fallback: UniChar = 46
            CTFontGetGlyphsForCharacters(font, &fallback, &result, 1)
        }
        glyphCache[scalar] = result
        return result
    }

    // MARK: - Drawing

    func draw(frame: GlyphFrame, in context: CGContext, size: CGSize) {
        guard size.width > 1, size.height > 1, frame.columns > 0, frame.rows > 0 else { return }

        let cellWidth = size.width / CGFloat(frame.columns)
        let cellHeight = size.height / CGFloat(frame.rows)
        ensureFont(cellWidth: cellWidth, cellHeight: cellHeight)

        context.saveGState()
        // Normalise to a y-down user space so one drawing path serves the
        // SwiftUI canvas and the encoder's bitmap context.
        if context.ctm.d > 0 {
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
        }
        context.interpolationQuality = .none
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        // Ground.
        context.setFillColor(frame.palette.background.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Cell backgrounds (inverted cells, solid plates).
        var backgroundRects: [PaletteRole: [CGRect]] = [:]
        for row in 0..<frame.rows {
            for column in 0..<frame.columns {
                let cell = frame.cells[row * frame.columns + column]
                guard cell.background != 255,
                      let role = PaletteRole(rawValue: cell.background) else { continue }
                let rect = CGRect(x: CGFloat(column) * cellWidth,
                                  y: CGFloat(row) * cellHeight,
                                  width: cellWidth + 0.5,
                                  height: cellHeight + 0.5)
                backgroundRects[role, default: []].append(rect)
            }
        }
        for (role, rects) in backgroundRects {
            context.setFillColor(frame.palette.color(role).cgColor)
            context.fill(rects)
        }

        // Glyph batches: one CoreText call per colour bucket.
        context.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        var batches: [Int: (glyphs: [CGGlyph], positions: [CGPoint])] = [:]
        let baselineOffset = ascent * 0.92

        for row in 0..<frame.rows {
            let y = CGFloat(row) * cellHeight + baselineOffset
            for column in 0..<frame.columns {
                let cell = frame.cells[row * frame.columns + column]
                if cell.scalar == 32 { continue }
                let bucket = GlyphRasterizer.bucket(role: cell.role, intensity: cell.intensity)
                let point = CGPoint(x: CGFloat(column) * cellWidth, y: y)
                let glyphValue = glyph(for: cell.scalar)
                if batches[bucket] == nil {
                    batches[bucket] = (glyphs: [glyphValue], positions: [point])
                } else {
                    batches[bucket]?.glyphs.append(glyphValue)
                    batches[bucket]?.positions.append(point)
                }
            }
        }

        for (bucket, batch) in batches {
            let role = PaletteRole(rawValue: UInt8(bucket / GlyphRasterizer.intensitySteps)) ?? .ground
            let step = bucket % GlyphRasterizer.intensitySteps
            let intensity = Double(step + 1) / Double(GlyphRasterizer.intensitySteps)
            let colour = frame.palette.color(role).scaled(intensity)
            context.setFillColor(colour.cgColor)
            batch.glyphs.withUnsafeBufferPointer { glyphPointer in
                batch.positions.withUnsafeBufferPointer { positionPointer in
                    guard let glyphBase = glyphPointer.baseAddress,
                          let positionBase = positionPointer.baseAddress else { return }
                    CTFontDrawGlyphs(font, glyphBase, positionBase, batch.glyphs.count, context)
                }
            }
        }

        if drawsScanlines && cellHeight > 3 {
            context.setFillColor(CGColor(gray: 0, alpha: 0.10))
            var y = cellHeight * 0.5
            while y < size.height {
                context.fill(CGRect(x: 0, y: y, width: size.width, height: 0.7))
                y += cellHeight
            }
        }

        context.restoreGState()
    }

    private static func bucket(role: PaletteRole, intensity: Float) -> Int {
        let clamped = clamp(Double(intensity), 0, 1)
        let step = min(intensitySteps - 1, max(0, Int(clamped * Double(intensitySteps) - 0.0001)))
        return Int(role.rawValue) * intensitySteps + step
    }
}
