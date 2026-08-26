import Foundation

enum CustomerIOURLRoutingResolution: Equatable {
    case notHandled
    case handled
    case invalidTrackingRedirect
    case redirect(URL)
}

enum CustomerIOURLRouting {
    /// Mirrors Flutter's documented default: a missing `FlutterDeepLinkingEnabled` key enables
    /// framework deep-link routing.
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

    static func didFlutterHandle(_ result: Any?) -> Bool {
        (result as? NSNumber)?.boolValue == true
    }
}

enum CustomerIOViewControllerTraversal {
    static func topmostFirst<Node: AnyObject>(
        roots: [Node],
        presentedViewController: (Node) -> Node?,
        children: (Node) -> [Node]
    ) -> [Node] {
        var visited = Set<ObjectIdentifier>()
        var ordered: [Node] = []

        func visit(_ node: Node) {
            guard visited.insert(ObjectIdentifier(node)).inserted else { return }

            if let presented = presentedViewController(node) {
                visit(presented)
            }
            for child in children(node).reversed() {
                visit(child)
            }
            ordered.append(node)
        }

        roots.forEach(visit)
        return ordered
    }
}

/// Flutter can forward one UIKit occurrence through more than one engine's plugin chain. Cache the
/// native resolution so Customer.io reports its metric once for that occurrence.
@MainActor
final class CustomerIOSceneOccurrenceResults {
    private final class Entry {
        weak var occurrence: AnyObject?
        let resolution: CustomerIOURLRoutingResolution
        var redirectDeliveryClaimed = false

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
        if let existing = entries[identifier], existing.occurrence === occurrence {
            return existing.resolution
        }

        let resolution = resolve()
        entries[identifier] = Entry(occurrence: occurrence, resolution: resolution)
        return resolution
    }

    func claimRedirectDelivery(for occurrence: AnyObject) -> Bool {
        entries = entries.filter { $0.value.occurrence != nil }
        let identifier = ObjectIdentifier(occurrence)
        guard let entry = entries[identifier], entry.occurrence === occurrence else { return false }
        guard !entry.redirectDeliveryClaimed else { return false }

        entry.redirectDeliveryClaimed = true
        return true
    }
}
