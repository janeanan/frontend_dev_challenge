import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  late DealModel deal;

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  final isLoading = true.obs;
  final hasError = false.obs;

  @override
  void onInit() {
    super.onInit();
    // TEMP: simulate fetch error — remove after testing
    // hasError.value = true;
    // isLoading.value = false;
    // return;

    final args = Get.arguments as DealModel?;
    if (args != null) {
      deal = args;
      _quantityLeft.value = deal.quantityLeft;
      isLoading.value = false;
      analytics.logEvent('deal_details_view', {
        'deal_id': deal.id,
        'source': Get.parameters['source'] ?? 'unknown',
      });
    } else {
      final id = int.tryParse(Get.parameters['id'] ?? '');
      if (id != null) _loadById(id);
    }
    // Whenever the cart changes, re-check this deal's remaining stock so the
    // details screen never shows stale availability.

    // ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  Future<void> _loadById(int id) async {
    try {
      deal = await dealRepo.fetchById(id);
      _quantityLeft.value = deal.quantityLeft;
      analytics.logEvent('deal_details_view', {
        'deal_id': deal.id,
        'source': Get.parameters['source'] ?? 'unknown',
      });
    } catch (e) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  // Future<void> _recheckAvailability() async {
  //   LogService.log('re-checking availability for deal ${deal.id}');
  //   final fresh = await dealRepo.fetchById(deal.id);
  //   _quantityLeft.value = fresh.quantityLeft;
  // }

  void addToCart() {
    cartService.add(deal);
    if (_quantityLeft.value != null) {
      _quantityLeft.value = (_quantityLeft.value! - 1).clamp(0, deal.quantityLeft);
    }
    Get.snackbar(
      'Added to bag',
      '${deal.name} — pick up ${deal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
