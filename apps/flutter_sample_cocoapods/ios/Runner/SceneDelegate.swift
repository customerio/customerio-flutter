import CioLiveActivities_Attributes
import Flutter
import OSLog
import UIKit
import customer_io

final class CustomerIOLiveActivitySceneHandler: NSObject, FlutterSceneLifeCycleDelegate {
    private let isCustomerIOURL: (URL) -> Bool
    private let handleWidgetURL: (URL) -> URL?
    private var pendingColdStartURLs: [URL] = []
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
        guard connectionOptions?.userActivities.isEmpty ?? true else { return false }
        guard let URLContexts = connectionOptions?.urlContexts else { return false }
        return routeCustomerIOURLs(URLContexts.map(\.url)) { [weak self] routableURL in
            guard let self = self else { return false }
            pendingColdStartURLs.append(routableURL)
            return true
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
        logger.notice("customerio-flutter-scene-open-url-contexts")
        return handleCustomerIOURLs(URLContexts)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard !pendingColdStartURLs.isEmpty else { return }
        let URLs = pendingColdStartURLs
        pendingColdStartURLs.removeAll()
        logger.notice("customerio-flutter-scene-flushing-cold-start-urls")

        // Wait until FlutterSceneDelegate has completed the activation callback. The launch
        // engine/view controller is attached by this point, unlike during willConnectTo.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for URL in URLs {
                _ = forwardToFlutter(URL)
            }
        }
    }

    private func handleCustomerIOURLs(_ URLContexts: Set<UIOpenURLContext>) -> Bool {
        routeCustomerIOURLs(URLContexts.map(\.url)) { [weak self] routableURL in
            self?.forwardToFlutter(routableURL) ?? false
        }
    }

    private func forwardToFlutter(_ URL: URL) -> Bool {
        let handled = UIApplication.shared.delegate?.application?(
            UIApplication.shared,
            open: URL,
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
        var didRoute = false
        var consumedTrackingURL = false
        for url in urls {
            let isTrackingURL = isCustomerIOURL(url)
            let routableURL = isTrackingURL ? handleWidgetURL(url) : url
            guard let routableURL else {
                consumedTrackingURL = consumedTrackingURL || isTrackingURL
                continue
            }
            guard !isCustomerIOURL(routableURL) else {
                logger.error("Customer.io Live Activity redirect resolved to another tracking URL")
                consumedTrackingURL = true
                continue
            }
            didRoute = route(routableURL) || didRoute
        }
        return didRoute || consumedTrackingURL
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
        var webRoutes: [URL] = []
        let webHandled = handler.routeCustomerIOURLs([tracking, web]) {
            webRoutes.append($0)
            return true
        }
        return handler.responds(to: NSSelectorFromString("scene:willConnectToSession:options:"))
            && handler.responds(to: NSSelectorFromString("scene:openURLContexts:"))
            && handler.responds(to: NSSelectorFromString("sceneDidBecomeActive:"))
            && handled
            && routedURLs.count == 2
            && Set(routedURLs) == Set([redirect, ordinary])
            && nestedHandled
            && nestedRoutes.isEmpty
            && webHandled
            && webRoutes.count == 2
            && Set(webRoutes) == Set([redirect, web])
    }
    #endif
}

/// Flutter owns scene lifecycle forwarding for the sample app.
class SceneDelegate: FlutterSceneDelegate {}
