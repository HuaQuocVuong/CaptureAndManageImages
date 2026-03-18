import 'package:flutter/material.dart';
import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/metadata/metadata_form.dart';
import 'dart:io';

import 'package:share_plus/share_plus.dart';

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  // Khởi tạo lớp truy cập dữ liệu (Data Access Object) cho Photo
  final PhotoDao _photoDao = PhotoDao();

  // Danh sách chứa dữ liệu ảnh lấy từ Database
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

  /// Hiển thị bottom sheet với các tùy chọn chia sẻ
  Future<void> _showShareOptions(PhotoTask photo) async {
    final file = File(photo.filePath);
    if (!await file.exists()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không tìm thấy file ảnh')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              // Chia sẻ ảnh
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Chia sẻ ảnh'),
                onTap: () async {
                  Navigator.pop(context); // đóng bottom sheet
                  try {
                    await Share.shareXFiles([
                      XFile(photo.filePath),
                    ]); //text: 'Chia sẻ ảnh từ ứng dụng');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi chia sẻ ảnh: $e')),
                    );
                  }
                },
              ),
              // Nếu ảnh có metadata, thêm tùy chọn chia sẻ metadata
              if (photo.title != null ||
                  photo.category != null ||
                  photo.price != null)
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Chia sẻ metadata'),
                  onTap: () async {
                    Navigator.pop(context);
                    // Tạo chuỗi metadata
                    String metadataText = 'THÔNG TIN SẢN PHẨM\n';
                    if (photo.title != null) {
                      metadataText += 'Tên sản phẩm: ${photo.title}\n';
                    }
                    if (photo.category != null) {
                      metadataText += 'Danh mục: ${photo.category}\n';
                    }
                    if (photo.price != null) {
                      metadataText +=
                          'Giá phẩm: ${_formatPrice(photo.price!)}đ\n';
                    }
                    try {
                      await Share.share(metadataText, subject: 'Metadata ảnh');
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi chia sẻ metadata: $e')),
                      );
                    }
                  },
                ),
              // 3Chia sẻ ảnh + metadata (nếu có metadata)
              if (photo.title != null ||
                  photo.category != null ||
                  photo.price != null)
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Chia sẻ ảnh + metadata'),
                  onTap: () async {
                    Navigator.pop(context);
                    String metadataText = 'THÔNG TIN SẢN PHẨM\n';
                    if (photo.title != null) {
                      metadataText += 'Sản phẩm: ${photo.title}\n';
                    }
                    if (photo.category != null) {
                      metadataText += 'Danh mục: ${photo.category}\n';
                    }
                    if (photo.price != null) {
                      metadataText +=
                          'Giá phẩm: ${_formatPrice(photo.price!)}đ\n';
                    }
                    try {
                      await Share.shareXFiles([
                        XFile(photo.filePath),
                      ], text: metadataText);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi chia sẻ: $e')),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
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
                  onLongPress: () =>
                      _showShareOptions(photo), // <-- Thêm dòng này
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

                      // Hiển thị metadata nếu có (THÊM PHẦN NÀY)
                      if (photo.title != null ||
                          photo.category != null ||
                          photo.price != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.black54,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (photo.title != null)
                                  Text(
                                    photo.title!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (photo.category != null)
                                  Text(
                                    photo.category!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (photo.price != null)
                                  Text(
                                    '${_formatPrice(photo.price!)}đ',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
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

  /// Format giá tiền để hiển thị
  String _formatPrice(double price) {
    if (price == price.toInt()) {
      return price.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    }
    return price.toString();
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
