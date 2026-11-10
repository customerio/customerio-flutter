package io.customer.customer_io.messagingpush

import android.content.Context
import io.customer.sdk.core.di.SDKComponent
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * A Flutter engine of the plugin's own that runs Dart silent push handlers when no app isolate
 * registered one, the way `firebase_messaging` runs `onBackgroundMessage`. It starts on the first
 * push and lasts as long as the process. Main thread only.
 */
internal object BackgroundPushIsolate {
    private var channel: MethodChannel? = null

    /** Returns null when the stored dispatcher isn't in this build of the app. */
    fun channel(context: Context, dispatcherHandle: Long): MethodChannel? {
        channel?.let { return it }

        val engine = FlutterEngine(context)
        val dispatcher = FlutterCallbackInformation.lookupCallbackInformation(dispatcherHandle)
        if (dispatcher == null) {
            SDKComponent.logger.error("Flutter silent push dispatcher not found. Call setBackgroundPushHandler from the app again.")
            engine.destroy()
            return null
        }
        engine.dartExecutor.executeDartCallback(
            DartExecutor.DartCallback(context.assets, FlutterInjector.instance().flutterLoader().findAppBundlePath(), dispatcher),
        )
        // Pushes sent while Dart starts wait in the channel buffer until the dispatcher listens.
        return MethodChannel(engine.dartExecutor, "customer_io_messaging_push_background")
            .also {
                it.resizeChannelBuffer(10)
                channel = it
            }
    }
}
