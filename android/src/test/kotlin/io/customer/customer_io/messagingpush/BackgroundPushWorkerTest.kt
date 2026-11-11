package io.customer.customer_io.messagingpush

import kotlin.test.assertEquals
import org.junit.Test

class BackgroundPushWorkerTest {
    @Test
    fun `work data carries the push to Dart, token included`() {
        val data = mapOf("account" to "refresh", "deliveryId" to "app value", "empty" to "")

        val arguments = BackgroundPushWorker.arguments(
            BackgroundPushWorker.inputData("dlv_1", "tok_1", data),
            handlerHandle = 22L,
        )

        assertEquals(
            mapOf("deliveryId" to "dlv_1", "deliveryToken" to "tok_1", "data" to data, "handlerHandle" to 22L),
            arguments,
        )
    }
}
