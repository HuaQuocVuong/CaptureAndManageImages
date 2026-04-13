import 'package:flutter/material.dart';
import 'package:module_s1/metadata/metadata_form_state.dart';

// Widget StatefulWidget cho màn hình nhập metadata của ảnh vừa chụp
// Nhận đường dẫn ảnh và tùy chọn photoId để hỗ trợ chế độ chỉnh sửa
class MetadataForm extends StatefulWidget {
  final String imagePath; // Đường dẫn đến file ảnh
  final int? photoId; // ID của ảnh (nếu có) để chỉnh sửa
  final DateTime? capturedAt;

  const MetadataForm({
    super.key,
    required this.imagePath,
    this.photoId,
    this.capturedAt,
  });

  @override
  State<MetadataForm> createState() => MetadataFormState();
}
