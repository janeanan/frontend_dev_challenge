import 'dart:async';

import 'package:get/get.dart';

import '../../repository/order_repo.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class CartController extends GetxController {
  final CartService cartService;
  final OrderRepo orderRepo;

  CartController({required this.cartService, required this.orderRepo});

  final isCheckingOut = false.obs;
  Timer? _expiryTicker;

  @override
  void onInit() {
    super.onInit();
    // Proactively drop expired lines while the user is just sitting on the
    // cart screen, instead of only finding out at checkout time.
    _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final expired = cartService.dropExpiredReservations();
      if (expired.isNotEmpty) {
        Get.snackbar(
          'Reservation timed out',
          '${expired.map((i) => i.deal.name).join(", ")} timed out and ${expired.length > 1 ? 'were' : 'was'} removed from your bag.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    });
  }

  @override
  void onClose() {
    _expiryTicker?.cancel();
    super.onClose();
  }

  Future<void> checkout() async {
    if (cartService.items.isEmpty || isCheckingOut.value) return;
    isCheckingOut.value = true;
    try {
      final order = await orderRepo.checkout(cartService.items.toList());
      cartService.clear();
      Get.snackbar(
        'Order confirmed',
        'Order #${order.id} — pick up soon!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      LogService.error('checkout failed', e);
      if (e.statusCode == 410) {
        cartService.dropExpiredReservations();
        Get.snackbar(
          'Some items timed out',
          'We removed the items that took too long to reserve. Please add them again.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Checkout failed',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
    isCheckingOut.value = false;
  }
}
