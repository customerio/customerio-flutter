import '../customer_io_enums.dart';

/// Payload describing the full desired state of a Live Activity (iOS) /
/// Live Notification (Android).
///
/// ActivityKit replaces the content-state wholesale on every update, so callers
/// must always pass the complete desired state to both
/// [CustomerIOLiveActivitiesPlatform.start] and
/// [CustomerIOLiveActivitiesPlatform.update].
///
/// The field names are identical across both platforms and map directly to the
/// native template attributes.
abstract class LiveActivityPayload {
  /// The built-in template this payload targets.
  final LiveActivityTemplate type;

  const LiveActivityPayload(this.type);

  /// Serializes the payload into a flat map understood by the native handlers.
  Map<String, dynamic> toMap();

  /// Creates a payload for the [LiveActivityTemplate.segments] template.
  const factory LiveActivityPayload.segments({
    required String header,
    required String status,
    String? substatus,
    required int segmentsTotal,
    required int segmentsComplete,
    String? trailingText,
  }) = SegmentsLiveActivityPayload;

  /// Creates a payload for the [LiveActivityTemplate.countdownTimer] template.
  const factory LiveActivityPayload.countdownTimer({
    required String header,
    required String title,
    String? statusMessage,
    int? endTime,
  }) = CountdownTimerLiveActivityPayload;
}

/// Payload for the segmented progress template.
class SegmentsLiveActivityPayload extends LiveActivityPayload {
  /// Static, non-changing header shown on the activity (an attribute, not state).
  final String header;

  /// Primary status line.
  final String status;

  /// Optional secondary status line.
  final String? substatus;

  /// Total number of segments.
  final int segmentsTotal;

  /// Number of segments completed so far.
  final int segmentsComplete;

  /// Optional trailing text (e.g. an ETA or count).
  final String? trailingText;

  const SegmentsLiveActivityPayload({
    required this.header,
    required this.status,
    this.substatus,
    required this.segmentsTotal,
    required this.segmentsComplete,
    this.trailingText,
  }) : super(LiveActivityTemplate.segments);

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.rawValue,
      'header': header,
      'status': status,
      'substatus': substatus,
      'segmentsTotal': segmentsTotal,
      'segmentsComplete': segmentsComplete,
      'trailingText': trailingText,
    };
  }
}

/// Payload for the countdown timer template.
class CountdownTimerLiveActivityPayload extends LiveActivityPayload {
  /// Static, non-changing header shown on the activity (an attribute, not state).
  final String header;

  /// Primary title line.
  final String title;

  /// Optional status message.
  final String? statusMessage;

  /// End time as epoch **seconds**. When null, no countdown is rendered.
  final int? endTime;

  const CountdownTimerLiveActivityPayload({
    required this.header,
    required this.title,
    this.statusMessage,
    this.endTime,
  }) : super(LiveActivityTemplate.countdownTimer);

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.rawValue,
      'header': header,
      'title': title,
      'statusMessage': statusMessage,
      'endTime': endTime,
    };
  }
}
