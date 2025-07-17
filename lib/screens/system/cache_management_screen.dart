// lib/screens/cache_management_screen.dart

import 'package:flutter/material.dart';
import '../../core/utils/secure_data_manager.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/network_monitor.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/localization/app_localizations.dart';
import '../../helper/dialogs.dart';

class CacheManagementScreen extends BaseStatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends BaseState<CacheManagementScreen> {
  Map<String, dynamic>? _storageStats;
  NetworkState? _networkState;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final stats = await SecureDataManager.getStorageStats();
      final networkState = NetworkMonitor().currentState;
      
      if (mounted) {
        setState(() {
          _storageStats = stats;
          _networkState = networkState;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Dialogs.showSnackbar(context, 'خطأ في تحميل البيانات');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'إدارة التخزين المؤقت',
          style: TextStyle(
            color: colors.onSurface,
          ),
        ),
        backgroundColor: colors.primaryContainer,
        iconTheme: IconThemeData(
          color: colors.onSurface,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return BaseLoadingWidget(
      message: 'جاري تحميل بيانات التخزين...',
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: colors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStorageOverview(),
          const SizedBox(height: 20),
          _buildDetailedStats(),
          const SizedBox(height: 20),
          _buildNetworkStatus(),
          const SizedBox(height: 20),
          _buildActiveDownloads(),
          const SizedBox(height: 20),
          _buildCacheActions(),
        ],
      ),
    );
  }

  Widget _buildStorageOverview() {
    final stats = _storageStats;
    if (stats == null) return const SizedBox.shrink();

    final totalMB = stats['total'] as int? ?? 0;
    final maxMB = stats['maxCacheSizeMB'] as int? ?? 500;
    final usagePercentage = stats['cacheUsagePercentage'] as int? ?? 0;

    return Card(
      color: colors.primaryContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'نظرة عامة على التخزين',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Storage bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: colors.primaryContainer.withOpacity(0.3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (usagePercentage / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _getUsageColor(usagePercentage),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${totalMB}MB / ${maxMB}MB',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  '${usagePercentage}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getUsageColor(usagePercentage),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            if (usagePercentage > 80) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      size: 16,
                      color: colors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'التخزين المؤقت ممتلئ تقريباً. يُنصح بتنظيفه.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    final stats = _storageStats;
    if (stats == null) return const SizedBox.shrink();

    return Card(
      color: colors.primaryContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'إحصائيات التخزين',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildStatRow('الصور', '${stats['imageFiles'] ?? 0}', Icons.image),
            _buildStatRow('الفيديوهات', '${stats['videoFiles'] ?? 0}', Icons.videocam),
            _buildStatRow('الملفات الصوتية', '${stats['audioFiles'] ?? 0}', Icons.audiotrack),
            _buildStatRow('إجمالي الملفات', '${stats['totalFiles'] ?? 0}', Icons.folder),
            _buildStatRow('متوسط مرات الوصول', '${stats['averageFileAccessCount'] ?? 0}', Icons.trending_up),
            _buildStatRow('عمر أقدم ملف', '${stats['oldestCacheAgeDays'] ?? 0} يوم', Icons.access_time),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: colors.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStatus() {
    final networkState = _networkState;
    if (networkState == null) return const SizedBox.shrink();

    return Card(
      color: colors.primaryContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getNetworkIcon(networkState),
                  color: _getNetworkColor(networkState),
                ),
                const SizedBox(width: 8),
                Text(
                  'حالة الشبكة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildNetworkRow('الحالة', networkState.isConnected ? 'متصل' : 'غير متصل'),
            _buildNetworkRow('النوع', _getNetworkTypeName(networkState.type)),
            _buildNetworkRow('الجودة', _getNetworkQualityName(networkState.quality)),
            if (networkState.downloadSpeedKbps != null)
              _buildNetworkRow('السرعة', '${networkState.downloadSpeedKbps}kbps'),
            if (networkState.pingMs != null)
              _buildNetworkRow('البينغ', '${networkState.pingMs}ms'),
            _buildNetworkRow('محدود', networkState.isMetered ? 'نعم' : 'لا'),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDownloads() {
    return ValueListenableBuilder<Map<String, DownloadProgress>>(
      valueListenable: DownloadManager().progressNotifier,
      builder: (context, progressMap, child) {
        final activeDownloads = progressMap.values
            .where((p) => p.status == DownloadStatus.downloading)
            .toList();

        if (activeDownloads.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          color: colors.primaryContainer,
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.download,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'التحميلات النشطة (${activeDownloads.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                ...activeDownloads.map((download) => _buildDownloadItem(download)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadItem(DownloadProgress download) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  download.fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(download.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: download.progress,
            backgroundColor: colors.primaryContainer.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheActions() {
    return Card(
      color: colors.primaryContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'إعدادات التخزين',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildActionButton(
              'تنظيف الملفات القديمة',
              'حذف الملفات الأقدم من 7 أيام',
              Icons.auto_delete,
              () => _clearCache(keepRecent: true),
            ),
            
            const SizedBox(height: 8),
            
            _buildActionButton(
              'مسح التخزين المؤقت بالكامل',
              'حذف جميع الملفات المحفوظة',
              Icons.delete_sweep,
              () => _clearCache(keepRecent: false),
              isDestructive: true,
            ),
            
            const SizedBox(height: 8),
            
            _buildActionButton(
              'تنظيف تلقائي',
              'تنظيف الملفات القديمة والكبيرة',
              Icons.cleaning_services,
              _performSmartCleanup,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ElevatedButton(
        onPressed: _isClearing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive 
              ? colors.error.withOpacity(0.1)
              : colors.primary.withOpacity(0.1),
          elevation: 0,
          padding: const EdgeInsets.all(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive 
                  ? colors.error
                  : colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDestructive 
                          ? colors.error
                          : colors.primary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (_isClearing)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache({required bool keepRecent}) async {
    final confirmed = await _showConfirmationDialog(
      keepRecent ? 'تنظيف الملفات القديمة' : 'مسح التخزين المؤقت',
      keepRecent 
          ? 'سيتم حذف الملفات الأقدم من 7 أيام. هل تريد المتابعة؟'
          : 'سيتم حذف جميع الملفات المحفوظة. هل تريد المتابعة؟',
    );
    
    if (!confirmed) return;

    setState(() => _isClearing = true);
    
    try {
      final result = await SecureDataManager.clearCache(keepRecent: keepRecent);
      final deletedFiles = result['files'] as int;
      final freedSpace = result['space_mb'] as int;
      
      if (mounted) {
        Dialogs.showSnackbar(
          context,
          'تم حذف $deletedFiles ملف وتحرير ${freedSpace}MB',
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        Dialogs.showSnackbar(context, 'خطأ في تنظيف التخزين المؤقت');
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  Future<void> _performSmartCleanup() async {
    final confirmed = await _showConfirmationDialog(
      'تنظيف ذكي',
      'سيتم تنظيف الملفات القديمة والكبيرة بناءً على الاستخدام. هل تريد المتابعة؟',
    );
    
    if (!confirmed) return;

    setState(() => _isClearing = true);
    
    try {
      await SecureDataManager.cleanOldFiles();
      
      if (mounted) {
        Dialogs.showSnackbar(context, 'تم التنظيف الذكي بنجاح');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        Dialogs.showSnackbar(context, 'خطأ في التنظيف الذكي');
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          title,
          style: TextStyle(
            color: colors.onSurface,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: colors.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: colors.primary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
            ),
            child: const Text(
              'موافق',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Color _getUsageColor(int percentage) {
    if (percentage < 50) {
      return Colors.green;
    } else if (percentage < 80) {
      return Colors.orange;
    } else {
      return colors.error;
    }
  }

  IconData _getNetworkIcon(NetworkState state) {
    if (!state.isConnected) return Icons.wifi_off;
    
    switch (state.type) {
      case NetworkType.wifi:
        return Icons.wifi;
      case NetworkType.mobile:
        return Icons.signal_cellular_4_bar;
      case NetworkType.ethernet:
        return Icons.ethernet;
      default:
        return Icons.network_check;
    }
  }

  Color _getNetworkColor(NetworkState state) {
    if (!state.isConnected) {
      return colors.error;
    }
    
    switch (state.quality) {
      case NetworkQuality.excellent:
      case NetworkQuality.good:
        return Colors.green;
      case NetworkQuality.moderate:
        return Colors.orange;
      case NetworkQuality.poor:
        return colors.error;
      default:
        return colors.onSurface.withOpacity(0.7);
    }
  }

  String _getNetworkTypeName(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return 'واي فاي';
      case NetworkType.mobile:
        return 'بيانات محمولة';
      case NetworkType.ethernet:
        return 'إيثرنت';
      case NetworkType.vpn:
        return 'VPN';
      case NetworkType.none:
        return 'غير متصل';
      default:
        return 'أخرى';
    }
  }

  String _getNetworkQualityName(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return 'ممتازة';
      case NetworkQuality.good:
        return 'جيدة';
      case NetworkQuality.moderate:
        return 'متوسطة';
      case NetworkQuality.poor:
        return 'ضعيفة';
      case NetworkQuality.none:
        return 'لا توجد';
    }
  }
}