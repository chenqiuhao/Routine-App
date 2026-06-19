import SwiftUI
import WidgetKit

struct RoutineStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: RoutineStatusSnapshot
}

struct RoutineStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> RoutineStatusEntry {
        let date = Date()
        return RoutineStatusEntry(
            date: date,
            snapshot: routineStatusSnapshot(at: date, routines: RoutineSharedStorage.sampleRoutines)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RoutineStatusEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RoutineStatusEntry>) -> Void) {
        let now = Date()
        let entry = entry(at: now)
        let refreshDate = nextTimelineRefreshDate(after: now, snapshot: entry.snapshot)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func entry(at date: Date) -> RoutineStatusEntry {
        RoutineStatusEntry(
            date: date,
            snapshot: routineStatusSnapshot(at: date, routines: RoutineSharedStorage.loadRoutines())
        )
    }

    private func nextTimelineRefreshDate(after date: Date, snapshot: RoutineStatusSnapshot) -> Date {
        guard let endDate = snapshot.endDate else {
            return date.addingTimeInterval(60 * 60)
        }

        return max(endDate.addingTimeInterval(1), date.addingTimeInterval(60))
    }
}

struct RoutineStatusWidget: Widget {
    let kind = "RoutineStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoutineStatusProvider()) { entry in
            RoutineStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Routine")
        .description("查看当前日程、倒计时和下一日程。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct RoutineStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: RoutineStatusEntry

    var body: some View {
        RoutineStatusCard(snapshot: entry.snapshot, compact: family == .systemSmall)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
    }
}

struct RoutineStatusCard: View {
    let snapshot: RoutineStatusSnapshot
    let compact: Bool

    var body: some View {
        if compact {
            compactBody
        } else {
            mediumBody
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.caption)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                WidgetRemainingText(snapshot: snapshot)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .offset(x: -4)
            }

            Text(snapshot.title)
                .font(.system(size: 30, weight: .black))
                .lineLimit(2)
                .minimumScaleFactor(0.52)

            WidgetProgressView(snapshot: snapshot)
                .tint(snapshot.tintColor)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("下一日程")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(snapshot.nextTitle)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.36)
            }
        }
        .padding(0)
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.caption)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(snapshot.title)
                        .font(.system(size: 26, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 4) {
                    WidgetRemainingText(snapshot: snapshot)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: 112, alignment: .trailing)

                    Text("下一日程")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(snapshot.nextTitle)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }

            WidgetProgressView(snapshot: snapshot)
                .tint(snapshot.tintColor)
                .scaleEffect(x: 1, y: 1.15, anchor: .center)

            HStack {
                Text(snapshot.startTimeText)
                Spacer()
                Text(snapshot.endTimeText)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private struct WidgetRemainingText: View {
    let snapshot: RoutineStatusSnapshot

    var body: some View {
        if let endDate = snapshot.endDate {
            Text(endDate, style: .relative)
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        } else {
            Text(snapshot.remainingMinuteText)
        }
    }
}

private struct WidgetProgressView: View {
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

