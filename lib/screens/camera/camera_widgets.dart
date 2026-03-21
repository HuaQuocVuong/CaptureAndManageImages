import 'package:flutter/material.dart';
import 'package:module_s1/models/photo_model.dart';
import 'dart:io';

class CameraTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final bool isBatchMode;
  final int queueLength;
  final VoidCallback onToggleFlash;
  final bool isFlashOn;

  const CameraTopBar({
    super.key,
    required this.onBack,
    required this.onRefresh,
    required this.isBatchMode,
    required this.queueLength,
    required this.onToggleFlash,
    required this.isFlashOn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: onRefresh,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                isBatchMode ? Icons.layers : Icons.photo_camera,
                color: Colors.pinkAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isBatchMode ? 'Batch: $queueLength' : 'Single',
                style: const TextStyle(color: Colors.pinkAccent, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            isFlashOn ? Icons.flash_on : Icons.flash_off,
            color: isFlashOn ? Colors.yellow : Colors.grey,
          ),
          onPressed: onToggleFlash,
        ),
      ],
    );
  }
}

class QueueThumbnail extends StatelessWidget {
  final PhotoTask task;
  final VoidCallback onTap;

  const QueueThumbnail({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (task.status) {
      case PhotoStatus.captured:
        statusColor = Colors.blue;
        statusIcon = Icons.camera_alt;
        break;
      case PhotoStatus.queued:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case PhotoStatus.processing:
        statusColor = Colors.purple;
        statusIcon = Icons.sync;
        break;
      case PhotoStatus.ready:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PhotoStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          border: Border.all(color: statusColor, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.black26,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<bool>(
              future: File(task.filePath).exists(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(task.filePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(Icons.broken_image, color: statusColor),
                        );
                      },
                    ),
                  );
                }
                return Center(child: Icon(statusIcon, color: statusColor));
              },
            ),
            if (task.status != PhotoStatus.ready)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (task.status == PhotoStatus.processing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.purple,
                            ),
                          ),
                        )
                      else
                        Icon(statusIcon, color: statusColor, size: 20),
                      const SizedBox(height: 2),
                      Text(
                        task.status.name[0].toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 8),
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
}

class CameraControlButtons extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCapture;
  final VoidCallback onToggleMode;
  final bool isBatchMode;
  final bool hasQueue;
  final VoidCallback? onBulkEdit;
  final int readyCount;
  final int totalCount;

  const CameraControlButtons({
    super.key,
    required this.onGallery,
    required this.onCapture,
    required this.onToggleMode,
    required this.isBatchMode,
    required this.hasQueue,
    this.onBulkEdit,
    required this.readyCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gallery button
        Positioned(
          bottom: 40,
          left: 24,
          child: GestureDetector(
            onTap: onGallery,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.green,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
        // Capture button
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: onCapture,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isBatchMode ? Colors.pinkAccent : Colors.blueAccent,
                    width: 4,
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Mode switch button
        Positioned(
          bottom: 127,
          right: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(30),
            ),
            child: IconButton(
              icon: Icon(
                isBatchMode ? Icons.layers_clear : Icons.layers,
                color: isBatchMode ? Colors.purple : Colors.pinkAccent,
                size: 32,
              ),
              onPressed: onToggleMode,
            ),
          ),
        ),
        // Bulk edit button
        if (isBatchMode)
          Positioned(
            bottom: 40,
            right: 40,
            child: Container(
              decoration: BoxDecoration(
                color: hasQueue ? Colors.black54 : Colors.black26,
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.edit_note,
                  color: Colors.deepOrange,
                  size: 32,
                ),
                onPressed: onBulkEdit,
              ),
            ),
          ),
        // Mode indicator
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isBatchMode ? Colors.pinkAccent : Colors.blueAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isBatchMode ? "BATCH MODE" : "SINGLE MODE",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        // Ready count
        if (isBatchMode && hasQueue)
          Positioned(
            bottom: 100,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$readyCount/$totalCount',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
