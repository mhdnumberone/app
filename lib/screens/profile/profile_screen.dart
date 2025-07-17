// lib/screens/profile_screen.dart
// MIGRATED VERSION - Using unified theme service and base widgets

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/base_widgets.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/error/error_handler.dart';
import '../../core/utils/permission_manager.dart';
import '../../api/apis.dart';
import '../../main.dart';
import '../../models/chat_user.dart';
import '../../widgets/profile_image.dart';

class ViewProfileScreenIntelligence extends BaseStatefulWidget {
  final ChatUser user;
  const ViewProfileScreenIntelligence({super.key, required this.user});

  @override
  State<ViewProfileScreenIntelligence> createState() => 
      _ViewProfileScreenIntelligenceState();
}

class _ViewProfileScreenIntelligenceState 
    extends BaseState<ViewProfileScreenIntelligence> {
  
  bool _showDestructionCode = false;

  @override
  void initState() {
    super.initState();
    _refreshAgentData();
  }

  /// Refresh agent data to ensure we have the latest information
  Future<void> _refreshAgentData() async {
    try {
      log('Refreshing agent data...');
      await APIs.getSelfInfo();
      
      // If destruction code is still null after refresh, try to fetch directly from Firestore
      if (APIs.currentAgent?.destructionCode == null && APIs.currentAgent?.isActive == true) {
        log('Destruction code is null, attempting direct Firestore fetch...');
        await _fetchDestructionCodeDirectly();
      }
      
      if (mounted) {
        setState(() {
          // Trigger rebuild with fresh data
        });
      }
      log('Agent data refreshed. currentAgent: ${APIs.currentAgent?.agentCode}, destructionCode: ${APIs.currentAgent?.destructionCode}');
    } catch (e) {
      log('Error refreshing agent data: $e');
    }
  }

  /// Fetch destruction code directly from Firestore as a fallback
  Future<void> _fetchDestructionCodeDirectly() async {
    try {
      if (APIs.currentAgent?.agentCode == null) return;
      
      final agentDoc = await APIs.firestore
          .collection('agent_identities')
          .doc(APIs.currentAgent!.agentCode)
          .get();
      
      if (agentDoc.exists) {
        final data = agentDoc.data();
        final destructionCode = data?['destructionCode'] as String?;
        log('Direct fetch result - destructionCode: $destructionCode');
        
        if (destructionCode != null && APIs.currentAgent != null) {
          // Update currentAgent with the fetched destruction code
          APIs.currentAgent = APIs.currentAgent!.copyWith(
            destructionCode: destructionCode,
          );
          log('✅ Updated currentAgent with destruction code: $destructionCode');
        }
      }
    } catch (e) {
      log('Error fetching destruction code directly: $e');
    }
  }
  
  /// Get user's personal destruction code from Firebase
  String? get _userDestructionCode {
    final destructionCode = APIs.currentAgent?.destructionCode;
    log('Debug: Checking destruction code - currentAgent: ${APIs.currentAgent?.agentCode}, destructionCode: $destructionCode');
    
    // If destruction code is null, it might have been cleared. 
    // For active agents, this shouldn't happen, so we'll show a fallback message
    if (destructionCode == null && APIs.currentAgent?.isActive == true) {
      log('Warning: Active agent has no destruction code. This might indicate data inconsistency.');
    }
    
    return destructionCode;
  }

  /// Check if this is the current user's own profile
  bool get _isOwnProfile {
    if (APIs.me == null) return false;
    
    // Check if viewing own profile by comparing IDs
    final isOwnUser = APIs.me!.id == widget.user.id;
    log('Debug: Profile ownership check - APIs.me.id: ${APIs.me!.id}, widget.user.id: ${widget.user.id}, isOwnUser: $isOwnUser');
    
    return isOwnUser;
  }
  
  /// Copy code to clipboard
  Future<void> _copyCodeToClipboard(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.param('code_copied_to_clipboard', {'code': code})),
          backgroundColor: context.appTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// Handle user data destruction with confirmation
  Future<void> _handleUserDestruction() async {
    try {
      final confirmed = await _showDestructionConfirmationDialog();
      if (!confirmed) return;

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => BaseLoadingWidget(
            message: localizations.get('processing_destruction'),
          ),
        );
      }

      // Call the user's destructor method
      widget.user.destroy();

      // Update Firebase with destroyed user data
      if (APIs.isValidSession) {
        await APIs.updateUserInfo();
        
        // Also sign out the user if they destroyed their own profile
        if (APIs.me?.id == widget.user.id) {
          await APIs.signOut();
        }
      }

      // Hide loading and navigate back
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pop(); // Return to previous screen
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.get('user_data_destroyed')),
            backgroundColor: context.appTheme.successColor,
          ),
        );
      }
    } catch (e) {
      final error = ErrorHandler.handleApiError(e);
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ErrorHandler.showErrorToUser(context, error);
      }
    }
  }

  /// Show destruction confirmation dialog
  Future<bool> _showDestructionConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: context.appTheme.errorColor, size: 28),
            const SizedBox(width: 8),
            Text(localizations.get('confirm_destruction')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.get('destruction_confirmation_text'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.appTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appTheme.errorColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${localizations.get('name')}: ${widget.user.name}'),
                  Text('${localizations.get('email')}: ${widget.user.email}'),
                  Text('${localizations.get('id')}: ${widget.user.id}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.get('action_cannot_be_undone'),
              style: TextStyle(
                color: context.appTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(localizations.get('destroy')),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.appTheme.primaryColor.withOpacity(0.1),
              context.appTheme.backgroundColor,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: mq.height * .35,
              floating: false,
              pinned: true,
              backgroundColor: context.appTheme.primaryColor,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.appTheme.primaryColor,
                        context.appTheme.primaryColor.withOpacity(0.8),
                        context.appTheme.accentColor,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: mq.height * .08),
                      
                      // Profile Image with glow effect
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.appTheme.accentColor.withOpacity(0.3),
                              spreadRadius: 4,
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ProfileImage(
                          size: mq.height * .15,
                          url: widget.user.image,
                        ),
                      ),
                      SizedBox(height: mq.height * .02),
                      
                      // User Name with modern styling
                      Text(
                        widget.user.name,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: mq.height * .01),
                      
                      // User Email with chip-like design
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          widget.user.email,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: mq.width * .05),
                child: Column(
                  children: [
                    SizedBox(height: mq.height * .03),
              
              // Eye Icon Instruction (only for current user)
              if (_isOwnProfile) 
                _buildInfoCard(
                  title: 'رمز التدمير الطارئ',
                  content: 'اضغط على أيقونة العين أدناه لإظهار رمز التدمير الطارئ الخاص بك',
                  icon: Icons.visibility,
                  isInstruction: true,
                ),
              
              // Last Seen Section
              _buildInfoCard(
                title: localizations.get('last_seen'),
                content: widget.user.isOnline 
                    ? localizations.get('online')
                    : _formatLastSeen(),
                icon: Icons.access_time_outlined,
              ),
              
              // Join Date Section
              _buildInfoCard(
                title: localizations.get('joined_on'),
                content: _formatJoinDate(),
                icon: Icons.calendar_today_outlined,
              ),
              
              // Emergency Destruction Code Section (only show for current user)
              if (_isOwnProfile && _userDestructionCode != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.appTheme.warningColor.withOpacity(0.1),
                        context.appTheme.warningColor.withOpacity(0.05),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.appTheme.warningColor.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: context.appTheme.warningColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations.get('emergency_destruction_code'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.appTheme.warningColor,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showDestructionCode = !_showDestructionCode;
                              });
                            },
                            icon: Icon(
                              _showDestructionCode 
                                  ? Icons.visibility_off 
                                  : Icons.visibility,
                              color: context.appTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.get('destruction_code_description'),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appTheme.textSecondaryColor,
                        ),
                      ),
                      if (_showDestructionCode) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.appTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.appTheme.warningColor.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.appTheme.warningColor.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.appTheme.warningColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.code,
                                  size: 20,
                                  color: context.appTheme.warningColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.appTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.appTheme.primaryColor.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    _userDestructionCode!,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: context.appTheme.textPrimaryColor,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: context.appTheme.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () => _copyCodeToClipboard(_userDestructionCode!),
                                  icon: Icon(
                                    Icons.copy,
                                    size: 20,
                                    color: context.appTheme.accentColor,
                                  ),
                                  tooltip: localizations.get('copy_to_clipboard'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.appTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: context.appTheme.errorColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      localizations.get('destruction_warning'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.appTheme.errorColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      localizations.get('destruction_warning_detail'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.appTheme.errorColor.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ),
                SizedBox(height: mq.height * .02),
              ],
              
              // Show message if no destruction code is available
              if (_isOwnProfile && _userDestructionCode == null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.appTheme.warningColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: context.appTheme.warningColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              localizations.get('destruction_code_not_available'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.appTheme.warningColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _refreshAgentData,
                            icon: Icon(Icons.refresh, color: context.appTheme.warningColor, size: 20),
                            tooltip: localizations.get('retry_loading_code'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.get('destruction_code_load_error'),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ${localizations.get('network_connectivity_issues')}', style: TextStyle(fontSize: 13, color: context.appTheme.textSecondaryColor)),
                            Text('• ${localizations.get('agent_configuration_problems')}', style: TextStyle(fontSize: 13, color: context.appTheme.textSecondaryColor)),
                            Text('• ${localizations.get('administrator_restrictions')}', style: TextStyle(fontSize: 13, color: context.appTheme.textSecondaryColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localizations.get('contact_administrator'),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appTheme.warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: mq.height * .02),
              ],
              
              // Manual Destruction Button (only show for current user)
              if (_isOwnProfile) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.appTheme.errorColor.withOpacity(0.1),
                        context.appTheme.errorColor.withOpacity(0.05),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.appTheme.errorColor.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.delete_forever,
                          color: context.appTheme.errorColor,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations.get('manual_data_destruction'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.appTheme.errorColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations.get('manual_destruction_description'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.appTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _handleUserDestruction,
                          icon: const Icon(Icons.delete_forever),
                          label: Text(localizations.get('destroy_user_data')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.appTheme.errorColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                ),
                ),
              ],
            ],
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    bool isInstruction = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.primaryColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.appTheme.surfaceColor,
                context.appTheme.surfaceColor.withOpacity(0.95),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isInstruction 
                            ? context.appTheme.warningColor.withOpacity(0.1)
                            : context.appTheme.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: isInstruction 
                            ? context.appTheme.warningColor
                            : context.appTheme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isInstruction 
                              ? context.appTheme.warningColor
                              : context.appTheme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.appTheme.textPrimaryColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastSeen() {
    if (widget.user.lastActive.isEmpty) {
      return localizations.get('unknown');
    }
    
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(
      int.parse(widget.user.lastActive),
    );
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inDays > 0) {
      return localizations.param('days_ago', {'count': '${difference.inDays}'});
    } else if (difference.inHours > 0) {
      return localizations.param('hours_ago', {'count': '${difference.inHours}'});
    } else if (difference.inMinutes > 0) {
      return localizations.param('minutes_ago', {'count': '${difference.inMinutes}'});
    } else {
      return localizations.get('just_now');
    }
  }

  String _formatJoinDate() {
    if (widget.user.createdAt.isEmpty) {
      return localizations.get('unknown');
    }
    
    try {
      final joinDate = DateTime.fromMillisecondsSinceEpoch(
        int.parse(widget.user.createdAt),
      );
      return '${joinDate.day}/${joinDate.month}/${joinDate.year}';
    } catch (e) {
      return localizations.get('unknown');
    }
  }
}
