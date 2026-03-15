import 'dart:io';

import 'package:flutter/material.dart';

import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/models/product_model.dart';

class BulkEditScreen extends StatefulWidget {
  // Nhận vào danh sách ảnh và danh sách sản phẩm từ màn hình trước
  final List<PhotoTask> photos;
  final List<Product> products;

  const BulkEditScreen({
    super.key,
    required this.photos,
    required this.products,
  });

  @override
  State<BulkEditScreen> createState() => _BulkEditScreenState();
}

class _BulkEditScreenState extends State<BulkEditScreen> {
  // Khởi tạo đối tượng truy cập cơ sở dữ liệu cho ảnh
  final PhotoDao _photoDao = PhotoDao();

  // Danh sách biến bool để theo dõi trạng thái chọn của từng ảnh (true = đã chọn)
  List<bool> _selectedPhotos = [];

  // Lưu trữ sản phẩm được chọn từ Dropdown
  Product? _selectedProduct;

  // Biến trạng thái để hiển thị tiến trình đang xử lý (loading)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo danh sách chọn với tất cả giá trị là false (chưa chọn ảnh nào)
    _selectedPhotos = List<bool>.filled(widget.photos.length, false);
  }

  /// Hàm thực hiện gán các ảnh đã chọn cho sản phẩm đã chọn
  Future<void> _assignToProduct() async {
    // Kiểm tra xem người dùng đã chọn sản phẩm hay chưa
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn sản phẩm')));
      return;
    }

    // Kiểm tra xem có ít nhất một ảnh được chọn hay chưa
    if (!_selectedPhotos.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 ảnh')),
      );
      return;
    }
    // Bật trạng thái loading để tránh người dùng thao tác trùng lặp
    setState(() => _isLoading = true);

    try {
      int successCount = 0;
      // Duyệt qua danh sách ảnh để xử lý những ảnh được đánh dấu chọn
      for (int i = 0; i < widget.photos.length; i++) {
        if (_selectedPhotos[i]) {
          // Gọi Database để cập nhật productId và trạng thái ảnh
          await _photoDao.assignToProduct(
            widget.photos[i].filePath,
            _selectedProduct!.id!,
            newStatus: PhotoStatus.ready,
          );
          successCount++;
        }
      }

      // Thông báo thành công và quay lại màn hình trước
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gán $successCount ảnh thành công')),
        );
        Navigator.pop(
          context,
          true,
        ); // Trả về giá trị true để màn hình trước biết cần refresh
      }
    } catch (e) {
      // Xử lý và hiển thị lỗi nếu có vấn đề với Database
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Đảm bảo tắt loading dù thành công hay thất bại
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm xử lý chọn/hủy chọn tất cả ảnh cùng lúc
  void _selectAll(bool? value) {
    setState(() {
      for (int i = 0; i < _selectedPhotos.length; i++) {
        _selectedPhotos[i] = value ?? false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chỉnh sửa hàng loạt (${widget.photos.length} ảnh)'),
        actions: [
          // Nút lưu (hình tích check) trên thanh AppBar
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _assignToProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Phần UI chọn sản phẩm và "Chọn tất cả"
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gán cho sản phẩm:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Dropdown danh sách sản phẩm
                      DropdownButtonFormField<Product>(
                        initialValue: _selectedProduct,
                        hint: const Text('Chọn sản phẩm'),
                        items: widget.products.map((product) {
                          return DropdownMenuItem<Product>(
                            value: product,
                            child: Text(
                              '${product.name} (${product.category})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProduct = value;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Checkbox điều khiển "Chọn tất cả"
                      Row(
                        children: [
                          Checkbox(
                            value: _selectedPhotos.every(
                              (e) => e,
                            ), // Kiểm tra nếu mọi ảnh đều được chọn
                            onChanged: _selectAll,
                          ),
                          const Text('Chọn tất cả'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Phần danh sách ảnh hiển thị dạng lưới
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: widget.photos.length,
                    itemBuilder: (context, index) {
                      final photo = widget.photos[index];
                      return GestureDetector(
                        onTap: () {
                          // Đảo ngược trạng thái chọn của ảnh khi nhấn vào
                          setState(() {
                            _selectedPhotos[index] = !_selectedPhotos[index];
                          });
                        },
                        child: Stack(
                          children: [
                            // Hiển thị nội dung ảnh
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedPhotos[index]
                                      ? Colors
                                            .blue // Viền xanh nếu được chọn
                                      : Colors.grey,
                                  width: _selectedPhotos[index] ? 3 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(photo.filePath),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            // Biểu tượng dấu check overlay trên ảnh khi được chọn
                            if (_selectedPhotos[index])
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
