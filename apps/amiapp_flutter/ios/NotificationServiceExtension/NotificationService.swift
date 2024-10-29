//
//  NotificationService.swift
//  NotificationServiceExtension
//

import CioMessagingPushFCM

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        print("NotificationService didReceive called")

        // TODO: Fix SDK initialization
        /*
        CustomerIO.initialize(siteId: Env.siteId, apiKey: Env.apiKey, region: .US) { config in
            config.autoTrackDeviceAttributes = true
            config.logLevel = .debug
        }
         */
        
        MessagingPush.shared.didReceive(request, withContentHandler: contentHandler)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        MessagingPush.shared.serviceExtensionTimeWillExpire()
    }
    
}
