package io.customer.customer_io.messaginginapp

import io.customer.messaginginapp.type.ModalPresentation
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.junit.Test

/**
 * Pins the contract between Dart's `ModalPresentationAndroid` and the native [ModalPresentation].
 *
 * The wire values and keys are spelled out here rather than taken from the mapper's constants, so a
 * rename on either side fails these tests instead of silently dropping the option.
 */
class ModalPresentationMapperTest {

    @Test
    fun `maps every wire value Dart can send`() {
        assertEquals(ModalPresentation.ACTIVITY, modalPresentationFrom("ACTIVITY"))
        assertEquals(ModalPresentation.HOST_WINDOW, modalPresentationFrom("HOST_WINDOW"))
    }

    @Test
    fun `returns null for an unrecognized or absent value`() {
        assertNull(modalPresentationFrom("host_window"))
        assertNull(modalPresentationFrom("hostWindow"))
        assertNull(modalPresentationFrom(""))
        assertNull(modalPresentationFrom(null))
    }

    @Test
    fun `reads the value out of the android sub-map of the inApp configuration`() {
        val config = mapOf(
            "siteId" to "site",
            "android" to mapOf("modalPresentation" to "HOST_WINDOW")
        )
        assertEquals("HOST_WINDOW", modalPresentationRawValueFrom(config))
    }

    @Test
    fun `returns null when the app configured no android options`() {
        assertNull(modalPresentationRawValueFrom(mapOf("siteId" to "site")))
        assertNull(modalPresentationRawValueFrom(mapOf("android" to emptyMap<String, Any>())))
    }

    @Test
    fun `ignores a modalPresentation outside the android sub-map`() {
        assertNull(modalPresentationRawValueFrom(mapOf("modalPresentation" to "HOST_WINDOW")))
    }
}
