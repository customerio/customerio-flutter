import CioDataPipelines
import CioInternalCommon
import CioMessagingInApp

enum SDKConfigBuilderError: Error {
    case missingCdpApiKey
}

extension SDKConfigBuilder {
    private enum Config: String {
        case migrationSiteId
        case cdpApiKey
        case region
        case logLevel
        case autoTrackDeviceAttributes
        case trackApplicationLifecycleEvents
        case flushAt
        case flushInterval
        case apiHost
        case cdnHost
    }

    @available(iOSApplicationExtension, unavailable)
    static func create(from config: [String: Any?]) throws -> SDKConfigBuilder {
        guard let cdpApiKey = config[Config.cdpApiKey.rawValue] as? String else {
            throw SDKConfigBuilderError.missingCdpApiKey
        }

        let builder = SDKConfigBuilder(cdpApiKey: cdpApiKey)
        Config.migrationSiteId.ifNotNil(in: config, thenPassItTo: builder.migrationSiteId)
        Config.region.ifNotNil(in: config, thenPassItTo: builder.region, transformingBy: Region.getRegion)
        Config.logLevel.ifNotNil(in: config, thenPassItTo: builder.logLevel, transformingBy: CioLogLevel.getLogLevel)
        Config.autoTrackDeviceAttributes.ifNotNil(in: config, thenPassItTo: builder.autoTrackDeviceAttributes)
        Config.trackApplicationLifecycleEvents.ifNotNil(in: config, thenPassItTo: builder.trackApplicationLifecycleEvents)
        Config.flushAt.ifNotNil(in: config, thenPassItTo: builder.flushAt) { (value: NSNumber) in value.intValue }
        Config.flushInterval.ifNotNil(in: config, thenPassItTo: builder.flushInterval) { (value: NSNumber) in value.doubleValue }
        Config.apiHost.ifNotNil(in: config, thenPassItTo: builder.apiHost)
        Config.cdnHost.ifNotNil(in: config, thenPassItTo: builder.cdnHost)

        return builder
    }
}

extension RawRepresentable where RawValue == String {
    func ifNotNil<Raw>(
        in config: [String: Any?]?,
        thenPassItTo handler: (Raw) -> Any
    ) {
        ifNotNil(in: config, thenPassItTo: handler) { $0 }
    }

    func ifNotNil<Raw, Transformed>(
        in config: [String: Any?]?,
        thenPassItTo handler: (Transformed) -> Any,
        transformingBy transform: (Raw) -> Transformed?
    ) {
        if let value = config?[self.rawValue] as? Raw, let result = transform(value) {
            _ = handler(result)
        }
    }
}
