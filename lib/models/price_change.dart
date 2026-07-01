class PriceChange {
  final int? id;
  final int productId;
  final String productName;
  final double oldPrice;
  final double newPrice;
  final double oldCost;
  final double newCost;
  final String date;

  PriceChange({
    this.id,
    required this.productId,
    required this.productName,
    required this.oldPrice,
    required this.newPrice,
    required this.oldCost,
    required this.newCost,
    required this.date,
  });

  factory PriceChange.fromMap(Map<String, dynamic> json) {
    return PriceChange(
      id: json['id'],
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      oldPrice: (json['old_price'] as num?)?.toDouble() ?? 0,
      newPrice: (json['new_price'] as num?)?.toDouble() ?? 0,
      oldCost: (json['old_cost'] as num?)?.toDouble() ?? 0,
      newCost: (json['new_cost'] as num?)?.toDouble() ?? 0,
      date: json['date'],
    );
  }
}
