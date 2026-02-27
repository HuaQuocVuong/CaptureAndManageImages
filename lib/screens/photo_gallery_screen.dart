import 'package:flutter/material.dart';
import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/screens/metadata_form.dart';
import 'dart:io';

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  // Khởi tạo lớp truy cập dữ liệu (Data Access Object) cho Photo
  final PhotoDao _photoDao = PhotoDao();

  // Danh sách chứa dữ liệu ảnh lấy từ DB
  List<PhotoTask> _photos = [];

  // Biến trạng thái để hiển thị vòng xoay loading khi đang tải dữ liệu
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Tải dữ liệu ngay khi màn hình được khởi tạo
    _loadPhotos();
  }

  /// Hàm xử lý tải danh sách ảnh từ cơ sở dữ liệu
  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      // Gọi DAO để lấy tất cả ảnh
      final photos = await _photoDao.getAllPhotos();
      setState(() {
        _photos = photos; // Cập nhật danh sách ảnh vào state
        _isLoading = false; // Tắt loading
      });
    } catch (e) {
      // Xử lý nếu xảy ra lỗi trong quá trình truy vấn
      setState(() => _isLoading = false);
      // Hiển thị thông báo lỗi nếu quá trình lấy dữ liệu thất bại
      if (mounted) {
        // Hiển thị thông báo lỗi nhanh (SnackBar) cho người dùng
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư viện ảnh'),
        actions: [
          // Nút bấm cho phép người dùng làm mới (refresh) danh sách thủ công
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPhotos),
        ],
      ),
      // Điều hướng hiển thị: Loading -> Empty State -> GridView
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Hiển thị khi đang đợi DB
          : _photos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có ảnh nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  // Nút quay lại màn hình trước đó để chụp ảnh
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Chụp ảnh ngay'),
                  ),
                ],
              ),
            )
          // Hiển thị danh sách ảnh theo dạng lưới (3 cột)
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Hiển thị 3 cột
                crossAxisSpacing: 4, // Khoảng cách ngang giữa các item
                mainAxisSpacing: 4, // Khoảng cách dọc giữa các item
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                return GestureDetector(
                  onTap: () {
                    // Khi chạm vào một ảnh, chuyển hướng sang trang MetadataForm
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MetadataForm(
                          imagePath: photo.filePath,
                          photoId: int.parse(photo.id),
                        ),
                      ),
                    ).then(
                      (_) => _loadPhotos(),
                    ); // Sau khi quay lại từ MetadataForm, tự động load lại ảnh
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Hiển thị ảnh từ file cục bộ
                      Image.file(File(photo.filePath), fit: BoxFit.cover),

                      // Badge hiển thị trạng thái của ảnh (Góc trên bên phải)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              photo.status,
                            ), // Màu dựa trên trạng thái
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            // Lấy ký tự đầu của trạng thái để hiển thị (ví dụ: R, P, Q, F)
                            photo.status.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Hàm xác định màu sắc dựa trên trạng thái (Status) của ảnh
  Color _getStatusColor(PhotoStatus status) {
    switch (status) {
      case PhotoStatus.ready:
        return Colors.green; // Hoàn thành/Sẵn sàng
      case PhotoStatus.processing:
        return Colors.orange; // Đang xử lý
      case PhotoStatus.queued:
        return Colors.blue; // Đang chờ
      case PhotoStatus.failed:
        return Colors.red; // Thất bại
      default:
        return Colors.grey;
    }
  }
}
