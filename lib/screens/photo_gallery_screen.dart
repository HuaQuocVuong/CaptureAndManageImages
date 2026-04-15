// ==================== PHOTO GALLERY SCREEN ====================
// Màn hình hiển thị danh sách ảnh đã chụp, phân nhóm theo danh mục,
// cho phép xem chi tiết, chia sẻ ảnh và metadata, cũng như mở camera để chụp thêm.

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/metadata/metadata_form.dart';
import 'package:module_s1/screens/camera_screen.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

// ---------- Stateful widget cho màn hình gallery ----------
class PhotoGalleryScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const PhotoGalleryScreen({super.key, required this.cameras});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen>
    with WidgetsBindingObserver {
  final PhotoDao _photoDao = PhotoDao();
  List<PhotoTask> _photos = [];
  List<PhotoTask> _filteredPhotos = []; // Danh sách đã lọc
  bool _isLoading = true;

  // Biến cho tìm kiếm
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _showSuggestions = false;
  List<String> _suggestions = [];

  // Biến cho bộ lọc ngày tháng
  DateTimeRange? _selectedDateRange;
  bool _isFilteringByDate = false;

  // ------------------------------------------------------------------
  // VÒNG ĐỜI (Lifecycle)
  // ------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPhotos();

    // Lắng nghe thay đổi trên search controller
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPhotos();
    }
  }

  // ------------------------------------------------------------------
  // XỬ LÝ TÌM KIẾM VÀ LỌC
  // ------------------------------------------------------------------
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _applyFilters();
    });
  }

  // Áp dụng tất cả bộ lọc (tìm kiếm + ngày tháng)
  void _applyFilters() {
    List<PhotoTask> result = List.from(_photos);

    // Lọc theo từ khóa tìm kiếm
    if (_searchQuery.isNotEmpty) {
      result = result.where((photo) {
        if (photo.title != null &&
            photo.title!.toLowerCase().contains(_searchQuery)) {
          return true;
        }
        if (photo.productType != null &&
            photo.productType!.toLowerCase().contains(_searchQuery)) {
          return true;
        }
        if (photo.color != null &&
            photo.color!.toLowerCase().contains(_searchQuery)) {
          return true;
        }
        if (photo.note != null &&
            photo.note!.toLowerCase().contains(_searchQuery)) {
          return true;
        }
        return false;
      }).toList();
    }

    // Lọc theo khoảng ngày tháng
    if (_isFilteringByDate && _selectedDateRange != null) {
      result = result.where((photo) {
        if (photo.createdAt == null) return false;
        final photoDate = photo.createdAt!;
        return photoDate.isAfter(
              _selectedDateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            photoDate.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    setState(() {
      _filteredPhotos = result;
      _updateSuggestions();
    });
  }

  // Cập nhật danh sách gợi ý
  void _updateSuggestions() {
    if (_searchQuery.isEmpty) {
      _suggestions = [];
      _showSuggestions = false;
      return;
    }

    final Set<String> suggestionsSet = {};

    for (var photo in _filteredPhotos) {
      if (photo.title != null &&
          photo.title!.toLowerCase().contains(_searchQuery)) {
        suggestionsSet.add(photo.title!);
      }
    }

    _suggestions = suggestionsSet.take(5).toList();
    _showSuggestions = _suggestions.isNotEmpty;
  }

  // Xử lý khi chọn một gợi ý
  void _onSuggestionSelected(String suggestion) {
    setState(() {
      _searchController.text = suggestion;
      _searchQuery = suggestion.toLowerCase();
      _applyFilters();
      _showSuggestions = false;
    });
  }

  // Xóa tìm kiếm
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _applyFilters();
      _showSuggestions = false;
      _searchFocusNode.unfocus();
    });
  }

  // Mở hộp thoại chọn khoảng ngày (hiển thị menu lựa chọn)
  Future<void> _selectDateRange() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Chọn bằng lịch'),
                onTap: () {
                  Navigator.pop(context);
                  _selectDateRangeWithCalendar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard),
                title: const Text('Nhập thủ công (DD/MM/YYYY)'),
                onTap: () {
                  Navigator.pop(context);
                  _selectDateRangeWithManualInput();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Hàm chọn bằng lịch
  Future<void> _selectDateRangeWithCalendar() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _isFilteringByDate = true;
        _applyFilters();
      });
    }
  }

  // Hàm nhập thủ công có tự động thêm dấu /
  Future<void> _selectDateRangeWithManualInput() async {
    TextEditingController startController = TextEditingController();
    TextEditingController endController = TextEditingController();

    // Khởi tạo giá trị hiện tại nếu có
    if (_selectedDateRange != null) {
      startController.text = _formatDate(_selectedDateRange!.start);
      endController.text = _formatDate(_selectedDateRange!.end);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nhập khoảng thời gian'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startController,
                decoration: const InputDecoration(
                  labelText: 'Ngày bắt đầu',
                  hintText: 'DD/MM/YYYY',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  // Chỉ cho nhập số và giới hạn độ dài
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                onChanged: (value) {
                  // Tự động format khi nhập
                  String formatted = _formatDateInput(value);
                  if (formatted != startController.text) {
                    startController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: endController,
                decoration: const InputDecoration(
                  labelText: 'Ngày kết thúc',
                  hintText: 'DD/MM/YYYY',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                onChanged: (value) {
                  // Tự động format khi nhập
                  String formatted = _formatDateInput(value);
                  if (formatted != endController.text) {
                    endController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                // Parse từ string có dấu / (DD/MM/YYYY)
                DateTime? startDate = _parseDateFromString(
                  startController.text,
                );
                DateTime? endDate = _parseDateFromString(endController.text);

                if (startDate != null && endDate != null) {
                  if (startDate.isBefore(endDate) ||
                      startDate.isAtSameMomentAs(endDate)) {
                    setState(() {
                      _selectedDateRange = DateTimeRange(
                        start: startDate,
                        end: endDate,
                      );
                      _isFilteringByDate = true;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ngày kết thúc phải sau hoặc bằng ngày bắt đầu',
                        ),
                      ),
                    );
                  }
                } else {
                  //ScaffoldMessenger.of(context).showSnackBar(
                  //const SnackBar(
                  //  content: Text(
                  //    'Vui lòng nhập đúng định dạng DD/MM/YYYY (ví dụ: 01/01/2026)',
                  //  ),
                  //),
                  //);
                }
              },
              child: const Text('Lọc'),
            ),
          ],
        );
      },
    );
  }

  // Hàm tự động format khi nhập (thêm dấu /)
  String _formatDateInput(String input) {
    // Xóa tất cả dấu / hiện có
    String cleaned = input.replaceAll('/', '');

    if (cleaned.length >= 3) {
      cleaned = cleaned.substring(0, 2) + '/' + cleaned.substring(2);
    }
    if (cleaned.length >= 6) {
      cleaned = cleaned.substring(0, 5) + '/' + cleaned.substring(5);
    }

    return cleaned;
  }

  // Hàm parse từ string có dấu / (DD/MM/YYYY) - không giới hạn năm
  DateTime? _parseDateFromString(String dateString) {
    try {
      final parts = dateString.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        // Kiểm tra ngày tháng hợp lệ (không giới hạn năm)
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year > 0) {
          return DateTime(year, month, day);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Hàm định dạng ngày DD/MM/YYYY
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Xóa bộ lọc ngày tháng
  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
      _isFilteringByDate = false;
      _applyFilters();
    });
  }

  // ------------------------------------------------------------------
  // NHÓM ẢNH THEO DANH MỤC (Category)
  // ------------------------------------------------------------------
  Map<String, List<PhotoTask>> get _groupedPhotos {
    final photosToGroup = _searchQuery.isEmpty && !_isFilteringByDate
        ? _photos
        : _filteredPhotos;
    final Map<String, List<PhotoTask>> groups = {};

    for (var photo in photosToGroup) {
      final category = (photo.category == null || photo.category!.isEmpty)
          ? 'Chưa phân loại'
          : photo.category!;
      groups.putIfAbsent(category, () => []);
      groups[category]!.add(photo);
    }
    return groups;
  }

  // ------------------------------------------------------------------
  // MỞ CAMERA ĐỂ CHỤP ẢNH MỚI
  // ------------------------------------------------------------------
  Future<void> _openCamera() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(cameras: widget.cameras),
      ),
    );
    _loadPhotos();
  }

  // ------------------------------------------------------------------
  // TẢI DANH SÁCH ẢNH TỪ DATABASE
  // ------------------------------------------------------------------
  Future<void> _loadPhotos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final photos = await _photoDao.getAllPhotos();
      if (mounted) {
        setState(() {
          _photos = photos;
          _filteredPhotos = List.from(photos);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
      }
    }
  }

  // ------------------------------------------------------------------
  // WIDGET: THANH TÌM KIẾM (đã thêm nút bộ lọc ngày tháng)
  // ------------------------------------------------------------------
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 25, 46),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ô tìm kiếm - chiếm phần lớn không gian
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm sản phẩm...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onTap: () {
                    setState(() {
                      if (_searchQuery.isNotEmpty) {
                        _showSuggestions = _suggestions.isNotEmpty;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Nút bộ lọc ngày tháng
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.filter_alt,
                      color: _isFilteringByDate ? Colors.blue : Colors.white,
                    ),
                    onPressed: _selectDateRange,
                    tooltip: 'Lọc theo ngày',
                  ),
                  if (_isFilteringByDate)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              // Nút xóa bộ lọc (chỉ hiển thị khi đang lọc)
              if (_isFilteringByDate)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: _clearDateFilter,
                  tooltip: 'Xóa lọc ngày',
                ),
            ],
          ),
          // Hiển thị thông tin bộ lọc ngày tháng
          if (_isFilteringByDate && _selectedDateRange != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _clearDateFilter,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          // Hiển thị gợi ý tìm kiếm
          if (_showSuggestions && _suggestions.isNotEmpty)
            _buildSuggestionsList(),
        ],
      ),
    );
  }

  // Widget hiển thị danh sách gợi ý
  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: _suggestions.map((suggestion) {
          return ListTile(
            leading: const Icon(Icons.search, size: 20, color: Colors.blue),
            title: Text(
              suggestion,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.teal,
                fontWeight: FontWeight.w500,
              ),
            ),
            dense: true,
            onTap: () => _onSuggestionSelected(suggestion),
          );
        }).toList(),
      ),
    );
  }

  // Widget hiển thị kết quả tìm kiếm và lọc
  Widget _buildSearchResultInfo() {
    if (_searchQuery.isEmpty && !_isFilteringByDate) {
      return const SizedBox.shrink();
    }

    final List<String> filters = [];
    if (_searchQuery.isNotEmpty) filters.add('"$_searchQuery"');
    if (_isFilteringByDate) filters.add('ngày tháng');

    final filterText = filters.join(' và ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tìm thấy ${_filteredPhotos.length} kết quả cho $filterText',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _clearSearch();
              _clearDateFilter();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // HIỂN THỊ BẢNG CHIA SẺ (Modal Bottom Sheet) CHO MỘT ẢNH
  // ------------------------------------------------------------------
  Future<void> _showShareOptions(PhotoTask photo) async {
    final file = File(photo.filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy file ảnh')),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Chia sẻ ảnh'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await Share.shareXFiles([XFile(photo.filePath)]);
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (mounted) _loadPhotos();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi chia sẻ: $e')),
                      );
                    }
                  }
                },
              ),
              if (photo.title != null ||
                  photo.category != null ||
                  photo.price != null)
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Chia sẻ metadata'),
                  onTap: () async {
                    Navigator.pop(context);
                    String metadataText = 'THÔNG TIN SẢN PHẨM\n';
                    if (photo.productType != null) {
                      metadataText += '- Loại sản phẩm: ${photo.productType} ';
                    }
                    if (photo.title != null) {
                      metadataText += '${photo.title}.\n';
                    }
                    if (photo.color != null) {
                      metadataText += '- Màu sắc: ${photo.color}.\n';
                    }
                    if (photo.price != null) {
                      metadataText +=
                          '- Giá: ${_formatPrice(photo.price!)}đ.\n';
                    }
                    try {
                      await Share.share(metadataText, subject: 'Metadata');
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (mounted) _loadPhotos();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  },
                ),
              if (photo.title != null ||
                  photo.category != null ||
                  photo.price != null)
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Chia sẻ ảnh + metadata'),
                  onTap: () async {
                    Navigator.pop(context);
                    String metadataText = 'THÔNG TIN SẢN PHẨM\n';
                    if (photo.productType != null) {
                      metadataText += '- Loại sản phẩm: ${photo.productType} ';
                    }
                    if (photo.title != null) {
                      metadataText += '${photo.title}.\n';
                    }
                    if (photo.color != null) {
                      metadataText += '- Màu sắc: ${photo.color}.\n';
                    }
                    if (photo.price != null) {
                      metadataText +=
                          '- Giá: ${_formatPrice(photo.price!)}đ.\n';
                    }
                    try {
                      await Share.shareXFiles([
                        XFile(photo.filePath),
                      ], text: metadataText);
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (mounted) _loadPhotos();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // ĐỊNH DẠNG GIÁ TIỀN (VD: 1.000.000đ)
  // ------------------------------------------------------------------
  String _formatPrice(double price) {
    if (price == price.toInt()) {
      return price.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    }
    return price.toString();
  }

  // ------------------------------------------------------------------
  // MÀU SẮC CHO STATUS BADGE
  // ------------------------------------------------------------------
  Color _getStatusColor(PhotoStatus status) {
    switch (status) {
      case PhotoStatus.ready:
        return Colors.green;
      case PhotoStatus.processing:
        return Colors.orange;
      case PhotoStatus.queued:
        return Colors.blue;
      case PhotoStatus.failed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ------------------------------------------------------------------
  // WIDGET: HIỂN THỊ MỘT ITEM ẢNH TRONG LƯỚI
  // ------------------------------------------------------------------
  Widget _buildPhotoItem(PhotoTask photo) {
    // Highlight nếu đang tìm kiếm và item này khớp
    final isHighlighted =
        _searchQuery.isNotEmpty &&
        (photo.title?.toLowerCase().contains(_searchQuery) == true);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MetadataForm(
              imagePath: photo.filePath,
              photoId: int.parse(photo.id),
            ),
          ),
        ).then((_) => _loadPhotos());
      },
      onLongPress: () => _showShareOptions(photo),
      child: Container(
        decoration: isHighlighted
            ? BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(photo.filePath), fit: BoxFit.cover),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(photo.status),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  photo.status.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (photo.title != null ||
                photo.category != null ||
                photo.price != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  color: isHighlighted
                      ? Colors.blue[900]?.withOpacity(0.7)
                      : Colors.black54,
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
      ),
    );
  }

  // ------------------------------------------------------------------
  // WIDGET: HIỂN THỊ KHI DANH SÁCH ẢNH RỖNG
  // ------------------------------------------------------------------
  Widget _buildEmptyState() {
    final message = _searchQuery.isNotEmpty || _isFilteringByDate
        ? 'Không tìm thấy kết quả phù hợp'
        : 'Chưa có ảnh nào';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty || _isFilteringByDate
                ? Icons.search_off
                : Icons.photo_library,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty && !_isFilteringByDate)
            ElevatedButton(
              onPressed: _openCamera,
              child: const Text('Chụp ảnh ngay'),
            )
          else
            ElevatedButton(
              onPressed: () {
                _clearSearch();
                _clearDateFilter();
              },
              child: const Text('Xóa bộ lọc'),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // BUILD CHÍNH
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final grouped = _groupedPhotos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho lưu trữ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _openCamera,
            tooltip: 'Chụp ảnh mới',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPhotos),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          _buildSearchBar(),

          // Thông tin kết quả tìm kiếm và lọc
          _buildSearchResultInfo(),

          // Nội dung chính (danh sách ảnh hoặc loading/empty)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _photos.isEmpty ||
                      ((_searchQuery.isNotEmpty || _isFilteringByDate) &&
                          _filteredPhotos.isEmpty)
                ? _buildEmptyState()
                : CustomScrollView(
                    slivers: grouped.entries.map((entry) {
                      return SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.label,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.key.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '(${entry.value.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _buildPhotoItem(entry.value[index]),
                                childCount: entry.value.length,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
