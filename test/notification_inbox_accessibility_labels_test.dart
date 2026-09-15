import 'package:flutter/foundation.dart';
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

  // A mistyped placeholder substitutes nothing and is announced verbatim, braces included.
  // Neither native layer can report that usefully — Android logs below the default level and
  // iOS does not check at all — so the warning is raised from Dart instead.
  group('count placeholder warning', () {
    late DebugPrintCallback original;
    late List<String> printed;

    setUp(() {
      printed = <String>[];
      original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };
    });

    tearDown(() => debugPrint = original);

    test('warns when the template is missing the placeholder', () {
      const NotificationInboxAccessibilityLabels(
        bellWithUnreadCount: 'Aviseringar, {COUNT} olasta',
      ).toMap();

      expect(printed, hasLength(1));
      expect(printed.single, contains('bellWithUnreadCount'));
      expect(
        printed.single,
        contains(NotificationInboxAccessibilityLabels.countPlaceholder),
      );
    });

    test('still serializes a template with a mistyped placeholder', () {
      // A label typo degrades an announcement; it must never fail initialization.
      final Map<String, dynamic> map =
          const NotificationInboxAccessibilityLabels(
        bellWithUnreadCount: 'Aviseringar, %d olasta',
      ).toMap();

      expect(map['bellWithUnreadCount'], 'Aviseringar, %d olasta');
    });

    test('stays quiet when the placeholder is present', () {
      const NotificationInboxAccessibilityLabels(
        bellWithUnreadCount: 'Aviseringar, {count} olasta',
      ).toMap();

      expect(printed, isEmpty);
    });

    test('stays quiet when bellWithUnreadCount is not configured', () {
      const NotificationInboxAccessibilityLabels(bell: 'Aviseringar').toMap();

      expect(printed, isEmpty);
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

    test('omits a labels object whose fields are all unset', () {
      // An all-null object serializes to {}, and sending that would make "configured nothing"
      // indistinguishable from "configured an empty object" natively, where both parsers key
      // off the map being present at all.
      final config = InAppConfig(
        siteId: 'siteId',
        accessibilityLabels: const NotificationInboxAccessibilityLabels(),
      );

      expect(config.toMap(), {'siteId': 'siteId'});
    });
  });
}
