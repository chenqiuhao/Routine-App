import ActivityKit
import SwiftUI
import WidgetKit

struct RoutineLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineActivityAttributes.self) { context in
            RoutineLiveActivityLockScreenView(snapshot: context.state.snapshot)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(context.state.snapshot.tintColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.snapshot.caption)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.72))
                        Text(context.state.snapshot.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: 92, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    LiveMinuteCountdownText(
                        snapshot: context.state.snapshot,
                        presentation: .expandedIsland
                    )
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: 116, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        LiveProgressView(snapshot: context.state.snapshot)
                            .tint(context.state.snapshot.tintColor)
                        Text("下一日程 \(context.state.snapshot.nextTitle)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Text(context.state.snapshot.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
                    .frame(maxWidth: 80, alignment: .leading)
            } compactTrailing: {
                LiveMinuteCountdownText(
                    snapshot: context.state.snapshot,
                    compact: true,
                    presentation: .compactIsland
                )
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
                    .frame(width: 50, alignment: .trailing)
                } minimal: {
                Circle()
                    .fill(context.state.snapshot.tintColor)
            }
            .keylineTint(context.state.snapshot.tintColor)
        }
    }
}

private struct RoutineLiveActivityLockScreenView: View {
    let snapshot: RoutineStatusSnapshot

    var body: some View {
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
                    LiveMinuteCountdownText(
                        snapshot: snapshot,
                        presentation: .lockScreen
                    )
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text("下一日程")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(snapshot.nextTitle)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(width: 136, alignment: .trailing)
            }

            LiveProgressView(snapshot: snapshot)
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
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
    }

}

private struct LiveMinuteCountdownText: View {
    let snapshot: RoutineStatusSnapshot
    var compact = false
    var presentation: LiveCountdownPresentation

    var body: some View {
        if let endDate = snapshot.endDate {
            LiveCountdownTimerText(
                startDate: snapshot.startDate,
                endDate: endDate,
                presentation: presentation
            )
        } else {
            Text(compact ? snapshot.compactRemainingMinuteText : snapshot.remainingMinuteText)
        }
    }
}

private enum LiveCountdownPresentation {
    case lockScreen
    case expandedIsland
    case compactIsland
}

private struct LiveCountdownTimerText: View {
    let startDate: Date?
    let endDate: Date
    let presentation: LiveCountdownPresentation

    var body: some View {
        let targetDate = max(endDate, Date.now.addingTimeInterval(1))

        switch presentation {
        case .lockScreen:
            LockScreenCountdownText(endDate: targetDate)
        case .expandedIsland, .compactIsland:
            IslandCountdownText(startDate: startDate, endDate: targetDate, presentation: presentation)
        }
    }
}

private struct LockScreenCountdownText: View {
    let endDate: Date

    var body: some View {
        Text(endDate, style: .relative)
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .lineLimit(1)
            .minimumScaleFactor(LiveCountdownPresentation.lockScreen.minimumScaleFactor)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct IslandCountdownText: View {
    let startDate: Date?
    let endDate: Date
    let presentation: LiveCountdownPresentation

    var body: some View {
        if let interval = routineCountdownInterval(startDate: startDate, endDate: endDate) {
            Text(timerInterval: interval, countsDown: true, showsHours: true)
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                .lineLimit(1)
                .minimumScaleFactor(presentation.minimumScaleFactor)
                .monospacedDigit()
        } else {
            Text("0:00")
                .lineLimit(1)
                .minimumScaleFactor(presentation.minimumScaleFactor)
                .monospacedDigit()
        }
    }
}

private struct LiveProgressView: View {
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

private extension LiveCountdownPresentation {
    var minimumScaleFactor: CGFloat {
        switch self {
        case .lockScreen:
            0.72
        case .expandedIsland:
            0.45
        case .compactIsland:
            0.32
        }
    }

}
