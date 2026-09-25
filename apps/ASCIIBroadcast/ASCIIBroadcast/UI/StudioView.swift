//
//  StudioView.swift
//  ASCII Broadcast
//
//  The whole control surface in one screen: session bar, queue, program,
//  score, inspector, deck, status bar. On iPhone the same panels stack into
//  tabs rather than being cut down.
//

import SwiftUI

struct StudioView: View {
    @StateObject private var model = StudioViewModel()
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .compact {
                CompactStudioView(model: model)
            } else {
                DeskStudioView(model: model)
            }
            #else
            DeskStudioView(model: model)
            #endif
        }
        .background(Theme.void)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.showPreflight) {
            PreflightSheet(model: model, coordinator: model.coordinator)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $model.showOnboarding) {
            OnboardingSheet(model: model)
                .preferredColorScheme(.dark)
        }
        .onDisappear { model.save() }
    }
}

// MARK: - Desk layout

struct DeskStudioView: View {
    @ObservedObject var model: StudioViewModel

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(model: model, coordinator: model.coordinator)

            HStack(spacing: Theme.Metric.gutter) {
                QueuePanelView(model: model, analysis: model.analysisService)
                    .frame(width: Theme.Metric.sideColumnWidth)

                VStack(spacing: Theme.Metric.gutter) {
                    ProgramPanelView(model: model, coordinator: model.coordinator)
                        .layoutPriority(1)
                    VisualScoreView(model: model)
                        .frame(height: 196)
                }

                InspectorView(model: model)
                    .frame(width: Theme.Metric.sideColumnWidth)
            }
            .padding(.horizontal, Theme.Metric.gutter)
            .padding(.top, Theme.Metric.gutter)

            BottomDeckView(model: model, coordinator: model.coordinator)
                .padding(Theme.Metric.gutter)

            StatusBarView(model: model, coordinator: model.coordinator)
        }
        .background(Theme.void)
        .overlay(alignment: .top) {
            if let banner = model.banner {
                BannerView(banner: banner) { model.dismissBanner() }
                    .padding(.top, Theme.Metric.topBarHeight + 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: model.banner)
    }
}

// MARK: - Compact layout (iPhone)

#if os(iOS)
struct CompactStudioView: View {
    @ObservedObject var model: StudioViewModel
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(model: model, coordinator: model.coordinator)

            TabView(selection: $tab) {
                VStack(spacing: Theme.Metric.gutter) {
                    ProgramPanelView(model: model, coordinator: model.coordinator)
                    NowPlayingPanel(model: model).frame(height: 120)
                    TransportPanel(model: model).frame(height: 132)
                }
                .padding(Theme.Metric.gutter)
                .tabItem { Label("PROGRAM", systemImage: "tv") }
                .tag(0)

                QueuePanelView(model: model, analysis: model.analysisService)
                    .padding(Theme.Metric.gutter)
                    .tabItem { Label("QUEUE", systemImage: "list.number") }
                    .tag(1)

                VisualScoreView(model: model)
                    .padding(Theme.Metric.gutter)
                    .tabItem { Label("SCORE", systemImage: "chart.bar.doc.horizontal") }
                    .tag(2)

                InspectorView(model: model)
                    .padding(Theme.Metric.gutter)
                    .tabItem { Label("DNA", systemImage: "slider.horizontal.3") }
                    .tag(3)

                VStack(spacing: Theme.Metric.gutter) {
                    OutboundPanel(model: model, coordinator: model.coordinator).frame(height: 168)
                    StreamHealthPanel(model: model, coordinator: model.coordinator).frame(height: 190)
                    OutputControlPanel(model: model, coordinator: model.coordinator)
                    Spacer(minLength: 0)
                }
                .padding(Theme.Metric.gutter)
                .tabItem { Label("OUTPUT", systemImage: "dot.radiowaves.left.and.right") }
                .tag(4)
            }
        }
        .background(Theme.void)
        .overlay(alignment: .top) {
            if let banner = model.banner {
                BannerView(banner: banner) { model.dismissBanner() }
                    .padding(.horizontal, 8)
                    .padding(.top, Theme.Metric.topBarHeight + 6)
            }
        }
    }
}
#endif
