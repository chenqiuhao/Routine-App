import ActivityKit
import Foundation

@MainActor
enum RoutineLiveActivityController {
    private static var lastSubmittedKey: ActivitySnapshotKey?

    static func sync(routines: [Routine], enabled: Bool) async {
        guard enabled, !routines.isEmpty else {
            lastSubmittedKey = nil
            await endAll()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let snapshot = routineStatusSnapshot(at: Date(), routines: routines)
        guard snapshot.endDate != nil else {
            await endAll()
            return
        }

        let state = RoutineActivityAttributes.ContentState(snapshot: snapshot, routines: routines)
        let content = ActivityContent(
            state: state,
            staleDate: nextRoutineStatusChangeDate(after: Date(), routines: routines)
        )
        let key = ActivitySnapshotKey(snapshot: snapshot, routines: routines)

        if let activity = Activity<RoutineActivityAttributes>.activities.first {
            if ActivitySnapshotKey(snapshot: activity.content.state.snapshot, routines: activity.content.state.routines) == key || lastSubmittedKey == key {
                lastSubmittedKey = key
                return
            }

            lastSubmittedKey = key
            await activity.update(content)
            return
        }

        guard lastSubmittedKey != key else { return }
        lastSubmittedKey = key

        do {
            _ = try Activity.request(
                attributes: RoutineActivityAttributes(createdAt: Date()),
                content: content,
                pushType: nil
            )
        } catch {
            lastSubmittedKey = nil
            return
        }
    }

    private static func endAll() async {
        for activity in Activity<RoutineActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }
}

private struct ActivitySnapshotKey: Equatable {
    let title: String
    let caption: String
    let startTimeText: String
    let endTimeText: String
    let nextTitle: String
    let tint: RoutineColor?
    let startDate: Date?
    let endDate: Date?
    let routines: [Routine]

    init(snapshot: RoutineStatusSnapshot, routines: [Routine]) {
        title = snapshot.title
        caption = snapshot.caption
        startTimeText = snapshot.startTimeText
        endTimeText = snapshot.endTimeText
        nextTitle = snapshot.nextTitle
        tint = snapshot.tint
        startDate = snapshot.startDate
        endDate = snapshot.endDate
        self.routines = routines
    }
}
