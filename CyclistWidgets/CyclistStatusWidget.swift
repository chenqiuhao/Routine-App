import SwiftUI
import WidgetKit

struct CyclistStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: RoutineStatusSnapshot
}

struct CyclistStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> CyclistStatusEntry {
        let date = Date()
        return CyclistStatusEntry(
            date: date,
            snapshot: routineStatusSnapshot(at: date, routines: RoutineSharedStorage.sampleRoutines)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CyclistStatusEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CyclistStatusEntry>) -> Void) {
        let now = Date()
        let routines = RoutineSharedStorage.loadRoutines()
        let entries = routineStatusWidgetTimelineDates(from: now, routines: routines)
            .map { entry(at: $0, routines: routines) }
        let refreshDate = nextTimelineRefreshDate(after: entries.last?.date ?? now, routines: routines)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func entry(at date: Date) -> CyclistStatusEntry {
        entry(at: date, routines: RoutineSharedStorage.loadRoutines())
    }

    private func entry(at date: Date, routines: [Routine]) -> CyclistStatusEntry {
        CyclistStatusEntry(
            date: date,
            snapshot: routineStatusSnapshot(at: date, routines: routines)
        )
    }

    private func nextTimelineRefreshDate(after date: Date, routines: [Routine]) -> Date {
        nextCyclistStatusWidgetTimelineDate(after: date, routines: routines)
            ?? date.addingTimeInterval(60 * 60)
    }
}

struct CyclistStatusWidget: Widget {
    let kind = "CyclistStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CyclistStatusProvider()) { entry in
            CyclistStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Cyclist")
        .description("查看当前日程、倒计时和下一日程。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct CyclistStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CyclistStatusEntry

    var body: some View {
        CyclistStatusCard(date: entry.date, snapshot: entry.snapshot, compact: family == .systemSmall)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
    }
}

struct CyclistStatusCard: View {
    let date: Date
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

                WidgetRemainingText(date: date, snapshot: snapshot)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(minWidth: 62, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
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
                    WidgetRemainingText(date: date, snapshot: snapshot)
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
    let date: Date
    let snapshot: RoutineStatusSnapshot

    var body: some View {
        if let endDate = snapshot.endDate,
           endDate.timeIntervalSince(date) < 60 {
            Text(endDate, style: .relative)
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        } else {
            Text(widgetRemainingCountdownText(date: date, snapshot: snapshot))
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

private func routineStatusWidgetTimelineDates(
    from date: Date,
    routines: [Routine],
    horizon: TimeInterval = 4 * 60 * 60,
    limit: Int = 120
) -> [Date] {
    guard limit > 0 else { return [] }

    var dates = [date]
    var cursor = date
    let endDate = date.addingTimeInterval(horizon)

    while dates.count < limit,
          let nextDate = nextCyclistStatusWidgetTimelineDate(after: cursor, routines: routines) {
        guard nextDate <= endDate else { break }

        if let lastDate = dates.last,
           nextDate.timeIntervalSince(lastDate) > 0.25 {
            dates.append(nextDate)
        }

        cursor = nextDate
    }

    return dates
}

private func nextCyclistStatusWidgetTimelineDate(after date: Date, routines: [Routine]) -> Date? {
    let snapshot = routineStatusSnapshot(at: date, routines: routines)
    let threshold = date.addingTimeInterval(0.5)
    var candidates: [Date] = []

    if let boundaryDate = nextRoutineStatusChangeDate(after: date, routines: routines)?.addingTimeInterval(1),
       boundaryDate > threshold {
        candidates.append(boundaryDate)
    }

    if let countdownDate = nextWidgetCountdownDisplayChangeDate(after: date, endDate: snapshot.endDate),
       countdownDate > threshold {
        candidates.append(countdownDate)
    }

    return candidates.min()
}

private func nextWidgetCountdownDisplayChangeDate(after date: Date, endDate: Date?) -> Date? {
    guard let endDate else { return nil }

    let wholeSeconds = widgetRemainingWholeSeconds(until: endDate, at: date)
    guard wholeSeconds > 0 else { return nil }

    let nextWholeSeconds: Int
    if wholeSeconds > 60 {
        let minutes = Int(ceil(Double(wholeSeconds) / 60.0))
        nextWholeSeconds = (minutes - 1) * 60
    } else if wholeSeconds == 60 {
        nextWholeSeconds = 59
    } else {
        return nil
    }

    return endDate.addingTimeInterval(-Double(nextWholeSeconds))
}

private func widgetRemainingCountdownText(date: Date, snapshot: RoutineStatusSnapshot) -> String {
    guard let endDate = snapshot.endDate else {
        return snapshot.remainingMinuteText
    }

    let wholeSeconds = widgetRemainingWholeSeconds(until: endDate, at: date)

    guard wholeSeconds >= 60 else {
        return "\(wholeSeconds) sec"
    }

    let minutes = Int(ceil(Double(wholeSeconds) / 60.0))
    return routineDurationText(minutes: minutes)
}

private func widgetRemainingWholeSeconds(until endDate: Date, at date: Date) -> Int {
    max(0, Int(ceil(endDate.timeIntervalSince(date))))
}
