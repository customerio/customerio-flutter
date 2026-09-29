package io.customer.customer_io.messagingpush

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.RejectedExecutionException
import kotlin.test.assertEquals
import org.junit.Test
import org.mockito.Mockito.verifyNoInteractions
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoMoreInteractions

class PushMessageDispatcherTest {
    private val call = MethodCall("onMessageReceived", mapOf("message" to "payload"))
    private val result = mock<MethodChannel.Result>()
    private val worker = mutableListOf<Runnable>()
    private val main = mutableListOf<Runnable>()
    private val dispatcher = PushMessageDispatcher(worker::add, main::add)

    @Test
    fun `dispatch returns the handled result only after background processing`() {
        dispatcher.dispatch(call, result) { args ->
            assertEquals("payload", args["message"])
            true
        }

        verifyNoInteractions(result)
        worker.single().run()
        verifyNoInteractions(result)
        main.single().run()

        verify(result).success(true)
        verifyNoMoreInteractions(result)
    }

    @Test
    fun `dispatch posts handler failure as one error`() {
        dispatcher.dispatch(call, result) { throw IllegalStateException("boom") }

        worker.single().run()
        main.single().run()

        verify(result).error(eq("onMessageReceived"), eq("boom"), any())
        verifyNoMoreInteractions(result)
    }

    @Test
    fun `dispatch reports a rejected worker without losing the result`() {
        val closed = PushMessageDispatcher(
            { throw RejectedExecutionException("closed") },
            main::add,
        )

        closed.dispatch(call, result) { true }

        verify(result).error(eq("onMessageReceived"), eq("closed"), any())
        verifyNoMoreInteractions(result)
    }

    @Test
    fun `dispatch does not reply to a detached Flutter engine`() {
        dispatcher.dispatch(call, result) { true }
        worker.single().run()
        dispatcher.close()

        main.single().run()

        verifyNoInteractions(result)
    }
}
