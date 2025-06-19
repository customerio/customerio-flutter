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
        
        // Add inline view to container
        _view.addSubview(_inlineView)
        _inlineView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            _inlineView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
            _inlineView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
            _inlineView.topAnchor.constraint(equalTo: _view.topAnchor),
            _inlineView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
        ])
        
        // Setup auto-resizing
        setupAutoResizing()
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
    
    private func setupAutoResizing() {
        // Add observer for view bounds changes
        _inlineView.addObserver(self, forKeyPath: "bounds", options: [.new, .old], context: nil)
        
        // Trigger initial height calculation
        DispatchQueue.main.async { [weak self] in
            self?.checkAndReportHeightChange()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds", let _ = object as? InlineMessageUIView {
            checkAndReportHeightChange()
        }
    }
    
    private func checkAndReportHeightChange() {
        let currentHeight = _inlineView.bounds.height
        
        // Only notify Flutter if the height has actually changed and is greater than 0
        if currentHeight != lastReportedHeight && currentHeight > 0 {
            lastReportedHeight = currentHeight
            
            // Notify Flutter about the size change (consistent with Android)
            let args: [String: Any] = [
                "height": currentHeight,
                "duration": 200.0
            ]
            
            invokeDartMethod("onSizeChange", args)
        }
    }
    
    deinit {
        // Remove observer to prevent crashes
        _inlineView.removeObserver(self, forKeyPath: "bounds")
    }
}

// MARK: - InlineMessageUIViewDelegate

extension InlineInAppMessagePlatformView: InlineMessageUIViewDelegate {
    func onActionClick(message: InAppMessage, actionValue: String, actionName: String) {
        // Send action event back to Flutter using consistent parameter constants
        let args: [String: Any] = [
            Args.actionValue: actionValue,
            Args.actionName: actionName,
            Args.messageId: message.messageId as Any,
            Args.deliveryId: message.deliveryId as Any
        ]
        
        invokeDartMethod("onAction", args)
    }
}