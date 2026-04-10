import 'dart:math';

/// Random class to help generate random values conveniently
class RandomValues {
  // Repeated numbers to increase the probability in random value
  final _emailUsernameWhitelistChars =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
  final _emailUsernameLength = 10;
  final List<String> _eventNames = [
    'Order Purchased',
    'movie_watched',
    'appointmentScheduled',
  ];

  String getEmail() {
    final random = Random();
    final charsLength = _emailUsernameWhitelistChars.length;
    String result = '';

    for (int i = 0; i < _emailUsernameLength; i++) {
      result += _emailUsernameWhitelistChars[random.nextInt(charsLength)];
    }

    return "$result@customer.io";
  }

  MapEntry<String, Map<String, Object>?> trackingEvent() {
    int index = Random().nextInt(_eventNames.length);
    Map<String, Object>? attributes;

    switch (index) {
      case 1:
        attributes = {
          'movie_name': 'The Incredibles',
        };
        break;
      case 2:
        DateTime appointmentTime = DateTime.now().add(const Duration(days: 7));
        attributes = {
          'appointmentTime': appointmentTime.millisecondsSinceEpoch ~/ 1000,
        };
        break;
      case 0:
      default:
        attributes = null;
    }

    return MapEntry(_eventNames[index], attributes);
  }
}
