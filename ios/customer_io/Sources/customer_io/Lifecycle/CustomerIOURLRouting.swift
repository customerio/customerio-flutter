import Foundation

enum CustomerIOURLRoutingResolution: Equatable {
    case notHandled
    case handled
    case invalidTrackingRedirect
    case redirect(URL)
}

enum CustomerIOLifecycleSeatSelection {
    static func shouldRegisterApplicationDelegate(
        hasSceneManifest: Bool,
        flutterDeepLinkingEnabled: Bool
    ) -> Bool {
        !hasSceneManifest && flutterDeepLinkingEnabled
    }

    static func shouldRegisterSceneDelegate(
        hasSceneManifest: Bool,
        flutterDeepLinkingEnabled: Bool
    ) -> Bool {
        hasSceneManifest && flutterDeepLinkingEnabled
    }
}

enum CustomerIOURLRouting {
    static func isFlutterDeepLinkingEnabled(_ configuredValue: Any?) -> Bool {
        guard let configuredValue else { return true }
        if let configuredValue = configuredValue as? NSNumber {
            return configuredValue.boolValue
        }
        if let configuredValue = configuredValue as? NSString {
            return configuredValue.boolValue
        }
        return false
    }

    static func resolve(
        _ url: URL,
        handleWidgetURL: (URL) -> URL?,
        isWidgetTrackingURL: (URL) -> Bool
    ) -> CustomerIOURLRoutingResolution {
        guard let destination = handleWidgetURL(url) else {
            return .handled
        }
        guard !isWidgetTrackingURL(destination) else {
            return .invalidTrackingRedirect
        }
        guard destination != url else {
            return .notHandled
        }
        return .redirect(destination)
    }

    static func canClaimColdConnection(
        urlCount: Int,
        userActivityCount: Int,
        hasShortcut: Bool,
        hasNotificationResponse: Bool
    ) -> Bool {
        urlCount == 1 &&
            userActivityCount == 0 &&
            !hasShortcut &&
            !hasNotificationResponse
    }
}

/// Flutter's scene provider forwards one UIKit occurrence through each engine's plugin chain.
/// Cache only the native resolution so Customer.io reports its metric once while each engine may
/// still receive the resolved destination.
@MainActor
final class CustomerIOSceneOccurrenceResults {
    private final class Entry {
        weak var occurrence: AnyObject?
        let resolution: CustomerIOURLRoutingResolution

        init(occurrence: AnyObject, resolution: CustomerIOURLRoutingResolution) {
            self.occurrence = occurrence
            self.resolution = resolution
        }
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    func resolution(
        for occurrence: AnyObject,
        resolve: () -> CustomerIOURLRoutingResolution
    ) -> CustomerIOURLRoutingResolution {
        entries = entries.filter { $0.value.occurrence != nil }
        let identifier = ObjectIdentifier(occurrence)
        if let existing = entries[identifier] {
            return existing.resolution
        }

        let resolution = resolve()
        entries[identifier] = Entry(occurrence: occurrence, resolution: resolution)
        return resolution
    }
}
