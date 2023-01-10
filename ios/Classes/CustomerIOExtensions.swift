import Foundation
import CioTracking

extension Region{
    static func from(regionStr : String) -> Region {
        switch regionStr {
        case "us" :
            return Region.US
        case "eu" :
            return Region.EU
        default:
            return Region.US
        }
    }
}

extension CioLogLevel {
    static func from(for level : String) -> CioLogLevel {
        switch level {
        case "none":
            return .none
        case "error":
            return .error
        case "info":
            return .info
        case "debug":
            return .debug
        default:
            return .error
        }
    }
}

extension String {
    func getEvent() -> Metric? {
        return Metric(rawValue: self.lowercased())
    }
}
