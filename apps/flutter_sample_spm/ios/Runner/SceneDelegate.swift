import CioLiveActivities_Attributes
import Flutter
import OSLog
import UIKit
import customer_io

final class CustomerIOLiveActivitySceneHandler: NSObject, FlutterSceneLifeCycleDelegate {
    private static let maximumQueuedForwardingAttempts = 40
    private static let forwardingRetryDelay = 0.25

    private let isCustomerIOURL: (URL) -> Bool
    private let handleWidgetURL: (URL) -> URL?
    private let forwardURLForSelfTest: ((URL) -> Bool)?
    private var pendingForwardingURLs: [URL] = []
    private var forwardingRetryWorkItem: DispatchWorkItem?
    private var flutterEngineIsReady = false
    private let runToken = ProcessInfo.processInfo.environment["CIO_SCENE_HANDLER_RUN_TOKEN"] ?? "none"
    private let logger = Logger(
        subsystem: "io.customer.flutter.fixture",
        category: "scene-lifecycle"
    )

    override init() {
        isCustomerIOURL = { CioLiveActivityWidgetUrl.parse($0) != nil }
        handleWidgetURL = CustomerIOLiveActivities.handleWidgetUrl
        forwardURLForSelfTest = nil
        super.init()
    }

    #if CIO_SCENE_CONTRACT_SELF_TEST
    private init(
        isCustomerIOURL: @escaping (URL) -> Bool,
        handleWidgetURL: @escaping (URL) -> URL?,
        forwardURL: ((URL) -> Bool)? = nil
    ) {
        self.isCustomerIOURL = isCustomerIOURL
        self.handleWidgetURL = handleWidgetURL
        forwardURLForSelfTest = forwardURL
        super.init()
    }
    #endif

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        logger.notice("customerio-flutter-scene-will-connect token=\(self.runToken, privacy: .public)")
        guard let urlContexts = connectionOptions?.urlContexts else { return false }
        return handleConnectionURLs(
            urlContexts.map(\.url),
            hasUserActivities: !(connectionOptions?.userActivities.isEmpty ?? true)
        )
    }

    private func handleConnectionURLs(_ urls: [URL], hasUserActivities: Bool) -> Bool {
        // Flutter owns universal-link user activities. A plugin cannot partially consume
        // connection options, so leave a mixed URL/user-activity occurrence untouched.
        guard !hasUserActivities else {
            logger.notice("customerio-flutter-scene-mixed-connection-options-not-consumed")
            return false
        }
        return routeCustomerIOURLs(urls) { [weak self] routableURL in
            guard let self = self else { return false }
            pendingForwardingURLs.append(routableURL)
            return true
        }
    }

    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
        logger.notice("customerio-flutter-scene-open-url-contexts")
        let sceneIsActive = scene.activationState == .foregroundActive
        let consumed = handleOpenURLs(
            urlContexts.map(\.url),
            sceneIsActive: sceneIsActive
        )
        if sceneIsActive {
            schedulePendingURLDrain(attempt: 0)
        }
        return consumed
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        logger.notice("customerio-flutter-scene-did-become-active token=\(self.runToken, privacy: .public)")
        schedulePendingURLDrain(attempt: 0)
    }

    func flutterEngineDidBecomeReady() {
        flutterEngineIsReady = true
        // The registry exists before the Dart navigation handler necessarily answers. Retain the
        // bounded retry below so a slow cold start does not strand the URL until reactivation.
        schedulePendingURLDrain(attempt: 0)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        forwardingRetryWorkItem?.cancel()
        forwardingRetryWorkItem = nil
        if !pendingForwardingURLs.isEmpty {
            logger.notice("Deferred pending Flutter URLs until the next scene activation")
        }
    }

    private func schedulePendingURLDrain(attempt: Int) {
        guard !pendingForwardingURLs.isEmpty else { return }
        guard flutterEngineIsReady else { return }
        guard forwardingRetryWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.drainPendingURLs(attempt: attempt)
        }
        forwardingRetryWorkItem = workItem
        let delay = attempt == 0 ? 0 : Self.forwardingRetryDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func drainPendingURLs(attempt: Int) {
        forwardingRetryWorkItem = nil
        let urls = pendingForwardingURLs
        pendingForwardingURLs.removeAll()
        logger.notice("customerio-flutter-scene-flushing-pending-urls")

        var urlsToRetry: [URL] = []
        for url in urls {
            if !forwardToFlutter(url) {
                urlsToRetry.append(url)
            }
        }
        guard !urlsToRetry.isEmpty else { return }

        pendingForwardingURLs.insert(contentsOf: urlsToRetry, at: 0)
        let nextAttempt = attempt + 1
        guard nextAttempt < Self.maximumQueuedForwardingAttempts else {
            logger.error("Flutter URL forwarding retry budget exhausted; URLs remain queued for the next activation")
            return
        }
        schedulePendingURLDrain(attempt: nextAttempt)
    }

    private func handleOpenURLs(_ urls: [URL], sceneIsActive: Bool) -> Bool {
        routeCustomerIOURLs(urls) { [weak self] routableURL in
            guard let self else { return false }
            if sceneIsActive, forwardToFlutter(routableURL) {
                return true
            }
            pendingForwardingURLs.append(routableURL)
            return true
        }
    }

    private func forwardToFlutter(_ url: URL) -> Bool {
        // Both sample manifests explicitly disable multiple scenes. The application delegate
        // therefore owns the one Flutter engine route for this reference integration.
        let handled: Bool
        if let forwardURLForSelfTest {
            handled = forwardURLForSelfTest(url)
        } else {
            handled = UIApplication.shared.delegate?.application?(
                UIApplication.shared,
                open: url,
                options: [:]
            ) ?? false
        }
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
        let failedForwardingHandler = CustomerIOLiveActivitySceneHandler(
            isCustomerIOURL: { $0 == tracking },
            handleWidgetURL: { _ in redirect },
            forwardURL: { _ in false }
        )
        let coldConsumed = failedForwardingHandler.handleConnectionURLs(
            [tracking],
            hasUserActivities: false
        )
        let coldQueued = failedForwardingHandler.pendingForwardingURLs == [redirect]
        failedForwardingHandler.pendingForwardingURLs.removeAll()
        let mixedConsumed = failedForwardingHandler.handleConnectionURLs(
            [tracking],
            hasUserActivities: true
        )
        let mixedStayedUnqueued = failedForwardingHandler.pendingForwardingURLs.isEmpty
        let inactiveWarmConsumed = failedForwardingHandler.handleOpenURLs(
            [tracking],
            sceneIsActive: false
        )
        let warmQueued = failedForwardingHandler.pendingForwardingURLs == [redirect]
        failedForwardingHandler.forwardingRetryWorkItem?.cancel()
        failedForwardingHandler.forwardingRetryWorkItem = nil
        failedForwardingHandler.drainPendingURLs(
            attempt: Self.maximumQueuedForwardingAttempts - 1
        )
        let exhaustedQueueWasPreserved = failedForwardingHandler.pendingForwardingURLs == [redirect]
        let successfulForwardingHandler = CustomerIOLiveActivitySceneHandler(
            isCustomerIOURL: { $0 == tracking },
            handleWidgetURL: { _ in redirect },
            forwardURL: { _ in true }
        )
        let activeWarmConsumed = successfulForwardingHandler.handleOpenURLs(
            [tracking],
            sceneIsActive: true
        )
        let successfulForwardLeftNoQueue = successfulForwardingHandler.pendingForwardingURLs.isEmpty
        let readinessHandler = CustomerIOLiveActivitySceneHandler(
            isCustomerIOURL: { $0 == tracking },
            handleWidgetURL: { _ in redirect },
            forwardURL: { _ in true }
        )
        _ = readinessHandler.handleConnectionURLs([tracking], hasUserActivities: false)
        let readinessWaitedForEngine = readinessHandler.forwardingRetryWorkItem == nil
        readinessHandler.flutterEngineDidBecomeReady()
        let readinessScheduledDrain = readinessHandler.forwardingRetryWorkItem != nil
        readinessHandler.forwardingRetryWorkItem?.cancel()
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
            && coldConsumed
            && coldQueued
            && !mixedConsumed
            && mixedStayedUnqueued
            && inactiveWarmConsumed
            && warmQueued
            && exhaustedQueueWasPreserved
            && activeWarmConsumed
            && successfulForwardLeftNoQueue
            && readinessWaitedForEngine
            && readinessScheduledDrain
    }
    #endif
}

/// Flutter owns scene lifecycle forwarding for the sample app.
class SceneDelegate: FlutterSceneDelegate {}
