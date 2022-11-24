package io.customer.customer_io.constant

internal object Keys {

    object Tracking {
        const val IDENTIFIER = "identifier"
        const val ATTRIBUTES = "attributes"
    }

    object Environment {
        const val SITE_ID = "siteId"
        const val API_KEY = "apiKey"
        const val REGION = "region"
        const val ORGANIZATION_ID = "organizationId"
    }

    object Config {
        const val TRACKING_API_URL = "trackingApiUrl"
        const val AUTO_TRACK_DEVICE_ATTRIBUTES = "autoTrackDeviceAttributes"
        const val LOG_LEVEL = "logLevel"
        const val BACKGROUND_QUEUE_MIN_NUMBER_OF_TASKS = "backgroundQueueMinNumberOfTasks"
        const val BACKGROUND_QUEUE_SECONDS_DELAY = "backgroundQueueSecondsDelay"
    }

    object PackageConfig {
        const val SOURCE_SDK_VERSION = "version"
    }
}
