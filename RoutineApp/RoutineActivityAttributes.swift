import ActivityKit
import Foundation

struct RoutineActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var snapshot: RoutineStatusSnapshot
    }

    var createdAt: Date
}

