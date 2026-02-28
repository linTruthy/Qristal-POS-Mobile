class ModifierOption {
  final String id;
  final String name;
  final double priceDelta;
  final String? routeTo;

  const ModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    this.routeTo,
  });
}

class ModifierGroupOption {
  final String id;
  final String name;
  final int minSelect;
  final int? maxSelect;
  final bool isRequired;
  final List<ModifierOption> modifiers;

  const ModifierGroupOption({
    required this.id,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.isRequired,
    required this.modifiers,
  });
}

class SideOption {
  final String id;
  final String name;
  final double priceDelta;
  final String? routeTo;

  const SideOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    this.routeTo,
  });
}

class ProductCustomization {
  final String productId;
  final String? productRouteTo;
  final List<ModifierGroupOption> modifierGroups;
  final List<SideOption> sides;

  const ProductCustomization({
    required this.productId,
    required this.productRouteTo,
    this.modifierGroups = const [],
    this.sides = const [],
  });

  bool get hasOptions => modifierGroups.isNotEmpty || sides.isNotEmpty;
}
