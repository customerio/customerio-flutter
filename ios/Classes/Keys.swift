import Foundation

// TODO: Cleanup this file later when all commented methods are implemented
struct Keys {
    
    struct Methods{
        static let initialize = "initialize"
        static let identify = "identify"
        static let clearIdentify = "clearIdentify"
        static let track = "track"
        static let screen = "screen"
        static let setDeviceAttributes = "setDeviceAttributes"
        static let setProfileAttributes = "setProfileAttributes"
        static let registerDeviceToken = "registerDeviceToken"
        static let trackMetric = "trackMetric"
        static let dismissMessage = "dismissMessage"
    }
    
    struct Tracking {
        static let userId = "userId"
        static let traits = "traits"
        static let eventName = "eventName"
        static let token = "token"
        static let deliveryId = "deliveryId"
        static let deliveryToken = "deliveryToken"
        static let metricEvent = "metricEvent"
        
        static let name = "name"
        static let properties = "properties"
    }
    
    struct Environment{
        static let siteId = "siteId"
        static let apiKey = "apiKey"
        static let region = "region"
        static let enableInApp = "enableInApp"
    }
    
}
