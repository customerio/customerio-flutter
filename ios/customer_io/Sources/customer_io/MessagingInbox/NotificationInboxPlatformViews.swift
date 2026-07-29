import CioInternalCommon
import Flutter
import CioMessagingInbox
import Foundation
import SwiftUI
import UIKit

/// Shared channel / method-name constants for the inbox UI platform views.
private enum InboxViewConstants {
    static let viewChannelPrefix = "customer_io_notification_inbox_view_"
    // The overlay has no channel: it owns panel presentation natively and reports nothing to Dart.
    static let bellChannelPrefix = "customer_io_notification_inbox_bell_view_"
}

private enum InboxMethodNames {
    // Bell -> Dart
    static let onTap = "onTap"
}

/// Helper to host a SwiftUI view inside a Flutter `UIView` container.
/// SwiftUI inbox components require iOS 15 (Jist floor); on older OS versions
/// we render an empty container so the host app does not crash.
private func makeHostedContainer<Content: View>(
    frame: CGRect,
    @ViewBuilder content: () -> Content
) -> UIView {
    let container = UIView(frame: frame)
    container.backgroundColor = .clear

    if #available(iOS 15.0, *) {
        let hosting = UIHostingController(rootView: content())
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        // Retain the hosting controller for the lifetime of the container so SwiftUI
        // continues to drive updates. Associated object keeps it alive without a stored property.
        objc_setAssociatedObject(container, &AssociatedKeys.hostingController, hosting, .OBJC_ASSOCIATION_RETAIN)
    }

    return container
}

private enum AssociatedKeys {
    static var hostingController = "cio_inbox_hosting_controller"
}

private func invokeDartMethod(_ channel: FlutterMethodChannel?, _ method: String, _ args: Any?) {
    DIGraphShared.shared.threadUtil.runMain {
        channel?.invokeMethod(method, arguments: args)
    }
}

// MARK: - NotificationInboxView (message list)

/// Flutter wrapper for the standalone `NotificationInboxView` (Jist-rendered list).
class NotificationInboxPlatformView: NSObject, FlutterPlatformView {
    private let _view: UIView
    private var methodChannel: FlutterMethodChannel?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments _: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        if let messenger = messenger {
            methodChannel = FlutterMethodChannel(
                name: "\(InboxViewConstants.viewChannelPrefix)\(viewId)",
                binaryMessenger: messenger
            )
        }

        _view = makeHostedContainer(frame: frame) {
            NotificationInboxView()
        }

        super.init()
    }

    func view() -> UIView {
        return _view
    }

    deinit {
        methodChannel?.setMethodCallHandler(nil)
    }
}

// MARK: - NotificationInboxOverlay (bell + slide-out panel)

/// Flutter wrapper for the drop-in `NotificationInboxOverlay`.
///
/// No method channel: the native overlay owns panel presentation itself, so nothing flows back to
/// Dart. iOS 16+ because that presentation uses a sheet with system detents; below it the container
/// stays empty (the bell and list components have no such floor).
class NotificationInboxOverlayPlatformView: NSObject, FlutterPlatformView {
    private let _view: UIView

    init(
        frame: CGRect,
        viewIdentifier _: Int64,
        arguments _: Any?,
        binaryMessenger _: FlutterBinaryMessenger?
    ) {
        _view = makeHostedContainer(frame: frame) {
            if #available(iOS 16.0, *) {
                NotificationInboxOverlay()
            }
        }

        super.init()
    }

    func view() -> UIView {
        return _view
    }
}

// MARK: - NotificationInboxBell (bell only)

/// Flutter wrapper for the standalone `NotificationInboxBell`.
/// Surfaces taps back to Dart over the per-view channel.
class NotificationInboxBellPlatformView: NSObject, FlutterPlatformView {
    private let _view: UIView
    private var methodChannel: FlutterMethodChannel?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments _: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        let channel: FlutterMethodChannel?
        if let messenger = messenger {
            channel = FlutterMethodChannel(
                name: "\(InboxViewConstants.bellChannelPrefix)\(viewId)",
                binaryMessenger: messenger
            )
        } else {
            channel = nil
        }
        methodChannel = channel

        _view = makeHostedContainer(frame: frame) {
            NotificationInboxBell(onTap: {
                invokeDartMethod(channel, InboxMethodNames.onTap, nil)
            })
        }

        super.init()
    }

    func view() -> UIView {
        return _view
    }

    deinit {
        methodChannel?.setMethodCallHandler(nil)
    }
}
