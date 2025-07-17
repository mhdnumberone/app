// المسار: lib/widgets/profile_image.dart

import 'package:cached_network_image/cached_network_image.dart'; //
import 'package:flutter/cupertino.dart'; //
import 'package:flutter/material.dart';
import '../core/themes/app_theme_extension.dart';
import '../core/widgets/base_widgets.dart';

class ProfileImage extends BaseStatelessWidget {
  final double size;
  final String? url;
  const ProfileImage({super.key, required this.size, this.url}); //

  @override
  Widget build(BuildContext context) {
    final Color placeholderBackgroundColor = Theme.of(context)
        .colorScheme
        .surface
        .withAlpha(150); // لون أفتح قليلاً من السطح
    final Color placeholderIconColor =
        context.appTheme.accentColor.withOpacity(0.7); // لون أيقونة ثانوي

    return Container(
      width: size, //
      height: size, //
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: context.appTheme.primaryLight.withOpacity(0.3),
              width: 1.5), // استخدام لون من الثيم مع سماكة
          // إضافة ظل خفيف لتمييز الصورة
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 3,
              offset: const Offset(0, 1),
            )
          ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size), //
        child: (url != null && url!.isNotEmpty) //
            ? CachedNetworkImage(
                //
                width: size, //
                height: size, //
                fit: BoxFit.cover, //
                imageUrl: url!, //
                placeholder: (context, url) => Container(
                  //
                  color: placeholderBackgroundColor, //
                  child: Icon(CupertinoIcons.person_alt,
                      color: placeholderIconColor,
                      size: size * 0.6), // أيقونة أنسب وحجم متناسق
                ),
                errorWidget: (context, url, error) => Container(
                  //
                  color: placeholderBackgroundColor, //
                  child: Icon(CupertinoIcons.person_alt,
                      color: placeholderIconColor, size: size * 0.6), //
                ),
              )
            : Container(
                //
                color: placeholderBackgroundColor, //
                child: Icon(CupertinoIcons.person_alt,
                    color: placeholderIconColor, size: size * 0.6), //
              ),
      ),
    );
  }
}
