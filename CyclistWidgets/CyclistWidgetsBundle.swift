import SwiftUI
import WidgetKit

@main
struct CyclistWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CyclistStatusWidget()
        CyclistLiveActivityWidget()
    }
}

