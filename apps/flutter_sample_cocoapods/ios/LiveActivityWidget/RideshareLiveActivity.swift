import ActivityKit
import CioLiveActivities_Attributes
import SwiftUI
import WidgetKit

/// SwiftUI rendering for the sample app's custom "rideshare" Live Activity.
///
/// The built-in Customer.io templates ship their SwiftUI in the SDK; a custom activity's UI is owned
/// by the app. What the SDK does provide is the attributes *type*: ``CIOCustomAttributes`` carries an
/// untyped `data` map, which is what lets Dart start and update this activity without the app
/// defining a Swift type a method channel could never reach.
///
/// The keys read below are the ones the Dart screen sends. Every value is a string, so parse whatever
/// you need at render time. Add this to `LiveActivityWidgetBundle`.
@available(iOS 16.2, *)
struct RideshareLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CIOCustomAttributes.self) { context in
            // Lock screen / banner presentation.
            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.state.data["driverName"] ?? "Your driver") is on the way")
                    .font(.headline)
                Text(context.state.data["status"] ?? "")
                Text("ETA \(context.state.data["etaMinutes"] ?? "—") min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.data["driverName"] ?? "")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.data["etaMinutes"] ?? "—") min")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.data["status"] ?? "")
                }
            } compactLeading: {
                Image(systemName: "car.fill")
            } compactTrailing: {
                Text("\(context.state.data["etaMinutes"] ?? "")m")
            } minimal: {
                Image(systemName: "car.fill")
            }
        }
    }
}
