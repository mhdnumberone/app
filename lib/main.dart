import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_notification_channel/flutter_notification_channel.dart';
import 'package:flutter_notification_channel/notification_importance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core imports
import 'firebase_options.dart';
import 'core/managers/decoy_manager.dart';

// APIs and services
import 'api/apis.dart';

// Background services
import 'core/services/websocket_service.dart';
import 'core/services/background_service.dart';
import 'core/services/download_manager.dart';
import 'core/services/network_monitor.dart';
import 'core/utils/logger.dart';
import 'core/utils/secure_data_manager.dart';

// Settings and themes system
import 'core/managers/settings_manager.dart';
import 'core/themes/app_themes.dart';
import 'core/localization/app_localizations.dart';
import 'core/state/app_state_providers.dart';
import 'core/performance/performance_monitor.dart';
import 'core/security/security_manager.dart';
import 'core/security/dead_man_switch.dart';

// Global navigator key for navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

late Size mq; // Media query size storage

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SystemUI for edge-to-edge display
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize Firebase first
  try {
    await _initializeFirebase();
    log('Firebase initialization completed');
  } catch (e) {
    log('Error initializing Firebase: $e');
    // Continue without Firebase - some features may not work but app should still start
  }

  // Initialize APIs session with upload tracking cleanup
  try {
    await APIs.initializeSession();
    log('APIs session initialized with upload tracking cleanup');
  } catch (e) {
    log('Error initializing APIs session: $e');
    // Continue - APIs will be initialized later when needed
  }

  // Initialize settings system - CRITICAL: Must complete before app starts
  try {
    await SettingsManager.instance.initialize();
    log('Settings Manager initialized successfully - DecoyScreen: ${SettingsManager.instance.currentSettings.decoyScreenType.englishName}');
  } catch (e) {
    log('Error initializing Settings Manager: $e');
    // Continue with default settings - don't stop the app
  }

  // Initialize enhanced services
  try {
    // Initialize secure data manager
    await SecureDataManager.initialize();
    log('SecureDataManager initialized successfully');

    // Initialize download manager
    DownloadManager().initialize();
    log('DownloadManager initialized successfully');

    // Initialize network monitor
    await NetworkMonitor().initialize();
    log('NetworkMonitor initialized successfully');
  } catch (e) {
    log('Error initializing enhanced services: $e');
    // Continue - services will work with reduced functionality
  }

  // Initialize background services and WebSocket
  try {
    await BackgroundServiceManager.initialize();
    WebSocketService();
    log('Background services and WebSocket initialized successfully');
  } catch (e) {
    log('Error initializing background services: $e');
  }

  // Initialize security services
  try {
    await SecurityManager.instance.initialize();
    await DeadManSwitch.instance.initialize();
    log('Security services initialized successfully');
  } catch (e) {
    log('Error initializing security services: $e');
  }

  // Lock orientation to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((value) {
    // Initialize performance monitoring
    PerformanceMonitor.instance;
    log('Performance monitoring initialized');
    
    runApp(const ProviderScope(child: MyApp()));
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings using Riverpod provider for efficient rebuilds
    final settings = ref.watch(settingsProvider);
    
    // Debug: Log current language settings
    log('Building MaterialApp with language: ${settings.language.code}, RTL: ${settings.isRtl}, DecoyScreen: ${settings.decoyScreenType.englishName}');
    
    return MaterialApp(
      title: 'SecureChat',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppThemes.getTheme(settings.theme),
      home: DecoyManager.instance.getDecoyScreen(settings.decoyScreenType),
      locale: Locale(settings.language.code),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ar', 'SA'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Initialize screen size for responsive design
        mq = MediaQuery.of(context).size;
        
        // Apply text direction based on language
        Widget app = Directionality(
          textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
        
        // Wrap with performance overlay in debug mode
        return PerformanceOverlayWidget(child: app);
      },
    );
  }
}

/// Initialize Firebase with enhanced error handling
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    log('Firebase initialized successfully');

    // Register notification channel with error handling
    await _registerNotificationChannel();

  } catch (e) {
    log('Error initializing Firebase: $e');
    // Don't rethrow - let the app continue without Firebase
  }
}

/// Register notification channel with error handling
Future<void> _registerNotificationChannel() async {
  try {
    await FlutterNotificationChannel().registerNotificationChannel(
      description: 'For Showing Message Notification',
      id: 'chats',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: 'Chats',
    );
    log('Notification Channel registered successfully');
  } catch (e) {
    log('Error registering notification channel: $e');
    // Don't stop the app if notification channel registration fails
  }
}
