import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class CameraUtils {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> playShutterSound() async {
    try {
      await _audioPlayer.play(AssetSource('images/camera-shutter-02.mp3'));
    } catch (e) {}
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
