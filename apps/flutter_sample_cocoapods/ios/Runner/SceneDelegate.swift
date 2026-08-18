import CioLiveActivities_Attributes
import Flutter
import OSLog
import UIKit
import customer_io

final class CustomerIOLiveActivitySceneHandler: NSObject, FlutterSceneLifeCycleDelegate {
    private static let maximumColdStartForwardingAttempts = 8
    private static let coldStartRetryDelay = 0.25

    private let isCustomerIOURL: (URL) -> Bool
    private let handleWidgetURL: (URL) -> URL?
    private var pendingColdStartURLs: [URL] = []
    private var coldStartRetryWorkItem: DispatchWorkItem?
    private let logger = Logger(
        subsystem: "io.customer.flutter.fixture",
        category: "scene-lifecycle"
    )

    override init() {
        isCustomerIOURL = { CioLiveActivityWidgetUrl.parse($0) != nil }
        handleWidgetURL = CustomerIOLiveActivities.handleWidgetUrl
        super.init()
    }

    #if CIO_SCENE_CONTRACT_SELF_TEST
    private init(
        isCustomerIOURL: @escaping (URL) -> Bool,
        handleWidgetURL: @escaping (URL) -> URL?
    ) {
        self.isCustomerIOURL = isCustomerIOURL
        self.handleWidgetURL = handleWidgetURL
        super.init()
    }
    #endif

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        logger.notice("customerio-flutter-scene-will-connect")
        // Flutter owns universal-link user activities. A plugin cannot partially consume
        // connection options, so leave a mixed URL/user-activity occurrence untouched.
        guard connectionOptions?.userActivities.isEmpty ?? true else {
            logger.notice("customerio-flutter-scene-mixed-connection-options-not-consumed")
            return false
        }
        guard let urlContexts = connectionOptions?.urlContexts else { return false }
        return routeCustomerIOURLs(urlContexts.map(\.url)) { [weak self] routableURL in
            guard let self = self else { return false }
            pendingColdStartURLs.append(routableURL)
            return true
        }
    }

    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
        logger.notice("customerio-flutter-scene-open-url-contexts")
        return handleCustomerIOURLs(urlContexts)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        scheduleColdStartURLDrain(attempt: 0)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        coldStartRetryWorkItem?.cancel()
        coldStartRetryWorkItem = nil
    }

    private func scheduleColdStartURLDrain(attempt: Int) {
        guard !pendingColdStartURLs.isEmpty else { return }
        guard coldStartRetryWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.drainColdStartURLs(attempt: attempt)
        }
        coldStartRetryWorkItem = workItem
        let delay = attempt == 0 ? 0 : Self.coldStartRetryDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func drainColdStartURLs(attempt: Int) {
        coldStartRetryWorkItem = nil
        let urls = pendingColdStartURLs
        pendingColdStartURLs.removeAll()
        logger.notice("customerio-flutter-scene-flushing-cold-start-urls")

        var urlsToRetry: [URL] = []
        for url in urls {
            if !forwardToFlutter(url) {
                urlsToRetry.append(url)
            }
        }
        guard !urlsToRetry.isEmpty else { return }

        pendingColdStartURLs.insert(contentsOf: urlsToRetry, at: 0)
        let nextAttempt = attempt + 1
        guard nextAttempt < Self.maximumColdStartForwardingAttempts else {
            logger.error("Flutter URL forwarding retry budget exhausted; URLs remain queued for the next activation")
            return
        }
        scheduleColdStartURLDrain(attempt: nextAttempt)
    }

    private func handleCustomerIOURLs(_ urlContexts: Set<UIOpenURLContext>) -> Bool {
        routeCustomerIOURLs(urlContexts.map(\.url)) { [weak self] routableURL in
            self?.forwardToFlutter(routableURL) ?? false
        }
    }

    private func forwardToFlutter(_ url: URL) -> Bool {
        // Both sample manifests explicitly disable multiple scenes. The application delegate
        // therefore owns the one Flutter engine route for this reference integration.
        let handled = UIApplication.shared.delegate?.application?(
            UIApplication.shared,
            open: url,
            options: [:]
        ) ?? false
        if !handled {
            logger.error("Flutter did not handle a URL received with a Customer.io Live Activity tap")
        }
        return handled
    }

    private func routeCustomerIOURLs(
        _ urls: [URL],
        route: (URL) -> Bool
    ) -> Bool {
        guard urls.contains(where: isCustomerIOURL) else { return false }

        // Consuming this callback prevents Flutter from routing the Customer.io tracking URL.
        // Replay every routable URL through FlutterAppDelegate so both custom-scheme and web
        // redirects reach Flutter instead of being handed back to the OS by UIScene.open.
        var consumedTrackingURL = false
        for url in urls {
            let isTrackingURL = isCustomerIOURL(url)
            consumedTrackingURL = consumedTrackingURL || isTrackingURL
            let routableURL = isTrackingURL ? handleWidgetURL(url) : url
            guard let routableURL else { continue }
            guard !isCustomerIOURL(routableURL) else {
                logger.error("Customer.io Live Activity redirect resolved to another tracking URL")
                continue
            }
            _ = route(routableURL)
        }
        return consumedTrackingURL
    }

    #if CIO_SCENE_CONTRACT_SELF_TEST
    static func runContractSelfTest() -> Bool {
        let tracking = URL(string: "cio-test://tracking")!
        let redirect = URL(string: "fixture://redirect")!
        let ordinary = URL(string: "fixture://ordinary")!
        let web = URL(string: "https://example.com/deep-link")!
        let nestedTracking = URL(string: "cio-test://nested")!
        let handler = CustomerIOLiveActivitySceneHandler(
            isCustomerIOURL: { $0 == tracking || $0 == nestedTracking },
            handleWidgetURL: { $0 == tracking ? redirect : nestedTracking }
        )
        var routedURLs: [URL] = []
        let handled = handler.routeCustomerIOURLs([tracking, ordinary]) {
            routedURLs.append($0)
            return true
        }
        var nestedRoutes: [URL] = []
        let nestedHandled = handler.routeCustomerIOURLs([nestedTracking]) {
            nestedRoutes.append($0)
            return true
        }
        var rejectedRoutes: [URL] = []
        let rejectedRouteConsumed = handler.routeCustomerIOURLs([tracking]) {
            rejectedRoutes.append($0)
            return false
        }
        let noRedirectHandler = CustomerIOLiveActivitySceneHandler(
            isCustomerIOURL: { $0 == tracking },
            handleWidgetURL: { _ in nil }
        )
        var noRedirectRoutes: [URL] = []
        let noRedirectConsumed = noRedirectHandler.routeCustomerIOURLs([tracking]) {
            noRedirectRoutes.append($0)
            return true
        }
        var webRoutes: [URL] = []
        let webHandled = handler.routeCustomerIOURLs([tracking, web]) {
            webRoutes.append($0)
            return true
        }
        var ordinaryRoutes: [URL] = []
        let ordinaryHandled = handler.routeCustomerIOURLs([ordinary]) {
            ordinaryRoutes.append($0)
            return true
        }
        return handler.responds(to: NSSelectorFromString("scene:willConnectToSession:options:"))
            && handler.responds(to: NSSelectorFromString("scene:openURLContexts:"))
            && handler.responds(to: NSSelectorFromString("sceneDidBecomeActive:"))
            && handler.responds(to: NSSelectorFromString("sceneWillResignActive:"))
            && handled
            && routedURLs.count == 2
            && Set(routedURLs) == Set([redirect, ordinary])
            && nestedHandled
            && nestedRoutes.isEmpty
            && rejectedRouteConsumed
            && rejectedRoutes == [redirect]
            && noRedirectConsumed
            && noRedirectRoutes.isEmpty
            && webHandled
            && webRoutes.count == 2
            && Set(webRoutes) == Set([redirect, web])
            && !ordinaryHandled
            && ordinaryRoutes.isEmpty
    }
    #endif
}

/// Flutter owns scene lifecycle forwarding for the sample app.
class SceneDelegate: FlutterSceneDelegate {}
