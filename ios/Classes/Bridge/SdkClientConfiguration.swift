import CioInternalCommon

/// Extension on `SdkClient` to provide configuration functionality.
///
/// **Note**: Due to Swift limitations with static methods in protocol extensions, static functions
/// in this extension should be called using `CustomerIOSdkClient.` to ensure correct behavior.
extension SdkClient {
    
    /// Configures and overrides the shared `SdkClient` instance with provided parameters.
    ///
    /// - Parameters:
    ///  - using: Dictionary containing values required for `SdkClient` protocol.
    /// - Returns: Configured `SdkClient` instance. Returns the existing shared client if required parameters are missing.
    @available(iOSApplicationExtension, unavailable)
    @discardableResult
    static func configure(using args: [String: Any?]) -> SdkClient {
        guard let source = args["source"] as? String,
              let version = args["version"] as? String
        else {
            DIGraphShared.shared.logger.error("Missing required parameters for SdkClient configuration in args: \(args)")
            return DIGraphShared.shared.sdkClient
        }

        let client = CustomerIOSdkClient(source: source, sdkVersion: version)
        DIGraphShared.shared.override(value: client, forType: SdkClient.self)
        
        return DIGraphShared.shared.sdkClient
    }
}
