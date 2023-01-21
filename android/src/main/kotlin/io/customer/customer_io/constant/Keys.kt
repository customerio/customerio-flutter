package io.customer.customer_io.constant

internal object Keys {

    object Methods {
        const val INITIALIZE = "initialize"
        const val IDENTIFY = "identify"
        const val CLEAR_IDENTIFY = "clearIdentify"
        const val TRACK = "track"
        const val SCREEN = "screen"
        const val SET_DEVICE_ATTRIBUTES = "setDeviceAttributes"
        const val SET_PROFILE_ATTRIBUTES = "setProfileAttributes"
    }

    object Tracking {
        const val IDENTIFIER = "identifier"
        const val ATTRIBUTES = "attributes"
        const val EVENT_NAME = "eventName"
    }

    object Environment {
        const val SITE_ID = "siteId"
        const val API_KEY = "apiKey"
        const val REGION = "region"
        const val ORGANIZATION_ID = "organizationId"
        const val ENABLE_IN_APP = "enableInApp"
    }

    object Config {
        const val TRACKING_API_URL = "trackingApiUrl"
        const val AUTO_TRACK_PUSH_EVENTS = "autoTrackPushEvents"
        const val AUTO_TRACK_DEVICE_ATTRIBUTES = "autoTrackDeviceAttributes"
        const val LOG_LEVEL = "logLevel"
        const val BACKGROUND_QUEUE_MIN_NUMBER_OF_TASKS = "backgroundQueueMinNumberOfTasks"
        const val BACKGROUND_QUEUE_SECONDS_DELAY = "backgroundQueueSecondsDelay"
    }

    object PackageConfig {
        const val SOURCE_SDK_VERSION = "version"
    }
}
