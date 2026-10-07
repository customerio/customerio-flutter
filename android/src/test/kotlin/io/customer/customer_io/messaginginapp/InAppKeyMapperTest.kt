package io.customer.customer_io.messaginginapp

import io.customer.sdk.data.model.Region
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.Test

class InAppKeyMapperTest {

    @Test
    fun `wk_ key counts as a public key`() {
        assertTrue(hasPublicKey(mapOf("cdpApiKey" to "wk_us_abc")))
        assertTrue(hasPublicKey(mapOf("cdpApiKey" to "wk_eu_abc")))
    }

    @Test
    fun `legacy and ak_ keys do not count as public keys`() {
        assertFalse(hasPublicKey(mapOf("cdpApiKey" to "legacy-key")))
        assertFalse(hasPublicKey(mapOf("cdpApiKey" to "ak_us_abc")))
        assertFalse(hasPublicKey(emptyMap()))
    }

    @Test
    fun `region comes from the wk_ key when the app sets none`() {
        assertEquals(Region.EU, inAppRegionFrom(mapOf("cdpApiKey" to "wk_eu_abc")))
    }

    @Test
    fun `region the app sets wins over the key`() {
        assertEquals(Region.US, inAppRegionFrom(mapOf("cdpApiKey" to "wk_eu_abc", "region" to "us")))
    }

    @Test
    fun `region defaults to US for legacy keys`() {
        assertEquals(Region.US, inAppRegionFrom(mapOf("cdpApiKey" to "legacy-key")))
    }
}
