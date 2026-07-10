class StockMovement {
  int? id;
  int productId;
  String productName;
  int oldQuantity;
  int newQuantity;
  int delta;
  String type;
  String reason;
  String date;

  StockMovement({
    this.id,
    required this.productId,
    required this.productName,
    required this.oldQuantity,
    required this.newQuantity,
    required this.delta,
    required this.type,
    this.reason = '',
    required this.date,
  });

  factory StockMovement.fromMap(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'],
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      oldQuantity: json['old_quantity'] ?? 0,
      newQuantity: json['new_quantity'] ?? 0,
      delta: json['delta'] ?? 0,
      type: json['type'] ?? 'adjustment',
      reason: json['reason'] ?? '',
      date: json['date'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'old_quantity': oldQuantity,
      'new_quantity': newQuantity,
      'delta': delta,
      'type': type,
      'reason': reason,
      'date': date,
    };
  }
}
