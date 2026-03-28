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
import 'metadata_form.dart';

class MetadataFormState extends State<MetadataForm> {
  // Khóa form để xác thực(validate)
  final _formKey = GlobalKey<FormState>();

  // Controllers cho các trường nhập liệu
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategory; // Danh mục được chọn

  // DAOs
  final ProductDao _productDao = ProductDao();
  final PhotoDao _photoDao = PhotoDao();

  // Trạng thái UI
  bool _isLoading = false; // Đang xử lý lưu
  bool _isEditMode = false; // Chế độ chỉnh sửa (có photoId)
  Product? _existingProduct; // Sản phẩm hiện tại nếu đã có
  List<Product> _recentProducts = []; // Sản phẩm gần đây để gợi ý
  bool _useExistingProduct = false; // Đang sử dụng sản phẩm có sẵn
  bool _isInitialLoading = false; // Đang tải dữ liệu ban đầu

  @override
  void initState() {
    super.initState();
    _loadRecentProducts();
    _loadExistingData();
  }

  // Load thông tin ảnh hiện có (nếu ở chế độ chỉnh sửa)
  Future<void> _loadExistingData() async {
    if (widget.photoId == null) return;

    setState(() {
      _isEditMode = true;
      _isInitialLoading = true;
    });

    try {
      final photo = await _photoDao.getPhotoById(widget.photoId.toString());
      if (photo != null && mounted) {
        setState(() {
          _nameController.text = photo.title ?? '';
          _selectedCategory = photo.category;
          _noteController.text = photo.note ?? '';
          if (photo.price != null) {
            _priceController.text = PriceFormatter.formatForDisplay(
              photo.price!,
            );
          }
        });

        if (photo.productId != null) {
          await _loadProductFromId(photo.productId!);
        }
      }
    } catch (e) {
      debugPrint('Lỗi load dữ liệu ảnh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải thông tin ảnh: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  // Lấy thông tin sản phẩm từ ID (khi ảnh đã được gán sản phẩm)
  Future<void> _loadProductFromId(int productId) async {
    try {
      final product = await _productDao.getById(productId);
      if (product != null && mounted) {
        setState(() {
          _existingProduct = product;
          _useExistingProduct = true;
        });
      }
    } catch (e) {
      debugPrint('Lỗi load sản phẩm: $e');
    }
  }

  // Tải danh sách sản phẩm gần đây (tối đa 10)
  Future<void> _loadRecentProducts() async {
    try {
      final products = await _productDao.getAll();
      if (mounted) {
        setState(() {
          _recentProducts = products.take(10).toList();
        });
      }
    } catch (e) {
      debugPrint('Lỗi load sản phẩm: $e');
    }
  }

  // Điền thông tin sản phẩm đã chọn vào form
  Future<void> _loadProductDetails(Product product) async {
    setState(() {
      _existingProduct = product;
      _useExistingProduct = true;
      _nameController.text = product.name;
      _selectedCategory = product.category;
      _priceController.text = PriceFormatter.formatForDisplay(product.price);
      _noteController.text = product.note ?? '';
    });
  }

  // Xóa toàn bộ form, chuyển sang chế độ tạo sản phẩm mới
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

  // Kiểm tra giá trị nhập vào ô giá
  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) return null;
    final numberString = value.replaceAll('.', '');
    final price = double.tryParse(numberString);
    if (price == null) return 'Giá không hợp lệ';
    if (price < 0) return 'Giá không thể âm';
    if (price > 1000000000) return 'Giá quá lớn';
    return null;
  }

  // Lưu metadata: tạo/cập nhật sản phẩm và ghi vào bảng photos
  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      int productId;
      final rawPrice = _priceController.text.replaceAll('.', '');
      final priceValue = rawPrice.isEmpty ? null : double.tryParse(rawPrice);

      if (_useExistingProduct && _existingProduct != null) {
        // Cập nhật sản phẩm đã tồn tại
        productId = _existingProduct!.id!;
        final updatedProduct = _existingProduct!.copyWith(
          name: _nameController.text.isNotEmpty
              ? _nameController.text
              : _existingProduct!.name,
          category: _selectedCategory ?? _existingProduct!.category,
          price: priceValue ?? _existingProduct!.price,
          note: _noteController.text.isNotEmpty
              ? _noteController.text
              : _existingProduct!.note,
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
      // Lưu hoặc cập nhật thông tin ảnh
      if (widget.photoId != null) {
        await _photoDao.updatePhotoMetadata(
          widget.photoId!,
          productId: productId,
          title: _nameController.text.isNotEmpty ? _nameController.text : null,
          description: _noteController.text.isNotEmpty
              ? _noteController.text
              : null,
          category: _selectedCategory,
          price: priceValue,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
          status: PhotoStatus.ready,
        );
      } else {
        await _photoDao.insertWithMetadata(
          imagePath: widget.imagePath,
          productId: productId,
          title: _nameController.text.isNotEmpty ? _nameController.text : null,
          description: _noteController.text.isNotEmpty
              ? _noteController.text
              : null,
          category: _selectedCategory,
          price: priceValue,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
          status: PhotoStatus.ready,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lưu thông tin thành công'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Lỗi lưu: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // CÁC PHƯƠNG THỨC XÂY DỰNG UI
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
        body: _isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
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
                            _buildImagePreview(),
                            const SizedBox(height: 20),
                            if (_recentProducts.isNotEmpty && !_isEditMode)
                              _buildRecentProductsSection(),
                            _buildNameField(),
                            const SizedBox(height: 15),
                            _buildCategoryDropdown(),
                            const SizedBox(height: 15),
                            _buildPriceField(),
                            const SizedBox(height: 5),
                            if (!_useExistingProduct || _isEditMode)
                              _buildPriceSuggestions(),
                            const SizedBox(height: 15),
                            _buildNoteField(),
                            const SizedBox(height: 5),
                            if (!_useExistingProduct || _isEditMode)
                              _buildNoteSuggestions(),
                            const SizedBox(height: 30),
                            _buildActionButtons(),
                            if (!_isEditMode) _buildRetakeButton(),
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

  // Hiển thị ảnh xem trước
  Widget _buildImagePreview() {
    return Center(
      child: Container(
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
    );
  }

  // Danh sách sản phẩm gần đây để chọn nhanh
  Widget _buildRecentProductsSection() {
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
                  selected: _existingProduct?.id == product.id,
                  onSelected: (selected) {
                    if (selected)
                      _loadProductDetails(product);
                    else
                      _clearForm();
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

  // Ô nhập tên sản phẩm
  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Tên sản phẩm',
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        border: const OutlineInputBorder(),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/Category_Icon_001.svg',
            width: 24,
            height: 24,
          ),
        ),
        hintText: 'Nhập tên sản phẩm',
      ),
      enabled: !_useExistingProduct || _isEditMode,
      validator: (value) {
        if (!_useExistingProduct && (value == null || value.isEmpty))
          return 'Vui lòng nhập tên sản phẩm';
        return null;
      },
    );
  }

  // Dropdown chọn danh mục
  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Danh mục',
        border: const OutlineInputBorder(),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/Product_Icon_001.svg',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('-- Chọn danh mục --')),
        ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
      ],
      onChanged: (_useExistingProduct && !_isEditMode)
          ? null
          : (val) => setState(() => _selectedCategory = val),
      validator: (value) {
        if (!_useExistingProduct && value == null)
          return 'Vui lòng chọn danh mục';
        return null;
      },
    );
  }

  // Ô nhập giá với bộ lọc và format
  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        ThousandsSeparatorInputFormatter(),
      ],
      decoration: InputDecoration(
        labelText: 'Giá sản phẩm',
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        border: const OutlineInputBorder(),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/Money_Icon_001.svg',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
        hintText: 'Nhập giá sản phẩm',
      ),
      validator: _validatePrice,
      enabled: !_useExistingProduct || _isEditMode,
    );
  }

  // Các chip gợi ý giá
  Widget _buildPriceSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: priceSuggestions.map((item) {
        return PriceSuggestionChip(
          label: item.label,
          value: item.value,
          enabled: !_useExistingProduct || _isEditMode,
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

  // Các chip gợi ý ghi chú
  Widget _buildNoteSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: noteSuggestions.map((text) {
        return NoteSuggestionChip(
          label: text,
          enabled: !_useExistingProduct || _isEditMode,
          onTap: () {
            setState(() {
              _noteController.text = text;
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
      decoration: InputDecoration(
        labelText: 'Ghi chú',
        border: const OutlineInputBorder(),
        prefixIcon: Transform.translate(
          offset: const Offset(0, -29),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/Note_Icon_001.svg',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          ),
        ),
        hintText: 'Nhập ghi chú...',
        alignLabelWithHint: true,
      ),
      enabled: !_useExistingProduct || _isEditMode,
    );
  }

  // Nút chính: Lưu hoặc Cập nhật
  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveMetadata,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEditMode ? Colors.lightGreen : Colors.blue,
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
            : Text(
                _isEditMode ? 'CẬP NHẬT' : 'LƯU & TIẾP TỤC CHỤP',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  // Nút chụp ảnh khác (chỉ hiển thị khi tạo mới)
  Widget _buildRetakeButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: TextButton.icon(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.camera_alt),
          label: const Text('CHỤP ẢNH KHÁC'),
        ),
      ),
    );
  }

  // Lớp phủ hiển thị khi đang lưu
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
                Text('Đang lưu...'),
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
