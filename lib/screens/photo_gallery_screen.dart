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

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen>
    with WidgetsBindingObserver {
  final PhotoDao _photoDao = PhotoDao();
  List<PhotoTask> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPhotos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPhotos();
    }
  }

  // LOGIC NHÓM ẢNH: Chuyển list phẳng thành Map theo danh mục
  Map<String, List<PhotoTask>> get _groupedPhotos {
    final Map<String, List<PhotoTask>> groups = {};
    for (var photo in _photos) {
      final category = (photo.category == null || photo.category!.isEmpty)
          ? 'Chưa phân loại'
          : photo.category!;
      if (!groups.containsKey(category)) {
        groups[category] = [];
      }
      groups[category]!.add(photo);
    }
    return groups;
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final photos = await _photoDao.getAllPhotos();
      if (mounted) {
        setState(() {
          _photos = photos;
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
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi chia sẻ: $e')),
                      );
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
                    if (photo.price != null)
                      metadataText +=
                          '- Giá: ${_formatPrice(photo.price!)}đ.\n';
                    try {
                      await Share.share(metadataText, subject: 'Metadata');
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (mounted) _loadPhotos();
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
    final grouped = _groupedPhotos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho lưu trữ'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPhotos),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
          ? _buildEmptyState()
          : CustomScrollView(
              slivers: grouped.entries.map((entry) {
                return SliverMainAxisGroup(
                  slivers: [
                    // PHẦN TIÊU ĐỀ DANH MỤC
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
                            const Expanded(child: Divider()),
                          ],
                        ),
                      ),
                    ),
                    // LƯỚI ẢNH CỦA DANH MỤC ĐÓ
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
    );
  }

  Widget _buildPhotoItem(PhotoTask photo) {
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Chưa có ảnh nào', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chụp ảnh ngay'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == price.toInt()) {
      return price.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    }
    return price.toString();
  }

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
}
