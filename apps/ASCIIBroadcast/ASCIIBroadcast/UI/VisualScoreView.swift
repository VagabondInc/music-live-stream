//
//  VisualScoreView.swift
//  ASCII Broadcast
//
//  The programme seen as structure: chapters, scenes, transitions, titles,
//  signal FX and memory marks against one timeline. This is the artefact the
//  creator edits and accepts — the engine plays what is written here.
//

import SwiftUI

struct VisualScoreView: View {
    @ObservedObject var model: StudioViewModel
    @State private var zoom: Double = 1.0

    private let laneHeight: CGFloat = 21
    private let labelWidth: CGFloat = 76

    var body: some View {
        StudioPanel(title: "VISUAL_SCORE // STRUCTURE") {
            HStack(spacing: 8) {
                Text("SCORE: \(model.score.name.isEmpty ? "—" : model.score.name.uppercased())")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textDim)
                IconButton(systemImage: "minus", accessibilityTitle: "Zoom out") {
                    zoom = max(0.5, zoom - 0.25)
                }
                IconButton(systemImage: "plus", accessibilityTitle: "Zoom in") {
                    zoom = min(4, zoom + 0.25)
                }
                IconButton(systemImage: "line.3.horizontal", accessibilityTitle: "Recompile score") {
                    model.compileScore()
                }
            }
        } content: {
            GeometryReader { proxy in
                let trackWidth = max(120, (proxy.size.width - labelWidth - 14) * zoom)
                let duration = max(1, model.score.duration > 0 ? model.score.duration : model.programDuration)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        laneLabels
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                chaptersLane(width: trackWidth, duration: duration)
                                scenesLane(width: trackWidth, duration: duration)
                                transitionsLane(width: trackWidth, duration: duration)
                                titlesLane(width: trackWidth, duration: duration)
                                fxLane(width: trackWidth, duration: duration)
                                memoryLane(width: trackWidth, duration: duration)
                                timeAxis(width: trackWidth, duration: duration)
                            }
                            playhead(width: trackWidth, duration: duration)
                        }
                        .frame(width: trackWidth)
                    }
                    .padding(.trailing, 10)
                }
                .padding(.vertical, 5)
            }
        }
    }

    // MARK: - Lane labels

    private var laneLabels: some View {
        VStack(spacing: 0) {
            ForEach(["CHAPTERS", "SCENES", "TRANSITIONS", "TITLES", "SIGNAL FX", "MEMORY"], id: \.self) { name in
                HStack {
                    Text(name)
                        .font(Theme.mono(8.5, .medium))
                        .tracked(0.8)
                        .foregroundStyle(Theme.textDim)
                    Spacer()
                }
                .frame(width: labelWidth, height: laneHeight)
            }
            Spacer(minLength: 0).frame(height: 16)
        }
        .padding(.leading, 9)
    }

    // MARK: - Lanes

    private func x(_ time: Double, width: CGFloat, duration: Double) -> CGFloat {
        CGFloat(clamp(time / duration, 0, 1)) * width
    }

    private func chaptersLane(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .leading) {
            laneBackground
            ForEach(model.score.chapters) { chapter in
                let start = x(chapter.start, width: width, duration: duration)
                let end = x(chapter.end, width: width, duration: duration)
                HStack(spacing: 5) {
                    Text(chapter.letter)
                        .font(Theme.mono(9, .bold))
                        .foregroundStyle(Theme.void)
                        .frame(width: 15, height: laneHeight - 5)
                        .background(chapterColor(chapter))
                    Text(chapter.title.uppercased())
                        .font(Theme.mono(9, .medium))
                        .tracked(0.8)
                        .foregroundStyle(chapterColor(chapter))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(width: max(18, end - start - 2), height: laneHeight - 5, alignment: .leading)
                .background(chapterColor(chapter).opacity(0.12))
                .overlay(Rectangle().strokeBorder(chapterColor(chapter).opacity(0.5), lineWidth: 1))
                .offset(x: start + 1)
            }
        }
        .frame(height: laneHeight)
    }

    private func chapterColor(_ chapter: ScoreChapterCue) -> Color {
        if chapter.isReprise { return Theme.red }
        switch chapter.letter {
        case "A": return Theme.amber
        case "B": return Theme.cyan
        case "C": return Theme.green
        default:  return Theme.magenta
        }
    }

    private func scenesLane(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .leading) {
            laneBackground
            ForEach(model.score.scenes) { scene in
                let start = x(scene.start, width: width, duration: duration)
                let end = x(scene.end, width: width, duration: duration)
                let isCurrent = model.currentScene?.id == scene.id
                Text(scene.slug)
                    .font(Theme.mono(8.5, .medium))
                    .tracked(0.5)
                    .foregroundStyle(isCurrent ? Theme.amber : Theme.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(width: max(20, end - start - 3), height: laneHeight - 6, alignment: .leading)
                    .background(isCurrent ? Theme.amberWash : Theme.panelRaised)
                    .overlay(Rectangle().strokeBorder(isCurrent ? Theme.amber : Theme.hairline, lineWidth: isCurrent ? 1.5 : 1))
                    .offset(x: start + 1.5)
            }
        }
        .frame(height: laneHeight)
    }

    private func transitionsLane(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .leading) {
            laneBackground
            ForEach(model.score.transitions) { transition in
                let start = x(transition.start, width: width, duration: duration)
                let end = x(transition.end, width: width, duration: duration)
                Text(transition.kind.description)
                    .font(Theme.mono(8, .medium))
                    .tracked(0.6)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .frame(width: max(16, end - start), height: laneHeight - 8, alignment: .center)
                    .background(Theme.panelRaised)
                    .overlay(Rectangle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                    .offset(x: start)
            }
        }
        .frame(height: laneHeight)
    }

    private func titlesLane(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .leading) {
            laneBackground
            ForEach(model.score.titles) { title in
                let start = x(title.start, width: width, duration: duration)
                let end = x(title.end, width: width, duration: duration)
                Text(title.primary.uppercased())
                    .font(Theme.mono(8.5, .medium))
                    .tracked(0.8)
                    .foregroundStyle(title.isOutgoing ? Theme.textDim : Theme.void)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(width: max(14, end - start), height: laneHeight - 8, alignment: .center)
                    .background(title.isOutgoing ? Theme.textFaint.opacity(0.35) : Theme.cyan.opacity(0.85))
                    .offset(x: start)
            }
        }
        .frame(height: laneHeight)
    }

    private func fxLane(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .leading) {
            laneBackground
            Canvas { context, size in
                guard duration > 0 else { return }
                // Energy curve behind the FX marks: the shape the score follows.
                var path = Path()
                let curve = energyCurve()
                if curve.count > 1 {
                    for (index, value) in curve.enumerated() {
                        let px = CGFloat(Double(index) / Double(curve.count - 1)) * size.width
                        let py = size.height - CGFloat(value) * (size.height - 4) - 2
                        if index == 0 { path.move(to: CGPoint(x: px, y: py)) }
                        else { path.addLine(to: CGPoint(x: px, y: py)) }
                    }
                    context.stroke(path, with: .color(Theme.amber.opacity(0.85)), lineWidth: 1)
                }
            }
            ForEach(model.score.fx) { cue in
                let start = x(cue.start, width: width, duration: duration)
                Circle()
                    .fill(fxColor(cue.kind))
                    .frame(width: 4.5, height: 4.5)
                    .offset(x: start - 2, y: laneHeight * 0.5 - 2 - CGFloat(cue.intensity) * 4)
            }
        }
        .frame(height: laneHeight)
    }

    private func fxColor(_ kind: SignalFXKind) -> Color {
        kind.isSafeUnderPhotosensitivity ? Theme.cyanBright : Theme.red
    }

    private func energyCurve() -> [Double] {
        let instances = model.playlist.instances
        guard !instances.isEmpty else { return [] }
        var out: [Double] = []
        for instance in instances {
            guard let analysis = model.analysis(for: instance), !analysis.energyCurve.isEmpty else {
                out.append(contentsOf: [0.35, 0.4, 0.38])
                continue
            }
            let stride = max(1, analysis.energyCurve.count / 24)
            for index in Swift.stride(from: 0, to: analysis.energyCurve.count, by: stride) {
                out.append(Double(analysis.energyCurve[index]))
            }
        }
        return out
    }

    private func memoryLane(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .leading) {
            laneBackground
            ForEach(model.score.memory) { mark in
                let start = x(mark.time, width: width, duration: duration)
                HStack(spacing: 3) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(Theme.textPrimary)
                    Text(mark.label)
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.textDim)
                }
                .offset(x: start - 4)
                .help(mark.motifName)
            }
        }
        .frame(height: laneHeight)
    }

    private func timeAxis(width: CGFloat, duration: Double) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 0.0, through: duration, by: axisStep(duration))), id: \.self) { time in
                VStack(spacing: 1) {
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 3)
                    Text(Timecode.clock(time))
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.textFaint)
                }
                .offset(x: x(time, width: width, duration: duration) - 14)
            }
        }
        .frame(height: 16, alignment: .topLeading)
    }

    private func axisStep(_ duration: Double) -> Double {
        switch duration {
        case ..<300:   return 30
        case ..<1200:  return 60
        case ..<3600:  return 300
        default:       return 600
        }
    }

    private func playhead(width: CGFloat, duration: Double) -> some View {
        let position = x(model.programTime, width: width, duration: duration)
        return VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.textPrimary.opacity(0.9))
                .frame(width: 1, height: laneHeight * 6)
            Triangle()
                .fill(Theme.amber)
                .frame(width: 9, height: 6)
                .offset(x: 0, y: -1)
        }
        .offset(x: position - 0.5)
        .allowsHitTesting(false)
    }

    private var laneBackground: some View {
        Rectangle()
            .fill(Theme.well.opacity(0.55))
            .overlay(alignment: .bottom) { HairlineDivider(color: Theme.hairlineFaint) }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
