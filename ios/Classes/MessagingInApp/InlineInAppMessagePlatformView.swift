import CioInternalCommon
import CioMessagingInApp
import Flutter
import Foundation
import UIKit

class InlineInAppMessagePlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var _inlineView: InlineMessageUIView
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
        let elementId = (args as? [String: AnyHashable])?.require(Args.elementId) ?? ""
        _inlineView = InlineMessageUIView(elementId: elementId)
        
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
        
        // Set this platform view as the delegate to receive action callbacks
        _inlineView.onActionDelegate = self
        
        // Add inline view to container
        _view.addSubview(_inlineView)
        _inlineView.translatesAutoresizingMaskIntoConstraints = false
        
        // Use priority-based constraints to avoid conflicts with Flutter's layout
        let topConstraint = _inlineView.topAnchor.constraint(equalTo: _view.topAnchor)
        let leadingConstraint = _inlineView.leadingAnchor.constraint(equalTo: _view.leadingAnchor)
        let trailingConstraint = _inlineView.trailingAnchor.constraint(equalTo: _view.trailingAnchor)
        let bottomConstraint = _inlineView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
        
        // Lower priority to avoid conflicts with intrinsic content size
        bottomConstraint.priority = UILayoutPriority(999)
        
        NSLayoutConstraint.activate([
            topConstraint,
            leadingConstraint, 
            trailingConstraint,
            bottomConstraint
        ])
        
        // Setup size observer for Flutter callbacks
        setupSizeObserver()
        
        // Trigger Customer.io element ID registration
        DispatchQueue.main.async { [weak self] in
            self?.triggerElementIdRegistration()
        }
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
        _inlineView.elementId = elementId
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
    
    private func setupSizeObserver() {
        // Add observer for view bounds changes to send size callbacks to Flutter
        _inlineView.addObserver(self, forKeyPath: "bounds", options: [.new, .old], context: nil)
        
        // Initial check
        DispatchQueue.main.async { [weak self] in
            self?.handleSizeChange()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds", let _ = object as? InlineMessageUIView {
            handleSizeChange()
        }
    }
    
    private func handleSizeChange() {
        let currentHeight = _inlineView.bounds.height
        let currentWidth = _inlineView.bounds.width
        
        // Only send updates when height actually changes
        if currentHeight != lastReportedHeight {
            lastReportedHeight = currentHeight
            
            if currentHeight > 0 {
                // Message is displayed - send state and size
                let stateArgs = ["state": "LoadingFinished"]
                invokeDartMethod("onStateChange", stateArgs)
                
                let sizeArgs: [String: Any] = [
                    "height": currentHeight,
                    "width": currentWidth,
                    "duration": 200.0
                ]
                invokeDartMethod("onSizeChange", sizeArgs)
            } else {
                // Height is 0 - no message
                let stateArgs = ["state": "NoMessageToDisplay"]
                invokeDartMethod("onStateChange", stateArgs)
                
                let sizeArgs: [String: Any] = [
                    "height": 0.0,
                    "duration": 200.0
                ]
                invokeDartMethod("onSizeChange", sizeArgs)
            }
        }
    }
    
    private func triggerElementIdRegistration() {
        // Reset elementId to trigger Customer.io registration
        let currentElementId = _inlineView.elementId
        if let elementId = currentElementId {
            _inlineView.elementId = nil
            _inlineView.elementId = elementId
        }
    }
    
    deinit {
        _inlineView.removeObserver(self, forKeyPath: "bounds")
    }
    
}

// MARK: - InlineMessageUIViewDelegate

extension InlineInAppMessagePlatformView: InlineMessageUIViewDelegate {
    func onActionClick(message: InAppMessage, actionValue: String, actionName: String) {
        // Send widget-specific action callbacks to Flutter
        let args: [String: Any] = [
            Args.actionValue: actionValue,
            Args.actionName: actionName,
            Args.messageId: message.messageId as Any,
            Args.deliveryId: message.deliveryId as Any
        ]
        
        invokeDartMethod("onAction", args)
    }
}

