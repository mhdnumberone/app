// lib/core/managers/decoy_manager.dart

import 'package:flutter/material.dart';
import '../../screens/security/decoy_screen.dart';
import '../../screens/camouflage/fake_apps/calculator_app.dart';
import '../../screens/camouflage/fake_apps/notes_app.dart';
import '../../screens/camouflage/fake_apps/weather_app.dart';
import '../../screens/camouflage/fake_apps/todo_app.dart';
import '../../screens/camouflage/fake_apps/timer_app.dart';
import '../../screens/camouflage/fake_apps/contacts_app.dart';
import '../../screens/camouflage/fake_apps/sms_app.dart';
import 'settings_manager.dart';

/// Manager for handling decoy screen selection and creation
class DecoyManager {
  static DecoyManager? _instance;
  static DecoyManager get instance => _instance ??= DecoyManager._();
  DecoyManager._();

  /// Get the appropriate decoy screen based on settings
  Widget getDecoyScreen(DecoyScreenType type) {
    switch (type) {
      case DecoyScreenType.systemUpdate:
        return const DecoyScreen();
      case DecoyScreenType.calculator:
        return const CalculatorApp();
      case DecoyScreenType.notes:
        return const NotesApp();
      case DecoyScreenType.weather:
        return const WeatherApp();
      case DecoyScreenType.todo:
        return const TodoApp();
      case DecoyScreenType.timer:
        return const TimerApp();
      case DecoyScreenType.contacts:
        return const ContactsApp();
      case DecoyScreenType.sms:
        return const SmsApp();
    }
  }

  /// Get current decoy screen from settings
  Widget getCurrentDecoyScreen() {
    final currentSettings = SettingsManager.instance.currentSettings;
    return getDecoyScreen(currentSettings.decoyScreenType);
  }

  /// Get decoy screen info for UI display
  DecoyScreenInfo getDecoyScreenInfo(DecoyScreenType type) {
    switch (type) {
      case DecoyScreenType.systemUpdate:
        return DecoyScreenInfo(
          type: type,
          name: 'تحديث النظام',
          description: 'يظهر كشاشة تحديث النظام الافتراضية',
          icon: Icons.system_update,
          color: Colors.blue,
        );
      case DecoyScreenType.calculator:
        return DecoyScreenInfo(
          type: type,
          name: 'الآلة الحاسبة',
          description: 'آلة حاسبة بسيطة وفعالة',
          icon: Icons.calculate,
          color: Colors.orange,
        );
      case DecoyScreenType.notes:
        return DecoyScreenInfo(
          type: type,
          name: 'المذكرات',
          description: 'تطبيق لحفظ الملاحظات والأفكار',
          icon: Icons.note,
          color: Colors.green,
        );
      case DecoyScreenType.weather:
        return DecoyScreenInfo(
          type: type,
          name: 'الطقس',
          description: 'معلومات الطقس الحالية والتوقعات',
          icon: Icons.wb_sunny,
          color: Colors.cyan,
        );
      case DecoyScreenType.todo:
        return DecoyScreenInfo(
          type: type,
          name: 'قائمة المهام',
          description: 'إدارة المهام اليومية والتذكيرات',
          icon: Icons.checklist,
          color: Colors.purple,
        );
      case DecoyScreenType.timer:
        return DecoyScreenInfo(
          type: type,
          name: 'الموقت',
          description: 'مؤقت وساعة إيقاف للأنشطة',
          icon: Icons.timer,
          color: Colors.red,
        );
      case DecoyScreenType.contacts:
        return DecoyScreenInfo(
          type: type,
          name: 'جهات الاتصال',
          description: 'تطبيق جهات الاتصال المزيف',
          icon: Icons.contacts,
          color: Colors.blueGrey,
        );
      case DecoyScreenType.sms:
        return DecoyScreenInfo(
          type: type,
          name: 'الرسائل',
          description: 'تطبيق الرسائل النصية المزيف',
          icon: Icons.message,
          color: Colors.deepPurple,
        );
    }
  }

  /// Get all available decoy screens
  List<DecoyScreenInfo> getAllDecoyScreens() {
    return DecoyScreenType.values
        .map((type) => getDecoyScreenInfo(type))
        .toList();
  }
}

/// Information about a decoy screen
class DecoyScreenInfo {
  final DecoyScreenType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const DecoyScreenInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}