import 'package:flutter/material.dart';
import '../../core/utils/permission_manager.dart';
import '../../core/utils/permission_preferences.dart';
import '../../core/localization/app_localizations.dart';

class PermissionsSettingsScreen extends StatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  State<PermissionsSettingsScreen> createState() => _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState extends State<PermissionsSettingsScreen> {
  bool _batteryOptimizationEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      // هنا استخدم الدالة العامة الجديدة
      _batteryOptimizationEnabled = await PermissionManager.checkBatteryOptimization();
    } catch (e) {
      print('خطأ في فحص الصلاحيات: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.permissionsSettings),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                Icons.battery_charging_full,
                color: _batteryOptimizationEnabled ? Colors.green : Colors.orange,
              ),
              title: Text(AppLocalizations.of(context)!.batteryOptimization),
              subtitle: Text(
                _batteryOptimizationEnabled
                    ? 'مفعل - التطبيق محمي من إيقاف النظام'
                    : 'مطلوب للعمل الصحيح للتطبيق',
              ),
              trailing: Icon(
                _batteryOptimizationEnabled ? Icons.check_circle : Icons.info,
                color: _batteryOptimizationEnabled ? Colors.green : Colors.orange,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)?.importantInformation ?? 'معلومات مهمة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.backgroundServicesRequired ?? 'الخدمات الخلفية مطلوبة لعمل التطبيق بشكل صحيح ولا يمكن إيقافها. يُنصح بتفعيل تحسين البطارية لضمان عدم إيقاف النظام للتطبيق.',
                    style: const TextStyle(fontSize: 14),
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
