// Cung cấp các phương thức định dạng giá trị số để hiển thị trên giao diện
// Hỗ trợ thêm dấu phân cách hàng nghìn và xử lý số thập phân
class PriceFormatter {
  // Định dạng chuỗi chữ số thành dạng có dấu chấm phân cách hàng nghìn
  static String formatNumber(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  // Định dạng giá trị số thực (double) để hiển thị dưới dạng chuỗi
  // Nếu price là số nguyên thì hiển thị phần nguyên, nếu có phần thập phân thì hiển thị 2 chữ số thập phân
  static String formatForDisplay(double? price) {
    if (price == null) return '';
    final intPart = price.toInt();
    if (price == intPart) {
      return formatNumber(intPart.toString());
    } else {
      final parts = price.toStringAsFixed(2).split('.');
      final intFormatted = formatNumber(parts[0]);
      return '$intFormatted.${parts[1]}';
    }
  }
}
