import 'dart:developer';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;
  String _activeQuery = '';

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  void onQueryChanged(String query) {
    _activeQuery = query;
    _search(query);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      results.clear();
      hasSearched.value = false;
      return;
    }
    isLoading.value = true;
    hasSearched.value = true;
    final stopwatch = Stopwatch()..start();
    log('search SENT: "$query"');
    try {
      final found = await dealRepo.search(query);
      stopwatch.stop();
      log('search RECEIVED: "$query" | ${stopwatch.elapsedMilliseconds}ms | ${found.length}');
      if (query != _activeQuery) return;
      results.assignAll(found);
      log('results NOW: ${results.length}');
    } catch (e) {
      LogService.error('search failed', e);
    }
    isLoading.value = false;
  }
}
