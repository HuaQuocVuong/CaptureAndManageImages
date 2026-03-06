import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5; // Độ dày của đường lưới

    // Vẽ 2 đường dọc (giữ nguyên)
    for (var i = 1; i < 3; i++) {
      double x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    //ĐIỀU CHỈNH 2 ĐƯỜNG NGANG
    // Vẽ 2 đường ngang với tỷ lệ tùy chỉnh
    // Ví dụ 1: Chia theo tỷ lệ vàng (0.382 và 0.618)
    double y1 = size.height * 0.300; // Đường ngang thứ nhất
    double y2 = size.height * 0.550; // Đường ngang thứ hai

    // Ví dụ 2: Chia theo tỷ lệ 1/4 và 3/4
    // double y1 = size.height * 0.25;
    // double y2 = size.height * 0.75;

    // Ví dụ 3: Dịch lên trên 10%
    // double y1 = size.height * 0.3;
    // double y2 = size.height * 0.7;

    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), paint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
