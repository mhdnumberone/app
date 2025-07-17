import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_settings/app_settings.dart';
import '../utils/logger.dart';

/// Service for handling storage permissions specifically for file manager
class StoragePermissionService {
  static final StoragePermissionService _instance = StoragePermissionService._internal();
  static StoragePermissionService get instance => _instance;
  
  factory StoragePermissionService() => _instance;
  
  StoragePermissionService._internal();

  /// Check if we have the necessary storage permissions
  Future<bool> hasStoragePermission() async {
    try {
      if (!Platform.isAndroid) return true;
      
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidVersion = androidInfo.version.sdkInt;
      
      AppLogger.info('Checking storage permissions for Android API $androidVersion');
      
      if (androidVersion >= 33) {
        // Android 13+ (API 33+) - Use granular media permissions
        final permissions = [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ];
        
        // Check if at least one media permission is granted
        for (final permission in permissions) {
          final status = await permission.status;
          if (status.isGranted) {
            AppLogger.info('Media permission granted: $permission');
            return true;
          }
        }
        
        // Check for MANAGE_EXTERNAL_STORAGE
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        if (manageStorageStatus.isGranted) {
          AppLogger.info('MANAGE_EXTERNAL_STORAGE permission granted');
          return true;
        }
        
        return false;
        
      } else if (androidVersion >= 30) {
        // Android 11-12 (API 30-32) - Check MANAGE_EXTERNAL_STORAGE first
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        if (manageStorageStatus.isGranted) {
          AppLogger.info('MANAGE_EXTERNAL_STORAGE permission granted');
          return true;
        }
        
        // Fall back to legacy storage permissions
        final storageStatus = await Permission.storage.status;
        return storageStatus.isGranted;
        
      } else {
        // Android 10 and below - Use legacy storage permissions
        final storageStatus = await Permission.storage.status;
        return storageStatus.isGranted;
      }
      
    } catch (e) {
      AppLogger.error('Error checking storage permissions', e);
      return false;
    }
  }

  /// Request storage permissions with proper UI flow
  Future<bool> requestStoragePermission(BuildContext context) async {
    try {
      if (!Platform.isAndroid) return true;
      
      // Check if we already have permissions
      if (await hasStoragePermission()) {
        return true;
      }
      
      // Show educational dialog first
      final userWantsToGrant = await _showPermissionEducationDialog(context);
      if (!userWantsToGrant) {
        return false;
      }
      
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidVersion = androidInfo.version.sdkInt;
      
      AppLogger.info('Requesting storage permissions for Android API $androidVersion');
      
      if (androidVersion >= 33) {
        // Android 13+ (API 33+) - Request granular media permissions
        return await _requestAndroid13Permissions(context);
        
      } else if (androidVersion >= 30) {
        // Android 11-12 (API 30-32) - Request MANAGE_EXTERNAL_STORAGE
        return await _requestAndroid11Permissions(context);
        
      } else {
        // Android 10 and below - Request legacy storage permissions
        return await _requestLegacyStoragePermissions(context);
      }
      
    } catch (e) {
      AppLogger.error('Error requesting storage permissions', e);
      return false;
    }
  }

  /// Request permissions for Android 13+
  Future<bool> _requestAndroid13Permissions(BuildContext context) async {
    try {
      // First try to request granular media permissions
      final permissions = [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ];
      
      final results = await permissions.request();
      
      // Check if at least one permission was granted
      bool hasAnyPermission = results.values.any((status) => status.isGranted);
      
      if (hasAnyPermission) {
        AppLogger.info('Media permissions granted');
        return true;
      }
      
      // If no media permissions, try MANAGE_EXTERNAL_STORAGE
      final shouldRequestManageStorage = await _showManageStorageDialog(context);
      if (shouldRequestManageStorage) {
        return await _requestManageExternalStorage(context);
      }
      
      return false;
      
    } catch (e) {
      AppLogger.error('Error requesting Android 13+ permissions', e);
      return false;
    }
  }

  /// Request permissions for Android 11-12
  Future<bool> _requestAndroid11Permissions(BuildContext context) async {
    try {
      // Try MANAGE_EXTERNAL_STORAGE first
      final shouldRequestManageStorage = await _showManageStorageDialog(context);
      if (shouldRequestManageStorage) {
        final granted = await _requestManageExternalStorage(context);
        if (granted) return true;
      }
      
      // Fall back to legacy storage permissions
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
      
    } catch (e) {
      AppLogger.error('Error requesting Android 11-12 permissions', e);
      return false;
    }
  }

  /// Request legacy storage permissions
  Future<bool> _requestLegacyStoragePermissions(BuildContext context) async {
    try {
      final storageStatus = await Permission.storage.request();
      
      if (storageStatus.isGranted) {
        AppLogger.info('Legacy storage permission granted');
        return true;
      }
      
      // If denied, show dialog to open settings
      if (storageStatus.isDenied || storageStatus.isPermanentlyDenied) {
        await _showOpenSettingsDialog(context);
      }
      
      return false;
      
    } catch (e) {
      AppLogger.error('Error requesting legacy storage permissions', e);
      return false;
    }
  }

  /// Request MANAGE_EXTERNAL_STORAGE permission
  Future<bool> _requestManageExternalStorage(BuildContext context) async {
    try {
      final status = await Permission.manageExternalStorage.request();
      
      if (status.isGranted) {
        AppLogger.info('MANAGE_EXTERNAL_STORAGE permission granted');
        return true;
      }
      
      // If denied, show dialog to open settings
      if (status.isDenied || status.isPermanentlyDenied) {
        await _showOpenSettingsDialog(context);
      }
      
      return false;
      
    } catch (e) {
      AppLogger.error('Error requesting MANAGE_EXTERNAL_STORAGE permission', e);
      return false;
    }
  }

  /// Show permission education dialog
  Future<bool> _showPermissionEducationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.folder_open, color: Colors.blue, size: 24),
            SizedBox(width: 12),
            Text('File Manager Permissions'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To access and manage your files, this app needs storage permissions.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'This allows the app to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Browse your device files and folders'),
            const Text('• View images, videos, and documents'),
            const Text('• Create, delete, and organize files'),
            const Text('• Access Downloads, Pictures, and other folders'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your privacy is protected. The app only accesses files you choose to view.',
                      style: TextStyle(color: Colors.green, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show dialog for MANAGE_EXTERNAL_STORAGE permission
  Future<bool> _showManageStorageDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text('Enhanced File Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For the best file management experience, you can grant "All Files Access" permission.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'This enhanced permission allows:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Access to all file types and folders'),
            const Text('• Complete file management capabilities'),
            const Text('• Better performance and reliability'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is optional. You can still use basic file access without this permission.',
                      style: TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Enhanced Access'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show dialog to open settings
  Future<void> _showOpenSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Text('Permission Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'File access permission is required to use this feature.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Please enable the permission in system settings:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Go to App Settings'),
            Text('2. Select "Permissions"'),
            Text('3. Enable "Files and Media" or "Storage"'),
            Text('4. Return to the app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Check if permission is permanently denied
  Future<bool> isPermissionPermanentlyDenied() async {
    try {
      if (!Platform.isAndroid) return false;
      
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidVersion = androidInfo.version.sdkInt;
      
      if (androidVersion >= 33) {
        // Check media permissions
        final permissions = [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ];
        
        for (final permission in permissions) {
          final status = await permission.status;
          if (status.isPermanentlyDenied) return true;
        }
        
        // Check MANAGE_EXTERNAL_STORAGE
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        return manageStorageStatus.isPermanentlyDenied;
        
      } else if (androidVersion >= 30) {
        // Check MANAGE_EXTERNAL_STORAGE
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        if (manageStorageStatus.isPermanentlyDenied) return true;
        
        // Check legacy storage
        final storageStatus = await Permission.storage.status;
        return storageStatus.isPermanentlyDenied;
        
      } else {
        // Check legacy storage
        final storageStatus = await Permission.storage.status;
        return storageStatus.isPermanentlyDenied;
      }
      
    } catch (e) {
      AppLogger.error('Error checking if permission is permanently denied', e);
      return false;
    }
  }

  /// Get current permission status summary
  Future<Map<String, dynamic>> getPermissionStatus() async {
    try {
      if (!Platform.isAndroid) {
        return {
          'hasPermission': true,
          'permissionType': 'iOS',
          'details': 'iOS does not require explicit storage permissions'
        };
      }
      
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidVersion = androidInfo.version.sdkInt;
      
      final status = <String, dynamic>{
        'androidVersion': androidVersion,
        'hasPermission': false,
        'permissionType': 'unknown',
        'details': {},
      };
      
      if (androidVersion >= 33) {
        // Android 13+ permissions
        final permissions = [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ];
        
        final permissionStatuses = <String, String>{};
        bool hasAnyMedia = false;
        
        for (final permission in permissions) {
          final permissionStatus = await permission.status;
          permissionStatuses[permission.toString()] = permissionStatus.toString();
          if (permissionStatus.isGranted) hasAnyMedia = true;
        }
        
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        permissionStatuses['manageExternalStorage'] = manageStorageStatus.toString();
        
        status['hasPermission'] = hasAnyMedia || manageStorageStatus.isGranted;
        status['permissionType'] = 'Android 13+ Media';
        status['details'] = permissionStatuses;
        
      } else if (androidVersion >= 30) {
        // Android 11-12 permissions
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        final storageStatus = await Permission.storage.status;
        
        status['hasPermission'] = manageStorageStatus.isGranted || storageStatus.isGranted;
        status['permissionType'] = 'Android 11-12';
        status['details'] = {
          'manageExternalStorage': manageStorageStatus.toString(),
          'storage': storageStatus.toString(),
        };
        
      } else {
        // Android 10 and below
        final storageStatus = await Permission.storage.status;
        
        status['hasPermission'] = storageStatus.isGranted;
        status['permissionType'] = 'Legacy Storage';
        status['details'] = {
          'storage': storageStatus.toString(),
        };
      }
      
      return status;
      
    } catch (e) {
      AppLogger.error('Error getting permission status', e);
      return {
        'hasPermission': false,
        'permissionType': 'error',
        'details': {'error': e.toString()}
      };
    }
  }

  /// Show permission status dialog (for debugging)
  Future<void> showPermissionStatusDialog(BuildContext context) async {
    final status = await getPermissionStatus();
    
    if (!context.mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Status'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Has Permission: ${status['hasPermission']}'),
              Text('Type: ${status['permissionType']}'),
              if (status['androidVersion'] != null)
                Text('Android Version: ${status['androidVersion']}'),
              const SizedBox(height: 16),
              const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...((status['details'] as Map<String, dynamic>).entries.map((entry) {
                return Text('${entry.key}: ${entry.value}');
              }).toList()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!status['hasPermission'])
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                requestStoragePermission(context);
              },
              child: const Text('Request Permission'),
            ),
        ],
      ),
    );
  }
}