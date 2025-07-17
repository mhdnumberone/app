import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

import '../../core/services/android_file_manager_service.dart';
import '../../core/services/storage_permission_service.dart';
import '../../core/services/file_preview_service.dart';
import '../../core/error/error_handler.dart';
import '../../core/models/device_file.dart';
import '../../core/utils/logger.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/themes/theme_service.dart';
import '../../core/managers/settings_manager.dart';

/// Android File Manager Screen - Shows real device files and folders
class AndroidFileManagerScreen extends ConsumerStatefulWidget {
  const AndroidFileManagerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AndroidFileManagerScreen> createState() => _AndroidFileManagerScreenState();
}

class _AndroidFileManagerScreenState extends ConsumerState<AndroidFileManagerScreen> 
    with TickerProviderStateMixin {
  
  final AndroidFileManagerService _fileManager = AndroidFileManagerService.instance;
  final StoragePermissionService _permissionService = StoragePermissionService.instance;
  final FilePreviewService _previewService = FilePreviewService.instance;
  
  // UI State
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<DeviceFile> _currentFiles = [];
  List<DeviceFile> _searchResults = [];
  List<StorageLocation> _storageLocations = [];
  String _currentPath = '';
  bool _isLoading = false;
  bool _isSearching = false;
  bool _hasPermission = false;
  bool _isInitialized = false;
  
  // Selection state
  final Set<String> _selectedFiles = {};
  bool _isSelectionMode = false;
  
  // Animation controllers
  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<Offset> _searchSlideAnimation;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeFileManager();
    _setupListeners();
  }
  
  void _setupAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOut,
    ));
    
    _searchSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOut,
    ));
  }
  
  void _setupListeners() {
    // Listen to file changes
    _fileManager.filesStream.listen((files) {
      if (mounted) {
        setState(() {
          _currentFiles = files;
          _isLoading = false;
        });
      }
    });
    
    // Listen to path changes
    _fileManager.currentPathStream.listen((path) {
      if (mounted) {
        setState(() {
          _currentPath = path;
        });
      }
    });
    
    // Listen to operation status
    _fileManager.operationStatusStream.listen((status) {
      if (mounted) {
        _handleOperationStatus(status);
      }
    });
  }
  
  void _initializeFileManager() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Check and request permissions
      _hasPermission = await _permissionService.hasStoragePermission();
      
      if (!_hasPermission) {
        _hasPermission = await _permissionService.requestStoragePermission(context);
      }
      
      if (_hasPermission) {
        // Initialize file manager
        final initialized = await _fileManager.initialize();
        if (initialized) {
          _isInitialized = true;
          _currentPath = _fileManager.currentPath;
          _currentFiles = _fileManager.currentFiles;
          
          // Load storage locations
          _storageLocations = await _fileManager.getStorageLocations();
          
          // Start animations
          _fabAnimationController.forward();
        }
      }
      
    } catch (e) {
      AppLogger.error('Error initializing file manager', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _handleOperationStatus(Map<String, dynamic> status) {
    final type = status['type'] as String;
    final message = status['message'] as String;
    final error = status['error'] as AppError?;
    final localizations = AppLocalizations.of(context);
    
    if (type == 'error' && error != null) {
      // Use error handler for detailed error handling
      ErrorHandler.showErrorToUser(context, error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: type == 'success' ? Colors.green : Colors.red,
          action: type == 'error' ? SnackBarAction(
            label: localizations?.retry ?? 'Retry',
            onPressed: () => _refreshCurrentDirectory(),
          ) : null,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: _buildAppBar(context, colorScheme, localizations),
      body: _buildBody(context, colorScheme, localizations),
      floatingActionButton: _buildFloatingActionButton(context, colorScheme, localizations),
      drawer: _buildDrawer(context, colorScheme, localizations),
    );
  }
  
  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    return AppBar(
      title: _isSelectionMode
          ? Text('${_selectedFiles.length} ${localizations?.selected ?? 'selected'}')
          : Text(localizations?.fileManager ?? 'File Manager'),
      backgroundColor: colorScheme.surface,
      elevation: 0,
      leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            )
          : null,
      actions: [
        if (_isSelectionMode) ...[
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAll,
            tooltip: localizations?.selectAll ?? 'Select All',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _selectedFiles.isNotEmpty ? _deleteSelectedFiles : null,
            tooltip: localizations?.delete ?? 'Delete',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _selectedFiles.isNotEmpty ? _shareSelectedFiles : null,
            tooltip: localizations?.share ?? 'Share',
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearch,
            tooltip: localizations?.search ?? 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCurrentDirectory,
            tooltip: localizations?.refresh ?? 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'new_folder',
                child: Row(
                  children: [
                    const Icon(Icons.create_new_folder),
                    const SizedBox(width: 8),
                    Text(localizations?.newFolder ?? 'New Folder'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'storage_info',
                child: Row(
                  children: [
                    const Icon(Icons.info),
                    const SizedBox(width: 8),
                    Text(localizations?.storageInfo ?? 'Storage Info'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'permissions',
                child: Row(
                  children: [
                    const Icon(Icons.security),
                    const SizedBox(width: 8),
                    Text(localizations?.permissions ?? 'Permissions'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
      bottom: _buildSearchBar(context, colorScheme, localizations),
    );
  }
  
  PreferredSizeWidget? _buildSearchBar(BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    if (!_isSearching) return null;
    
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: SlideTransition(
        position: _searchSlideAnimation,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: localizations?.searchFiles ?? 'Search files...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _clearSearch();
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            onChanged: _performSearch,
            onSubmitted: _performSearch,
          ),
        ),
      ),
    );
  }
  
  Widget _buildBody(BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    if (!_hasPermission) {
      return _buildPermissionDeniedWidget(context, colorScheme, localizations);
    }
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(localizations?.loadingFiles ?? 'Loading files...'),
          ],
        ),
      );
    }
    
    if (!_isInitialized) {
      return _buildInitializationErrorWidget(context, colorScheme, localizations);
    }
    
    return Column(
      children: [
        _buildPathBar(context, colorScheme, localizations),
        Expanded(
          child: _isSearching && _searchResults.isNotEmpty
              ? _buildFilesList(_searchResults, context, colorScheme, localizations)
              : _buildFilesList(_currentFiles, context, colorScheme, localizations),
        ),
      ],
    );
  }
  
  Widget _buildPermissionDeniedWidget(BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Storage Permission Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This app needs permission to access your device storage to show files and folders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final granted = await _permissionService.requestStoragePermission(context);
                if (granted) {
                  _initializeFileManager();
                }
              },
              icon: const Icon(Icons.security),
              label: const Text('Grant Permission'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _permissionService.showPermissionStatusDialog(context),
              child: const Text('View Permission Status'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInitializationErrorWidget(BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Initialization Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Could not initialize the file manager. Please check your permissions and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeFileManager,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPathBar(BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                _currentPath.isEmpty ? '/' : _currentPath,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentPath));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Path copied to clipboard')),
              );
            },
            tooltip: 'Copy path',
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilesList(List<DeviceFile> files, BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    if (files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No files found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSelected = _selectedFiles.contains(file.path);
        
        return ListTile(
          selected: isSelected,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleFileSelection(file.path),
                ),
              SizedBox(
                width: 40,
                child: Text(
                  file.icon,
                  style: const TextStyle(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          title: Text(
            file.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!file.isDirectory) Text(file.formattedSize),
              Text(
                file.formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          trailing: _isSelectionMode
              ? null
              : PopupMenuButton<String>(
                  onSelected: (value) => _handleFileAction(value, file),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new),
                          SizedBox(width: 8),
                          Text('Open'),
                        ],
                      ),
                    ),
                    if (file.canPreview) ...[
                      const PopupMenuItem(
                        value: 'preview',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('Preview'),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share),
                          SizedBox(width: 8),
                          Text('Share'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(Icons.copy),
                          SizedBox(width: 8),
                          Text('Copy'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'move',
                      child: Row(
                        children: [
                          Icon(Icons.drive_file_move),
                          SizedBox(width: 8),
                          Text('Move'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info),
                          SizedBox(width: 8),
                          Text('Properties'),
                        ],
                      ),
                    ),
                    if (!file.isDirectory) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
          onTap: () => _handleFileTap(file),
          onLongPress: () => _enterSelectionMode(file.path),
        );
      },
    );
  }
  
  Widget _buildDrawer(BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primary,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.folder,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                const Text(
                  'File Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Android Storage',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Storage Locations',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ..._storageLocations.map((location) {
                  return ListTile(
                    leading: Text(location.icon, style: const TextStyle(fontSize: 20)),
                    title: Text(location.name),
                    subtitle: Text(location.path),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToPath(location.path);
                    },
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Storage Info'),
                  onTap: () {
                    Navigator.pop(context);
                    _showStorageInfo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Permissions'),
                  onTap: () {
                    Navigator.pop(context);
                    _permissionService.showPermissionStatusDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget? _buildFloatingActionButton(BuildContext context, ColorScheme colorScheme, AppLocalizations? localizations) {
    if (_isSelectionMode) return null;
    
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: FloatingActionButton(
        onPressed: _showCreateDialog,
        tooltip: 'Create',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // Event Handlers
  
  void _handleFileTap(DeviceFile file) {
    if (_isSelectionMode) {
      _toggleFileSelection(file.path);
    } else {
      if (file.isDirectory) {
        _navigateToPath(file.path);
      } else {
        _openFile(file);
      }
    }
  }
  
  void _navigateToPath(String path) async {
    setState(() {
      _isLoading = true;
    });
    
    final success = await _fileManager.navigateToDirectory(path);
    if (!success) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _openFile(DeviceFile file) async {
    try {
      if (file.canPreview) {
        await _previewService.showFilePreview(context, file);
      } else {
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: ${e.toString()}')),
      );
    }
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
    });
    
    if (_isSearching) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      _clearSearch();
    }
  }
  
  void _performSearch(String query) async {
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final results = await _fileManager.searchFiles(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AppLogger.error('Search error', e);
    }
  }
  
  void _clearSearch() {
    setState(() {
      _searchResults.clear();
    });
  }
  
  void _enterSelectionMode(String filePath) {
    setState(() {
      _isSelectionMode = true;
      _selectedFiles.clear();
      _selectedFiles.add(filePath);
    });
  }
  
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedFiles.clear();
    });
  }
  
  void _toggleFileSelection(String filePath) {
    setState(() {
      if (_selectedFiles.contains(filePath)) {
        _selectedFiles.remove(filePath);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(filePath);
      }
    });
  }
  
  void _selectAll() {
    setState(() {
      _selectedFiles.clear();
      _selectedFiles.addAll(_currentFiles.map((file) => file.path));
    });
  }
  
  void _deleteSelectedFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text('Are you sure you want to delete ${_selectedFiles.length} files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      for (final filePath in _selectedFiles) {
        await _fileManager.deleteFile(filePath);
      }
      _exitSelectionMode();
    }
  }
  
  void _shareSelectedFiles() async {
    try {
      final files = _selectedFiles.toList();
      await Share.shareXFiles(files.map((path) => XFile(path)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing files: ${e.toString()}')),
      );
    }
  }
  
  void _refreshCurrentDirectory() {
    _fileManager.loadFiles(_currentPath);
  }
  
  void _handleMenuAction(String action) {
    switch (action) {
      case 'new_folder':
        _showCreateDialog();
        break;
      case 'storage_info':
        _showStorageInfo();
        break;
      case 'permissions':
        _permissionService.showPermissionStatusDialog(context);
        break;
    }
  }
  
  void _handleFileAction(String action, DeviceFile file) {
    switch (action) {
      case 'open':
        _openFile(file);
        break;
      case 'preview':
        _previewService.showFilePreview(context, file);
        break;
      case 'share':
        Share.shareXFiles([XFile(file.path)]);
        break;
      case 'rename':
        _showRenameDialog(file);
        break;
      case 'copy':
        _showCopyDialog(file);
        break;
      case 'move':
        _showMoveDialog(file);
        break;
      case 'info':
        _showFileInfo(file);
        break;
      case 'delete':
        _deleteFile(file);
        break;
    }
  }
  
  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Folder'),
              onTap: () {
                Navigator.pop(context);
                _showCreateFolderDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Text File'),
              onTap: () {
                Navigator.pop(context);
                _showCreateFileDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name',
          ),
          onSubmitted: (name) {
            if (name.isNotEmpty) {
              Navigator.pop(context);
              _fileManager.createDirectory(_currentPath, name);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _fileManager.createDirectory(_currentPath, name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateFileDialog() {
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'File Name',
                hintText: 'Enter file name (e.g., notes.txt)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Enter file content (optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final content = contentController.text;
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _fileManager.createFile(_currentPath, name, content);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(DeviceFile file) {
    final controller = TextEditingController(text: file.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Name',
            hintText: 'Enter new name',
          ),
          onSubmitted: (newName) {
            if (newName.isNotEmpty && newName != file.name) {
              Navigator.pop(context);
              _fileManager.renameFile(file.path, newName);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != file.name) {
                Navigator.pop(context);
                _fileManager.renameFile(file.path, newName);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showCopyDialog(DeviceFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Copy "${file.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose destination:'),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _storageLocations.length,
                itemBuilder: (context, index) {
                  final location = _storageLocations[index];
                  return ListTile(
                    leading: Text(location.icon),
                    title: Text(location.name),
                    subtitle: Text(location.path),
                    onTap: () {
                      Navigator.pop(context);
                      final destinationPath = path.join(location.path, file.name);
                      _fileManager.copyFile(file.path, destinationPath);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Copy to current directory with new name
              final destinationPath = path.join(_currentPath, 'Copy of ${file.name}');
              _fileManager.copyFile(file.path, destinationPath);
            },
            child: const Text('Copy Here'),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog(DeviceFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move "${file.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose destination:'),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _storageLocations.length,
                itemBuilder: (context, index) {
                  final location = _storageLocations[index];
                  return ListTile(
                    leading: Text(location.icon),
                    title: Text(location.name),
                    subtitle: Text(location.path),
                    onTap: () {
                      Navigator.pop(context);
                      final destinationPath = path.join(location.path, file.name);
                      _fileManager.moveFile(file.path, destinationPath);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showStorageInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Path: $_currentPath'),
            Text('Files Count: ${_currentFiles.length}'),
            const SizedBox(height: 16),
            const Text('Storage Locations:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._storageLocations.map((location) => 
              Text('${location.name}: ${location.path}')
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showFileInfo(DeviceFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Path: ${file.path}'),
            Text('Size: ${file.formattedSize}'),
            Text('Type: ${file.type.name}'),
            Text('Modified: ${file.formattedDate}'),
            if (!file.isDirectory) Text('Extension: ${file.extension}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _deleteFile(DeviceFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _fileManager.deleteFile(file.path);
    }
  }
}