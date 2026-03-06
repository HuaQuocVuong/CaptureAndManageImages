import 'dart:io';

import 'package:flutter/material.dart';
import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/database/product_dao.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/models/product_model.dart';

// Form nhập metadata sau khi chụp ảnh, gồm: tên sản phẩm, danh mục, giá, ghi chú
class MetadataForm extends StatefulWidget {
  final String imagePath; // Đường dẫn đến ảnh vừa chụp
  final int?
  photoId; // ID của ảnh trong database (có thể null nếu ảnh chưa lưu)

  const MetadataForm({
    super.key,
    required this.imagePath,
    this.photoId, // Tham số không bắt buộc
  });

  @override
  State<MetadataForm> createState() => _MetadataFormState();
}

class _MetadataFormState extends State<MetadataForm> {
  // Key để quản lý form validation
  final _formKey = GlobalKey<FormState>();

  // Controllers cho các trường nhập liệu
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // Danh mục được chọn và danh sách các danh mục có sẵn
  String? _selectedCategory;
  final List<String> _categories = [
    'Điện thoại',
    'Laptop',
    'Máy tính bảng',
    'Phụ kiện',
    'Thời trang',
    'Đồ gia dụng',
    'Sách',
    'Khác',
  ];

  // DAO objects để tương tác với database
  final ProductDao _productDao = ProductDao();
  final PhotoDao _photoDao = PhotoDao();

  // State quản lý
  bool _isLoading = false;
  bool _isEditMode = false;
  Product? _existingProduct;
  List<Product> _recentProducts = [];
  bool _useExistingProduct = false;

  @override
  void initState() {
    super.initState();
    _loadRecentProducts();
    _checkIfPhotoExists();
  }

  // Kiểm tra xem ảnh đã tồn tại trong database chưa
  Future<void> _checkIfPhotoExists() async {
    if (widget.photoId != null) {
      setState(() => _isEditMode = true);
    }
  }

  // Load danh sách sản phẩm gần đây
  Future<void> _loadRecentProducts() async {
    try {
      final products = await _productDao.getAll();
      setState(() {
        _recentProducts = products.take(10).toList();
      });
    } catch (e) {
      print('Lỗi load sản phẩm: $e');
    }
  }

  // Load thông tin sản phẩm có sẵn
  Future<void> _loadProductDetails(Product product) async {
    setState(() {
      _existingProduct = product;
      _useExistingProduct = true;
      _nameController.text = product.name;
      _selectedCategory = product.category;
      _priceController.text = product.price?.toString() ?? '';
      _noteController.text = product.note ?? '';
    });
  }

  // Xóa form
  void _clearForm() {
    setState(() {
      _useExistingProduct = false;
      _existingProduct = null;
      _nameController.clear();
      _priceController.clear();
      _noteController.clear();
      _selectedCategory = null;
    });
  }

  // Validate giá
  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) return null;

    final price = double.tryParse(value);
    if (price == null) {
      return 'Giá không hợp lệ';
    }
    if (price < 0) {
      return 'Giá không thể âm';
    }
    return null;
  }

  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      int productId;

      if (_useExistingProduct && _existingProduct != null) {
        // Sử dụng sản phẩm có sẵn
        productId = _existingProduct!.id!;

        // Cập nhật thông tin sản phẩm nếu có thay đổi
        if (_nameController.text.isNotEmpty) {
          final updatedProduct = _existingProduct!.copyWith(
            name: _nameController.text,
            category: _selectedCategory ?? _existingProduct!.category,
            price:
                double.tryParse(_priceController.text) ??
                _existingProduct!.price,
            note: _noteController.text.isNotEmpty
                ? _noteController.text
                : _existingProduct!.note,
          );
          await _productDao.update(updatedProduct);
        }
      } else {
        // Tạo sản phẩm mới
        final product = Product(
          name: _nameController.text,
          category: _selectedCategory!,
          price: double.tryParse(_priceController.text),
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );
        productId = await _productDao.insert(product);
      }

      // Cập nhật ảnh
      if (widget.photoId != null) {
        // Nếu ảnh đã có trong database, cập nhật thông tin
        await _photoDao.assignToProduct(
          widget.imagePath,
          productId,
          //newStatus: PhotoStatus.ready,
        );
      } else {
        // Nếu ảnh chưa có trong database, thêm mới
        final photoId = await _photoDao.insert(widget.imagePath);
        await _photoDao.assignToProduct(
          widget.imagePath,
          productId,
          //newStatus: PhotoStatus.ready,
        );
      }

      if (!mounted) return;

      // Hiển thị thông báo thành công
      //ScaffoldMessenger.of(context).showSnackBar(
      //  SnackBar(
      //    content: Text('Lưu sản phẩm thành công'),
      //    backgroundColor: Colors.green,
      //    behavior: SnackBarBehavior.floating,
      //  ),
      //);

      // Quay lại màn hình trước
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) return false;

        // Hỏi người dùng có muốn hủy không
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hủy nhập liệu?'),
            content: const Text(
              'Thông tin sẽ không được lưu. Bạn có chắc muốn thoát?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('KHÔNG'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('CÓ'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditMode ? 'Chỉnh sửa thông tin' : 'Nhập thông tin sản phẩm',
          ),
          actions: [
            if (!_isEditMode)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _clearForm,
                tooltip: 'Làm mới form',
              ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hiển thị ảnh vừa chụp
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(widget.imagePath),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (_isEditMode)
                            const Positioned(
                              top: 10,
                              right: 10,
                              child: CircleAvatar(
                                backgroundColor: Colors.deepOrangeAccent,
                                radius: 15,
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Chọn sản phẩm có sẵn (nếu có)
                    if (_recentProducts.isNotEmpty && !_isEditMode)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hoặc chọn sản phẩm có sẵn:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _recentProducts.length,
                              itemBuilder: (ctx, index) {
                                final product = _recentProducts[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(product.name),
                                    selected:
                                        _existingProduct?.id == product.id,
                                    onSelected: (selected) {
                                      if (selected) {
                                        _loadProductDetails(product);
                                      } else {
                                        _clearForm();
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                        ],
                      ),

                    // Trường nhập tên sản phẩm
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText:
                            'Tên sản phẩm ${_useExistingProduct ? '' : '*'}',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.shopping_bag),
                        hintText: 'Nhập tên sản phẩm',
                        enabled: !_useExistingProduct || _isEditMode,
                      ),
                      validator: (value) {
                        if (!_useExistingProduct &&
                            (value == null || value.isEmpty)) {
                          return 'Vui lòng nhập tên sản phẩm';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Dropdown chọn danh mục
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Danh mục ${_useExistingProduct ? '' : '*'}',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('-- Chọn danh mục --'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: _useExistingProduct && !_isEditMode
                          ? null
                          : (val) => setState(() => _selectedCategory = val),
                      validator: (value) {
                        if (!_useExistingProduct && value == null) {
                          return 'Vui lòng chọn danh mục';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Trường nhập giá
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá sản phẩm (VNĐ)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        hintText: 'Nhập giá sản phẩm',
                      ),
                      validator: _validatePrice,
                      enabled: !_useExistingProduct || _isEditMode,
                    ),
                    const SizedBox(height: 15),

                    // Trường nhập ghi chú
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                        hintText: 'Nhập ghi chú (không bắt buộc)',
                        alignLabelWithHint: true,
                      ),
                      enabled: !_useExistingProduct || _isEditMode,
                    ),
                    const SizedBox(height: 30),

                    // Nút xác nhận
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveMetadata,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isEditMode ? 'CẬP NHẬT' : 'LƯU & TIẾP TỤC CHỤP',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isEditMode
                              ? Colors.lightGreen
                              : Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    if (!_isEditMode) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('CHỤP ẢNH KHÁC'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Đang lưu...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
