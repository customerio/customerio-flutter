package io.customer.customer_io.messaginginapp

import io.customer.customer_io.utils.getAs
import io.customer.sdk.data.model.Region

private const val CDP_API_KEY = "cdpApiKey"
private const val REGION_KEY = "region"

/**
 * Public `wk_` keys carry their region in the prefix, e.g. `wk_eu_...`.
 */
private val publicKeyPrefix = Regex("^wk_(us|eu)_")

/**
 * True when the SDK is set up with a public `wk_` key, which is enough for in-app without a
 * site ID.
 */
internal fun hasPublicKey(config: Map<String, Any>): Boolean =
    publicKeyPrefix.containsMatchIn(config.getAs<String>(CDP_API_KEY).orEmpty())

/**
 * Region the app set, or the one in a `wk_` key prefix when it set none, matching iOS.
 */
internal fun inAppRegionFrom(config: Map<String, Any>): Region {
    val keyRegion = publicKeyPrefix.find(config.getAs<String>(CDP_API_KEY).orEmpty())
        ?.groupValues?.get(1)
        ?.let { Region.getRegion(it) }
    return Region.getRegion(config.getAs<String>(REGION_KEY), fallback = keyRegion ?: Region.US)
}
