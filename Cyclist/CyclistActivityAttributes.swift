import ActivityKit
import Foundation

struct CyclistActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var snapshot: RoutineStatusSnapshot
        var routines: [Routine]

        init(snapshot: RoutineStatusSnapshot, routines: [Routine] = []) {
            self.snapshot = snapshot
            self.routines = routines
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            snapshot = try container.decode(RoutineStatusSnapshot.self, forKey: .snapshot)
            routines = try container.decodeIfPresent([Routine].self, forKey: .routines) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case snapshot
            case routines
        }
    }

    var createdAt: Date
}
