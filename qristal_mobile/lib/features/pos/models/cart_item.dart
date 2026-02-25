import '../../../database/database.dart';

class CartModifier {
  final String name;
  final double priceDelta;
  final String? routeTo;

  const CartModifier({
    required this.name,
    this.priceDelta = 0,
    this.routeTo,
  });
}

class CartSide {
  final String name;
  final int quantity;
  final double priceDelta;
  final String? routeTo;

  const CartSide({
    required this.name,
    this.quantity = 1,
    this.priceDelta = 0,
    this.routeTo,
  });
}

class CartItem {
  final Product product;
  final int quantity;
  final String notes;
  final String? routeTo;
  final List<CartModifier> modifiers;
  final List<CartSide> sides;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes = '',
    this.routeTo,
    this.modifiers = const [],
    this.sides = const [],
  });

  double get perItemTotal {
    final modifiersTotal = modifiers.fold<double>(0, (sum, m) => sum + m.priceDelta);
    final sidesTotal = sides.fold<double>(
      0,
      (sum, s) => sum + (s.priceDelta * s.quantity),
    );
    return product.price + modifiersTotal + sidesTotal;
  }

  double get total => perItemTotal * quantity;

  CartItem copyWith({
    int? quantity,
    String? notes,
    String? routeTo,
    List<CartModifier>? modifiers,
    List<CartSide>? sides,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      routeTo: routeTo ?? this.routeTo,
      modifiers: modifiers ?? this.modifiers,
      sides: sides ?? this.sides,
    );
  }
}
