package io.customer.customer_io.messaginginapp

import io.customer.customer_io.utils.getAs
import io.customer.sdk.data.model.Region

private const val CDP_API_KEY = "cdpApiKey"
private const val REGION_KEY = "region"

/**
 * Keys carry their region after the type prefix, e.g. `pk_eu_...`.
 */
private val keyRegionPrefix = Regex("^[a-z]{2}_(us|eu)_")

private fun regionFromKey(key: String): Region? =
    keyRegionPrefix.find(key)?.groupValues?.get(1)?.let { Region.getRegion(it) }

/**
 * True when the SDK is set up with a public `pk_` key, which is enough for in-app without a
 * site ID.
 */
internal fun hasPublicKey(config: Map<String, Any>): Boolean {
    val key = config.getAs<String>(CDP_API_KEY).orEmpty()
    return key.startsWith("pk_") && regionFromKey(key) != null
}

/**
 * Region the app set, or the one in the key prefix when it set none, matching iOS.
 */
internal fun inAppRegionFrom(config: Map<String, Any>): Region {
    val keyRegion = regionFromKey(config.getAs<String>(CDP_API_KEY).orEmpty())
    return Region.getRegion(config.getAs<String>(REGION_KEY), fallback = keyRegion ?: Region.US)
}
