import CioInternalCommon
import CioMessagingInApp
import Flutter
import Foundation
import UIKit

/// Constants for inline message platform view implementation
private enum InlineMessageConstants {
    static let defaultAnimationDuration = 200.0
    static let channelNamePrefix = "customer_io_inline_view_"
}

private enum MethodNames {
    static let setElementId = "setElementId"
    static let getElementId = "getElementId"
    static let cleanup = "cleanup"
    static let onAction = "onAction"
    static let onSizeChange = "onSizeChange"
    static let onStateChange = "onStateChange"
}

private enum MessageState {
    static let noMessageToDisplay = "NoMessageToDisplay"
    static let loadingStarted = "LoadingStarted"
    static let loadingFinished = "LoadingFinished"
}

private enum PayloadKeys {
    static let state = "state"
    static let height = "height"
    static let width = "width"
    static let duration = "duration"
}

/// Flutter wrapper for inline message display with InlineMessageBridgeView (same as React Native)
class InlineInAppMessagePlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private let contentView: InlineMessageBridgeView = .init()
    private var methodChannel: FlutterMethodChannel?
    private var lastReportedHeight: CGFloat = 0
    
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
                name: "\(InlineMessageConstants.channelNamePrefix)\(viewId)",
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
        case MethodNames.setElementId:
            call.native(result: result, transform: { $0 as? String }) { elementId in
                setElementId(elementId)
            }
            
        case MethodNames.getElementId:
            call.nativeNoArgs(result: result) {
                getElementId()
            }
            
        case MethodNames.cleanup:
            // dart view makes explicitly call cleanup when view goes away
            call.nativeNoArgs(result: result) {
                cleanup()
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
    
    private func cleanup() {
        contentView.onViewDetached()
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
        
        invokeDartMethod(MethodNames.onAction, args)
        return true
    }
    
    func onMessageSizeChanged(width: CGFloat, height: CGFloat) {
        // Native SDK size change callback - same as React Native receives
        var payload: [String: Any] = [
            PayloadKeys.height: height,
            PayloadKeys.duration: InlineMessageConstants.defaultAnimationDuration
        ]
        
        // Only include positive width values as rendering requires valid width to calculate layout size
        if width > 0 {
            payload[PayloadKeys.width] = width
        }
        
        invokeDartMethod(MethodNames.onSizeChange, payload)
    }
    
    func onNoMessageToDisplay() {
        // Native SDK state change callback - same as React Native receives
        let stateArgs = [PayloadKeys.state: MessageState.noMessageToDisplay]
        invokeDartMethod(MethodNames.onStateChange, stateArgs)
    }
    
    func onStartLoading(onComplete: @escaping () -> Void) {
        let stateArgs = [PayloadKeys.state: MessageState.loadingStarted]
        invokeDartMethod(MethodNames.onStateChange, stateArgs)
        onComplete()
    }
    
    func onFinishLoading() {
        let stateArgs = [PayloadKeys.state: MessageState.loadingFinished]
        invokeDartMethod(MethodNames.onStateChange, stateArgs)
    }
}
