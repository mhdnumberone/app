// lib/screens/about_screen.dart
// Enhanced About Screen with Intelligence Character and Bilingual Support

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/base_widgets.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/error/error_handler.dart';
import '../../main.dart';

class AboutScreen extends BaseStatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends BaseState<AboutScreen>
    with TickerProviderStateMixin {
  late AnimationController _characterController;
  late AnimationController _fadeController;
  late Animation<double> _characterAnimation;
  late Animation<double> _fadeAnimation;

  bool _showAdvancedFeatures = false;
  bool _isCharacterTalking = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startWelcomeSequence();
  }

  void _initializeAnimations() {
    _characterController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _characterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _characterController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
  }

  void _startWelcomeSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _characterController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isCharacterTalking = true;
      });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isCharacterTalking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _characterController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.about),
        backgroundColor: appColors.surfaceColor,
        foregroundColor: appColors.textPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showAdvancedFeatures = !_showAdvancedFeatures;
              });
            },
            icon: Icon(
              _showAdvancedFeatures ? Icons.visibility_off : Icons.visibility,
              color: appColors.primaryColor,
            ),
            tooltip: _showAdvancedFeatures 
                ? localizations.get('hide_advanced') 
                : localizations.get('show_advanced'),
          ),
        ],
      ),
      backgroundColor: appColors.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntelligenceCharacterSection(appColors),
            const SizedBox(height: 30),
            _buildAppIntroSection(appColors),
            const SizedBox(height: 25),
            _buildFeaturesOverviewSection(appColors),
            const SizedBox(height: 25),
            _buildHowToUseSection(appColors),
            const SizedBox(height: 25),
            _buildFileManagementSection(appColors),
            const SizedBox(height: 25),
            _buildEncryptionFeaturesSection(appColors),
            const SizedBox(height: 25),
            _buildSecurityFeaturesSection(appColors),
            const SizedBox(height: 25),
            _buildArchitectureSection(appColors),
            if (_showAdvancedFeatures) ...[
              const SizedBox(height: 25),
              _buildAdvancedSecuritySection(appColors),
              const SizedBox(height: 25),
              _buildDestructionSystemSection(appColors),
            ],
            const SizedBox(height: 25),
            _buildSecurityTipsSection(appColors),
            const SizedBox(height: 40),
            _buildAppInfoSection(appColors),
          ],
        ),
      ),
    );
  }

  Widget _buildIntelligenceCharacterSection(AppThemeExtension appColors) {
    return AnimatedBuilder(
      animation: _characterAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _characterAnimation.value,
          child: BaseCardWidget(
            backgroundColor: appColors.primaryColor.withOpacity(0.1),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Character Avatar
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            appColors.primaryColor,
                            appColors.accentColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: appColors.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.psychology,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    
                    // Talking Animation
                    if (_isCharacterTalking)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Character Introduction
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        localizations.get('intelligence_character_name'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: appColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.get('intelligence_character_title'),
                        style: TextStyle(
                          fontSize: 16,
                          color: appColors.accentColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Speech Bubble
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: appColors.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: appColors.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.format_quote,
                                  color: appColors.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    localizations.get('character_welcome_message'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: appColors.textPrimaryColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '- ${localizations.get('intelligence_character_name')}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: appColors.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppIntroSection(AppThemeExtension appColors) {
    return _buildSection(
      icon: Icons.shield_outlined,
      title: localizations.get('what_is_app'),
      description: localizations.get('app_description'),
      color: appColors.primaryColor,
      appColors: appColors,
      content: [
        _buildFeaturePoint(
          icon: Icons.security,
          title: localizations.get('secure_platform'),
          description: localizations.get('secure_platform_desc'),
          appColors: appColors,
        ),
        _buildFeaturePoint(
          icon: Icons.group,
          title: localizations.get('agent_network'),
          description: localizations.get('agent_network_desc'),
          appColors: appColors,
        ),
        _buildFeaturePoint(
          icon: Icons.lock,
          title: localizations.get('privacy_first'),
          description: localizations.get('privacy_first_desc'),
          appColors: appColors,
        ),
      ],
    );
  }

  Widget _buildFeaturesOverviewSection(AppThemeExtension appColors) {
    return _buildExpandableSection(
      icon: Icons.star_border,
      title: localizations.get('main_features'),
      appColors: appColors,
      children: [
        _buildFeatureGrid([
          _buildFeatureCard(
            icon: Icons.chat_bubble_outline,
            title: localizations.get('secure_messaging'),
            description: localizations.get('secure_messaging_desc'),
            color: Colors.blue,
            appColors: appColors,
          ),
          _buildFeatureCard(
            icon: Icons.folder_special,
            title: localizations.get('secure_file_management'),
            description: localizations.get('secure_file_management_desc'),
            color: Colors.green,
            appColors: appColors,
          ),
          _buildFeatureCard(
            icon: Icons.voice_chat,
            title: localizations.get('voice_messages'),
            description: localizations.get('voice_messages_desc'),
            color: Colors.orange,
            appColors: appColors,
          ),
          _buildFeatureCard(
            icon: Icons.enhanced_encryption,
            title: localizations.get('steganography_encryption'),
            description: localizations.get('steganography_encryption_desc'),
            color: Colors.purple,
            appColors: appColors,
          ),
        ]),
      ],
    );
  }

  Widget _buildHowToUseSection(AppThemeExtension appColors) {
    return _buildExpandableSection(
      icon: Icons.help_outline,
      title: localizations.get('how_to_use'),
      appColors: appColors,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: appColors.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: appColors.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.get('usage_guide_intro'),
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildStepByStepGuide([
          _buildStep(
            stepNumber: 1,
            title: localizations.get('step_1_title'),
            description: localizations.get('step_1_desc'),
            icon: Icons.key,
            appColors: appColors,
          ),
          _buildStep(
            stepNumber: 2,
            title: localizations.get('step_2_title'),
            description: localizations.get('step_2_desc'),
            icon: Icons.person_add,
            appColors: appColors,
          ),
          _buildStep(
            stepNumber: 3,
            title: localizations.get('step_3_title'),
            description: localizations.get('step_3_desc'),
            icon: Icons.chat,
            appColors: appColors,
          ),
          _buildStep(
            stepNumber: 4,
            title: localizations.get('step_4_title'),
            description: localizations.get('step_4_desc'),
            icon: Icons.settings,
            appColors: appColors,
          ),
          _buildStep(
            stepNumber: 5,
            title: localizations.get('step_5_title'),
            description: localizations.get('step_5_desc'),
            icon: Icons.verified_user,
            appColors: appColors,
          ),
        ]),
      ],
    );
  }

  Widget _buildFileManagementSection(AppThemeExtension appColors) {
    return _buildExpandableSection(
      icon: Icons.folder_special,
      title: localizations.get('secure_file_management_section'),
      appColors: appColors,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: appColors.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.security, color: appColors.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.get('file_management_intro'),
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFileManagementFeature(
          icon: Icons.delete_forever,
          title: localizations.get('dod_secure_deletion'),
          description: localizations.get('dod_secure_deletion_desc'),
          level: localizations.get('military_standard'),
          color: Colors.red,
          appColors: appColors,
        ),
        _buildFileManagementFeature(
          icon: Icons.layers,
          title: localizations.get('multi_pass_overwriting'),
          description: localizations.get('multi_pass_overwriting_desc'),
          level: localizations.get('7_passes'),
          color: Colors.orange,
          appColors: appColors,
        ),
        _buildFileManagementFeature(
          icon: Icons.drive_file_rename_outline,
          title: localizations.get('filename_obfuscation'),
          description: localizations.get('filename_obfuscation_desc'),
          level: localizations.get('advanced'),
          color: Colors.blue,
          appColors: appColors,
        ),
        _buildFileManagementFeature(
          icon: Icons.verified,
          title: localizations.get('deletion_verification'),
          description: localizations.get('deletion_verification_desc'),
          level: localizations.get('automatic'),
          color: Colors.green,
          appColors: appColors,
        ),
        _buildFileManagementFeature(
          icon: Icons.tab,
          title: localizations.get('organized_interface'),
          description: localizations.get('organized_interface_desc'),
          level: localizations.get('user_friendly'),
          color: Colors.purple,
          appColors: appColors,
        ),
      ],
    );
  }

  Widget _buildEncryptionFeaturesSection(AppThemeExtension appColors) {
    return _buildExpandableSection(
      icon: Icons.enhanced_encryption,
      title: localizations.get('encryption_steganography_section'),
      appColors: appColors,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: appColors.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.visibility_off, color: appColors.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.get('encryption_intro'),
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildEncryptionFeature(
          icon: Icons.text_snippet,
          title: localizations.get('simple_steganography'),
          description: localizations.get('simple_steganography_desc'),
          features: [
            localizations.get('caesar_encryption'),
            localizations.get('invisible_unicode'),
            localizations.get('natural_distribution'),
          ],
          color: Colors.blue,
          appColors: appColors,
        ),
        _buildEncryptionFeature(
          icon: Icons.security,
          title: localizations.get('advanced_steganography'),
          description: localizations.get('advanced_steganography_desc'),
          features: [
            localizations.get('aes_256_encryption'),
            localizations.get('pbkdf2_key_derivation'),
            localizations.get('data_partitioning'),
            localizations.get('100k_iterations'),
          ],
          color: Colors.red,
          appColors: appColors,
        ),
        _buildEncryptionFeature(
          icon: Icons.hide_source,
          title: localizations.get('invisible_hiding'),
          description: localizations.get('invisible_hiding_desc'),
          features: [
            localizations.get('4_invisible_chars'),
            localizations.get('2bit_encoding'),
            localizations.get('base64_compression'),
            localizations.get('smart_distribution'),
          ],
          color: Colors.purple,
          appColors: appColors,
        ),
        _buildEncryptionFeature(
          icon: Icons.auto_awesome,
          title: localizations.get('auto_detection'),
          description: localizations.get('auto_detection_desc'),
          features: [
            localizations.get('multiple_methods'),
            localizations.get('clear_error_messages'),
            localizations.get('user_guidance'),
            localizations.get('security_validation'),
          ],
          color: Colors.green,
          appColors: appColors,
        ),
      ],
    );
  }

  Widget _buildSecurityFeaturesSection(AppThemeExtension appColors) {
    return _buildExpandableSection(
      icon: Icons.security,
      title: localizations.get('security_features'),
      appColors: appColors,
      children: [
        _buildSecurityFeature(
          icon: Icons.enhanced_encryption,
          title: localizations.get('end_to_end_encryption'),
          description: localizations.get('encryption_description'),
          level: localizations.get('military_grade'),
          color: Colors.green,
          appColors: appColors,
        ),
        _buildSecurityFeature(
          icon: Icons.screenshot_monitor,
          title: localizations.get('screenshot_protection'),
          description: localizations.get('screenshot_description'),
          level: localizations.get('active'),
          color: Colors.blue,
          appColors: appColors,
        ),
        _buildSecurityFeature(
          icon: Icons.timer,
          title: localizations.get('auto_lock'),
          description: localizations.get('auto_lock_description'),
          level: localizations.get('configurable'),
          color: Colors.orange,
          appColors: appColors,
        ),
      ],
    );
  }

  Widget _buildAdvancedSecuritySection(AppThemeExtension appColors) {
    return _buildExpandableSection(
      icon: Icons.security_update_good,
      title: localizations.get('advanced_security'),
      appColors: appColors,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appColors.warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.warningColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: appColors.warningColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    localizations.get('advanced_warning_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: appColors.warningColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                localizations.get('advanced_warning_desc'),
                style: TextStyle(
                  fontSize: 14,
                  color: appColors.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAdvancedFeature(
          icon: Icons.timer_off,
          title: localizations.get('dead_man_switch'),
          description: localizations.get('dead_man_switch_desc'),
          appColors: appColors,
        ),
        _buildAdvancedFeature(
          icon: Icons.visibility_off,
          title: localizations.get('stealth_mode'),
          description: localizations.get('stealth_mode_desc'),
          appColors: appColors,
        ),
        _buildAdvancedFeature(
          icon: Icons.memory,
          title: localizations.get('secure_memory'),
          description: localizations.get('secure_memory_desc'),
          appColors: appColors,
        ),
      ],
    );
  }

  Widget _buildDestructionSystemSection(AppThemeExtension appColors) {
    return Container(
      decoration: BoxDecoration(
        color: appColors.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.errorColor.withOpacity(0.3)),
      ),
      child: _buildExpandableSection(
        icon: Icons.dangerous,
        title: localizations.get('destruction_system'),
        titleColor: appColors.errorColor,
        appColors: appColors,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appColors.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dangerous, color: appColors.errorColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      localizations.get('critical_warning'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: appColors.errorColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  localizations.get('destruction_warning'),
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDestructionLevel(
            icon: Icons.delete,
            title: localizations.get('level_1_messages'),
            description: localizations.get('level_1_desc'),
            color: Colors.orange,
            appColors: appColors,
          ),
          _buildDestructionLevel(
            icon: Icons.delete_sweep,
            title: localizations.get('level_2_data'),
            description: localizations.get('level_2_desc'),
            color: Colors.red,
            appColors: appColors,
          ),
          _buildDestructionLevel(
            icon: Icons.delete_forever,
            title: localizations.get('level_3_complete'),
            description: localizations.get('level_3_desc'),
            color: Colors.red.shade900,
            appColors: appColors,
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureSection(AppThemeExtension appColors) {
    return _buildExpandableSection(
      icon: Icons.architecture,
      title: localizations.get('app_architecture'),
      appColors: appColors,
      children: [
        _buildArchitectureComponent(
          icon: Icons.cloud_off,
          title: localizations.get('zero_knowledge'),
          description: localizations.get('zero_knowledge_desc'),
          color: Colors.purple,
          appColors: appColors,
        ),
        _buildArchitectureComponent(
          icon: Icons.enhanced_encryption,
          title: localizations.get('e2e_encryption'),
          description: localizations.get('e2e_encryption_desc'),
          color: Colors.blue,
          appColors: appColors,
        ),
        _buildArchitectureComponent(
          icon: Icons.storage,
          title: localizations.get('local_storage'),
          description: localizations.get('local_storage_desc'),
          color: Colors.green,
          appColors: appColors,
        ),
        _buildArchitectureComponent(
          icon: Icons.network_check,
          title: localizations.get('secure_transport'),
          description: localizations.get('secure_transport_desc'),
          color: Colors.orange,
          appColors: appColors,
        ),
      ],
    );
  }

  Widget _buildSecurityTipsSection(AppThemeExtension appColors) {
    return _buildExpandableSection(
      icon: Icons.lightbulb_outline,
      title: localizations.get('security_tips'),
      appColors: appColors,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appColors.successColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: appColors.successColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: appColors.successColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.get('security_tips_intro'),
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTip(
          icon: Icons.key,
          title: localizations.get('tip_1_title'),
          description: localizations.get('tip_1_desc'),
          priority: localizations.get('critical'),
          color: Colors.red,
          appColors: appColors,
        ),
        _buildTip(
          icon: Icons.logout,
          title: localizations.get('tip_2_title'),
          description: localizations.get('tip_2_desc'),
          priority: localizations.get('important'),
          color: Colors.orange,
          appColors: appColors,
        ),
        _buildTip(
          icon: Icons.update,
          title: localizations.get('tip_3_title'),
          description: localizations.get('tip_3_desc'),
          priority: localizations.get('recommended'),
          color: Colors.green,
          appColors: appColors,
        ),
        _buildTip(
          icon: Icons.security,
          title: localizations.get('tip_4_title'),
          description: localizations.get('tip_4_desc'),
          priority: localizations.get('essential'),
          color: Colors.blue,
          appColors: appColors,
        ),
        _buildTip(
          icon: Icons.network_wifi,
          title: localizations.get('tip_5_title'),
          description: localizations.get('tip_5_desc'),
          priority: localizations.get('critical'),
          color: Colors.red,
          appColors: appColors,
        ),
        // New tips for file management and encryption
        _buildTip(
          icon: Icons.folder_special,
          title: localizations.get('file_management_tip'),
          description: localizations.get('file_management_tip_desc'),
          priority: localizations.get('important'),
          color: Colors.green,
          appColors: appColors,
        ),
        _buildTip(
          icon: Icons.enhanced_encryption,
          title: localizations.get('encryption_tip'),
          description: localizations.get('encryption_tip_desc'),
          priority: localizations.get('recommended'),
          color: Colors.purple,
          appColors: appColors,
        ),
      ],
    );
  }

  Widget _buildAppInfoSection(AppThemeExtension appColors) {
    return BaseCardWidget(
      backgroundColor: appColors.surfaceColor,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: appColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: appColors.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.get('app_info'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: appColors.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations.get('version_info'),
                      style: TextStyle(
                        fontSize: 14,
                        color: appColors.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: appColors.textSecondaryColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user,
                color: appColors.successColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                localizations.get('secure_by_design'),
                style: TextStyle(
                  fontSize: 16,
                  color: appColors.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            localizations.get('copyright_info'),
            style: TextStyle(
              fontSize: 12,
              color: appColors.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget Methods

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    List<Widget>? content,
    required AppThemeExtension appColors,
  }) {
    return BaseCardWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: appColors.textPrimaryColor,
              height: 1.6,
            ),
          ),
          if (content != null) ...[
            const SizedBox(height: 16),
            ...content,
          ],
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? titleColor,
    required AppThemeExtension appColors,
  }) {
    return BaseCardWidget(
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Icon(
            icon,
            color: titleColor ?? appColors.successColor, // Changed from green.shade700
            size: 24,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleColor ?? appColors.successColor, // Changed from green.shade700
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildFeaturePoint({
    required IconData icon,
    required String title,
    required String description,
    required AppThemeExtension appColors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: appColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: appColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: appColors.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(List<Widget> features) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.1,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: features,
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required AppThemeExtension appColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: appColors.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: appColors.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepByStepGuide(List<Widget> steps) {
    return Column(
      children: steps,
    );
  }

  Widget _buildStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required AppThemeExtension appColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: appColors.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: appColors.accentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: appColors.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFeature({
    required IconData icon,
    required String title,
    required String description,
    required String level,
    required Color color,
    required AppThemeExtension appColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appColors.textPrimaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        level,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFeature({
    required IconData icon,
    required String title,
    required String description,
    required AppThemeExtension appColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appColors.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.warningColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: appColors.warningColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: appColors.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestructionLevel({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required AppThemeExtension appColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureComponent({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required AppThemeExtension appColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: appColors.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileManagementFeature({
    required IconData icon,
    required String title,
    required String description,
    required String level,
    required Color color,
    required AppThemeExtension appColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appColors.textPrimaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        level,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptionFeature({
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
    required Color color,
    required AppThemeExtension appColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: appColors.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: appColors.textSecondaryColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features.map((feature) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                feature,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTip({
    required IconData icon,
    required String title,
    required String description,
    required String priority,
    required Color color,
    required AppThemeExtension appColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appColors.textPrimaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priority,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}