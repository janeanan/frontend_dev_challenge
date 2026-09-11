import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final scrollOffset = 0.0.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;
  int _generation = 0;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals.toList();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    scrollOffset.value = scrollController.offset;
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    final gen = ++_generation;
    log('REFRESH START — gen=$gen _page=$_page _isFetchingMore=$_isFetchingMore deals=${deals.length}');
    _page = 1;
    final res = await dealRepo.fetchDeals(page: 1);
    if (_generation != gen) {
      log('REFRESH DISCARDED — gen=$gen superseded by gen=$_generation');
      return;
    }
    _totalPages = res.totalPages;
    deals.assignAll(res.items);
    refreshController.refreshCompleted();
    log('REFRESH DONE — gen=$gen deals=${deals.length}');
  }

  Future<void> loadMore() async {
    if (_isFetchingMore) return;
    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }
    final gen = _generation;
    _isFetchingMore = true;
    _page++;
    log('LOADMORE START — gen=$gen fetching page $_page deals=${deals.length}');
    try {
      final res = await dealRepo.fetchDeals(page: _page);
      if (_generation != gen) {
        log('LOADMORE DISCARDED — gen=$gen superseded by gen=$_generation');
        _page--;
        _isFetchingMore = false;
        return;
      }
      _totalPages = res.totalPages;
      deals.addAll(res.items);
      log('LOADMORE DONE — gen=$gen _page=$_page deals=${deals.length}');
    } catch (e) {
      LogService.error('loadMore failed', e);
      _page--;
    }
    _isFetchingMore = false;
    refreshController.loadComplete();
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}
