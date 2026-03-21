import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:module_s1/database/photo_dao.dart';
import 'package:module_s1/database/product_dao.dart';
import 'package:module_s1/models/photo_model.dart';
import 'package:module_s1/models/product_model.dart';
import 'package:module_s1/screens/camera/camera_controller_manager.dart';
import 'package:module_s1/screens/camera/photo_processor.dart';
import 'package:module_s1/screens/camera/camera_widgets.dart';
import 'package:module_s1/screens/photo_gallery_screen.dart';
import 'package:module_s1/screens/bulk_edit_screen.dart';
import 'package:module_s1/widgets/grid_painter.dart';
import 'package:module_s1/metadata/metadata_form.dart';

// Màn hình chụp ảnh chính của ứng dụng (Singer/Batch Short)
class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

// Trạng thái của CameraScreen, quản lý toàn bộ logic camera,
// hàng đợi ảnh, chuyển đổi chế độ, tương tác với database và điều hướng.
class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // QUẢN LÝ CAMERA
  // Đối tượng quản lý controller camera (khởi tạo, chụp, flash...)
  CameraControllerManager? _cameraManager;
  bool _isCameraInitializing = false; // Cờ đang khởi tạo camera
  String? _cameraError; // Lỗi camera nếu có
  // TRẠNG THÁI ỨNG DỤNG
  // Chế độ chụp hàng loạt (batch mode) hay chụp đơn
  bool _isBatchMode = false;
  // Danh sách ảnh đã chụp (dùng cho chế độ batch và hiển thị thumbnail)
  List<PhotoTask> _queue = [];
  // Danh sách sản phẩm gần đây để gán nhanh metadata
  List<Product> _recentProducts = [];
  // DAO tương tác với database ảnh và sản phẩm
  final PhotoDao _photoDao = PhotoDao();
  final ProductDao _productDao = ProductDao();
  // Phát âm thanh tiếng máy ảnh
  late AudioPlayer _audioPlayer;
  // Cờ để tránh thao tác sau khi dispose
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo audio player
    _audioPlayer = AudioPlayer();
    // Lắng nghe vòng đời ứng dụng (để pause/resume camera)
    WidgetsBinding.instance.addObserver(this);
    _initCameraManager(); // Khởi tạo camera manager
    _loadRecentPhotos(); // Tải danh sách ảnh gần đây
    _loadRecentProducts(); // Tải danh sách sản phẩm gần đây
  }

  // Phát tiếng máy ảnh khi chụp
  Future<void> _playShutterSound() async {
    if (_disposed) return;
    try {
      await _audioPlayer.play(AssetSource('images/camera-shutter-02.mp3'));
    } catch (e) {
      // Bỏ qua lỗi âm thanh
    }
  }

  // Khởi tạo CameraControllerManager và đăng ký callback
  void _initCameraManager() {
    _cameraManager = CameraControllerManager(
      cameras: widget.cameras,
      onError: (error) {
        if (!_disposed && mounted) {
          setState(() => _cameraError = error);
        }
      },
      onInitializingChanged: (initializing) {
        if (!_disposed && mounted) {
          setState(() => _isCameraInitializing = initializing);
        }
      },
      onCameraReady: () {
        if (!_disposed && mounted) {
          setState(() {});
        }
      },
    );
    _cameraManager!.initialize();
  }

  // Tải 10 ảnh gần nhất từ database để hiển thị thumbnail hàng đợi
  Future<void> _loadRecentPhotos() async {
    if (_disposed || !mounted) return;
    try {
      final photos = await _photoDao.getAllPhotos();
      if (!_disposed && mounted) {
        setState(() {
          _queue = photos.take(10).toList();
        });
      }
    } catch (e) {
      //
    }
  }

  // Tải 5 sản phẩm gần nhất để gợi ý khi nhập metadata
  Future<void> _loadRecentProducts() async {
    if (_disposed || !mounted) return;
    try {
      final products = await _productDao.getAll();
      if (!_disposed && mounted) {
        setState(() {
          _recentProducts = products.take(5).toList();
        });
      }
    } catch (e) {
      //
    }
  }

  // Xử lý sự kiện chụp ảnh
  Future<void> _handleCapture() async {
    // Kiểm tra camera đã sẵn sàng chưa
    if (_cameraManager?.isInitialized != true) {
      _showSnackBar('Camera chưa sẵn sàng', isError: true);
      return;
    }
    try {
      // Phát âm thanh
      await _playShutterSound();
      // Chụp ảnh và lấy đường dẫn file
      final imagePath = await _cameraManager!.capture();
      if (imagePath == null) {
        _showSnackBar('Chụp ảnh thất bại', isError: true);
        return;
      }
      // Lưu thông tin ảnh vào database, nhận ID
      final id = await _photoDao.insert(imagePath);
      // Tạo đối tượng PhotoTask (dùng trong batch mode)
      final newTask = PhotoTask(
        id: id.toString(),
        filePath: imagePath,
        status: PhotoStatus.captured,
      );
      // Xử lý theo chế độ
      if (_isBatchMode) {
        // Chế độ hàng loạt: thêm vào hàng đợi và xử lý ngầm
        if (mounted) {
          setState(() => _queue.insert(0, newTask));
        }
        // Xử lý ảnh (có thể là nhận diện, trích xuất metadata...)
        final processor = PhotoProcessor(
          onUpdate: (updatedTask) {
            if (mounted && !_disposed) {
              setState(() {
                final index = _queue.indexWhere((t) => t.id == updatedTask.id);
                if (index != -1) _queue[index] = updatedTask;
              });
            }
          },
        );
        processor.process(newTask).then((_) => _loadRecentPhotos());
      } else {
        // Chế độ đơn: chuyển ngay sang màn hình nhập metadata
        _navigateToMetadata(imagePath, id);
      }
    } catch (e) {
      _showSnackBar('Lỗi: $e', isError: true);
    }
  }

  // Điều hướng tới màn hình nhập metadata cho ảnh vừa chụp
  void _navigateToMetadata(String imagePath, int photoId) {
    if (!mounted || _disposed) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MetadataForm(imagePath: imagePath, photoId: photoId),
      ),
    ).then((_) {
      if (!_disposed && mounted) {
        _loadRecentPhotos();
        _loadRecentProducts();
      }
    });
  }

  // Điều hướng tới thư viện ảnh
  void _navigateToGallery() {
    if (!mounted || _disposed) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhotoGalleryScreen()),
    ).then((_) {
      if (!_disposed && mounted) _loadRecentPhotos();
    });
  }

  // Điều hướng tới màn hình chỉnh sửa hàng loạt (batch edit)
  void _navigateToBulkEdit() {
    if (!mounted || _disposed) return;
    final readyPhotos = _queue
        .where((p) => p.status == PhotoStatus.ready)
        .toList();
    if (readyPhotos.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BulkEditScreen(photos: readyPhotos, products: _recentProducts),
      ),
    ).then((_) {
      if (!_disposed && mounted) {
        _loadRecentPhotos();
        _loadRecentProducts();
      }
    });
  }

  // Chuyển đổi giữa chế độ chụp đơn và chụp hàng loạt
  void _toggleMode() {
    if (mounted && !_disposed) setState(() => _isBatchMode = !_isBatchMode);
  }

  // Bật/tắt đèn flash
  void _toggleFlash() {
    _cameraManager?.toggleFlash();
    if (mounted) setState(() {});
  }

  // Hiển thị thông báo ngắn (SnackBar)
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || _disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // VÒNG ĐỜI ỨNG DỤNG
  // Xử lý khi ứng dụng chuyển trạng thái (inactive/resumed) để giải phóng/khởi tạo lại camera
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.inactive) {
      _cameraManager?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _cameraManager?.initialize();
    }
  }

  // Dọn dẹp tài nguyên khi thoát màn hình
  @override
  void dispose() {
    _disposed = true;
    _audioPlayer.dispose();
    _cameraManager?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // GIAO DIỆN
  @override
  Widget build(BuildContext context) {
    // Hiển thị thông báo lỗi nếu camera gặp vấn đề
    if (_cameraError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _cameraError!,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _cameraError = null);
                    _cameraManager?.initialize();
                  },
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Nếu không có camera trên thiết bị
    if (widget.cameras.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Không tìm thấy camera trên thiết bị",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    // Đang khởi tạo camera
    if (_isCameraInitializing || _cameraManager?.isInitialized != true) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Đang khởi tạo camera..."),
            ],
          ),
        ),
      );
    }
    // Camera đã sẵn sàng, xây dựng giao diện chính
    final controller = _cameraManager!.controller!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Preview Camera
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
          // Lưới chỉnh hình (grid) hỗ trợ bố cục
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          // Vùng tối giới hạn
          Positioned(
            // Trên
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top + 60,
              color: Colors.black.withOpacity(1.0),
            ),
          ),
          Positioned(
            // Dưới
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(height: 190, color: Colors.black.withOpacity(1.0)),
          ),
          //Thanh trên cùng (nút quay lại, làm mới, flash, chế độ batch)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: CameraTopBar(
              onBack: () => Navigator.pop(context),
              onRefresh: () {
                _loadRecentPhotos();
                _loadRecentProducts();
                _showSnackBar('Đã làm mới dữ liệu');
              },
              isBatchMode: _isBatchMode,
              queueLength: _queue.length,
              onToggleFlash: _toggleFlash,
              isFlashOn: _cameraManager?.isFlashOn ?? false,
            ),
          ),
          // Hàng đợi thumbnail (chỉ hiển thị khi ở chế độ batch và có ảnh)
          if (_isBatchMode && _queue.isNotEmpty)
            Positioned(
              top: 100,
              right: 10,
              bottom: 200,
              child: SizedBox(
                width: 80,
                child: ListView.builder(
                  itemCount: _queue.length > 10 ? 10 : _queue.length,
                  itemBuilder: (context, index) {
                    final task = _queue[index];
                    return QueueThumbnail(
                      task: task,
                      onTap: () {
                        if (task.status == PhotoStatus.ready) {
                          _navigateToMetadata(
                            task.filePath,
                            int.parse(task.id),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          // Các nút điều khiển chính (chụp, thư viện, toggle mode, bulk edit)
          CameraControlButtons(
            onGallery: _navigateToGallery,
            onCapture: _handleCapture,
            onToggleMode: _toggleMode,
            isBatchMode: _isBatchMode,
            hasQueue: _queue.isNotEmpty,
            onBulkEdit: _queue.isNotEmpty ? _navigateToBulkEdit : null,
            readyCount: _queue
                .where((p) => p.status == PhotoStatus.ready)
                .length,
            totalCount: _queue.length,
          ),
        ],
      ),
    );
  }
}
