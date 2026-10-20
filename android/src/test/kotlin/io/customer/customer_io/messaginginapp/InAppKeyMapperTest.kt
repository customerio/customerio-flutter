package io.customer.customer_io.messaginginapp

import io.customer.sdk.data.model.Region
import kotlin.test.assertEquals
import org.junit.Test

class InAppKeyMapperTest {

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
