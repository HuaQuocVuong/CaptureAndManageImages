class Product {
  //Thuộc tính của sản phẩm
  int? id;  //ID
  String name;  // Tên sản phẩm
  String category;  // Danh mục
  double? price;  // Giá tiền
  String? note; // Ghi chú
  DateTime? createdAt;  // Thời điểm tạo 
  DateTime? updatedAt;  // Thời điểm cập nhật cuối

  //Constructor dùng để khởi tạo đối tượng Product
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
  factory Product.fromMap(Map<String, dynamic> map) { // Chuyển DateTime thành String để lưu trữ vì DB thường không lưu trực tiếp kiểu Date
    return Product(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      // Ép kiểu về double đề phòng trường hợp dữ liệu trả về là int
      price: map['price']?.toDouble(),
      note: map['note'],
      // Chuyển chuỗi String ISO8601 từ DB thành đối tượng DateTime trong Dart
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      // Chuyển DateTime thành String để lưu trữ vì DB thường không lưu trực tiếp kiểu Date
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
