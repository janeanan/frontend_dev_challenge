import 'dart:async';

import 'package:get/get.dart';

import '../util/log_service.dart';
import 'fake_api_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink. Events are visible on the debug screen
/// (overflow menu on Home -> "Analytics debug") and in the console.
///
/// The "Impression tracking" feature task builds on top of this service.
class AnalyticsService extends GetxService {
  late final FakeApiService _api;

  final events = <AnalyticsEvent>[].obs;

  // Session-scoped dedup: each deal is logged at most once.
  final _seenDealIds = <int>{};

  // Impression batch buffer.
  final _pending = <AnalyticsEvent>[];
  Timer? _batchTimer;

  static const _batchSize = 10;
  static const _batchWindow = Duration(seconds: 15);

  @override
  void onInit() {
    super.onInit();
    _api = Get.find<FakeApiService>();
  }

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
  }

  /// Log a deal_impression event, deduplicated per session.
  /// Batches are flushed when [_batchSize] events accumulate or [_batchWindow] elapses.
  void logImpression(int dealId, String source, int position) {
    if (_seenDealIds.contains(dealId)) return;
    _seenDealIds.add(dealId);

    final event = AnalyticsEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      'position': position,
    });
    events.add(event);
    LogService.log('analytics: deal_impression deal_id=$dealId source=$source position=$position');

    _pending.add(event);
    _scheduleBatch();
  }

  void _scheduleBatch() {
    if (_pending.length >= _batchSize) {
      _flushBatch();
      return;
    }
    // Start 15-second window only on the first pending event.
    _batchTimer ??= Timer(_batchWindow, _flushBatch);
  }

  void _flushBatch() {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_pending.isEmpty) return;
    final payload = _pending.map((e) => e.toJson()).toList();
    _pending.clear();
    _api.sendAnalyticsBatch(payload);
  }

  @override
  void onClose() {
    _flushBatch();
    super.onClose();
  }
}
