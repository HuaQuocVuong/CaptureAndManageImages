// Danh sách các danh mục sản phẩm có sẵn
const List<String> categories = [
  'Thời trang',
  'Đồ công nghệ',
  'Đồ gia dụng',
  'Sách',
  'Khác',
];

// Lớp lưu thông tin gợi ý giá (hiển thị và giá trị số)
class PriceSuggestionItem {
  final String label; // Chuỗi giá trị hiển thị trên chip
  final int value; // Giá trị tương ứng
  const PriceSuggestionItem(this.label, this.value);
}

// Danh sách gợi ý nhanh - Giá
final List<PriceSuggestionItem> priceSuggestions = [
  PriceSuggestionItem('19.999', 19000),
  PriceSuggestionItem('49.999', 49999),
  PriceSuggestionItem('99.999', 99999),
  PriceSuggestionItem('199.999', 199999),
  PriceSuggestionItem('999.999', 999999),
];
// Danh sách các gợi ý nhanh - Ghi chú
final List<String> noteSuggestions = [
  'Còn hàng',
  'Hết hàng',
  'Sắp về hàng',
  'Hàng mới về',
];
