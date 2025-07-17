// lib/widgets/enhanced_file_upload_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/themes/app_theme_extension.dart';
import '../core/widgets/base_widgets.dart';
import '../core/localization/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../helper/dialogs.dart';

/// Enhanced file upload widget with improved UX
class EnhancedFileUploadWidget extends BaseStatefulWidget {
  final ChatUser user;
  final Function(String filePath, Type type) onFileSelected;
  final Function(Message message) onOptimisticMessageAdd;
  final Function(Message) onCreateOptimisticMessage;
  final VoidCallback onRequestStoragePermissions;
  final VoidCallback onRequestCameraPermission;
  final VoidCallback onRequestFileAndVideoPermissions;
  final Function(bool) onUploadingChanged;
  
  const EnhancedFileUploadWidget({
    super.key,
    required this.user,
    required this.onFileSelected,
    required this.onOptimisticMessageAdd,
    required this.onCreateOptimisticMessage,
    required this.onRequestStoragePermissions,
    required this.onRequestCameraPermission,
    required this.onRequestFileAndVideoPermissions,
    required this.onUploadingChanged,
  });

  @override
  State<EnhancedFileUploadWidget> createState() => _EnhancedFileUploadWidgetState();
}

class _EnhancedFileUploadWidgetState extends BaseState<EnhancedFileUploadWidget> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  final ImagePicker _imagePicker = ImagePicker();
  final ValueNotifier<bool> _isProcessingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> _processingStatusNotifier = ValueNotifier(null);
  final ValueNotifier<double> _compressionProgressNotifier = ValueNotifier(0.0);
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _isProcessingNotifier.dispose();
    _processingStatusNotifier.dispose();
    _compressionProgressNotifier.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final appColors = context.appTheme;
    final localizations = this.localizations(context);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: appColors.surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with drag handle
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: appColors.textSecondaryColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          localizations.attachFile,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: appColors.textPrimaryColor,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: appColors.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Processing indicator
                  ValueListenableBuilder<bool>(
                    valueListenable: _isProcessingNotifier,
                    builder: (context, isProcessing, child) {
                      if (!isProcessing) return const SizedBox.shrink();
                      
                      return Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ValueListenableBuilder<String?>(
                              valueListenable: _processingStatusNotifier,
                              builder: (context, status, child) {
                                return Text(
                                  status ?? localizations.processing,
                                  style: TextStyle(
                                    color: appColors.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<double>(
                              valueListenable: _compressionProgressNotifier,
                              builder: (context, progress, child) {
                                return LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: appColors.textSecondaryColor.withOpacity(0.3),
                                  color: appColors.accentColor,
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  // File options grid
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildFileOption(
                          icon: Icons.photo_library,
                          label: localizations.gallery,
                          color: Colors.purple,
                          onTap: _pickFromGallery,
                        ),
                        _buildFileOption(
                          icon: Icons.camera_alt,
                          label: localizations.camera,
                          color: Colors.red,
                          onTap: _pickFromCamera,
                        ),
                        _buildFileOption(
                          icon: Icons.videocam,
                          label: localizations.video,
                          color: Colors.green,
                          onTap: _pickVideo,
                        ),
                        _buildFileOption(
                          icon: Icons.attach_file,
                          label: localizations.file,
                          color: Colors.blue,
                          onTap: _pickFile,
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom safe area
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFileOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isProcessingNotifier,
      builder: (context, isProcessing, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isProcessing ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _pickFromGallery() async {
    try {
      await _showProcessingStatus(localizations.selectingFromGallery);
      
      // Check permissions
      final storagePermission = await Permission.photos.request();
      if (!storagePermission.isGranted) {
        widget.onRequestStoragePermissions();
        return;
      }
      
      // Pick multiple images with fallback to single
      List<XFile> files = [];
      try {
        files = await _imagePicker.pickMultipleMedia() ?? [];
      } catch (e) {
        final file = await _imagePicker.pickImage(source: ImageSource.gallery);
        if (file != null) files = [file];
      }
      
      if (files.isEmpty) {
        await _hideProcessingStatus();
        return;
      }
      
      await _processSelectedFiles(files);
      
    } catch (e) {
      await _hideProcessingStatus();
      if (mounted) {
        Dialogs.showSnackbar(context, localizations.failedToSelectImage);
      }
    }
  }
  
  Future<void> _pickFromCamera() async {
    try {
      await _showProcessingStatus(localizations.openingCamera);
      
      // Check permissions
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        widget.onRequestCameraPermission();
        return;
      }
      
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (file == null) {
        await _hideProcessingStatus();
        return;
      }
      
      await _processSelectedFiles([file]);
      
    } catch (e) {
      await _hideProcessingStatus();
      if (mounted) {
        Dialogs.showSnackbar(context, localizations.failedToTakePhoto);
      }
    }
  }
  
  Future<void> _pickVideo() async {
    try {
      await _showProcessingStatus(localizations.selectingVideo);
      
      // Check permissions
      final storagePermission = await Permission.photos.request();
      if (!storagePermission.isGranted) {
        widget.onRequestFileAndVideoPermissions();
        return;
      }
      
      final file = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (file == null) {
        await _hideProcessingStatus();
        return;
      }
      
      await _processSelectedFiles([file]);
      
    } catch (e) {
      await _hideProcessingStatus();
      if (mounted) {
        Dialogs.showSnackbar(context, localizations.failedToSelectVideo);
      }
    }
  }
  
  Future<void> _pickFile() async {
    try {
      await _showProcessingStatus(localizations.selectingFile);
      
      // Check permissions
      final storagePermission = await Permission.storage.request();
      if (!storagePermission.isGranted) {
        widget.onRequestFileAndVideoPermissions();
        return;
      }
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowedExtensions: null,
      );
      
      if (result?.files.isEmpty ?? true) {
        await _hideProcessingStatus();
        return;
      }
      
      final file = result!.files.first;
      if (file.path == null) {
        await _hideProcessingStatus();
        if (mounted) {
          Dialogs.showSnackbar(context, localizations.failedToSelectFile);
        }
        return;
      }
      
      // Check file size (max 100MB)
      const maxFileSize = 100 * 1024 * 1024; // 100MB
      if (file.size > maxFileSize) {
        await _hideProcessingStatus();
        if (mounted) {
          Dialogs.showSnackbar(context, localizations.fileTooLarge);
        }
        return;
      }
      
      await _processSelectedFiles([XFile(file.path!)]);
      
    } catch (e) {
      await _hideProcessingStatus();
      if (mounted) {
        Dialogs.showSnackbar(context, localizations.failedToSelectFile);
      }
    }
  }
  
  Future<void> _processSelectedFiles(List<XFile> files) async {
    try {
      widget.onUploadingChanged(true);
      
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        
        // Update processing status
        _processingStatusNotifier.value = '${localizations.processing} ${i + 1}/${files.length}';
        _compressionProgressNotifier.value = (i / files.length);
        
        // Determine file type
        final fileExtension = file.path.split('.').last.toLowerCase();
        Type messageType = Type.file;
        
        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension)) {
          messageType = Type.image;
        } else if (['mp4', 'mov', 'avi', 'mkv'].contains(fileExtension)) {
          messageType = Type.video;
        } else if (['mp3', 'wav', 'm4a', 'aac'].contains(fileExtension)) {
          messageType = Type.audio;
        }
        
        // Create optimistic message
        final optimisticMessage = widget.onCreateOptimisticMessage(
          Message(
            msg: file.path,
            toId: widget.user.id,
            read: '',
            type: messageType,
            sent: DateTime.now().millisecondsSinceEpoch.toString(),
            fromId: '', // Will be set by the parent
          ),
        );
        
        // Add optimistic message to UI
        widget.onOptimisticMessageAdd(optimisticMessage);
        
        // Trigger file upload
        widget.onFileSelected(file.path, messageType);
        
        // Small delay for better UX
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Close the upload widget
      if (mounted) {
        Navigator.pop(context);
      }
      
    } catch (e) {
      if (mounted) {
        Dialogs.showSnackbar(context, localizations.failedToProcessFile);
      }
    } finally {
      widget.onUploadingChanged(false);
      await _hideProcessingStatus();
    }
  }
  
  Future<void> _showProcessingStatus(String status) async {
    _processingStatusNotifier.value = status;
    _compressionProgressNotifier.value = 0.0;
    _isProcessingNotifier.value = true;
    
    // Add haptic feedback
    HapticFeedback.lightImpact();
  }
  
  Future<void> _hideProcessingStatus() async {
    _isProcessingNotifier.value = false;
    _processingStatusNotifier.value = null;
    _compressionProgressNotifier.value = 0.0;
  }
}

// Extension for localization strings
extension EnhancedFileUploadLocalizations on AppLocalizations {
  String get attachFile => 'إرفاق ملف';
  String get gallery => 'المعرض';
  String get camera => 'الكاميرا';
  String get video => 'فيديو';
  String get file => 'ملف';
  String get processing => 'جاري المعالجة...';
  String get selectingFromGallery => 'جاري اختيار الصورة...';
  String get openingCamera => 'جاري فتح الكاميرا...';
  String get selectingVideo => 'جاري اختيار الفيديو...';
  String get selectingFile => 'جاري اختيار الملف...';
  String get failedToSelectImage => 'فشل في اختيار الصورة';
  String get failedToTakePhoto => 'فشل في التقاط الصورة';
  String get failedToSelectVideo => 'فشل في اختيار الفيديو';
  String get failedToSelectFile => 'فشل في اختيار الملف';
  String get failedToProcessFile => 'فشل في معالجة الملف';
  String get fileTooLarge => 'حجم الملف كبير جداً (الحد الأقصى 100 ميجابايت)';
}