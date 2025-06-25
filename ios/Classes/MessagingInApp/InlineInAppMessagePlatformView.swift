import CioInternalCommon
import CioMessagingInApp
import Flutter
import Foundation
import UIKit

/// Flutter wrapper for inline message display with InlineMessageBridgeView (same as React Native)
class InlineInAppMessagePlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private let contentView: InlineMessageBridgeView = .init()
    private var methodChannel: FlutterMethodChannel?
    
    private enum Args {
        static let elementId = "elementId"
        static let actionValue = "actionValue"
        static let actionName = "actionName"
        static let messageId = "messageId"
        static let deliveryId = "deliveryId"
    }
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _view = UIView(frame: frame)
        
        super.init()
        
        // Setup method channel for communication with Flutter
        if let messenger = messenger {
            methodChannel = FlutterMethodChannel(
                name: "customer_io_inline_view_\(viewId)",
                binaryMessenger: messenger
            )
            methodChannel?.setMethodCallHandler(handleMethodCall)
        }
        
        // Attach content view to container and set delegate (same as React Native)
        contentView.attachToParent(parent: _view, delegate: self)
        
        // Set initial element ID from creation params
        if let params = args as? [String: AnyHashable],
           let elementId = params[Args.elementId] as? String {
            contentView.elementId = elementId
        }
        
        // Setup for use (same as React Native)
        contentView.onViewAttached()
    }
    
    func view() -> UIView {
        return _view
    }
    
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setElementId":
            call.native(result: result, transform: { $0 as? String }) { elementId in
                setElementId(elementId)
            }
            
        case "getElementId":
            call.nativeNoArgs(result: result) {
                getElementId()
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func setElementId(_ elementId: String?) {
        contentView.elementId = elementId
    }
    
    private func getElementId() -> String? {
        return contentView.elementId
    }
    
    private func invokeDartMethod(_ method: String, _ args: Any?) {
        // Thread-safe Flutter communication following the same pattern as CustomerIOInAppMessaging
        DIGraphShared.shared.threadUtil.runMain { [weak self] in
            guard let self else { return }
            self.methodChannel?.invokeMethod(method, arguments: args)
        }
    }
    
    deinit {
        contentView.onViewDetached()
    }
    
}

// MARK: - InlineMessageBridgeViewDelegate (Same as React Native)

extension InlineInAppMessagePlatformView: InlineMessageBridgeViewDelegate {
    func onActionClick(message: InAppMessage, actionValue: String, actionName: String) -> Bool {
        // Send widget-specific action callbacks to Flutter
        let args: [String: Any] = [
            Args.actionValue: actionValue,
            Args.actionName: actionName,
            Args.messageId: message.messageId as Any,
            Args.deliveryId: message.deliveryId as Any
        ]
        
        invokeDartMethod("onAction", args)
        return true
    }
    
    func onMessageSizeChanged(width: CGFloat, height: CGFloat) {
        // Native SDK size change callback - same as React Native receives
        let duration = 300.0
        var payload: [String: Any] = [
            "height": height,
            "duration": duration
        ]
        
        // Only include positive width values as rendering requires valid width to calculate layout size
        if width > 0 {
            payload["width"] = width
        }
        
        invokeDartMethod("onSizeChange", payload)
    }
    
    func onNoMessageToDisplay() {
        // Native SDK state change callback - same as React Native receives
        let stateArgs = ["state": "NoMessageToDisplay"]
        invokeDartMethod("onStateChange", stateArgs)
    }
    
    func onStartLoading(onComplete: @escaping () -> Void) {
        let stateArgs = ["state": "LoadingStarted"]
        invokeDartMethod("onStateChange", stateArgs)
        onComplete()
    }
    
    func onFinishLoading() {
        let stateArgs = ["state": "LoadingFinished"]
        invokeDartMethod("onStateChange", stateArgs)
    }
}


