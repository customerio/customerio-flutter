package io.customer.customer_io.messagingpush

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.RejectedExecutionException

/** Keeps push processing off Flutter's platform thread while preserving its result contract. */
internal class PushMessageDispatcher(
    private val execute: (Runnable) -> Unit,
    private val postToMain: (Runnable) -> Unit,
) {
    @Volatile private var active = true

    fun close() {
        active = false
    }

    @Suppress("UNCHECKED_CAST")
    fun dispatch(
        call: MethodCall,
        result: MethodChannel.Result,
        handler: (Map<String, Any>) -> Boolean,
    ) {
        if (!active) return
        try {
            execute(Runnable {
                val outcome = runCatching {
                    handler(call.arguments as? Map<String, Any> ?: emptyMap())
                }
                postToMain(Runnable {
                    if (active) {
                        outcome.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error(call.method, it.localizedMessage, it) },
                        )
                    }
                })
            })
        } catch (e: RejectedExecutionException) {
            if (active) result.error(call.method, e.localizedMessage, e)
        }
    }
}
