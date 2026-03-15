import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/database/product_dao.dart';
import 'package:module_s1/models/product_model.dart';
import 'package:module_s1/metadata/thousands_separator_input_fomatter.dart';

//Màn hình form nhập thông tin metadata cho ảnh vừa chụp.
class MetadataForm extends StatefulWidget {
  final String imagePath; // Đường dẫn đến file ảnh vừa chụp
  final int? photoId; // ID của ảnh nếu đã tồn tại (chế độ chỉnh sửa)

  const MetadataForm({super.key, required this.imagePath, this.photoId});

  @override
  State<MetadataForm> createState() => _MetadataFormState();
}

class _MetadataFormState extends State<MetadataForm> {
  final _formKey = GlobalKey<FormState>();

  //Controllers cho các trường nhập liệu
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategory; // Danh mục được chọn
  final List<String> _categories = const [
    'Đồ điện tử',
    'Thời trang',
    'Đồ gia dụng',
    'Sách',
    'Khác',
  ];

  // Khởi tạo các đối tượng truy cập dữ liệu
  final ProductDao _productDao = ProductDao();
  final PhotoDao _photoDao = PhotoDao();

  bool _isLoading = false; //Trạng thái khi thực hiện lưu vào database
  bool _isEditMode = false; //Xác định là cập nhật ảnh cũ hay thêm mới
  Product?
  _existingProduct; // Lưu trữ thông tin sản phẩm nếu chọn từ danh sách có sẵn
  List<Product> _recentProducts = []; // Danh sách gợi ý sản phẩm đã tạo gần đây
  bool _useExistingProduct =
      false; // Cờ xác định có đang dùng dữ liệu sản phẩm cũ hay không
  bool _isInitialLoading =
      false; //Trạng thái load dữ liệu từ Database lên Form khi bắt đầu

  @override
  void initState() {
    super.initState();
    // Luồng khởi tạo dữ liệu ban đầu
    _loadRecentProducts();
    _loadExistingData();
  }

  //Tải dữ liệu Metadata từ Database nếu photoID tồn tại
  //Mapping từ PhotoModel sang các Controller hiển thị trên UI.
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
            _priceController.text = _formatPriceForDisplay(photo.price!);
          }
        });

        // Nếu ảnh đã được gán cho sản phẩm, load thông tin sản phẩm
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

  //Lấy thông tin sản phẩm cụ thể theo ID
  Future<void> _loadProductFromId(int productId) async {
    try {
      // Giả sử ProductDao có phương thức getProduct(id)
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

  //Lấy 10 sản phẩm mới nhất để làm danh sách chọn nhanh (Quick-select).
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

  //Xử lý định dạng chuỗi số có dấu chấm phân cách
  String _formatWithSeparator(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  //Chuyển đổi từ Double (Database) sang String (UI) có định dạng
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

  //Tự động điền dữ liệu vào Form khi người dùng chọn sản phẩm có sẵn
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

  //Reset toàn bộ trạng thái của Form về mặc định
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

  //Ràng buộc dữ liệu nhập cho trường Giá (Price Validation).
  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) return null;
    final numberString = value.replaceAll('.', '');
    final price = double.tryParse(numberString);
    if (price == null) return 'Giá không hợp lệ';
    if (price < 0) return 'Giá không thể âm';
    if (price > 1000000000) return 'Giá quá lớn';
    return null;
  }

  //XỬ LÝ LƯU TRỮ
  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      int productId;
      final rawPrice = _priceController.text.replaceAll('.', '');
      final priceValue = rawPrice.isEmpty ? null : double.tryParse(rawPrice);

      //Xử lý bảng sản phẩm
      if (_useExistingProduct && _existingProduct != null) {
        productId = _existingProduct!.id!;
        // Cập nhật sản phẩm nếu có thay đổi
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

      //Xử lý bảng hình ảnh
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

  @override
  Widget build(BuildContext context) {
    //WillPopScope ngăn người dùng thoát vô ý khi đang nhập liệu hoặc đang lưu.
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
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImagePreview(), //Phần xem trước hình ảnh
                          const SizedBox(height: 20),
                          if (_recentProducts.isNotEmpty && !_isEditMode)
                            _buildRecentProductsSection(), //Gợi ý sản phẩm nhanh
                          _buildNameField(),
                          const SizedBox(height: 15),
                          _buildCategoryDropdown(),
                          const SizedBox(height: 15),
                          _buildPriceField(),
                          const SizedBox(height: 5),
                          if (!_useExistingProduct || _isEditMode)
                            _buildPriceSuggestions(), //Phần gợi ý giá tiền
                          const SizedBox(height: 15),
                          _buildNoteField(),
                          const SizedBox(height: 30),
                          _buildActionButtons(),
                          if (!_isEditMode) _buildRetakeButton(),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading)
                    _buildLoadingOverlay(), //Hiệu ứng loading đè lên màn hình
                ],
              ),
      ),
    );
  }

  // Các Widget con được Module hóa
  //Hiển thi ảnh vừa chụp được
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

  //Hiển thị hàng ngang các sản phẩm đã có trong Database
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

  //Nhập tên sản phẩm
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
        if (!_useExistingProduct && (value == null || value.isEmpty)) {
          return 'Vui lòng nhập tên sản phẩm';
        }
        return null;
      },
    );
  }

  //Dropdown chọn danh mục sản phẩm
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
        ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
      ],
      onChanged: (_useExistingProduct && !_isEditMode)
          ? null
          : (val) => setState(() => _selectedCategory = val),
      validator: (value) {
        if (!_useExistingProduct && value == null) {
          return 'Vui lòng chọn danh mục';
        }
        return null;
      },
    );
  }

  //Trường nhập giá với Format phân cách hàng nghìn
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

  //Các chip gợi ý nhanh các mức tiền phổ biến trong bán hàng
  Widget _buildPriceSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _SuggestionChip(label: '19.999', value: 19000),
        _SuggestionChip(label: '49.999', value: 49999),
        _SuggestionChip(label: '99.999', value: 99999),
        _SuggestionChip(label: '199.999', value: 199999),
        _SuggestionChip(label: '999.999', value: 999999),
      ],
    );
  }

  //Trường nhập ghi chú tự do
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

  //Nút kích hoạt lệnh lưu Metadata
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

  //Nút thoát ra để thực hiện lại thao tác chụp ảnh
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

  //Lớp phủ màu đen mờ khi đang trong quá trình xử lý Database
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

  //Giải phóng bộ nhớ của các Controller để tránh Memory Leak
  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}

//Thành phần UI con dùng để hiển thị chip gợi ý giá
//Tự động định dạng giá trị được chọn và đẩy vào Controller của lớp cha
class _SuggestionChip extends StatelessWidget {
  final String label;
  final int value;

  const _SuggestionChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_MetadataFormState>();
    final isEnabled =
        !(state?._useExistingProduct ?? false) || (state?._isEditMode ?? false);

    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(
          color: Color.fromARGB(255, 150, 150, 150),
          fontSize: 13,
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 213, 234, 253),
      onPressed: isEnabled
          ? () {
              if (state != null) {
                // ignore: invalid_use_of_protected_member
                state.setState(() {
                  state._priceController.text = state._formatWithSeparator(
                    value.toString(),
                  );
                });
              }
            }
          : null,
      elevation: 0,
    );
  }
}
