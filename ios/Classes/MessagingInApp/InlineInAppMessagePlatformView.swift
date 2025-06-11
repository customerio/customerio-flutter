import CioInternalCommon
import CioMessagingInApp
import Flutter
import Foundation
import UIKit

class InlineInAppMessagePlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var _inlineView: InlineMessageUIView
    private var methodChannel: FlutterMethodChannel?
    
    private enum Args {
        static let elementId = "elementId"
        static let progressTint = "progressTint"
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
        _inlineView = InlineMessageUIView()
        
        super.init()
        
        // Setup method channel for communication with Flutter
        if let messenger = messenger {
            methodChannel = FlutterMethodChannel(
                name: "customer_io_inline_view_\(viewId)",
                binaryMessenger: messenger
            )
            methodChannel?.setMethodCallHandler(handleMethodCall)
        }
        
        // Configure the inline view
        setupInlineView(with: args)
        
        // Add inline view to container
        _view.addSubview(_inlineView)
        _inlineView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            _inlineView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
            _inlineView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
            _inlineView.topAnchor.constraint(equalTo: _view.topAnchor),
            _inlineView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
        ])
    }
    
    func view() -> UIView {
        return _view
    }
    
    private func setupInlineView(with args: Any?) {
        guard let params = args as? [String: AnyHashable] else { return }
        
        // Use require extension for safe parameter access
        if let elementId: String = params.require(Args.elementId) {
            _inlineView.elementId = elementId
        }
        
        if let progressTint: NSNumber = params.require(Args.progressTint) {
            setProgressTint(progressTint.uint32Value)
        }
        
        // Setup delegate for handling message events
        _inlineView.delegate = self
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setElementId":
            call.native(result: result, transform: { $0 as? String }) { elementId in
                setElementId(elementId)
            }
            
        case "setProgressTint":
            call.native(result: result, transform: { $0 as? NSNumber }) { colorValue in
                setProgressTint(colorValue.uint32Value)
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
        _inlineView.elementId = elementId
    }
    
    private func setProgressTint(_ colorValue: UInt32) {
        // Convert ARGB to UIColor
        let alpha = CGFloat((colorValue >> 24) & 0xFF) / 255.0
        let red = CGFloat((colorValue >> 16) & 0xFF) / 255.0
        let green = CGFloat((colorValue >> 8) & 0xFF) / 255.0
        let blue = CGFloat(colorValue & 0xFF) / 255.0
        
        let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
        
        // InlineMessageUIView doesn't directly expose progress tint
        // Try to access the internal GistInlineMessageUIView if available
        if let internalView = _inlineView.value(forKey: "inAppMessageView") as? UIView,
           internalView.responds(to: Selector(("setProgressTintColor:"))) {
            internalView.setValue(color, forKey: "progressTintColor")
        }
        // Fallback: Set tint color on the main view
        _inlineView.tintColor = color
    }
    
    private func getElementId() -> String? {
        return _inlineView.elementId
    }
    
    private func invokeDartMethod(_ method: String, _ args: Any?) {
        // Thread-safe Flutter communication following the same pattern as CustomerIOInAppMessaging
        DIGraphShared.shared.threadUtil.runMain { [weak self] in
            guard let self else { return }
            self.methodChannel?.invokeMethod(method, arguments: args)
        }
    }
}

// MARK: - InlineMessageUIViewDelegate

extension InlineInAppMessagePlatformView: InlineMessageUIViewDelegate {
    func onActionClick(message: InAppMessage, actionValue: String, actionName: String) {
        // Send action event back to Flutter using consistent parameter constants
        let args: [String: Any] = [
            Args.actionValue: actionValue,
            Args.actionName: actionName,
            Args.messageId: message.messageId ?? "",
            Args.deliveryId: message.deliveryId ?? ""
        ]
        
        invokeDartMethod("onAction", args)
    }
}