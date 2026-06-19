import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = RoutineStore()
    @AppStorage("RoutineApp.themeMode") private var themeMode = AppThemeMode.system
    @State private var liveActivityEnabled = RoutineSharedStorage.loadLiveActivityEnabled()
    @State private var liveActivitySyncTask: Task<Void, Never>?
    @State private var lastImmediateLiveActivitySyncDate: Date?

    var body: some View {
        TabView {
            ScheduleView(routines: store.routines)
                .tabItem {
                    Label("日程", systemImage: "clock")
                }

            SettingsView(store: store, themeMode: $themeMode, liveActivityEnabled: $liveActivityEnabled)
                .tabItem {
                    Label("配置", systemImage: "slider.horizontal.3")
                }
        }
        .tint(.primary)
        .preferredColorScheme(themeMode.colorScheme)
        .task {
            guard liveActivityEnabled else { return }
            syncLiveActivity(immediately: true)
        }
        .onChange(of: store.routines) { _, _ in
            guard liveActivityEnabled else { return }
            syncLiveActivity()
        }
        .onChange(of: liveActivityEnabled) { _, _ in
            RoutineSharedStorage.saveLiveActivityEnabled(liveActivityEnabled)
            syncLiveActivity(immediately: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            syncLiveActivityAfterSceneActivation()
        }
    }

    private func syncLiveActivityAfterSceneActivation() {
        guard liveActivityEnabled else { return }

        let now = Date()
        if let lastImmediateLiveActivitySyncDate,
           now.timeIntervalSince(lastImmediateLiveActivitySyncDate) < 1.5 {
            return
        }

        syncLiveActivity(immediately: true)
    }

    private func syncLiveActivity(immediately: Bool = false) {
        liveActivitySyncTask?.cancel()

        let routines = store.routines
        let enabled = liveActivityEnabled

        if immediately {
            lastImmediateLiveActivitySyncDate = Date()
        }

        liveActivitySyncTask = Task {
            if !immediately {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled else { return }
            }

            await RoutineLiveActivityController.sync(routines: routines, enabled: enabled)
        }
    }
}

struct ScheduleView: View {
    let routines: [Routine]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width - 16, proxy.size.height - 20)

            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        CurrentRoutineStatusView(snapshot: routineStatusSnapshot(at: timeline.date, routines: routines))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 14)

                    Spacer()
                }

                RoutineRingView(routines: routines)
                    .frame(width: max(260, side), height: max(260, side))
                    .padding(.horizontal, 8)
            }
        }
    }
}

private struct CurrentRoutineStatusView: View {
    let snapshot: RoutineStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.caption)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(snapshot.title)
                        .font(.system(size: 24, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    CurrentRoutineCountdownText(snapshot: snapshot)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("下一日程")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(snapshot.nextTitle)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
            }

            CurrentRoutineProgressView(snapshot: snapshot)
                .tint(snapshot.tintColor)
                .scaleEffect(x: 1, y: 1.3, anchor: .center)

            HStack {
                Text(snapshot.startTimeText)

                Spacer()

                Text(snapshot.endTimeText)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.caption)，\(snapshot.title)，剩余 \(snapshot.remainingText)")
    }
}

private struct CurrentRoutineCountdownText: View {
    let snapshot: RoutineStatusSnapshot

    var body: some View {
        if let endDate = snapshot.endDate,
           let interval = routineCountdownInterval(startDate: snapshot.startDate, endDate: endDate) {
            Text(timerInterval: interval, countsDown: true, showsHours: true)
        } else {
            Text(snapshot.remainingText)
        }
    }
}

private struct CurrentRoutineProgressView: View {
    let snapshot: RoutineStatusSnapshot

    var body: some View {
        if let startDate = snapshot.startDate,
           let endDate = snapshot.endDate,
           startDate < endDate {
            ProgressView(timerInterval: startDate...endDate, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        } else {
            ProgressView(value: snapshot.progress)
        }
    }
}

#Preview {
    ContentView()
}
