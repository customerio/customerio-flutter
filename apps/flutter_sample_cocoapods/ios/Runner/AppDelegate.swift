import UIKit
import Flutter
import OSLog
import CioDataPipelines
import CioMessagingPushFCM
import FirebaseMessaging
import FirebaseCore
import CioFirebaseWrapper
import customer_io
#if canImport(CioLocationGeofence)
import CioLocationGeofence
#endif

@main
class AppDelegateWithCioIntegration: CioAppDelegateWrapper<AppDelegate> {}

@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private let permissionHandler = PermissionChannelHandler()
    // Flutter stores plugin scene delegates weakly, so the AppDelegate owns this handler.
    private let liveActivitySceneHandler = CustomerIOLiveActivitySceneHandler()

    /// Registry key for this app's permission channel. This helper owns every generated
    /// plugin registration seat, so claiming the permission channel first is also its
    /// once-per-engine guard.
    private static let permissionChannelPluginKey = "io.customer.testbed.PermissionChannelHandler"
    private static let liveActivityScenePluginKey = "io.customer.testbed.LiveActivitySceneHandler"

    private func registerLiveActivitySceneHandlerIfNeeded(with registry: FlutterPluginRegistry) {
        guard !registry.hasPlugin(Self.liveActivityScenePluginKey) else { return }
        guard let registrar = registry.registrar(forPlugin: Self.liveActivityScenePluginKey) else {
            assertionFailure("Live Activity scene registrar unavailable")
            return
        }
        registrar.addSceneDelegate(liveActivitySceneHandler)
    }

    private func registerPluginsIfNeeded(with registry: FlutterPluginRegistry) {
        guard !registry.hasPlugin(Self.permissionChannelPluginKey) else { return }
        guard let registrar = registry.registrar(forPlugin: Self.permissionChannelPluginKey) else {
            assertionFailure("permission channel registrar unavailable")
            return
        }

        GeneratedPluginRegistrant.register(with: registry)
        permissionHandler.register(with: registrar.messenger())
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        registerLiveActivitySceneHandlerIfNeeded(with: engineBridge.pluginRegistry)
        registerPluginsIfNeeded(with: engineBridge.pluginRegistry)
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // FlutterAppDelegate drives a headless launch engine when iOS wakes the app before
        // a FlutterViewController exists. Register that engine here, then reuse the same
        // registry-key guard if Flutter later reports an implicit engine callback.
        registerLiveActivitySceneHandlerIfNeeded(with: self)
        registerPluginsIfNeeded(with: self)

        #if CIO_SCENE_CONTRACT_SELF_TEST
        if ProcessInfo.processInfo.environment["CIO_SCENE_HANDLER_SELF_TEST"] == "1" {
            precondition(CustomerIOLiveActivitySceneHandler.runContractSelfTest())
            Logger(subsystem: "io.customer.flutter.fixture", category: "scene-lifecycle")
                .notice("customerio-flutter-scene-handler-contract-passed")
        }
        #endif

        #if canImport(CioLocationGeofence)
        // iOS can cold-wake the app for a geofence transition before the Dart runtime
        // starts, so bootstrap here rather than relying on CustomerIO.initialize.
        GeofenceModule.bootstrapForBackgroundDelivery(launchOptions: launchOptions)
        #endif

        // Depending on the method you choose to install Firebase in your app,
        // you may need to add functions to this file, such as the following:
        // FirebaseApp.configure()
        //
        // Be sure to read the official Firebase docs to correctly install Firebase in your app.

        Messaging.messaging().delegate = self
        
        MessagingPushFCM.initialize(
            withConfig: MessagingPushConfigBuilder()
                .appGroupId("group.io.customer.testbed.flutter.cocoapods")
                .build()
        )
        
        // Sets a 3rd party push event handler for the app besides the Customer.io SDK and FlutterFire.
        // Setting the AppDelegate to be the handler will internally use `flutter_local_notifications` to handle the push event.
        UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ application: UIApplication,
                              didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        
        Messaging.messaging().apnsToken = deviceToken
    }
    
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
        // Not needed when CioAppDelegateWrapper is used
//        MessagingPush.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    // IMPORTANT: This method is necessary to have CIO deep linking working!
    // Putting `return false` in the body is sufficient, as this is an indicator for the CIO SDK to forward the link to iOS for processing.
    // This will open the browser or the associated app.
    // If this method is not overriden, default Flutter's deep link processing will just discard CIO deep links.
    override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        super.application(application, continue: userActivity, restorationHandler: restorationHandler)
        return false
    }

    // Reference pattern: report a Live Activity tap so Customer.io attributes an `opened` metric.
    // A tap arrives here through the normal openURL path; the wrapper forwards the URL to the SDK.
    // For a Customer.io widget URL this returns the customer's redirect target to route to (nil
    // when it carries none); any other URL comes back unchanged, so existing deep links still work.
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let routableUrl = CustomerIOLiveActivities.handleWidgetUrl(url) else { return true }
        return super.application(app, open: routableUrl, options: options)
    }
}

extension AppDelegate {
    // Function called when a push notification is clicked or swiped away.
    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Track custom event with Customer.io.
        // NOT required for basic PN tap tracking - that is done automatically with `CioAppDelegateWrapper`.
        CustomerIO.shared.track(
            name: "custom push-clicked event",
            properties: ["push": response.notification.request.content.userInfo]
        )
        
        completionHandler()
    }
    
    // To test sending of local notifications, display the push while app in foreground. So when you press the button to display local push in the app, you are able to see it and click on it.
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
        // Or return empty array if you do not want notifications in foreground
//        completionHandler([])
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Not needed when CioAppDelegateWrapper is used
//        MessagingPush.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }
}
