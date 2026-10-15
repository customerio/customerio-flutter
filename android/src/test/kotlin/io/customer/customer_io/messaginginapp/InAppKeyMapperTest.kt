package io.customer.customer_io.messaginginapp

import io.customer.sdk.data.model.Region
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.Test

class InAppKeyMapperTest {

    @Test
    fun `pk_ key counts as a public key`() {
        assertTrue(hasPublicKey(mapOf("cdpApiKey" to "pk_us_abc")))
        assertTrue(hasPublicKey(mapOf("cdpApiKey" to "pk_eu_abc")))
    }

    @Test
    fun `legacy and sk_ keys do not count as public keys`() {
        assertFalse(hasPublicKey(mapOf("cdpApiKey" to "legacy-key")))
        assertFalse(hasPublicKey(mapOf("cdpApiKey" to "sk_us_abc")))
        assertFalse(hasPublicKey(emptyMap()))
    }

    @Test
    fun `region comes from the pk_ key when the app sets none`() {
        assertEquals(Region.EU, inAppRegionFrom(mapOf("cdpApiKey" to "pk_eu_abc")))
    }

    @Test
    fun `region the app sets wins over the key`() {
        assertEquals(Region.US, inAppRegionFrom(mapOf("cdpApiKey" to "pk_eu_abc", "region" to "us")))
    }

    @Test
    fun `region defaults to US for legacy keys`() {
        assertEquals(Region.US, inAppRegionFrom(mapOf("cdpApiKey" to "legacy-key")))
    }
}
