import CioInternalCommon

extension Dictionary where Key == String, Value == AnyHashable {
    /// Retrieves a value from dictionary for given key and casts it to given type.
    ///
    /// - Parameters:
    ///   - key: Key to look up in the dictionary.
    ///   - onFailure: An optional closure executed if the key is missing or the value cannot be cast.
    ///     Defaults to `nil`, in which case no additional action is taken.
    /// - Returns: The value associated with the key, cast to given type, or `nil` if the key is missing or the cast fails.
    func require<T>(_ key: String, onFailure: (() -> Void)? = nil) -> T? {
        guard let value = self[key] as? T else {
            // Using if-else for increased readability
            if let onFailure = onFailure {
                onFailure()
            } else {
                DIGraphShared.shared.logger.error("Missing or invalid value for key: \(key) in: \(self)")
            }
            return nil
        }
        return value
    }
}
