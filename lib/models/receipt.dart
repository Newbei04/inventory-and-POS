import 'dart:convert';

class ReceiptItem {
  int productId;
  String productName;
  String barcode;
  double price;
  int quantity;
  double total;

  ReceiptItem({
    required this.productId,
    required this.productName,
    this.barcode = '',
    required this.price,
    required this.quantity,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'product_name': productName,
    'barcode': barcode,
    'price': price,
    'quantity': quantity,
    'total': total,
  };

  factory ReceiptItem.fromMap(Map<String, dynamic> m) => ReceiptItem(
    productId: m['product_id'],
    productName: m['product_name'],
    barcode: m['barcode'] ?? '',
    price: (m['price'] ?? 0).toDouble(),
    quantity: m['quantity'] ?? 0,
    total: (m['total'] ?? 0).toDouble(),
  );
}

class Receipt {
  int? id;
  String receiptNo;
  double subtotal;
  double tax;
  double total;
  double cash;
  double change;
  String date;
  List<ReceiptItem> items;

  Receipt({
    this.id,
    required this.receiptNo,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.cash,
    required this.change,
    required this.date,
    required this.items,
  });

  Map<String, dynamic> toMap() => {
    'receipt_no': receiptNo,
    'subtotal': subtotal,
    'tax': tax,
    'total': total,
    'cash': cash,
    'change': change,
    'date': date,
    'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
  };

  factory Receipt.fromMap(Map<String, dynamic> m) {
    final itemsRaw = m['items_json'] as String? ?? '[]';
    final itemsList = (jsonDecode(itemsRaw) as List)
        .map((e) => ReceiptItem.fromMap(e as Map<String, dynamic>))
        .toList();
    return Receipt(
      id: m['id'],
      receiptNo: m['receipt_no'],
      subtotal: (m['subtotal'] ?? 0).toDouble(),
      tax: (m['tax'] ?? 0).toDouble(),
      total: (m['total'] ?? 0).toDouble(),
      cash: (m['cash'] ?? 0).toDouble(),
      change: (m['change'] ?? 0).toDouble(),
      date: m['date'],
      items: itemsList,
    );
  }
}
