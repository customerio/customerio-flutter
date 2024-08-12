import UIKit
import Flutter
import CioMessagingPushFCM
import CioTracking
import FirebaseMessaging
import FirebaseCore

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Depending on the method you choose to install Firebase in your app, 
        // you may need to add functions to this file, such as the following:
        // FirebaseApp.configure()
        // 
        // Be sure to read the official Firebase docs to correctly install Firebase in your app. 

        Messaging.messaging().delegate = self
        
        CustomerIO.initialize(siteId: Env.siteId, apiKey: Env.apiKey, region: .US) { config in
            config.autoTrackDeviceAttributes = true
            config.logLevel = .debug
        }
        MessagingPushFCM.initialize(configOptions: nil)
        
        // Sets a 3rd party push event handler for the app besides the Customer.io SDK and FlutterFire.
        // Setting the AppDelegate to be the handler will internally use `flutter_local_notifications` to handle the push event.
        UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Called when app receives a APN device token.
    // The Customer.io SDK automatically gets called when the token is received, no need to pass it to the SDK from this function.
    // To test that the Customer.io SDK is compatible with 3rd party SDKs, we expect that this function is called in case the customer needs the APN token for other purposes.
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        
        CustomerIO.shared.track(name: "APN token received from AppDelegate", data: [
            "token": deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        ])
    }
}

extension AppDelegate: MessagingDelegate {
    // Called when app receives a FCM device token.
    // The Customer.io SDK automatically gets called when the token is received, no need to pass it to the SDK from this function.
    // To test that the Customer.io SDK is compatible with 3rd party SDKs, we expect that this function is called in case the customer needs the FCM token for other purposes.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        CustomerIO.shared.track(name: "FCM token received from AppDelegate", data: [
            "token": fcmToken ?? "nil"
        ])
    }
}
