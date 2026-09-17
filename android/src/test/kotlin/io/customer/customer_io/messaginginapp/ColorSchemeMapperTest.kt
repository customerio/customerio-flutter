package io.customer.customer_io.messaginginapp

import io.customer.messaginginapp.type.ColorScheme
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.junit.Test

/**
 * Pins the contract between Dart's `CioColorScheme` and the native [ColorScheme].
 *
 * The wire values are spelled out here rather than taken from the mapper's own constants on
 * purpose: these tests exist to pin the agreement with Dart, and reusing the constants would keep
 * them green through a rename that stops the override from arriving. The failure mode is silent —
 * an unmapped value renders whichever variant the device asks for, so the message looks styled
 * rather than broken.
 */
class ColorSchemeMapperTest {

    @Test
    fun `maps every wire value Dart can send`() {
        assertEquals(ColorScheme.AUTO, colorSchemeFrom("auto"))
        assertEquals(ColorScheme.LIGHT, colorSchemeFrom("light"))
        assertEquals(ColorScheme.DARK, colorSchemeFrom("dark"))
    }

    @Test
    fun `returns null when the app configured no scheme`() {
        assertNull(colorSchemeFrom(mapOf("siteId" to "site")))
    }

    @Test
    fun `reads the scheme out of the inApp configuration`() {
        assertEquals(
            ColorScheme.DARK,
            colorSchemeFrom(mapOf("siteId" to "site", "colorScheme" to "dark"))
        )
    }

    @Test
    fun `returns null rather than AUTO for an unrecognized value`() {
        // Null is what lets the caller leave the current scheme alone and log. Falling back to
        // AUTO here would quietly undo a scheme the app had set correctly earlier.
        assertNull(colorSchemeFrom("DARK"))
        assertNull(colorSchemeFrom("system"))
        assertNull(colorSchemeFrom(""))
    }

    @Test
    fun `returns null for an absent value`() {
        assertNull(colorSchemeFrom(null as String?))
    }
}
