import 'package:customer_io/config/in_app_config.dart';
import 'package:customer_io/config/notification_inbox_accessibility_labels.dart';
import 'package:flutter_test/flutter_test.dart';

/// The labels are plain data: Dart hands them to the platform channel and the native side does
/// the work — iOS parses the dictionary in `MessagingInAppConfigBuilder.build(from:)`, Android
/// converts the `{count}` template into the `(Int) -> String` closure the SDK takes. What Dart
/// owns is the contract, so these tests pin the wire keys and the absent-means-absent rule. A
/// rename on either side silently drops every label rather than failing, because the SDK emits
/// no text of its own — the inbox would just go unlabeled.
void main() {
  group('NotificationInboxAccessibilityLabels', () {
    test('serializes every label under the keys the native parsers read', () {
      const labels = NotificationInboxAccessibilityLabels(
        bell: 'Aviseringar',
        bellWithUnreadCount: 'Aviseringar, {count} olasta',
        loadingIndicator: 'Laddar',
        emptyState: 'Inga aviseringar',
      );

      expect(labels.toMap(), {
        'bell': 'Aviseringar',
        'bellWithUnreadCount': 'Aviseringar, {count} olasta',
        'loadingIndicator': 'Laddar',
        'emptyState': 'Inga aviseringar',
      });
    });

    test('omits unset labels rather than sending explicit nulls', () {
      const labels =
          NotificationInboxAccessibilityLabels(emptyState: 'Inga aviseringar');

      // The native default is "emit no label at all", so an unset label must not reach the
      // platform channel as a key the parsers would have to distinguish from absent.
      expect(labels.toMap(), {'emptyState': 'Inga aviseringar'});
    });

    test('is an empty map when nothing is configured', () {
      expect(const NotificationInboxAccessibilityLabels().toMap(), isEmpty);
    });

    test('keeps the count placeholder intact for the native side', () {
      const labels = NotificationInboxAccessibilityLabels(
        bellWithUnreadCount: 'Aviseringar, {count} olasta',
      );

      // Dart must not interpolate: the count is only known natively, at render time.
      expect(
        labels.toMap()['bellWithUnreadCount'],
        contains(NotificationInboxAccessibilityLabels.countPlaceholder),
      );
    });
  });

  group('InAppConfig', () {
    test('nests the labels under the key shared with the native parsers', () {
      final config = InAppConfig(
        siteId: 'siteId',
        accessibilityLabels:
            const NotificationInboxAccessibilityLabels(bell: 'Aviseringar'),
      );

      expect(config.toMap(), {
        'siteId': 'siteId',
        'notificationInboxAccessibilityLabels': {'bell': 'Aviseringar'},
      });
    });

    test('omits the labels entirely when the app configures none', () {
      expect(InAppConfig(siteId: 'siteId').toMap(), {'siteId': 'siteId'});
    });
  });
}
