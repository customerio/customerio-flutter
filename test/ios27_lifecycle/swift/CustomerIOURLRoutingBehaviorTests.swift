import Foundation

private final class Occurrence {}

@main
enum CustomerIOURLRoutingBehaviorTests {
    @MainActor
    static func main() {
        testLifecycleSeatSelection()
        testFlutterDeepLinkingConfiguration()
        testRoutingResolution()
        testColdConnectionOwnership()
        testOccurrenceDeduplication()
        print("CustomerIOURLRoutingBehaviorTests passed")
    }

    private static func testLifecycleSeatSelection() {
        expect(
            !CustomerIOLifecycleSeatSelection.shouldRegisterSceneDelegate(
                hasSceneManifest: false,
                flutterDeepLinkingEnabled: true
            ),
            "an AppDelegate host must keep its existing URL lifecycle integration"
        )
        expect(
            CustomerIOLifecycleSeatSelection.shouldRegisterSceneDelegate(
                hasSceneManifest: true,
                flutterDeepLinkingEnabled: true
            ),
            "a UIScene host must register only the scene lifecycle seat"
        )
        for hasSceneManifest in [false, true] {
            expect(
                !CustomerIOLifecycleSeatSelection.shouldRegisterSceneDelegate(
                    hasSceneManifest: hasSceneManifest,
                    flutterDeepLinkingEnabled: false
                ),
                "a host that disables Flutter deep linking must retain lifecycle ownership"
            )
        }
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
