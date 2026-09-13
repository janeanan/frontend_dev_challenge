import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../repository/order_repo.dart';
import '../service/api_exception.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// Original (starter) comment: "NOTE: the starter cart is purely local — it
/// does not reserve stock on the backend. See the 'Reservations' feature task in PROBLEM.md."

/// Updated after F-3: adding a deal now reserves stock on the backend
/// (optimistic UI — the line appears instantly, then rolls back if the
/// reservation fails).
class CartService extends GetxService {
  final OrderRepo orderRepo;

  CartService({required this.orderRepo});

  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  // Per-deal request counter: guards against an in-flight reserve() call
  // resolving after a newer one for the same deal (rapid taps), same
  // technique as the generation counter in home_controller.dart (RES-104).
  final Map<int, int> _reserveGeneration = {};

  Future<void> add(DealModel deal) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null && existing.quantity >= deal.quantityLeft) {
      LogService.log('cart: cannot add more of deal ${deal.id}');
      return;
    }

    if (existing != null) {
      existing.quantity++;
    } else {
      items.add(CartItemModel(deal: deal));
    }
    items.refresh();
    _recount();

    final gen = (_reserveGeneration[deal.id] ?? 0) + 1;
    _reserveGeneration[deal.id] = gen;

    try {
      final reservation = await orderRepo.reserve(deal.id);
      if (_reserveGeneration[deal.id] != gen) return;
      final line = items.firstWhereOrNull((i) => i.deal.id == deal.id);
      line?.reservation = reservation;
      items.refresh();
    } on ApiException catch (e) {
      LogService.error('cart: reserve failed for deal ${deal.id}', e);
      if (_reserveGeneration[deal.id] != gen) return;
      _rollback(deal.id);
      Get.snackbar(
        'Couldn\'t add to bag',
        'Someone just grabbed this item. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _rollback(int dealId) {
    final line = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (line == null) return;
    if (line.quantity > 1) {
      line.quantity--;
      items.refresh();
    } else {
      items.remove(line);
    }
    _recount();
  }

  Future<void> decrement(int dealId) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    final releasedReservation = existing.reservation;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      existing.reservation = null;
      items.refresh();
    }
    _recount();
    if (releasedReservation != null) {
      _release(releasedReservation.id);
    }
  }

  Future<void> remove(int dealId) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
    if (existing?.reservation != null) {
      _release(existing!.reservation!.id);
    }
  }

  void clear() {
    for (final item in items) {
      final reservation = item.reservation;
      if (reservation != null) _release(reservation.id);
    }
    items.clear();
    _recount();
  }

  /// Drops any line whose reservation has expired — called by a periodic
  /// ticker (see CartController) so a stale line never lingers unusable in
  /// the bag until the user tries to check out.
  List<CartItemModel> dropExpiredReservations() {
    final expired =
        items.where((i) => i.reservation?.isExpired ?? false).toList();
    if (expired.isEmpty) return expired;
    items.removeWhere((i) => expired.contains(i));
    _recount();
    return expired;
  }

  void _release(String reservationId) {
    orderRepo.releaseReservation(reservationId).catchError((e) {
      LogService.error('cart: release failed for $reservationId', e);
    });
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
