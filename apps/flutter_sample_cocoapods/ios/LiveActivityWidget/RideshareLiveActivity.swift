import ActivityKit
import SwiftUI
import WidgetKit

/// SwiftUI rendering for the sample app's custom "rideshare" Live Activity. Unlike the built-in
/// Customer.io templates (whose SwiftUI ships in the SDK), a custom type's UI is owned by the app.
/// Add this to `LiveActivityWidgetBundle`.
@available(iOS 16.2, *)
struct RideshareLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideshareAttributes.self) { context in
            // Lock screen / banner presentation.
            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.attributes.driverName) is on the way")
                    .font(.headline)
                Text(context.state.status)
                Text("ETA \(context.state.etaMinutes) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.driverName)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.etaMinutes) min")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.status)
                }
            } compactLeading: {
                Image(systemName: "car.fill")
            } compactTrailing: {
                Text("\(context.state.etaMinutes)m")
            } minimal: {
                Image(systemName: "car.fill")
            }
        }
    }
}
