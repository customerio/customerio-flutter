package io.customer.customer_io.messaginginapp

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory for creating InlineInAppMessagePlatformView instances.
 * This factory is registered with Flutter to create platform views for inline in-app messages.
 */
class InlineInAppMessageViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String, Any?>?
        return InlineInAppMessagePlatformView(context, viewId, creationParams, messenger)
    }
}