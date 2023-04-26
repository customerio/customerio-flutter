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
        const val REGISTER_DEVICE_TOKEN = "registerDeviceToken"
        const val TRACK_METRIC = "trackMetric"
        const val ON_MESSAGE_RECEIVED = "onMessageReceived"
    }

    object Tracking {
        const val IDENTIFIER = "identifier"
        const val ATTRIBUTES = "attributes"
        const val EVENT_NAME = "eventName"
        const val TOKEN = "token"
        const val DELIVERY_ID = "deliveryId"
        const val DELIVERY_TOKEN = "deliveryToken"
        const val METRIC_EVENT = "metricEvent"
    }

    object Environment {
        const val SITE_ID = "siteId"
        const val API_KEY = "apiKey"
        const val REGION = "region"
        const val ENABLE_IN_APP = "enableInApp"
    }
}
