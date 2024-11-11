package io.customer.customer_io.constant

// TODO: Cleanup this file later when all commented methods are implemented
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
        const val DISMISS_MESSAGE = "dismissMessage"
    }

    object Tracking {
        const val USER_ID = "userId"
        const val TRAITS = "traits"
        const val EVENT_NAME = "eventName"
        const val TOKEN = "token"
        const val DELIVERY_ID = "deliveryId"
        const val DELIVERY_TOKEN = "deliveryToken"
        const val METRIC_EVENT = "metricEvent"

        const val NAME = "name"
        const val PROPERTIES = "properties"
        const val TITLE = "title"
    }
}
