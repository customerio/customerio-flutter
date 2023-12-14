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
        
        Messaging.messaging().delegate = self
        
        CustomerIO.initialize(siteId: Env.siteId, apiKey: Env.apiKey, region: .US) { config in
            config.autoTrackDeviceAttributes = true
            config.logLevel = .debug
        }
        MessagingPushFCM.initialize(configOptions: nil)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func application(application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().setAPNSToken(deviceToken, type: .unknown);
    }
    
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        MessagingPush.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        MessagingPush.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }
}
