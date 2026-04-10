import Flutter

extension FlutterMethodCall {
    /// Handles native method call with argument transformation and response handling.
    ///
    /// - Parameters:
    ///   - result: `FlutterResult` to send the response back to Flutter.
    ///   - transform: Closure to transform the method arguments.
    ///   - handler: Closure to process the transformed arguments and return a result.
    func native<Arguments, Result>(
        result: FlutterResult,
        transform: (Any?) throws -> Arguments,
        handler: (Arguments) throws -> Result
    ) {
        do {
            let args: Arguments
            do {
                args = try transform(arguments)
            } catch {
                result(FlutterError(code: method, message: "params not available", details: nil))
                return
            }

            let response = try handler(args)
            if response is Void {
                // If the result is Unit, then return true to the Flutter side
                // As returning Void may throw an error on the Flutter side
                result(true)
            } else {
                result(response)
            }
        } catch {
            // Handle exceptions and send error to Flutter
            result(FlutterError(code: method, message: "Unexpected error: \(error).", details: nil))
        }
    }

    /// Handles native method call with no arguments.
    ///
    /// - Parameters:
    ///   - result: `FlutterResult` to send the response back to Flutter.
    ///   - handler: Closure to process the call and return a result.
    func nativeNoArgs<Result>(
        result: FlutterResult,
        handler: () throws -> Result
    ) {
        native(result: result, transform: { _ in () }) { _ in try handler() }
    }

    /// Handles native method call with map arguments.
    ///
    /// - Parameters:
    ///   - result: `FlutterResult` to send the response back to Flutter.
    ///   - handler: Closure to process the map arguments and return a result.
    func nativeMapArgs<Result>(
        result: FlutterResult,
        handler: ([String: AnyHashable]) throws -> Result
    ) {
        native(result: result, transform: {
            $0 as? [String: AnyHashable] ?? [:]
        }, handler: handler)
    }
}
