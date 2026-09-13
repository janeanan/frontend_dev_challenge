import 'deal_model.dart';
import 'reservation_model.dart';

class CartItemModel {
  final DealModel deal;
  int quantity;

  /// Original (starter) comment: "Stock hold for this line item. The starter
  /// app does not reserve stock — see the 'Reservations' feature task."
  
  /// Updated after F-3: null while a reservation is in flight (optimistic
  /// add) or after it has expired and been dropped.
  ReservationModel? reservation;

  CartItemModel({required this.deal, this.quantity = 1, this.reservation});

  num get lineTotal => deal.price * quantity;
}
