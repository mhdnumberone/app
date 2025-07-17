import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;

import '../models/device_file.dart';
import '../utils/logger.dart';
import 'android_file_manager_service.dart';

/// Service for previewing different file types
class FilePreviewService {
  static final FilePreviewService _instance = FilePreviewService._internal();
  static FilePreviewService get instance => _instance;
  
  factory FilePreviewService() => _instance;
  
  FilePreviewService._internal();

  final AndroidFileManagerService _fileManager = AndroidFileManagerService.instance;

  /// Show file preview based on file type
  Future<void> showFilePreview(BuildContext context, DeviceFile file) async {
    try {
      AppLogger.info('Showing preview for file: ${file.path}');
      
      if (file.isDirectory) {
        // Navigate to directory
        await _fileManager.navigateToDirectory(file.path);
        return;
      }
      
      switch (file.type) {
        case FileType.image:
          await _showImagePreview(context, file);
          break;
        case FileType.video:
          await _showVideoPreview(context, file);
          break;
        case FileType.audio:
          await _showAudioPreview(context, file);
          break;
        case FileType.text:
          await _showTextPreview(context, file);
          break;
        case FileType.document:
          await _showDocumentPreview(context, file);
          break;
        default:
          await _showDefaultPreview(context, file);
      }
      
    } catch (e) {
      AppLogger.error('Error showing file preview: ${file.path}', e);
      _showErrorDialog(context, 'Could not preview file', e.toString());
    }
  }

  /// Show image preview with zoom and gallery support
  Future<void> _showImagePreview(BuildContext context, DeviceFile file) async {
    // Find other images in the same directory for gallery
    final currentDir = Directory(file.parentPath);
    final imageFiles = <DeviceFile>[];
    
    try {
      final entities = await currentDir.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final extension = path.extension(fileName).toLowerCase();
          
          if (_isImageExtension(extension)) {
            final stat = await entity.stat();
            imageFiles.add(DeviceFile(
              name: fileName,
              path: entity.path,
              isDirectory: false,
              size: stat.size,
              lastModified: stat.modified,
              extension: extension,
              type: FileType.image,
              icon: '🖼️',
            ));
          }
        }
      }
      
      // Sort by name
      imageFiles.sort((a, b) => a.name.compareTo(b.name));
      
      // Find current image index
      final currentIndex = imageFiles.indexWhere((f) => f.path == file.path);
      
      if (imageFiles.length > 1) {
        // Show gallery
        await _showImageGallery(context, imageFiles, currentIndex);
      } else {
        // Show single image
        await _showSingleImage(context, file);
      }
      
    } catch (e) {
      AppLogger.error('Error preparing image preview', e);
      await _showSingleImage(context, file);
    }
  }

  /// Show single image preview
  Future<void> _showSingleImage(BuildContext context, DeviceFile file) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PhotoView(
              imageProvider: FileImage(File(file.path)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              heroAttributes: PhotoViewHeroAttributes(tag: file.path),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.formattedSize} • ${file.formattedDate}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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

  /// Show image gallery
  Future<void> _showImageGallery(BuildContext context, List<DeviceFile> images, int initialIndex) async {
    await showDialog(
      context: context,
      builder: (context) => _ImageGalleryDialog(
        images: images,
        initialIndex: initialIndex,
      ),
    );
  }

  /// Show video preview
  Future<void> _showVideoPreview(BuildContext context, DeviceFile file) async {
    await showDialog(
      context: context,
      builder: (context) => _VideoPreviewDialog(file: file),
    );
  }

  /// Show audio preview
  Future<void> _showAudioPreview(BuildContext context, DeviceFile file) async {
    await showDialog(
      context: context,
      builder: (context) => _AudioPreviewDialog(file: file),
    );
  }

  /// Show text file preview
  Future<void> _showTextPreview(BuildContext context, DeviceFile file) async {
    try {
      final content = await _fileManager.getFileContent(file.path);
      if (content == null) {
        _showErrorDialog(context, 'Could not read file', 'File content is empty or unreadable');
        return;
      }
      
      await showDialog(
        context: context,
        builder: (context) => _TextPreviewDialog(file: file, content: content),
      );
      
    } catch (e) {
      _showErrorDialog(context, 'Could not read file', e.toString());
    }
  }

  /// Show document preview
  Future<void> _showDocumentPreview(BuildContext context, DeviceFile file) async {
    // For documents, we'll use the system default app
    await _showDefaultPreview(context, file);
  }

  /// Show default preview (open with system app)
  Future<void> _showDefaultPreview(BuildContext context, DeviceFile file) async {
    try {
      final result = await OpenFile.open(file.path);
      
      if (result.type != ResultType.done) {
        _showErrorDialog(context, 'Could not open file', result.message);
      }
      
    } catch (e) {
      _showErrorDialog(context, 'Could not open file', e.toString());
    }
  }

  /// Show error dialog
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Check if extension is an image type
  bool _isImageExtension(String extension) {
    const imageExtensions = [
      '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.ico'
    ];
    return imageExtensions.contains(extension.toLowerCase());
  }

  /// Generate video thumbnail
  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await Directory.systemTemp.createTemp()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 75,
      );
      
      return thumbnailPath;
    } catch (e) {
      AppLogger.error('Error generating video thumbnail', e);
      return null;
    }
  }
}

/// Image Gallery Dialog
class _ImageGalleryDialog extends StatefulWidget {
  final List<DeviceFile> images;
  final int initialIndex;

  const _ImageGalleryDialog({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.images.length,
            builder: (context, index) {
              final image = widget.images[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(image.path)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                heroAttributes: PhotoViewHeroAttributes(tag: image.path),
              );
            },
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.images[_currentIndex].name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.images[_currentIndex].formattedSize} • ${widget.images[_currentIndex].formattedDate}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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
}

/// Video Preview Dialog
class _VideoPreviewDialog extends StatefulWidget {
  final DeviceFile file;

  const _VideoPreviewDialog({required this.file});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.file.path));
      await _controller.initialize();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: _isLoading
                ? const CircularProgressIndicator()
                : _hasError
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading video',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (!_isLoading && !_hasError) ...[
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop, color: Colors.white),
                          onPressed: () {
                            _controller.seekTo(Duration.zero);
                            _controller.pause();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.file.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.file.formattedSize} • ${widget.file.formattedDate}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Audio Preview Dialog
class _AudioPreviewDialog extends StatefulWidget {
  final DeviceFile file;

  const _AudioPreviewDialog({required this.file});

  @override
  State<_AudioPreviewDialog> createState() => _AudioPreviewDialogState();
}

class _AudioPreviewDialogState extends State<_AudioPreviewDialog> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _player.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _player.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      setState(() {
        _isLoading = true;
      });
      await _player.play(DeviceFileSource(widget.file.path));
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _stop() async {
    await _player.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Audio Player',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.music_note,
                size: 50,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.file.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.file.formattedSize} • ${widget.file.formattedDate}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stop,
                ),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _isLoading ? null : _playPause,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_duration.inMilliseconds > 0) ...[
              Slider(
                value: _position.inMilliseconds.toDouble(),
                max: _duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  _player.seek(Duration(milliseconds: value.toInt()));
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position)),
                  Text(_formatDuration(_duration)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Text Preview Dialog
class _TextPreviewDialog extends StatefulWidget {
  final DeviceFile file;
  final String content;

  const _TextPreviewDialog({
    required this.file,
    required this.content,
  });

  @override
  State<_TextPreviewDialog> createState() => _TextPreviewDialogState();
}

class _TextPreviewDialogState extends State<_TextPreviewDialog> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.file.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.file.formattedSize} • ${widget.file.formattedDate}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isEditing ? Icons.save : Icons.edit),
                        onPressed: _isEditing ? _saveFile : _toggleEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: _isEditing
                    ? TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Edit text content...',
                        ),
                      )
                    : SingleChildScrollView(
                        child: SelectableText(
                          widget.content,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveFile() async {
    try {
      final file = File(widget.file.path);
      await file.writeAsString(_controller.text);
      
      setState(() {
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: ${e.toString()}')),
      );
    }
  }
}