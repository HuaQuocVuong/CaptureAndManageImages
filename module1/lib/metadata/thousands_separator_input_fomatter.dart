import 'package:flutter/services.dart';

//Tự động thêm dấu chấm (.) phân cách hàng nghìn khi người dùng nhập số
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    //Nếu ô nhập liệu trống, trả về giá trị rỗng ngay lập tức
    if (newValue.text.isEmpty) return newValue;
    //Loại bỏ tất cả ký tự không phải là số (RegExp)
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    //Gọi hàm định dạng với dấu phân cách.
    final formatted = _formatWithSeparator(digitsOnly);

    //Trả về giá trị mới cho TextField kèm theo vị trí con trỏ (Cursor).
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ), //Đẩy con trỏ về cuối chuỗi.
    );
  }

  //Đảo ngược chuỗi -> Chèn dấu chấm sau mỗi 3 chữ số -> Đảo ngược lại.
  String _formatWithSeparator(String digits) {
    if (digits.isEmpty) return '';
    //Đảo ngược chuỗi để đếm từ hàng đơn vị lên (từ phải sang trái).
    final reversed = digits.split('').reversed.join();
    final buffer = StringBuffer();
    for (int i = 0; i < reversed.length; i++) {
      //Cứ sau mỗi 3 chữ số (i % 3 == 0) và không phải vị trí đầu tiên (i > 0) thì chèn dấu '.'.
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(reversed[i]);
    }
    //Đảo ngược chuỗi một lần nữa để về định dạng đọc xuôi chuẩn.
    return buffer.toString().split('').reversed.join('');
  }
}
