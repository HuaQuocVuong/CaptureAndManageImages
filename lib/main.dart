import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'database/database_helper.dart'; // Đảm bảo đúng đường dẫn file của bạn
import 'screens/camera_screen.dart';

// Biến toàn cục lưu danh sách camera
List<CameraDescription> cameras = [];

Future<void> main() async {
  // 1. Đảm bảo các ràng buộc của Flutter đã được khởi tạo trước khi gọi code native
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Khởi tạo Database
  try {
    final dbHelper = DatabaseHelper();
    // Gọi getter database để kích hoạt _initDatabase -> _onCreate
    await dbHelper.database;
    //print('Database initialized and ready.');
  } catch (e) {
    //print('Database initialization failed: $e');
    // Bạn có thể thông báo cho người dùng hoặc ghi log lỗi tại đây
  }

  // 3. Khởi tạo Camera
  try {
    cameras = await availableCameras();
    //print(' Cameras found: ${cameras.length}');
  } on CameraException {
    //print('Camera Error: ${e.code}, ${e.description}');
  }

  // 4. Chạy ứng dụng
  runApp(const PhotographyApp());
}

class PhotographyApp extends StatelessWidget {
  const PhotographyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý Hình ảnh Sản phẩm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3:
            true, // Khuyến khích dùng Material 3 cho giao diện hiện đại
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        // Dark mode giúp tiết kiệm pin và tập trung vào hình ảnh
        brightness: Brightness.dark,
      ),
      // Truyền danh sách camera vào màn hình chính
      // Nếu cameras trống, CameraScreen nên có logic xử lý thông báo "Không tìm thấy camera"
      home: CameraScreen(cameras: cameras),
    );
  }
}
