import 'package:flutter/material.dart';

//Vẽ một lưới 3x3 (2 đường dọc, 2 đường ngang) lên Canvas.
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5) //Trong suốt
      ..strokeWidth = 1.0;  //Độ dày nét 

    // Vẽ 2 đường dọc [cite: 60]
    for (var i = 1; i < 3; i++) {
      double x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Vẽ 2 đường ngang [cite: 60]
    for (var i = 1; i < 3; i++) {
      double y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // shouldRepaint quyết định khi nào CustomPainter cần vẽ lại.
  // Trả về false vì lưới không thay đổi theo thời gian (luôn vẽ 2 đường dọc, 2 đường ngang),
  // nên không cần vẽ lại trừ khi kích thước thay đổi (framework tự xử lý).
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}