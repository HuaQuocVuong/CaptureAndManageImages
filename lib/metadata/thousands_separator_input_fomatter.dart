import 'package:flutter/services.dart';

// Định dạng đầu vào cho phép người dùng nhập số và tự động thêm dấu phân cách hàng nghìn (dấu chấm)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Chuỗi mới rỗng, trả về (tránh lỗi khi xóa hết)
    if (newValue.text.isEmpty) return newValue;

    // Loại bỏ tất cả ký tự không phải số (chỉ giữ lại 0-9)
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Định dạng chuỗi số với dấu chấm phân cách hàng nghìn
    final formatted = _formatWithSeparator(digitsOnly);

    // Trả về giá trị mới đã được định dạng, con trỏ đặt ở cuối chuỗi
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  // Hàm định dạng một chuỗi chỉ gồm các chữ số thành dạng có dấu chấm sau mỗi 3 chữ số (từ phải sang)
  String _formatWithSeparator(String digits) {
    if (digits.isEmpty) return '';

    // Đảo ngược chuỗi để dễ xử lý thêm dấu chấm từ cuối lên
    final reversed = digits.split('').reversed.join();

    final buffer = StringBuffer();
    for (int i = 0; i < reversed.length; i++) {
      // Cứ mỗi 3 ký tự (trừ vị trí đầu tiên) thì thêm dấu chấm
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(reversed[i]);
    }
    // Sau khi thêm dấu chấm, đảo ngược lại để có kết quả đúng
    return buffer.toString().split('').reversed.join('');
  }
}
