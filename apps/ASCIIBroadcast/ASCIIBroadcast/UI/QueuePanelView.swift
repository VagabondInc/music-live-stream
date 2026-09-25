//
//  QueuePanelView.swift
//  ASCII Broadcast
//
//  QUEUE / LIBRARY / FILTER / IMPORT. The queue is the programme: order,
//  analysis state, rights state, and what plays next, all legible at a glance
//  from across a room.
//

import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

struct QueuePanelView: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var analysis: AnalysisService

    @State private var tabIndex = 0
    @State private var showFilter = false
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 0) {
            TabStrip(items: ["QUEUE", "LIBRARY", "FILTER", "IMPORT"], selection: Binding(
                get: { tabIndex },
                set: { newValue in
                    switch newValue {
                    case 2: showFilter.toggle()
                    case 3: showImporter = true
                    default:
                        tabIndex = newValue
                        model.libraryTab = newValue == 0 ? .queue : .library
                    }
                }))

            if showFilter {
                filterField
            }

            header

            if analysis.isRunning {
                analysisStrip
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.libraryTab == .queue {
                        ForEach(Array(model.filteredInstances.enumerated()), id: \.element.id) { index, instance in
                            QueueRowView(model: model,
                                         instance: instance,
                                         ordinal: (model.playlist.instances.firstIndex(where: { $0.id == instance.id }) ?? index) + 1)
                        }
                    } else {
                        ForEach(model.filteredLibraryAssets, id: \.id) { asset in
                            LibraryRowView(model: model, asset: asset)
                        }
                    }
                }
            }
            .background(Theme.panel)

            nextUp
        }
        .panelChrome()
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: importTypes,
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): model.importFiles(urls: urls)
            case .failure(let error):
                model.show(.warning, "Import cancelled", error.localizedDescription, remedy: nil)
            }
        }
    }

    private var importTypes: [UTType] {
        #if canImport(UniformTypeIdentifiers)
        return [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
        #else
        return []
        #endif
    }

    private var filterField: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 9))
                .foregroundStyle(Theme.textDim)
            TextField("FILTER", text: $model.filterText)
                .textFieldStyle(.plain)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.textPrimary)
            if !model.filterText.isEmpty {
                IconButton(systemImage: "xmark", accessibilityTitle: "Clear filter") {
                    model.filterText = ""
                }
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(Theme.well)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(model.libraryTab == .queue
                 ? "QUEUE // \(String(format: "%02d", model.playlist.instances.count)) TRACKS"
                 : "LIBRARY // \(String(format: "%02d", model.library.assets.count)) ASSETS")
                .font(Theme.mono(10.5, .semibold))
                .tracked(1.1)
                .foregroundStyle(Theme.cyanBright)
            Spacer(minLength: 4)
            IconButton(systemImage: "shuffle", accessibilityTitle: "Shuffle queue") {
                model.playlist.instances.shuffle()
                model.playlist.touch()
                model.loadTransportEntries(startAt: 0)
                model.compileScore()
                model.save()
            }
            IconButton(systemImage: analysis.isRunning ? "stop.circle" : "arrow.triangle.2.circlepath",
                       accessibilityTitle: analysis.isRunning ? "Cancel analysis" : "Analyse queue",
                       tint: analysis.isRunning ? Theme.amber : Theme.textDim) {
                if analysis.isRunning {
                    model.cancelAnalysis()
                } else {
                    model.analyzeAll()
                }
            }
            IconButton(systemImage: "trash", accessibilityTitle: "Remove selected track") {
                if let id = model.selectedInstanceID { model.removeInstance(id) }
            }
            IconButton(systemImage: "ellipsis", accessibilityTitle: "More queue actions") {
                model.installDemoProgram()
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Theme.panelRaised.opacity(0.5))
        .overlay(alignment: .bottom) { HairlineDivider(color: Theme.hairline) }
    }

    private var analysisStrip: some View {
        VStack(spacing: 3) {
            HStack {
                Text(analysis.phase)
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.amber)
                Spacer()
                Text("\(analysis.completed)/\(analysis.total)")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textDim)
            }
            BarMeter(value: analysis.overallProgress, color: Theme.amber, height: 3)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.amberWash.opacity(0.5))
    }

    private var nextUp: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NEXT UP")
                    .font(Theme.mono(9.5, .semibold))
                    .tracked(1.1)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(Theme.panelRaised.opacity(0.5))
            .overlay(alignment: .top) { HairlineDivider(color: Theme.hairline) }

            VStack(spacing: 0) {
                ForEach(upcoming, id: \.0) { pair in
                    HStack(spacing: 8) {
                        StatusDot(color: pair.1.availability.isPlayable ? Theme.green : Theme.red, size: 5)
                        Image(systemName: transitionIcon(for: pair.0))
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.amber.opacity(0.8))
                            .frame(width: 10)
                        Text(pair.1.titleOrFilename.uppercased())
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(Timecode.clock(pair.1.duration))
                            .font(Theme.mono(9.5))
                            .foregroundStyle(Theme.textDim)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, 2)
            .background(Theme.panel)
        }
    }

    private var upcoming: [(Int, SourceAsset)] {
        var out: [(Int, SourceAsset)] = []
        var index = model.currentIndex + 1
        while out.count < 3 && index < model.currentIndex + 1 + model.playlist.instances.count {
            let wrapped = model.playlist.loops ? index % max(1, model.playlist.instances.count) : index
            guard let instance = model.playlist.instances[safe: wrapped],
                  let asset = model.library.asset(instance.assetID) else { break }
            out.append((wrapped, asset))
            index += 1
        }
        return out
    }

    private func transitionIcon(for index: Int) -> String {
        guard let instance = model.playlist.instances[safe: index] else { return "arrow.right" }
        switch instance.transitionPreference {
        case .glitch:        return "bolt.horizontal"
        case .beatMatch:     return "metronome"
        case .negativeSpace: return "circle.dashed"
        case .hold:          return "pause"
        default:             return "arrow.triangle.merge"
        }
    }
}

// MARK: - Rows

struct QueueRowView: View {
    @ObservedObject var model: StudioViewModel
    let instance: TrackInstance
    let ordinal: Int

    private var asset: SourceAsset? { model.asset(for: instance) }
    private var analysis: TrackAnalysis? { model.analysis(for: instance) }
    private var isCurrent: Bool { model.currentInstance?.id == instance.id }

    var body: some View {
        Button {
            model.selectedInstanceID = instance.id
            if let index = model.playlist.instances.firstIndex(where: { $0.id == instance.id }) {
                model.skip(to: index)
            }
        } label: {
            HStack(spacing: 8) {
                Text(String(format: "%02d", ordinal))
                    .font(Theme.mono(10, .medium))
                    .foregroundStyle(isCurrent ? Theme.amber : Theme.textDim)
                    .frame(width: 18, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    Text((asset?.titleOrFilename ?? "MISSING").uppercased())
                        .font(Theme.mono(10.5, .medium))
                        .tracked(0.5)
                        .foregroundStyle(isCurrent ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                    Text((asset?.artist ?? "—").uppercased())
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isCurrent && model.isPlaying {
                    PlayingIndicator()
                        .frame(width: 14, height: 11)
                } else {
                    Image(systemName: rightsIcon)
                        .font(.system(size: 9))
                        .foregroundStyle(rightsColor)
                }

                Text(Timecode.clock(asset?.duration ?? 0))
                    .font(Theme.mono(9.5))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.horizontal, 9)
            .frame(height: Theme.Metric.rowHeight)
            .background(background)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isCurrent ? Theme.amber : Color.clear)
                    .frame(width: 2)
            }
            .overlay(alignment: .bottom) { HairlineDivider() }
            .overlay(alignment: .leading) {
                StatusDot(color: analysisColor, size: 4)
                    .offset(x: 21, y: 9)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Track \(ordinal), \(asset?.titleOrFilename ?? "missing"), \(analysis?.state.display ?? "not analysed")")
        .contextMenu {
            Button("Remove from queue") { model.removeInstance(instance.id) }
            Menu("Transition into this track") {
                Button("Automatic") { model.setTransition(nil, for: instance.id) }
                ForEach(TransitionKind.allCases, id: \.self) { kind in
                    Button(kind.description) { model.setTransition(kind, for: instance.id) }
                }
            }
        }
    }

    private var background: Color {
        if isCurrent { return Theme.amberWash }
        if model.selectedInstanceID == instance.id { return Theme.panelRaised }
        return Theme.panel
    }

    private var analysisColor: Color {
        switch analysis?.state {
        case .complete: return Theme.green
        case .partial:  return Theme.amber
        case .running:  return Theme.cyan
        case .failed:   return Theme.red
        default:        return Theme.textFaint
        }
    }

    private var rightsIcon: String {
        guard let asset else { return "questionmark" }
        return model.library.rightsRecord(for: asset.id).allowsBroadcast ? "checkmark.seal" : "exclamationmark.triangle"
    }

    private var rightsColor: Color {
        guard let asset else { return Theme.textFaint }
        return model.library.rightsRecord(for: asset.id).allowsBroadcast ? Theme.textFaint : Theme.amberDim
    }
}

struct LibraryRowView: View {
    @ObservedObject var model: StudioViewModel
    let asset: SourceAsset

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(color: asset.availability.isPlayable ? Theme.green : Theme.red, size: 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(asset.titleOrFilename.uppercased())
                    .font(Theme.mono(10.5, .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Text("\(asset.artist.uppercased())  ·  \(asset.codecDescription)")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            IconButton(systemImage: "plus", accessibilityTitle: "Add to queue") {
                model.addToQueue(assetID: asset.id)
            }
            Text(Timecode.clock(asset.duration))
                .font(Theme.mono(9.5))
                .foregroundStyle(Theme.textDim)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 9)
        .frame(height: Theme.Metric.rowHeight)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }
}

/// The four-bar level glyph on the playing row.
struct PlayingIndicator: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
            Canvas { context, size in
                let bars = 4
                let barWidth = size.width / Double(bars * 2 - 1)
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<bars {
                    let wave = (sin(time * 6 + Double(index) * 1.7) + 1) / 2
                    let height = size.height * (0.25 + wave * 0.75)
                    let rect = CGRect(x: Double(index) * barWidth * 2,
                                      y: size.height - height,
                                      width: barWidth,
                                      height: height)
                    context.fill(Path(rect), with: .color(Theme.cyanBright))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
