import CioInternalCommon
import CioMessagingInbox
import Flutter
import Foundation
import SwiftUI
import UIKit

/// Shared channel / method-name constants for the inbox UI platform views.
private enum InboxViewConstants {
    static let viewChannelPrefix = "customer_io_notification_inbox_view_"
    static let bellChannelPrefix = "customer_io_notification_inbox_bell_view_"
}

private enum InboxMethodNames {
    // Bell -> Dart
    static let onTap = "onTap"
}

/// Container that hosts a SwiftUI view for a Flutter platform view.
///
/// Owns the `UIHostingController` and — importantly — adds it to the view-controller hierarchy once
/// the container is in a window. Adopting only a hosting controller's view leaves the controller
/// orphaned, so UIKit has no presentation context or trait/safe-area chain for it: the bell's panel
/// then resolves its sheet insets against the wrong container, which shows up as a phantom top margin
/// while dragging the sheet. Native usage never hits this because there the hosting controller is a
/// real pushed view controller.
private final class HostedContainerView: UIView {
    private let hostingController: UIViewController

    init(frame: CGRect, hostingController: UIViewController) {
        self.hostingController = hostingController
        super.init(frame: frame)

        backgroundColor = .clear
        let hosted = hostingController.view!
        hosted.backgroundColor = .clear
        hosted.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosted)
        NSLayoutConstraint.activate([
            hosted.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosted.topAnchor.constraint(equalTo: topAnchor),
            hosted.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            guard hostingController.parent == nil, let parent = nearestViewController() else { return }
            parent.addChild(hostingController)
            hostingController.didMove(toParent: parent)
        } else if hostingController.parent != nil {
            hostingController.willMove(toParent: nil)
            hostingController.removeFromParent()
        }
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }
}

/// Hosts a SwiftUI view inside a Flutter `UIView` container.
///
/// The inbox SwiftUI components require iOS 15 (Jist floor); on older versions an empty container is
/// returned so the host app does not crash.
private func makeHostedContainer<Content: View>(
    frame: CGRect,
    @ViewBuilder content: () -> Content
) -> UIView {
    guard #available(iOS 15.0, *) else {
        let container = UIView(frame: frame)
        container.backgroundColor = .clear
        return container
    }

    return HostedContainerView(
        frame: frame,
        hostingController: UIHostingController(rootView: content())
    )
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

// MARK: - NotificationInboxBell (bell that opens the SDK's panel)

/// Flutter wrapper for the Visual Notification Inbox bell.
///
/// Hosts the native `NotificationInboxOverlay` composition rather than the bare
/// `NotificationInboxBell`: only the overlay ties the bell to the SDK's own panel, and the wrapper
/// deliberately does not reimplement panel presentation. Sized to the frame Flutter gives it, that
/// composition *is* a bell that opens the inbox.
///
/// Remote branding still styles the bell; branding's bell *position* has no effect, because alignment
/// resolves inside this view's frame and the host owns placement.
///
/// iOS 16+ because the panel is a sheet with system detents; below that the container stays empty.
class NotificationInboxBellPlatformView: NSObject, FlutterPlatformView {
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
                name: "\(InboxViewConstants.bellChannelPrefix)\(viewId)",
                binaryMessenger: messenger
            )
        }

        _view = makeHostedContainer(frame: frame) {
            if #available(iOS 16.0, *) {
                NotificationInboxOverlay()
            }
        }

        super.init()

        // Observational tap reporting. The SDK owns presentation, so the recognizer must not consume
        // the touch: `cancelsTouchesInView = false` leaves the gesture for SwiftUI, which opens the
        // panel. Reports any tap inside this view's frame, which is the bell when the view is sized to
        // it as recommended. The recognizer holds its target weakly; Flutter retains this platform
        // view for the lifetime of the widget.
        let tapObserver = UITapGestureRecognizer(target: self, action: #selector(handleObservedTap))
        tapObserver.cancelsTouchesInView = false
        tapObserver.delaysTouchesEnded = false
        _view.addGestureRecognizer(tapObserver)
    }

    func view() -> UIView {
        return _view
    }

    @objc private func handleObservedTap() {
        invokeDartMethod(methodChannel, InboxMethodNames.onTap, nil)
    }

    deinit {
        methodChannel?.setMethodCallHandler(nil)
    }
}
