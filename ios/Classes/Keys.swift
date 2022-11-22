//
//  Keys.swift
//  customer_io
//
//  Created by ShahrozAli on 11/11/22.
//

import Foundation

struct Keys {
    
    struct Tracking {
        static let identifier = "identifier"
        static let attributes = "attributes"
        static let eventName = "eventName"
    }
    
    struct Environment{
        static let siteId = "siteId"
        static let apiKey = "apiKey"
        static let region = "region"
        static let organizationId = "organizationId"
    }
    
    struct Config{
        static let trackingApiUrl = "trackingApiUrl"
        static let autoTrackDeviceAttributes = "autoTrackDeviceAttributes"
        static let logLevel = "logLevel"
        static let autoTrackPushEvents = "autoTrackPushEvents"
        static let backgroundQueueMinNumberOfTasks = "backgroundQueueMinNumberOfTasks"
        static let backgroundQueueSecondsDelay = "backgroundQueueSecondsDelay"
    }
    
    struct PackageConfig{
        static let version = "version"
        static let sdkVersion = "sdkVersion"
    }
}
