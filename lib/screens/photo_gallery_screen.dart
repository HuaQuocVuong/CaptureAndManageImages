// ==================== PHOTO GALLERY SCREEN ====================
// Màn hình hiển thị danh sách ảnh đã chụp, phân nhóm theo danh mục,
// cho phép xem chi tiết, chia sẻ ảnh và metadata, cũng như mở camera để chụp thêm.

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/metadata/metadata_form.dart';
import 'package:module_s1/screens/camera_screen.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

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
  // XỬ LÝ TÌM KIẾM
  // ------------------------------------------------------------------
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _filterPhotos();
      _updateSuggestions();
    });
  }

  // Lọc ảnh dựa trên từ khóa tìm kiếm
  void _filterPhotos() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = List.from(_photos);
    } else {
      _filteredPhotos = _photos.where((photo) {
        // Tìm trong tên sản phẩm
        if (photo.title != null &&
            photo.title!.toLowerCase().contains(_searchQuery)) {
          return true;
        }
        // Tìm trong loại sản phẩm
        if (photo.productType != null &&
            photo.productType!.toLowerCase().contains(_searchQuery)) {
          return true;
        }
        // Tìm trong màu sắc
        if (photo.color != null &&
            photo.color!.toLowerCase().contains(_searchQuery)) {
          return true;
        }
        // Tìm trong ghi chú
        if (photo.note != null &&
            photo.note!.toLowerCase().contains(_searchQuery)) {
          return true;
        }
        return false;
      }).toList();
    }
  }

  // Cập nhật danh sách gợi ý
  void _updateSuggestions() {
    if (_searchQuery.isEmpty) {
      _suggestions = [];
      _showSuggestions = false;
      return;
    }

    final Set<String> suggestionsSet = {};

    // Thu thập tất cả tên sản phẩm có chứa từ khóa
    for (var photo in _photos) {
      if (photo.title != null &&
          photo.title!.toLowerCase().contains(_searchQuery)) {
        suggestionsSet.add(photo.title!);
      }
    }

    _suggestions = suggestionsSet.take(5).toList(); // Giới hạn 5 gợi ý
    _showSuggestions = _suggestions.isNotEmpty;
  }

  // Xử lý khi chọn một gợi ý
  void _onSuggestionSelected(String suggestion) {
    setState(() {
      _searchController.text = suggestion;
      _searchQuery = suggestion.toLowerCase();
      _filterPhotos();
      _showSuggestions = false;
    });

    // Cuộn đến sản phẩm đầu tiên khớp
    _scrollToFirstMatch();
  }

  // Cuộn đến sản phẩm đầu tiên phù hợp
  void _scrollToFirstMatch() {
    if (_filteredPhotos.isNotEmpty) {
      // Tìm vị trí của sản phẩm đầu tiên
      final firstMatch = _filteredPhotos.first;

      // Tìm category của sản phẩm đó
      final category =
          (firstMatch.category == null || firstMatch.category!.isEmpty)
          ? 'Chưa phân loại'
          : firstMatch.category!;

      //Hiển thị thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tìm thấy "${firstMatch.title}" trong danh mục "$category"',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Xóa tìm kiếm
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _filterPhotos();
      _showSuggestions = false;
      _searchFocusNode.unfocus();
    });
  }

  // ------------------------------------------------------------------
  // NHÓM ẢNH THEO DANH MỤC (Category)
  // ------------------------------------------------------------------
  Map<String, List<PhotoTask>> get _groupedPhotos {
    final photosToGroup = _searchQuery.isEmpty ? _photos : _filteredPhotos;
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
  // WIDGET: THANH TÌM KIẾM
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
        children: [
          TextField(
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
                color: Colors.teal, // Đen tuyền
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

  // Widget hiển thị kết quả tìm kiếm
  Widget _buildSearchResultInfo() {
    if (_searchQuery.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tìm thấy ${_filteredPhotos.length} kết quả cho "$_searchQuery"',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _clearSearch,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Xóa'),
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
    final message = _searchQuery.isEmpty
        ? 'Chưa có ảnh nào'
        : 'Không tìm thấy sản phẩm "$_searchQuery"';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.photo_library : Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            ElevatedButton(
              onPressed: _openCamera,
              child: const Text('Chụp ảnh ngay'),
            )
          else
            ElevatedButton(
              onPressed: _clearSearch,
              child: const Text('Xóa tìm kiếm'),
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

          // Thông tin kết quả tìm kiếm
          _buildSearchResultInfo(),

          // Nội dung chính (danh sách ảnh hoặc loading/empty)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _photos.isEmpty ||
                      (_searchQuery.isNotEmpty && _filteredPhotos.isEmpty)
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
