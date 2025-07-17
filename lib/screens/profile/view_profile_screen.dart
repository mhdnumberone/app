// المسار: lib/screens/view_profile_screen.dart

import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/managers/settings_manager.dart';
import '../../helper/my_date_util.dart';
import '../../main.dart';
import '../../models/chat_user.dart';
import '../../widgets/profile_image.dart';

class ViewProfileScreen extends BaseStatefulWidget {
  final ChatUser user;
  const ViewProfileScreen({super.key, required this.user}); // [cite: 437]

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends BaseState<ViewProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: Scaffold(
          appBar: AppBar(title: Text(widget.user.name)), // سيتأثر بـ AppTheme
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: mq.width * .05),
            child: SingleChildScrollView(
              // [cite: 439]
              child: Column(
                children: [
                  SizedBox(
                      width: mq.width, height: mq.height * .03), // [cite: 439]
                  ProfileImage(
                    // [cite: 440]
                    size: mq.height * .2,
                    url: widget.user.image,
                  ),
                  SizedBox(height: mq.height * .03), // [cite: 441]
                  Text(
                    widget.user.name, // [cite: 441]
                    style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500), // [cite: 442, 443]
                  ),
                  SizedBox(height: mq.height * .02),
                  Text(widget.user.email, // [cite: 444]
                      style: textTheme.bodyMedium
                          ?.copyWith(fontSize: 16)), // [cite: 444]
                  SizedBox(height: mq.height * .02),
                  _buildInfoContainer(
                    // استخدام دالة مساعدة لتوحيد شكل الحاويات
                    context,
                    title: AppLocalizations.of(context)!.about,
                    content: widget.user.about, // [cite: 450]
                    iconData: Icons.info_outline,
                    iconColor: context.appTheme.accentColor, // [cite: 446, 447]
                  ),
                  SizedBox(height: mq.height * .03), // [cite: 453]
                  _buildInfoContainer(
                    context,
                    title: AppLocalizations.of(context)!.joinedOn, // [cite: 456]
                    content: _getFormattedJoinDate(
                        widget.user.createdAt), // [cite: 458]
                    iconData: Icons.calendar_today,
                    iconColor: context.appTheme.accentColor, // [cite: 454, 455]
                  ),
                  SizedBox(height: mq.height * .03), // [cite: 461]
                  Container(
                    // حاوية خاصة لحالة الاتصال
                    width: double.infinity,
                    padding: EdgeInsets.all(mq.width * .04), // [cite: 462]
                    margin: EdgeInsets.symmetric(
                        horizontal: mq.width * .02), // [cite: 462]
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .cardTheme
                          .color
                          ?.withAlpha(150), // استخدام لون الكارت مع شفافية
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.user.isOnline
                            ? context.appTheme.successColor
                                .withAlpha(100) // [cite: 463, 464]
                            : context.appTheme.textSecondaryColor
                                .withAlpha(100), // [cite: 463, 464]
                      ),
                    ),
                    child: Row(
                      // [cite: 465]
                      children: [
                        Icon(
                          Icons.circle,
                          color: widget.user.isOnline
                              ? context.appTheme.successColor
                              : context.appTheme.textSecondaryColor, // [cite: 466]
                          size: 16,
                        ),
                        SizedBox(width: mq.width * .02), // [cite: 467]
                        Text(
                          widget.user.isOnline
                              ? 'Online' // [cite: 468]
                              : 'Last seen: ${MyDateUtil.getLastActiveTime(context: context, lastActive: widget.user.lastActive)}', // [cite: 468]
                          style: TextStyle(
                            // [cite: 469]
                            color: widget.user.isOnline
                                ? context.appTheme.successColor // [cite: 469, 470]
                                : colorScheme.onSurface
                                    .withOpacity(0.7), // [cite: 469, 470]
                            fontSize: 15,
                            fontWeight: widget.user.isOnline
                                ? FontWeight.w500 // [cite: 471, 472]
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: mq.height * .03),
                ],
              ),
            ),
          )),
    );
  }

  Widget _buildInfoContainer(BuildContext context,
      {required String title,
      required String content,
      IconData? iconData,
      Color? iconColor}) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mq.width * .04),
      margin: EdgeInsets.symmetric(horizontal: mq.width * .02),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .cardTheme
            .color
            ?.withAlpha(150), // استخدام لون الكارت مع شفافية
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (iconColor ?? context.appTheme.accentColor).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconData != null)
                Icon(iconData,
                    color: iconColor ?? context.appTheme.accentColor, size: 18),
              if (iconData != null) SizedBox(width: mq.width * .02),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                    fontSize: 16, color: (iconColor ?? context.appTheme.accentColor)),
              ),
            ],
          ),
          SizedBox(height: mq.height * .01),
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.85)), // [cite: 451]
          ),
        ],
      ),
    );
  }

  String _getFormattedJoinDate(String timestamp) {
    try {
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(
          int.parse(timestamp)); // [cite: 474]
      final DateTime now = DateTime.now(); // [cite: 475]

      final String day = date.day.toString().padLeft(2, '0'); // [cite: 475]
      final String month = _getMonthName(date.month); // [cite: 476]
      final String year = date.year.toString(); // [cite: 476]
      if (date.year == now.year) {
        // [cite: 477]
        return '$day $month'; // [cite: 477]
      } else {
        return '$day $month $year'; // [cite: 478]
      }
    } catch (e) {
      return 'Unknown'; // [cite: 479]
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      // [cite: 480]
      case 1:
        return 'January'; // [cite: 480]
      case 2:
        return 'February'; // [cite: 481]
      case 3:
        return 'March'; // [cite: 482]
      case 4:
        return 'April'; // [cite: 483]
      case 5:
        return 'May'; // [cite: 484]
      case 6:
        return 'June'; // [cite: 485]
      case 7:
        return 'July'; // [cite: 486]
      case 8:
        return 'August'; // [cite: 487]
      case 9:
        return 'September'; // [cite: 488]
      case 10:
        return 'October'; // [cite: 489]
      case 11:
        return 'November'; // [cite: 490]
      case 12:
        return 'December'; // [cite: 491]
      default:
        return 'Unknown'; // [cite: 492]
    }
  }
}
