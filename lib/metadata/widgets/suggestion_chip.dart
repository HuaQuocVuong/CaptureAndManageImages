// Các widget chip gợi ý cho ô nhập giá và ô nhập ghi chú.
// Khi nhấn, chip sẽ đổi màu trong thoáng chốc để phản hồi người dùng.
import 'package:flutter/material.dart';

/// Chip gợi ý giá (Stateful để có hiệu ứng nhấn).
/// Khi nhấn, gọi callback với giá trị số và tạm thời đổi màu nền.
class PriceSuggestionChip extends StatefulWidget {
  final String label;
  final int value;
  final bool enabled;
  final void Function(int value) onTap;

  const PriceSuggestionChip({
    super.key,
    required this.label,
    required this.value,
    this.enabled = true,
    required this.onTap,
  });

  @override
  State<PriceSuggestionChip> createState() => _PriceSuggestionChipState();
}

class _PriceSuggestionChipState extends State<PriceSuggestionChip> {
  bool _isPressed = false;

  void _handleTap() {
    if (!widget.enabled) return;
    setState(() => _isPressed = true);
    widget.onTap(widget.value);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _isPressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        widget.label,
        style: const TextStyle(color: Colors.black, fontSize: 13),
      ),
      backgroundColor: _isPressed
          ? const Color.fromARGB(255, 196, 165, 255) // màu khi nhấn
          : const Color.fromARGB(255, 157, 208, 255), // màu bình thường
      onPressed: widget.enabled ? _handleTap : null,
      elevation: 0,
    );
  }
}

/// Chip gợi ý ghi chú (Stateful để có hiệu ứng nhấn).
/// Khi nhấn, gọi callback và tạm thời đổi màu nền.
class NoteSuggestionChip extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const NoteSuggestionChip({
    super.key,
    required this.label,
    this.enabled = true,
    required this.onTap,
  });

  @override
  State<NoteSuggestionChip> createState() => _NoteSuggestionChipState();
}

class _NoteSuggestionChipState extends State<NoteSuggestionChip> {
  bool _isPressed = false;

  void _handleTap() {
    if (!widget.enabled) return;
    setState(() => _isPressed = true);
    widget.onTap();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _isPressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        widget.label,
        style: const TextStyle(color: Colors.black, fontSize: 13),
      ),
      backgroundColor: _isPressed
          ? const Color.fromARGB(255, 196, 165, 255) // màu khi nhấn (giống giá)
          : const Color.fromARGB(255, 157, 208, 255), // màu bình thường
      onPressed: widget.enabled ? _handleTap : null,
      elevation: 0,
    );
  }
}
