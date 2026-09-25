//
//  ProgramCanvasView.swift
//  ASCII Broadcast
//
//  The preview subscribes to the authoritative program frame; it never drives
//  it. `TimelineView(.animation)` asks for a redraw at the display's rate and
//  the renderer decides whether that means a new frame or the cached one.
//

import SwiftUI

struct ProgramCanvasView: View {
    let renderer: ProgramRenderer
    var isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { _ in
            Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                let frame = renderer.frame()
                context.withCGContext { cgContext in
                    renderer.draw(into: cgContext, size: size, frame: frame)
                }
            }
        }
        .drawingGroup(opaque: true)
        .background(Theme.canvas)
        .accessibilityElement()
        .accessibilityLabel("Program output")
        .accessibilityValue(isPlaying ? "Rendering live" : "Paused")
    }
}

/// The 16:9 letterbox with corner marks, exactly as the mockup frames it.
struct ProgramFrameView: View {
    let renderer: ProgramRenderer
    var isPlaying: Bool
    var isSending: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = fit(into: proxy.size)
            ZStack {
                Theme.well
                ProgramCanvasView(renderer: renderer, isPlaying: isPlaying)
                    .frame(width: side.width, height: side.height)
                    .overlay(alignment: .topLeading) { corner(.topLeading) }
                    .overlay(alignment: .topTrailing) { corner(.topTrailing) }
                    .overlay(alignment: .bottomLeading) { corner(.bottomLeading) }
                    .overlay(alignment: .bottomTrailing) { corner(.bottomTrailing) }
                    .overlay(
                        Rectangle()
                            .strokeBorder(isSending ? Theme.cyanDim : Theme.hairline, lineWidth: 1)
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func fit(into size: CGSize) -> CGSize {
        let target: CGFloat = 16.0 / 9.0
        let available = max(0.0001, size.width / max(0.0001, size.height))
        if available > target {
            return CGSize(width: size.height * target, height: size.height)
        }
        return CGSize(width: size.width, height: size.width / target)
    }

    @ViewBuilder
    private func corner(_ alignment: Alignment) -> some View {
        CornerMark(alignment: alignment)
            .stroke(Theme.cyan.opacity(0.75), lineWidth: 1)
            .frame(width: 14, height: 14)
            .padding(4)
    }
}

private struct CornerMark: Shape {
    var alignment: Alignment

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch alignment {
        case .topLeading:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .topTrailing:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottomLeading:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        default:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        return path
    }
}
