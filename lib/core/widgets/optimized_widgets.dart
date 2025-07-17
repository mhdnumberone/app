import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state_providers.dart';
import '../managers/settings_manager.dart';
import '../themes/app_themes.dart';

/// Performance-optimized widgets that minimize rebuilds
/// These widgets use Riverpod selectors and builders to rebuild only when necessary

/// Optimized connection status indicator
class ConnectionStatusWidget extends ConsumerWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuild when connection status changes
    final connectionStatus = ref.watch(connectionStatusTextProvider);
    final isConnected = ref.watch(connectionInfoProvider).isConnected;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            connectionStatus,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized file count display
class FileCountWidget extends ConsumerWidget {
  const FileCountWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuild when file counts change
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Files',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _StatItem(
              label: 'Audio Files',
              value: 'N/A', // fileStatsProvider removed
              icon: Icons.audiotrack,
            ),
            _StatItem(
              label: 'Browser Files',
              value: 'N/A', // fileStatsProvider removed
              icon: Icons.folder,
            ),
            _StatItem(
              label: 'Total Files',
              value: 'N/A', // fileStatsProvider removed
              icon: Icons.storage,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal widget for file stats - doesn't rebuild unless values change
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isTotal;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isTotal ? Theme.of(context).primaryColor : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized loading indicator that only shows when actually loading
class LoadingIndicatorWidget extends ConsumerWidget {
  const LoadingIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(isLoadingProvider);
    
    if (!isLoading) {
      return const SizedBox.shrink();
    }
    
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(),
    );
  }
}

/// Optimized error display that only shows when there are errors
class ErrorDisplayWidget extends ConsumerWidget {
  const ErrorDisplayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasError = ref.watch(hasErrorProvider);
    final errorStates = ref.watch(errorStateProvider);
    
    if (!hasError) {
      return const SizedBox.shrink();
    }
    
    final errorMessage = errorStates.values
        .where((error) => error != null)
        .first;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(errorStateProvider.notifier).state = {};
            },
          ),
        ],
      ),
    );
  }
}

/// Optimized audio file list that uses ListView.builder for performance
class OptimizedAudioFileList extends ConsumerWidget {
  final String? filter;
  
  const OptimizedAudioFileList({
    super.key,
    this.filter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استخدم مزود النظام الجديد لعرض الملفات
    final filesAsync = ref.watch(deviceFilesProvider);

    return filesAsync.when(
      data: (files) {
        // فلترة الملفات الصوتية فقط
        final audioFiles = files.where((f) => f.type == 'audio').toList();
        // تطبيق الفلتر إذا كان موجودًا
        final filtered = (filter != null && filter!.isNotEmpty)
            ? audioFiles.where((f) => f.name.toLowerCase().contains(filter!.toLowerCase())).toList()
            : audioFiles;
        if (filtered.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.audiotrack_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No audio files found',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final audioFile = filtered[index];
            return AudioFileListTile(
              key: ValueKey(audioFile.path),
              audioFile: audioFile,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('خطأ في تحميل الملفات الصوتية')),
    );
  }
}

/// Individual audio file tile that only rebuilds when file data changes
class AudioFileListTile extends StatelessWidget {
  final dynamic audioFile; // AudioFile type
  
  const AudioFileListTile({
    super.key,
    required this.audioFile,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.audiotrack),
      title: Text(audioFile.name),
      subtitle: Text(audioFile.path),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              // Play audio file
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // Delete audio file
            },
          ),
        ],
      ),
    );
  }
}

/// Optimized theme switcher that doesn't rebuild the entire app
class ThemeSwitcherWidget extends ConsumerWidget {
  const ThemeSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(currentThemeProvider);
    
    return DropdownButton<AppThemeType>(
      value: currentTheme,
      onChanged: (AppThemeType? newTheme) {
        if (newTheme != null) {
          SettingsManager.instance.updateTheme(newTheme);
        }
      },
      items: AppThemeType.values.map((theme) {
        return DropdownMenuItem<AppThemeType>(
          value: theme,
          child: Text(_getThemeName(theme)),
        );
      }).toList(),
    );
  }
  
  String _getThemeName(AppThemeType theme) {
    switch (theme) {
      case AppThemeType.intelligence:
        return 'Intelligence';
      case AppThemeType.dark:
        return 'Dark';
      case AppThemeType.light:
        return 'Light';
      case AppThemeType.auto:
        return 'Auto';
    }
  }
}

/// Debounced search widget that doesn't trigger searches on every keystroke
class DebouncedSearchWidget extends ConsumerStatefulWidget {
  final String category;
  final String hint;
  final Function(String) onSearch;
  
  const DebouncedSearchWidget({
    super.key,
    required this.category,
    required this.hint,
    required this.onSearch,
  });

  @override
  ConsumerState<DebouncedSearchWidget> createState() => _DebouncedSearchWidgetState();
}

class _DebouncedSearchWidgetState extends ConsumerState<DebouncedSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  
  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider(widget.category).notifier).state = query;
      widget.onSearch(query);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: _onSearchChanged,
    );
  }
}

/// Memoized expensive widget that caches its build result
class MemoizedExpensiveWidget extends ConsumerWidget {
  final String input;
  
  const MemoizedExpensiveWidget({
    super.key,
    required this.input,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This will only recompute when input changes
    final result = ref.watch(expensiveComputationProvider(input));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(result),
    );
  }
}

/// Performance metrics widget for monitoring app performance
class PerformanceMetricsWidget extends ConsumerWidget {
  const PerformanceMetricsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceGrade = ref.watch(performanceGradeProvider);
    final frameDropRate = ref.watch(frameDropRateProvider);
    final avgFrameTime = ref.watch(averageFrameTimeProvider);
    final slowOpsCount = ref.watch(slowOperationsCountProvider);
    final isPerformanceGood = ref.watch(performanceStatusProvider);
    
    return Card(
      color: isPerformanceGood ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isPerformanceGood ? Icons.check_circle : Icons.warning,
                  color: isPerformanceGood ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Performance Grade: $performanceGrade',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPerformanceGood ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _MetricRow(
              label: 'Frame Time',
              value: '${avgFrameTime}ms',
              isGood: avgFrameTime <= 16,
            ),
            _MetricRow(
              label: 'Drop Rate',
              value: '${frameDropRate.toStringAsFixed(1)}%',
              isGood: frameDropRate < 5.0,
            ),
            _MetricRow(
              label: 'Slow Ops',
              value: slowOpsCount.toString(),
              isGood: slowOpsCount < 3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal widget for performance metric rows
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isGood;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isGood ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

