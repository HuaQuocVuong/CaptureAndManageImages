import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/database/product_dao.dart';

import 'package:module_s1/models/product_model.dart';
import 'package:module_s1/models/photo_model.dart';

import 'package:module_s1/metadata/thousands_separator_input_fomatter.dart';
import 'package:module_s1/metadata/constants/metadata_constants.dart';
import 'package:module_s1/metadata/utils/price_formatter.dart';
import 'package:module_s1/metadata/widgets/suggestion_chip.dart';

class BatchMetadataForm extends StatefulWidget {
  final List<PhotoTask> photos; // Danh sách ảnh cần cập nhật metadata
  final List<Product> recentProducts; // Sản phẩm gần đây

  const BatchMetadataForm({
    super.key,
    required this.photos,
    required this.recentProducts,
  });

  @override
  State<BatchMetadataForm> createState() => _BatchMetadataFormState();
}

class _BatchMetadataFormState extends State<BatchMetadataForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers cho các trường nhập liệu
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategory;
  bool _isLoading = false;
  bool _useExistingProduct = false;
  Product? _selectedProduct;

  List<Product> _recentProducts = [];

  final PhotoDao _photoDao = PhotoDao();
  final ProductDao _productDao = ProductDao();

  @override
  void initState() {
    super.initState();
    _loadRecentProducts();
  }

  // Tải danh sách sản phẩm gần đây
  Future<void> _loadRecentProducts() async {
    try {
      //final products = await _productDao.getAll();
      final products = await _productDao.getAll();
      if (mounted) {
        setState(() {
          _recentProducts = products.take(10).toList(); // Lưu vào state
        });
      }
    } catch (e) {
      debugPrint('Lỗi load sản phẩm: $e');
    }
  }

  // Điền thông tin sản phẩm đã chọn vào form
  void _loadProductDetails(Product product) {
    setState(() {
      _selectedProduct = product;
      _useExistingProduct = true;
      _nameController.text = product.name;
      _selectedCategory = product.category;
      if (product.price != null) {
        _priceController.text = PriceFormatter.formatForDisplay(product.price!);
      }
      _noteController.text = product.note ?? '';
    });
  }

  // Xóa form
  void _clearForm() {
    setState(() {
      _useExistingProduct = false;
      _selectedProduct = null;
      _nameController.clear();
      _priceController.clear();
      _noteController.clear();
      _selectedCategory = null;
    });
  }

  // Kiểm tra giá
  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) return null;
    final numberString = value.replaceAll('.', '');
    final price = double.tryParse(numberString);
    if (price == null) return 'Giá không hợp lệ';
    if (price < 0) return 'Giá không thể âm';
    if (price > 1000000000) return 'Giá quá lớn';
    return null;
  }

  // Lưu metadata cho TẤT CẢ ảnh trong batch
  Future<void> _saveBatchMetadata() async {
    if (!_formKey.currentState!.validate()) return;

    // Kiểm tra có ảnh nào không
    if (widget.photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có ảnh nào để lưu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      int productId;
      final rawPrice = _priceController.text.replaceAll('.', '');
      final priceValue = rawPrice.isEmpty ? null : double.tryParse(rawPrice);

      // Xử lý sản phẩm
      if (_useExistingProduct && _selectedProduct != null) {
        // Cập nhật sản phẩm đã tồn tại
        productId = _selectedProduct!.id!;
        final updatedProduct = _selectedProduct!.copyWith(
          name: _nameController.text.isNotEmpty
              ? _nameController.text
              : _selectedProduct!.name,
          category: _selectedCategory ?? _selectedProduct!.category,
          price: priceValue ?? _selectedProduct!.price,
          note: _noteController.text.isNotEmpty
              ? _noteController.text
              : _selectedProduct!.note,
        );
        await _productDao.update(updatedProduct);
      } else {
        // Tạo sản phẩm mới
        final product = Product(
          name: _nameController.text,
          category: _selectedCategory!,
          price: priceValue,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );
        productId = await _productDao.insert(product);
      }

      // LƯU METADATA CHO TẤT CẢ ẢNH
      int successCount = 0;
      for (var photo in widget.photos) {
        try {
          await _photoDao.updatePhotoMetadata(
            int.parse(photo.id),
            productId: productId,
            title: _nameController.text.isNotEmpty
                ? _nameController.text
                : null,
            description: _noteController.text.isNotEmpty
                ? _noteController.text
                : null,
            category: _selectedCategory,
            price: priceValue,
            note: _noteController.text.isNotEmpty ? _noteController.text : null,
            status: PhotoStatus.ready,
          );
          successCount++;
        } catch (e) {
          debugPrint('Lỗi cập nhật ảnh ${photo.id}: $e');
        }
      }

      if (!mounted) return;

      // Hiển thị kết quả
      if (successCount == widget.photos.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu metadata cho $successCount ảnh'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chỉ lưu được $successCount/${widget.photos.length} ảnh',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Lỗi lưu batch: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
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
            content: Text(
              'Bạn đang chỉnh sửa ${widget.photos.length} ảnh. '
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
          title: Text('Nhập metadata cho ${widget.photos.length} ảnh'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _clearForm,
              tooltip: 'Làm mới form',
            ),
          ],
        ),
        body: Stack(
          children: [
            Scrollbar(
              thumbVisibility: true,
              radius: const Radius.circular(10),
              thickness: 8,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hiển thị danh sách thumbnail của các ảnh
                      _buildThumbnailList(),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      // Thông báo số lượng ảnh
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Metadata sẽ được áp dụng cho tất cả ${widget.photos.length} ảnh',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Phần chọn sản phẩm có sẵn
                      if (widget.recentProducts.isNotEmpty)
                        _buildRecentProductsSection(),

                      // Form nhập metadata
                      _buildNameField(),
                      const SizedBox(height: 15),
                      _buildCategoryDropdown(),
                      const SizedBox(height: 15),
                      _buildPriceField(),
                      const SizedBox(height: 5),
                      _buildPriceSuggestions(),
                      const SizedBox(height: 15),
                      _buildNoteField(),
                      const SizedBox(height: 5),
                      _buildNoteSuggestions(),
                      const SizedBox(height: 30),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  // Hiển thị danh sách thumbnail của các ảnh
  Widget _buildThumbnailList() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.photos.length > 10 ? 10 : widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // Sửa lại _buildRecentProductsSection dùng _recentProducts
  Widget _buildRecentProductsSection() {
    if (_recentProducts.isEmpty) return const SizedBox.shrink();

    return Column(
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
                  selected: _selectedProduct?.id == product.id,
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
    );
  }

  // Ô nhập tên
  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Tên sản phẩm',
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
        border: OutlineInputBorder(),
        hintText: 'Nhập tên sản phẩm',
      ),
      validator: (value) {
        if (!_useExistingProduct && (value == null || value.isEmpty)) {
          return 'Vui lòng nhập tên sản phẩm';
        }
        return null;
      },
    );
  }

  // Dropdown danh mục
  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Danh mục',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('-- Chọn danh mục --')),
        ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
      ],
      onChanged: (val) => setState(() => _selectedCategory = val),
      validator: (value) {
        if (!_useExistingProduct && value == null) {
          return 'Vui lòng chọn danh mục';
        }
        return null;
      },
    );
  }

  // Ô nhập giá
  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        ThousandsSeparatorInputFormatter(),
      ],
      decoration: const InputDecoration(
        labelText: 'Giá sản phẩm',
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
        border: OutlineInputBorder(),
        hintText: 'Nhập giá sản phẩm',
      ),
      validator: _validatePrice,
    );
  }

  // Gợi ý giá
  Widget _buildPriceSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: priceSuggestions.map((item) {
        return PriceSuggestionChip(
          label: item.label,
          value: item.value,
          enabled: true,
          onTap: (value) {
            setState(() {
              _priceController.text = PriceFormatter.formatNumber(
                value.toString(),
              );
            });
          },
        );
      }).toList(),
    );
  }

  // Ô nhập ghi chú
  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Ghi chú',
        border: OutlineInputBorder(),
        hintText: 'Nhập ghi chú...',
        alignLabelWithHint: true,
      ),
    );
  }

  // Gợi ý ghi chú
  Widget _buildNoteSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: noteSuggestions.map((text) {
        return NoteSuggestionChip(
          label: text,
          enabled: true,
          onTap: () {
            setState(() {
              _noteController.text = text;
            });
          },
        );
      }).toList(),
    );
  }

  // Nút lưu
  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveBatchMetadata,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'LƯU CHO TẤT CẢ ẢNH',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }

  // Overlay loading
  Widget _buildLoadingOverlay() {
    return Container(
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
                Text('Đang lưu metadata cho tất cả ảnh...'),
              ],
            ),
          ),
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
