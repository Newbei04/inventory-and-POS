class Product {
  int? id;

  String barcode;
  String name;
  String category;
  double price;
  double cost;
  int quantity;
  String unit;
  String description;
  String imagePath;
  String dateAdded;
  String dateUpdated;

  Product({
    this.id,
    required this.barcode,
    required this.name,
    this.category = '',
    this.price = 0,
    this.cost = 0,
    this.quantity = 0,
    this.unit = 'pc',
    this.description = '',
    this.imagePath = '',
    required this.dateAdded,
    required this.dateUpdated,
  });

  factory Product.fromMap(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      barcode: json['barcode'],
      name: json['name'],
      category: json['category'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      cost: (json['cost'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? 'pc',
      description: json['description'] ?? '',
      imagePath: json['image_path'] ?? '',
      dateAdded: json['date_added'],
      dateUpdated: json['date_updated'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'category': category,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'unit': unit,
      'description': description,
      'image_path': imagePath,
      'date_added': dateAdded,
      'date_updated': dateUpdated,
    };
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    String? category,
    double? price,
    double? cost,
    int? quantity,
    String? unit,
    String? description,
    String? imagePath,
    String? dateAdded,
    String? dateUpdated,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      dateAdded: dateAdded ?? this.dateAdded,
      dateUpdated: dateUpdated ?? this.dateUpdated,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, barcode: $barcode, name: $name)';
  }
}
