package io.customer.customer_io.messaginginapp

import android.content.Context
import io.customer.messaginginapp.ui.InlineInAppMessageView
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

class InlineInAppMessageViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val view = InlineInAppMessageView(context)
        val params = args as? Map<String, Any>
        val elementId = params?.get("elementId") as? String
        view.elementId = elementId
        return object : PlatformView {
            override fun getView() = view
            override fun dispose() {}
        }
    }
} 