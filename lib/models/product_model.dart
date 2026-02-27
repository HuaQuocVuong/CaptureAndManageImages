class Product {
  int? id;
  String name;
  String category;
  double? price;
  String? note;
  DateTime? createdAt;
  DateTime? updatedAt;

  Product({
    this.id,
    required this.name,
    required this.category,
    this.price,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  // Factory constructor từ Map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      price: map['price']?.toDouble(),
      note: map['note'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  // Method chuyển sang Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // THÊM METHOD copyWith NÀY
  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? price,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Thêm method toString để dễ debug
  @override
  String toString() {
    return 'Product{id: $id, name: $name, category: $category, price: $price, note: $note, createdAt: $createdAt, updatedAt: $updatedAt}';
  }

  // Thêm method equals để so sánh 2 product
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.price == price &&
        other.note == note;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        category.hashCode ^
        price.hashCode ^
        note.hashCode;
  }
}
