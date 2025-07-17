// المسار: lib/helper/dialogs.dart

import 'package:flutter/material.dart';
// لا حاجة لاستيراد AppTheme هنا إذا كنا سنستخدم Theme.of(context)

class Dialogs {
  static void showSnackbar(BuildContext context, String msg,
      {Duration duration = const Duration(seconds: 4)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onInverseSurface)), // لون نص مناسب للـ Snackbar
        backgroundColor: Theme.of(context)
            .colorScheme
            .inverseSurface, // لون خلفية Snackbar من الثيم
        behavior: SnackBarBehavior.floating,
        duration: duration)); // **الإصلاح: استخدام معامل المدة**
  }

  static void showLoading(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, // جعل الخط أعرض قليلاً
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context)
                    .colorScheme
                    .primary) // استخدام لون من الثيم
            )));
  }

  static void showProgressBar(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          elevation: 0,
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              if (message != null) ...[
                const SizedBox(height: 18),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }


  // **الإصلاح: إضافة دالة حوار التأكيد**
  static void showConfirmationDialog(BuildContext context,
      {required String title,
        required String content,
        required String confirmText,
        required VoidCallback onConfirm}) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content:
          Text(content, style: Theme.of(context).textTheme.bodyMedium),
          actions: [
            // زر الإلغاء
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),

            // زر التأكيد
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Text(confirmText),
            )
          ],
        ));
  }
}
