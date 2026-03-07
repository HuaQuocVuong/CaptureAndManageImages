import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/database/product_dao.dart';
import 'package:module_s1/models/product_model.dart';
import 'package:module_s1/metadata/thousands_separator_input_fomatter.dart'; // SỬA LỖI CHÍNH TẢ

class MetadataForm extends StatefulWidget {
  final String imagePath;
  final int? photoId;

  const MetadataForm({super.key, required this.imagePath, this.photoId});

  @override
  State<MetadataForm> createState() => _MetadataFormState();
}

class _MetadataFormState extends State<MetadataForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategory;
  final List<String> _categories = [
    'Đồ điện tử',
    'Thời trang',
    'Đồ gia dụng',
    'Sách',
    'Khác',
  ];

  final ProductDao _productDao = ProductDao();
  final PhotoDao _photoDao = PhotoDao();

  bool _isLoading = false;
  bool _isEditMode = false;
  Product? _existingProduct; // Sản phẩm đã tồn tại
  List<Product> _recentProducts = []; // Danh sách sản phẩm gần đây
  bool _useExistingProduct = false;

  @override
  void initState() {
    super.initState();
    _loadRecentProducts(); // Tải sản phẩm gần đây
    _checkIfPhotoExists(); // Kiểm tra ảnh đã tồn tại
  }

  Future<void> _checkIfPhotoExists() async {
    if (widget.photoId != null) {
      setState(() => _isEditMode = true);
    }
  }

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

  String _formatWithSeparator(String digits) {
    if (digits.isEmpty) return '';
    final reversed = digits.split('').reversed.join();
    final buffer = StringBuffer();
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(reversed[i]);
    }
    return buffer.toString().split('').reversed.join('');
  }

  String _formatPriceForDisplay(double? price) {
    if (price == null) return '';
    final intPart = price.toInt();
    if (price == intPart) {
      return _formatWithSeparator(intPart.toString());
    } else {
      final parts = price.toStringAsFixed(2).split('.');
      final intFormatted = _formatWithSeparator(parts[0]);
      return '$intFormatted.${parts[1]}';
    }
  }

  Future<void> _loadProductDetails(Product product) async {
    setState(() {
      _existingProduct = product;
      _useExistingProduct = true;
      _nameController.text = product.name;
      _selectedCategory = product.category;
      _priceController.text = _formatPriceForDisplay(product.price);
      _noteController.text = product.note ?? '';
    });
  }

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

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) return null;

    final numberString = value.replaceAll('.', '');
    final price = double.tryParse(numberString);

    if (price == null) {
      return 'Giá không hợp lệ';
    }
    if (price < 0) {
      return 'Giá không thể âm';
    }
    if (price > 1000000000) {
      return 'Giá quá lớn';
    }
    return null;
  }

  Widget _buildSuggestionChip(String displayText, int value) {
    return ActionChip(
      label: Text(
        displayText,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      backgroundColor: Colors.grey.shade100,
      onPressed: (_useExistingProduct && !_isEditMode)
          ? null
          : () {
              setState(() {
                _priceController.text = _formatWithSeparator(value.toString());
              });
            },
      elevation: 0,
    );
  }

  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      int productId;
      final rawPrice = _priceController.text.replaceAll('.', '');
      final priceValue = double.tryParse(rawPrice);

      if (_useExistingProduct && _existingProduct != null) {
        productId = _existingProduct!.id!;

        if (_nameController.text.isNotEmpty) {
          final updatedProduct = _existingProduct!.copyWith(
            name: _nameController.text,
            category: _selectedCategory ?? _existingProduct!.category,
            price: priceValue ?? _existingProduct!.price,
            note: _noteController.text.isNotEmpty
                ? _noteController.text
                : _existingProduct!.note,
          );
          await _productDao.update(updatedProduct);
        }
      } else {
        final product = Product(
          name: _nameController.text,
          category: _selectedCategory!,
          price: priceValue,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );
        productId = await _productDao.insert(product);
      }

      if (widget.photoId != null) {
        await _photoDao.assignToProduct(widget.imagePath, productId);
      } else {
        await _photoDao.insert(widget.imagePath);
        await _photoDao.assignToProduct(widget.imagePath, productId);
      }

      if (!mounted) return;
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

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hủy nhập liệu?'),
            content: const Text(
              'Thông tin sẽ không được lưu khi bạn hủy. Bạn có chắc chắn muốn thoát?',
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

                    // Chọn sản phẩm có sẵn
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Giá sản phẩm',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        hintText: 'Nhập giá sản phẩm',
                      ),
                      validator: _validatePrice,
                      enabled: !_useExistingProduct || _isEditMode,
                    ),
                    const SizedBox(height: 5),

                    // GỢI Ý GIÁ NHANH (màu xám)
                    if (!_useExistingProduct || _isEditMode)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSuggestionChip('1.000', 1000),
                          _buildSuggestionChip('10.000', 10000),
                          _buildSuggestionChip('100.000', 100000),
                          _buildSuggestionChip('1.000.000', 1000000),
                          _buildSuggestionChip('10.000.000', 10000000),
                        ],
                      ),
                    const SizedBox(height: 15),

                    // Trường nhập ghi chú (CHỈ 1 LẦN)
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                        hintText: 'Nhập ghi chú...',
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
