package io.customer.customer_io.messagingpush

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.customer.messagingpush.data.communication.CustomerIOBackgroundPushCallback
import io.customer.messagingpush.data.model.CustomerIOBackgroundPushPayload
import io.customer.sdk.core.di.SDKComponent
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resume
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/**
 * The native SDK's silent push callback for Flutter apps, installed by [BackgroundPushInitProvider].
 * Firebase gives the callback only a short time, so it queues a job that runs the Dart handler.
 */
internal object FlutterBackgroundPushCallback : CustomerIOBackgroundPushCallback {
    override fun onBackgroundPushReceived(context: Context, payload: CustomerIOBackgroundPushPayload) {
        if (BackgroundPushHandles.read(context) == null) return

        val request = OneTimeWorkRequestBuilder<BackgroundPushWorker>()
            .setInputData(BackgroundPushWorker.inputData(payload.deliveryId, payload.deliveryToken, payload.data))
            .build()
        // Keyed like the SDK's Delivered job, so a copy that arrives while one waits or runs is dropped.
        WorkManager.getInstance(context)
            .enqueueUniqueWork("cio-background-push-${payload.deliveryId}", ExistingWorkPolicy.KEEP, request)
    }
}

/**
 * Runs the Dart handler for one silent push, on the app's isolate if its Dart code registered the
 * handler and is running, otherwise on [BackgroundPushIsolate]. The job lasts until the handler
 * finishes, and WorkManager runs it again if the process dies first.
 */
internal class BackgroundPushWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        // The app may have cleared its handler while the job waited.
        val handles = BackgroundPushHandles.read(applicationContext) ?: return Result.success()

        return withContext(Dispatchers.Main) {
            val mainIsolate = CustomerIOPushMessaging.mainIsolate
            val channel = mainIsolate?.flutterCommunicationChannel
                ?: BackgroundPushIsolate.channel(applicationContext, handles.dispatcherHandle)
                ?: return@withContext Result.success()
            suspendCancellableCoroutine { continuation ->
                val finish = { result: Result -> if (continuation.isActive) continuation.resume(result) }
                // Runs the push again if the app's engine goes away before its handler answers.
                val retry = { finish(Result.retry()) }
                mainIsolate?.onDetach?.add(retry)
                val arguments = arguments(inputData, handles.handlerHandle)
                channel.invokeMethod("onBackgroundPushReceived", arguments, object : MethodChannel.Result {
                    override fun success(result: Any?) = done(Result.success())

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        SDKComponent.logger.error("Flutter silent push handler failed: $errorMessage")
                        done(Result.success())
                    }

                    // No Dart handler took it, for example when more pushes arrived than the channel
                    // buffers while Dart started.
                    override fun notImplemented() = done(Result.retry())

                    private fun done(result: Result) {
                        mainIsolate?.onDetach?.remove(retry)
                        finish(result)
                    }
                })
            }
        }
    }

    companion object {
        private const val DELIVERY_ID = "deliveryId"
        private const val DELIVERY_TOKEN = "deliveryToken"
        private const val DATA_PREFIX = "data."

        fun inputData(deliveryId: String, deliveryToken: String, data: Map<String, String>): Data =
            Data.Builder()
                .putAll(data.mapKeys { DATA_PREFIX + it.key })
                .putString(DELIVERY_ID, deliveryId)
                .putString(DELIVERY_TOKEN, deliveryToken)
                .build()

        /** What the Dart side receives. The background isolate finds the handler by its handle. */
        fun arguments(inputData: Data, handlerHandle: Long): Map<String, Any?> = mapOf(
            DELIVERY_ID to inputData.getString(DELIVERY_ID),
            DELIVERY_TOKEN to inputData.getString(DELIVERY_TOKEN),
            "data" to inputData.keyValueMap
                .filterKeys { it.startsWith(DATA_PREFIX) }
                .mapKeys { it.key.removePrefix(DATA_PREFIX) },
            "handlerHandle" to handlerHandle,
        )
    }
}

/** Callback handles the app registered from Dart, kept for pushes that start the process. */
internal data class BackgroundPushHandles(val dispatcherHandle: Long, val handlerHandle: Long) {
    fun save(context: Context) {
        preferences(context).edit()
            .putLong(DISPATCHER_HANDLE, dispatcherHandle)
            .putLong(HANDLER_HANDLE, handlerHandle)
            .apply()
    }

    companion object {
        private const val DISPATCHER_HANDLE = "dispatcher_handle"
        private const val HANDLER_HANDLE = "handler_handle"

        fun read(context: Context): BackgroundPushHandles? {
            val preferences = preferences(context)
            if (!preferences.contains(HANDLER_HANDLE)) return null
            return BackgroundPushHandles(
                preferences.getLong(DISPATCHER_HANDLE, 0),
                preferences.getLong(HANDLER_HANDLE, 0),
            )
        }

        fun clear(context: Context) {
            preferences(context).edit().clear().apply()
        }

        private fun preferences(context: Context) = context.applicationContext
            .getSharedPreferences("io.customer.customer_io.background_push", Context.MODE_PRIVATE)
    }
}
