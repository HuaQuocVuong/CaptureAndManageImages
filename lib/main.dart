import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'database/database_helper.dart';
//import 'screens/camera_screen.dart';
import 'screens/photo_gallery_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Database
  try {
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
  } catch (e) {
    // Xử lý lỗi database
  }

  // Khởi tạo Camera
  try {
    cameras = await availableCameras();
  } on CameraException {
    // Xử lý lỗi camera
  }

  // Chạy ứng dụng, truyền cameras vào App
  runApp(PhotographyApp(cameras: cameras));
}

class PhotographyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const PhotographyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý Hình ảnh Sản phẩm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      // Màn hình chính là PhotoGalleryScreen
      home: PhotoGalleryScreen(cameras: cameras),
    );
  }
}
