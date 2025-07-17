// المسار: lib/widgets/dialogs/profile_dialog.dart

import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/managers/settings_manager.dart';
import '../../main.dart'; //
import '../../models/chat_user.dart'; //
import '../../screens/profile/view_profile_screen.dart';
import '../profile_image.dart'; // استيراد ProfileImage المُعدل

class ProfileDialog extends BaseStatelessWidget {
  final ChatUser user;
  const ProfileDialog({super.key, required this.user}); //

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return AlertDialog(
      // سيتأثر بـ dialogTheme
      contentPadding: EdgeInsets.zero,
      // backgroundColor: Colors.white.withOpacity(.9), // تم إزالته، سيعتمد على dialogTheme
      // shape: const RoundedRectangleBorder( // تم إزالته، سيعتمد على dialogTheme
      //   borderRadius: BorderRadius.all(Radius.circular(20)),
      // ),
      content: SizedBox(
        width: mq.width * .6, //
        height: mq.height * .35, //
        child: Stack(
          //
          alignment: Alignment
              .center, // محاذاة العناصر في المنتصف لتسهيل تحديد المواقع
          children: [
            // صورة الملف الشخصي للمستخدم
            Positioned(
                //
                top: mq.height * .04, // تعديل الموضع قليلاً
                child: ProfileImage(
                    url: user.image,
                    size: mq.width *
                        .35) // استخدام ProfileImage المُعدل وحجم متناسق
                ),
            // اسم المستخدم
            Positioned(
              //
              top: mq.height * .04 +
                  (mq.width * .35) +
                  mq.height * .015, // أسفل الصورة مباشرة
              width: mq.width * .55, //
              child: Text(
                //
                user.name, //
                style: textTheme.titleMedium
                    ?.copyWith(color: colorScheme.onSurface), //
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // نبذة عن المستخدم
            Positioned(
              //
              top: mq.height * .04 +
                  (mq.width * .35) +
                  mq.height * .015 +
                  (textTheme.titleMedium?.fontSize ?? 18) +
                  mq.height * .01, // أسفل الاسم
              width: mq.width * .55, //
              child: Text(
                //
                user.about, //
                style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7)), //
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // زر المعلومات
            Positioned(
                //
                right: 8,
                top: 6,
                child: MaterialButton(
                  //
                  onPressed: () {
                    //
                    Navigator.pop(context); //
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ViewProfileScreen(user: user))); //
                  },
                  minWidth: 0,
                  padding: const EdgeInsets.all(0),
                  shape: const CircleBorder(),
                  child: Icon(Icons.info_outline,
                      color: colorScheme.primary, size: 30), // لون من الثيم
                )),
          ],
        ),
      ),
    );
  }
}
