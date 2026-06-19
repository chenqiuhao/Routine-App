import SwiftUI

struct ContentView: View {
    @State private var store = RoutineStore()
    @AppStorage("RoutineApp.themeMode") private var themeMode = AppThemeMode.system

    var body: some View {
        TabView {
            ScheduleView(routines: store.routines)
                .tabItem {
                    Label("日程", systemImage: "clock")
                }

            SettingsView(store: store, themeMode: $themeMode)
                .tabItem {
                    Label("配置", systemImage: "slider.horizontal.3")
                }
        }
        .tint(.primary)
        .preferredColorScheme(themeMode.colorScheme)
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
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        CurrentRoutineStatusView(snapshot: routineSnapshot(at: timeline.date, routines: routines))
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
    let snapshot: RoutineSnapshot

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
                    Text(snapshot.remainingText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

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

            ProgressView(value: snapshot.progress)
                .tint(snapshot.tint)
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

private struct RoutineSnapshot {
    let title: String
    let caption: String
    let progress: Double
    let remainingText: String
    let startTimeText: String
    let endTimeText: String
    let nextTitle: String
    let tint: Color
}

private func routineSnapshot(at date: Date, routines: [Routine]) -> RoutineSnapshot {
    guard !routines.isEmpty else {
        return RoutineSnapshot(
            title: "暂无日程",
            caption: "当前",
            progress: 0,
            remainingText: "--:--:--",
            startTimeText: "--:--",
            endTimeText: "--:--",
            nextTitle: "无",
            tint: .secondary
        )
    }

    let seconds = secondsSinceStartOfDay(for: date)

    if let current = routines.first(where: { $0.contains(daySecond: seconds) }) {
        let elapsed = current.elapsedSeconds(at: seconds)
        let duration = max(current.durationMinutes * 60, 1)
        let remaining = max(duration - elapsed, 0)
        let next = nextRoutine(after: seconds, routines: routines, excluding: current.id)

        return RoutineSnapshot(
            title: current.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新日程" : current.name,
            caption: "当前日程",
            progress: min(max(Double(elapsed) / Double(duration), 0), 1),
            remainingText: countdownString(seconds: remaining),
            startTimeText: timeString(minutes: current.startMinutes),
            endTimeText: timeString(minutes: current.endMinutes),
            nextTitle: next.map { displayName(for: $0.routine) } ?? "无",
            tint: current.color.swiftUIColor
        )
    }

    let next = nextRoutine(after: seconds, routines: routines)

    return RoutineSnapshot(
        title: "空闲",
        caption: next.map { "距离 \($0.routine.name) 开始" } ?? "当前",
        progress: 0,
        remainingText: countdownString(seconds: next?.remaining ?? 0),
        startTimeText: "--:--",
        endTimeText: "--:--",
        nextTitle: next.map { displayName(for: $0.routine) } ?? "无",
        tint: .secondary
    )
}

private func nextRoutine(
    after seconds: Int,
    routines: [Routine],
    excluding excludedID: Routine.ID? = nil
) -> (routine: Routine, remaining: Int)? {
    routines
        .filter { $0.id != excludedID }
        .map { routine in (routine: routine, remaining: secondsUntilStart(of: routine, from: seconds)) }
        .min { $0.remaining < $1.remaining }
}

private func secondsSinceStartOfDay(for date: Date) -> Int {
    let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    return ((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)) % (minutesPerDay * 60)
}

private func secondsUntilStart(of routine: Routine, from seconds: Int) -> Int {
    let startSeconds = routine.startMinutes.normalizedDayMinute * 60
    let raw = startSeconds - seconds
    return raw >= 0 ? raw : raw + minutesPerDay * 60
}

private func countdownString(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let seconds = seconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

private func timeString(minutes: Int) -> String {
    let normalized = minutes.normalizedDayMinute
    return String(format: "%02d:%02d", normalized / 60, normalized % 60)
}

private func displayName(for routine: Routine) -> String {
    let trimmed = routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "新日程" : trimmed
}

private extension Routine {
    func contains(daySecond: Int) -> Bool {
        let start = startMinutes.normalizedDayMinute * 60
        let end = endMinutes.normalizedDayMinute * 60

        if start == end {
            return true
        }

        if start < end {
            return daySecond >= start && daySecond < end
        }

        return daySecond >= start || daySecond < end
    }

    func elapsedSeconds(at daySecond: Int) -> Int {
        let start = startMinutes.normalizedDayMinute * 60
        let raw = daySecond - start
        return raw >= 0 ? raw : raw + minutesPerDay * 60
    }
}

#Preview {
    ContentView()
}
