// Rebuild-Optimized Widget System
import 'package:flutter/material.dart';
import '../performance/rebuild_tracker.dart';
import '../themes/app_theme_extension.dart';
import '../localization/app_localizations.dart';

/// Base optimized widget that prevents unnecessary rebuilds
abstract class OptimizedWidget extends StatefulWidget {
  const OptimizedWidget({super.key});
  
  @override
  State<OptimizedWidget> createState();
}

abstract class OptimizedWidgetState<T extends OptimizedWidget> extends State<T> {
  String get widgetName => T.toString();
  
  @override
  Widget build(BuildContext context) {
    return RebuildTrackingWidget(
      name: widgetName,
      child: RepaintBoundary(
        child: buildOptimized(context),
      ),
    );
  }
  
  Widget buildOptimized(BuildContext context);
}

/// Optimized list item with proper keys and boundaries
class OptimizedListItem extends StatefulWidget {
  final String itemKey;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  const OptimizedListItem({
    super.key,
    required this.itemKey,
    required this.child,
    this.onTap,
    this.onLongPress,
  });
  
  @override
  State<OptimizedListItem> createState() => _OptimizedListItemState();
}

class _OptimizedListItemState extends State<OptimizedListItem> {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: ValueKey(widget.itemKey),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      ),
    );
  }
}

/// Optimized stream builder that prevents excessive rebuilds
class OptimizedStreamBuilder<T> extends StatefulWidget {
  final Stream<T> stream;
  final T? initialData;
  final Widget Function(BuildContext, AsyncSnapshot<T>) builder;
  final String? debugName;
  
  const OptimizedStreamBuilder({
    super.key,
    required this.stream,
    this.initialData,
    required this.builder,
    this.debugName,
  });
  
  @override
  State<OptimizedStreamBuilder<T>> createState() => _OptimizedStreamBuilderState<T>();
}

class _OptimizedStreamBuilderState<T> extends State<OptimizedStreamBuilder<T>> {
  AsyncSnapshot<T>? _lastSnapshot;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: widget.stream,
      initialData: widget.initialData,
      builder: (context, snapshot) {
        // Only rebuild if data actually changed
        if (_lastSnapshot != null && 
            _lastSnapshot!.data == snapshot.data &&
            _lastSnapshot!.connectionState == snapshot.connectionState) {
          return widget.builder(context, _lastSnapshot!);
        }
        
        _lastSnapshot = snapshot;
        
        if (widget.debugName != null) {
          RebuildTracker.instance.trackRebuild(
            'OptimizedStreamBuilder:${widget.debugName}',
            reason: 'Data changed',
          );
        }
        
        return widget.builder(context, snapshot);
      },
    );
  }
}

/// Optimized text field that doesn't rebuild parent
class OptimizedTextField extends StatefulWidget {
  final String? hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;
  final int? maxLines;
  final bool enabled;
  
  const OptimizedTextField({
    super.key,
    this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.decoration,
    this.maxLines = 1,
    this.enabled = true,
  });
  
  @override
  State<OptimizedTextField> createState() => _OptimizedTextFieldState();
}

class _OptimizedTextFieldState extends State<OptimizedTextField> {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        onSubmitted: widget.onSubmitted,
        maxLines: widget.maxLines,
        enabled: widget.enabled,
        decoration: widget.decoration ?? InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Optimized button that prevents parent rebuilds
class OptimizedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool loading;
  
  const OptimizedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.loading = false,
  });
  
  @override
  State<OptimizedButton> createState() => _OptimizedButtonState();
}

class _OptimizedButtonState extends State<OptimizedButton> {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ElevatedButton(
        onPressed: widget.loading ? null : widget.onPressed,
        style: widget.style,
        child: widget.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : widget.child,
      ),
    );
  }
}

/// Optimized list view with proper keys and boundaries
class OptimizedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, int, T) itemBuilder;
  final String Function(T) keyExtractor;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  
  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.keyExtractor,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
  });
  
  @override
  State<OptimizedListView<T>> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final key = widget.keyExtractor(item);
        
        return OptimizedListItem(
          key: ValueKey(key),
          itemKey: key,
          child: widget.itemBuilder(context, index, item),
        );
      },
    );
  }
}

/// Optimized card widget with proper boundaries
class OptimizedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final double? elevation;
  
  const OptimizedCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.elevation,
  });
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: margin ?? const EdgeInsets.all(8),
        child: Card(
          elevation: elevation ?? 2,
          color: backgroundColor,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Optimized app bar that doesn't rebuild unnecessarily
class OptimizedAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  
  const OptimizedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
  });
  
  @override
  State<OptimizedAppBar> createState() => _OptimizedAppBarState();
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _OptimizedAppBarState extends State<OptimizedAppBar> {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AppBar(
        title: Text(widget.title),
        actions: widget.actions,
        leading: widget.leading,
        automaticallyImplyLeading: widget.automaticallyImplyLeading,
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
      ),
    );
  }
}

/// Optimized tab bar that prevents rebuilds
class OptimizedTabBar extends StatefulWidget {
  final List<Tab> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;
  
  const OptimizedTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.onTap,
  });
  
  @override
  State<OptimizedTabBar> createState() => _OptimizedTabBarState();
}

class _OptimizedTabBarState extends State<OptimizedTabBar> {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TabBar(
        tabs: widget.tabs,
        controller: widget.controller,
        onTap: widget.onTap,
      ),
    );
  }
}

/// Optimized page view that caches pages
class OptimizedPageView extends StatefulWidget {
  final List<Widget> pages;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final bool cachePages;
  
  const OptimizedPageView({
    super.key,
    required this.pages,
    this.controller,
    this.onPageChanged,
    this.cachePages = true,
  });
  
  @override
  State<OptimizedPageView> createState() => _OptimizedPageViewState();
}

class _OptimizedPageViewState extends State<OptimizedPageView> {
  final Map<int, Widget> _pageCache = {};
  
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.controller,
      onPageChanged: widget.onPageChanged,
      itemCount: widget.pages.length,
      itemBuilder: (context, index) {
        if (widget.cachePages) {
          return _pageCache.putIfAbsent(
            index,
            () => RepaintBoundary(
              key: ValueKey('page_$index'),
              child: widget.pages[index],
            ),
          );
        }
        
        return RepaintBoundary(
          key: ValueKey('page_$index'),
          child: widget.pages[index],
        );
      },
    );
  }
}

/// Conditional widget that prevents unnecessary rebuilds
class ConditionalWidget extends StatefulWidget {
  final bool condition;
  final Widget Function() trueBuilder;
  final Widget Function()? falseBuilder;
  final bool cache;
  
  const ConditionalWidget({
    super.key,
    required this.condition,
    required this.trueBuilder,
    this.falseBuilder,
    this.cache = true,
  });
  
  @override
  State<ConditionalWidget> createState() => _ConditionalWidgetState();
}

class _ConditionalWidgetState extends State<ConditionalWidget> {
  Widget? _cachedTrueWidget;
  Widget? _cachedFalseWidget;
  
  @override
  Widget build(BuildContext context) {
    if (widget.condition) {
      if (widget.cache) {
        return _cachedTrueWidget ??= widget.trueBuilder();
      }
      return widget.trueBuilder();
    } else {
      if (widget.falseBuilder != null) {
        if (widget.cache) {
          return _cachedFalseWidget ??= widget.falseBuilder!();
        }
        return widget.falseBuilder!();
      }
      return const SizedBox.shrink();
    }
  }
}

/// Lazy loading widget that builds only when needed
class LazyWidget extends StatefulWidget {
  final Widget Function() builder;
  final bool preload;
  
  const LazyWidget({
    super.key,
    required this.builder,
    this.preload = false,
  });
  
  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  Widget? _cachedWidget;
  bool _isBuilt = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.preload) {
      _buildWidget();
    }
  }
  
  void _buildWidget() {
    if (!_isBuilt) {
      _cachedWidget = widget.builder();
      _isBuilt = true;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    _buildWidget();
    return _cachedWidget ?? const SizedBox.shrink();
  }
}

/// Memoized widget that caches build results
class MemoizedWidget extends StatefulWidget {
  final Widget Function() builder;
  final List<Object?> dependencies;
  
  const MemoizedWidget({
    super.key,
    required this.builder,
    required this.dependencies,
  });
  
  @override
  State<MemoizedWidget> createState() => _MemoizedWidgetState();
}

class _MemoizedWidgetState extends State<MemoizedWidget> {
  Widget? _cachedWidget;
  List<Object?>? _lastDependencies;
  
  @override
  Widget build(BuildContext context) {
    if (_shouldRebuild()) {
      _cachedWidget = widget.builder();
      _lastDependencies = List.from(widget.dependencies);
    }
    
    return _cachedWidget ?? const SizedBox.shrink();
  }
  
  bool _shouldRebuild() {
    if (_lastDependencies == null) return true;
    
    if (_lastDependencies!.length != widget.dependencies.length) {
      return true;
    }
    
    for (int i = 0; i < widget.dependencies.length; i++) {
      if (_lastDependencies![i] != widget.dependencies[i]) {
        return true;
      }
    }
    
    return false;
  }
}