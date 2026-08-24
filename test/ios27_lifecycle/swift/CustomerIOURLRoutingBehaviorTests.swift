import Foundation

private final class Occurrence {}

private final class ViewControllerNode {
    let name: String
    var presentedViewController: ViewControllerNode?
    var children: [ViewControllerNode] = []

    init(_ name: String) {
        self.name = name
    }
}

@main
enum CustomerIOURLRoutingBehaviorTests {
    @MainActor
    static func main() {
        testFlutterDeepLinkingConfiguration()
        testRoutingResolution()
        testColdConnectionOwnership()
        testFlutterDeliveryResult()
        testTopmostViewControllerTraversal()
        testOccurrenceDeduplication()
        print("CustomerIOURLRoutingBehaviorTests passed")
    }

    private static func testFlutterDeepLinkingConfiguration() {
        expect(
            CustomerIOURLRouting.isFlutterDeepLinkingEnabled(nil),
            "Flutter deep linking must remain enabled by default"
        )
        expect(
            CustomerIOURLRouting.isFlutterDeepLinkingEnabled(NSNumber(value: true)),
            "an enabled Flutter deep-link setting must register automatic routing"
        )
        expect(
            !CustomerIOURLRouting.isFlutterDeepLinkingEnabled(NSNumber(value: false)),
            "a disabled Flutter deep-link setting must preserve host-owned routing"
        )
        expect(
            CustomerIOURLRouting.isFlutterDeepLinkingEnabled("true" as NSString),
            "a string Flutter deep-link setting must match Flutter's boolValue behavior"
        )
        expect(
            !CustomerIOURLRouting.isFlutterDeepLinkingEnabled(["invalid": true]),
            "an invalid Flutter deep-link setting must fail closed"
        )
    }

    private static func testRoutingResolution() {
        let ordinary = URL(string: "myapp://settings")!
        expect(
            CustomerIOURLRouting.resolve(
                ordinary,
                handleWidgetURL: { $0 },
                isWidgetTrackingURL: { _ in false }
            ) == .notHandled,
            "ordinary URLs must remain unclaimed"
        )

        let tracking = URL(string: "cio-live-activity://open?id=1")!
        expect(
            CustomerIOURLRouting.resolve(
                tracking,
                handleWidgetURL: { _ in nil },
                isWidgetTrackingURL: { _ in false }
            ) == .handled,
            "a tracking URL without a redirect must be consumed"
        )

        let destination = URL(string: "myapp://inbox")!
        expect(
            CustomerIOURLRouting.resolve(
                tracking,
                handleWidgetURL: { _ in destination },
                isWidgetTrackingURL: { _ in false }
            ) == .redirect(destination),
            "a customer redirect must be forwarded"
        )

        let nestedTracking = URL(string: "cio-live-activity://open?id=2")!
        expect(
            CustomerIOURLRouting.resolve(
                tracking,
                handleWidgetURL: { _ in nestedTracking },
                isWidgetTrackingURL: { $0 == nestedTracking }
            ) == .invalidTrackingRedirect,
            "a nested tracking redirect must be consumed without forwarding"
        )

        expect(
            CustomerIOURLRouting.resolve(
                tracking,
                handleWidgetURL: { $0 },
                isWidgetTrackingURL: { $0 == tracking }
            ) == .invalidTrackingRedirect,
            "a self-referential tracking redirect must be consumed without forwarding"
        )
    }

    private static func testColdConnectionOwnership() {
        expect(
            CustomerIOURLRouting.canClaimColdConnection(
                urlCount: 1,
                userActivityCount: 0,
                hasShortcut: false,
                hasNotificationResponse: false
            ),
            "one URL by itself must be claimable"
        )

        let ambiguousInputs: [(Int, Int, Bool, Bool)] = [
            (0, 0, false, false),
            (2, 0, false, false),
            (1, 1, false, false),
            (1, 0, true, false),
            (1, 0, false, true),
        ]
        for input in ambiguousInputs {
            expect(
                !CustomerIOURLRouting.canClaimColdConnection(
                    urlCount: input.0,
                    userActivityCount: input.1,
                    hasShortcut: input.2,
                    hasNotificationResponse: input.3
                ),
                "mixed or ambiguous connection options must remain unclaimed"
            )
        }
    }

    private static func testFlutterDeliveryResult() {
        expect(
            CustomerIOURLRouting.didFlutterHandle(NSNumber(value: true)),
            "a true Flutter result must consume the destination"
        )
        expect(
            !CustomerIOURLRouting.didFlutterHandle(NSNumber(value: false)),
            "a false Flutter result must use the native fallback"
        )
        expect(
            !CustomerIOURLRouting.didFlutterHandle(nil),
            "a missing Flutter result must use the native fallback"
        )
    }

    private static func testTopmostViewControllerTraversal() {
        let underlyingFlutter = ViewControllerNode("underlying Flutter")
        let container = ViewControllerNode("container")
        let presentedFlutter = ViewControllerNode("presented Flutter")

        container.children = [underlyingFlutter]
        container.presentedViewController = presentedFlutter
        // UIKit may expose an ancestor's presented controller through its descendants.
        underlyingFlutter.presentedViewController = presentedFlutter

        let ordered = CustomerIOViewControllerTraversal.topmostFirst(
            roots: [container],
            presentedViewController: \.presentedViewController,
            children: \.children
        )
        expect(
            ordered.map(\.name) == ["presented Flutter", "underlying Flutter", "container"],
            "the topmost controller must be considered before the underlying Flutter engine"
        )
        expect(
            ordered.filter { $0 === presentedFlutter }.count == 1,
            "a presented controller reachable through an ancestor and child must be visited once"
        )
    }

    @MainActor
    private static func testOccurrenceDeduplication() {
        let results = CustomerIOSceneOccurrenceResults()
        let first = Occurrence()
        var routeCount = 0

        let destination = URL(string: "myapp://inbox")!
        let firstResult = results.resolution(for: first) {
            routeCount += 1
            return .redirect(destination)
        }
        let repeatedResult = results.resolution(for: first) {
            routeCount += 1
            return .notHandled
        }
        expect(
            firstResult == .redirect(destination) && repeatedResult == firstResult,
            "one occurrence must return one stable resolution"
        )
        expect(routeCount == 1, "one occurrence must resolve exactly once")
        expect(
            results.claimRedirectDelivery(for: first),
            "the first engine must claim redirect delivery"
        )
        expect(
            !results.claimRedirectDelivery(for: first),
            "later engines must not deliver the same redirect again"
        )

        let second = Occurrence()
        let secondResult = results.resolution(for: second) {
            routeCount += 1
            return .notHandled
        }
        expect(secondResult == .notHandled, "a later occurrence must retain its own result")
        expect(routeCount == 2, "a later occurrence must resolve independently")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        guard condition() else {
            fatalError(message)
        }
    }
}
