// lib/screens/encryption_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/security/aes_gcm_service.dart';
import '../../core/security/zero_width_service.dart';
import '../../core/themes/app_themes.dart';
import '../../core/themes/theme_service.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/error/error_handler.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/secure_data_manager.dart';
import '../../core/managers/settings_manager.dart';
import '../../core/widgets/rebuild_optimized_widgets.dart';

// Operation modes for encryption
enum OperationMode {
  encrypt,
  decrypt,
  hide,
  reveal,
  encryptAndHide,
  revealAndDecrypt
}

// State management for encryption
class EncryptionState {
  final String secretInput;
  final String coverInput;
  final String passwordInput;
  final String outputText;
  final bool isLoading;
  final bool isPasswordVisible;
  final OperationMode operationMode;

  EncryptionState({
    this.secretInput = '',
    this.coverInput = '',
    this.passwordInput = '',
    this.outputText = '',
    this.isLoading = false,
    this.isPasswordVisible = false,
    this.operationMode = OperationMode.encrypt,
  });

  bool get useSteganography => _deriveUseSteganography(operationMode);
  bool get usePassword => _deriveUsePassword(operationMode);

  EncryptionState copyWith({
    String? secretInput,
    String? coverInput,
    String? passwordInput,
    String? outputText,
    bool? isLoading,
    bool? isPasswordVisible,
    OperationMode? operationMode,
  }) {
    final newOperationMode = operationMode ?? this.operationMode;
    return EncryptionState(
      secretInput: secretInput ?? this.secretInput,
      coverInput: coverInput ?? this.coverInput,
      passwordInput: passwordInput ?? this.passwordInput,
      outputText: outputText ?? this.outputText,
      isLoading: isLoading ?? this.isLoading,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      operationMode: newOperationMode,
    );
  }

  static bool _deriveUseSteganography(OperationMode mode) {
    return mode == OperationMode.hide ||
        mode == OperationMode.reveal ||
        mode == OperationMode.encryptAndHide ||
        mode == OperationMode.revealAndDecrypt;
  }

  static bool _deriveUsePassword(OperationMode mode) {
    return mode == OperationMode.encrypt ||
        mode == OperationMode.decrypt ||
        mode == OperationMode.encryptAndHide ||
        mode == OperationMode.revealAndDecrypt;
  }
}

final encryptionStateProvider = StateNotifierProvider<EncryptionNotifier, EncryptionState>((ref) {
  return EncryptionNotifier(ref);
});

class EncryptionNotifier extends StateNotifier<EncryptionState> {
  final Ref ref;

  EncryptionNotifier(this.ref) : super(EncryptionState());

  void updateSecretInput(String value) {
    state = state.copyWith(secretInput: value);
  }

  void updateCoverInput(String value) {
    state = state.copyWith(coverInput: value);
  }

  void updatePasswordInput(String value) {
    state = state.copyWith(passwordInput: value);
  }

  void updateOperationMode(OperationMode mode) {
    state = state.copyWith(operationMode: mode);
  }

  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  void clearOutput() {
    state = state.copyWith(outputText: '');
  }

  void clearAll() {
    state = EncryptionState();
  }

  Future<void> performOperation() async {
    state = state.copyWith(isLoading: true);
    
    try {
      String result = '';
      
      switch (state.operationMode) {
        case OperationMode.encrypt:
          result = await _encrypt();
          break;
        case OperationMode.decrypt:
          result = await _decrypt();
          break;
        case OperationMode.hide:
          result = await _hide();
          break;
        case OperationMode.reveal:
          result = await _reveal();
          break;
        case OperationMode.encryptAndHide:
          result = await _encryptAndHide();
          break;
        case OperationMode.revealAndDecrypt:
          result = await _revealAndDecrypt();
          break;
      }
      
      state = state.copyWith(outputText: result, isLoading: false);
      AppLogger.info('Encryption operation completed: ${state.operationMode}');
    } catch (e) {
      state = state.copyWith(isLoading: false);
      AppLogger.error('Encryption operation failed', e);
      ErrorHandler.handleApiError(e);
    }
  }

  Future<String> _encrypt() async {
    final aesService = ref.read(aesGcmServiceProvider);
    return await aesService.encryptWithPassword(state.secretInput, state.passwordInput);
  }

  Future<String> _decrypt() async {
    final aesService = ref.read(aesGcmServiceProvider);
    return await aesService.decryptWithPassword(state.secretInput, state.passwordInput);
  }

  Future<String> _hide() async {
    final zeroWidthService = ref.read(zeroWidthServiceProvider);
    return zeroWidthService.hideInCoverText(state.coverInput, state.secretInput);
  }

  Future<String> _reveal() async {
    final zeroWidthService = ref.read(zeroWidthServiceProvider);
    return zeroWidthService.extractFromText(state.secretInput);
  }

  Future<String> _encryptAndHide() async {
    final aesService = ref.read(aesGcmServiceProvider);
    final zeroWidthService = ref.read(zeroWidthServiceProvider);
    
    final encrypted = await aesService.encryptWithPassword(state.secretInput, state.passwordInput);
    return zeroWidthService.hideInCoverText(state.coverInput, encrypted);
  }

  Future<String> _revealAndDecrypt() async {
    final aesService = ref.read(aesGcmServiceProvider);
    final zeroWidthService = ref.read(zeroWidthServiceProvider);
    
    final revealed = zeroWidthService.extractFromText(state.secretInput);
    return await aesService.decryptWithPassword(revealed, state.passwordInput);
  }
}

class EncryptionScreen extends ConsumerStatefulWidget {
  const EncryptionScreen({super.key});

  @override
  ConsumerState<EncryptionScreen> createState() => _EncryptionScreenState();
}

class _EncryptionScreenState extends ConsumerState<EncryptionScreen> {
  final TextEditingController _secretMessageController = TextEditingController();
  final TextEditingController _coverTextController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  bool _showGuide = false;

  void _toggleGuide() {
    setState(() {
      _showGuide = !_showGuide;
    });
  }

  void _clearAllFields() {
    ref.read(encryptionStateProvider.notifier).clearAll();
    _secretMessageController.clear();
    _coverTextController.clear();
    _passwordController.clear();
    _outputController.clear();
  }

  @override
  void initState() {
    super.initState();
    _secretMessageController.addListener(_onSecretInputChanged);
    _coverTextController.addListener(_onCoverInputChanged);
    _passwordController.addListener(_onPasswordInputChanged);
  }

  @override
  void dispose() {
    _secretMessageController.dispose();
    _coverTextController.dispose();
    _passwordController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  void _onSecretInputChanged() {
    ref.read(encryptionStateProvider.notifier).updateSecretInput(_secretMessageController.text);
  }

  void _onCoverInputChanged() {
    ref.read(encryptionStateProvider.notifier).updateCoverInput(_coverTextController.text);
  }

  void _onPasswordInputChanged() {
    ref.read(encryptionStateProvider.notifier).updatePasswordInput(_passwordController.text);
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool obscureText = false, // سيبقى هنا فقط للتحكم في InputDecoration
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return OptimizedTextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        suffixIcon: suffixIcon,
      ),
      // لا تمرر obscureText هنا
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(encryptionStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);

    // Update output controller when state changes
    if (_outputController.text != state.outputText) {
      _outputController.text = state.outputText;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.encryptionTitle ?? 'Encryption'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearAllFields,
            tooltip: localizations?.clearAll ?? 'Clear All',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // زر إظهار/إخفاء الدليل
            Row(
              children: [
                IconButton(
                  icon: Icon(_showGuide ? Icons.help : Icons.help_outline, color: colorScheme.primary, size: 28),
                  onPressed: _toggleGuide,
                  tooltip: 'إظهار/إخفاء دليل الاستخدام',
                ),
                const SizedBox(width: 8),
                Text(
                  'دليل الاستخدام',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (_showGuide) ...[
              BaseCardWidget(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'قسم التشفير يتيح لك حماية رسائلك أو إخفائها داخل نصوص أخرى. اختر نمط العملية المناسب من القائمة المنسدلة، ثم أدخل البيانات المطلوبة.\n',
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface.withOpacity(0.85),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'شرح الأنماط المتاحة:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildGuideItem('تشفير (Encrypt):',
                      'تحويل الرسالة إلى نص مشفر باستخدام كلمة مرور. لا يمكن قراءة الرسالة إلا بعد فك التشفير بنفس كلمة المرور.'),
                    _buildGuideItem('فك تشفير (Decrypt):',
                      'إرجاع الرسالة المشفرة إلى نصها الأصلي باستخدام كلمة المرور الصحيحة.'),
                    _buildGuideItem('إخفاء (Hide):',
                      'إخفاء رسالة سرية داخل نص غلاف باستخدام تقنية الإخفاء (Steganography).'),
                    _buildGuideItem('كشف (Reveal):',
                      'استخراج الرسالة المخفية من نص الغلاف.'),
                    _buildGuideItem('تشفير وإخفاء (Encrypt & Hide):',
                      'تشفير الرسالة أولاً ثم إخفاؤها داخل نص غلاف. حماية مزدوجة.'),
                    _buildGuideItem('كشف وفك تشفير (Reveal & Decrypt):',
                      'استخراج الرسالة المخفية من نص الغلاف ثم فك تشفيرها بكلمة المرور.'),
                    const SizedBox(height: 12),
                    Text(
                      '- أدخل الرسالة أو النص المطلوب في الحقول المناسبة.\n- إذا كان النمط يتطلب كلمة مرور أو نص غلاف، ستظهر الحقول تلقائياً.\n- اضغط زر تنفيذ العملية للحصول على النتيجة.\n- استخدم زر "مسح" لمسح جميع الحقول.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withOpacity(0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            BaseCardWidget(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations?.operationMode ?? 'Operation Mode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<OperationMode>(
                    value: state.operationMode,
                    isExpanded: true,
                    items: OperationMode.values.map((mode) {
                      return DropdownMenuItem<OperationMode>(
                        value: mode,
                        child: Text(_getOperationModeLabel(mode, localizations)),
                      );
                    }).toList(),
                    onChanged: (mode) {
                      if (mode != null && mode != state.operationMode) {
                        _clearAllFields();
                        ref.read(encryptionStateProvider.notifier).updateOperationMode(mode);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            BaseCardWidget(
              child: Column(
                children: [
                  _buildInputField(
                    controller: _secretMessageController,
                    label: _getSecretInputLabel(state.operationMode, localizations),
                    hint: _getSecretInputHint(state.operationMode, localizations),
                    maxLines: 4,
                  ),
                  if (state.useSteganography) ...[
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _coverTextController,
                      label: localizations?.coverText ?? 'Cover Text',
                      hint: localizations?.coverTextHint ?? 'Enter cover text to hide message in...',
                      maxLines: 3,
                    ),
                  ],
                  if (state.usePassword) ...[
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _passwordController,
                      label: localizations?.password ?? 'Password',
                      hint: localizations?.passwordHint ?? 'Enter encryption password...',
                      obscureText: !state.isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          state.isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          color: colorScheme.onSurface,
                        ),
                        onPressed: () {
                          ref.read(encryptionStateProvider.notifier).togglePasswordVisibility();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OptimizedButton(
                    onPressed: state.isLoading ? null : () {
                      ref.read(encryptionStateProvider.notifier).performOperation();
                    },
                    loading: state.isLoading,
                    child: Text(
                      state.isLoading
                          ? (localizations?.processing ?? 'Processing...')
                          : _getOperationButtonLabel(state.operationMode, localizations),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OptimizedButton(
                  onPressed: () {
                    ref.read(encryptionStateProvider.notifier).clearOutput();
                    _outputController.clear();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.clear),
                      const SizedBox(width: 4),
                      Text(localizations?.clear ?? 'Clear'),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red, // لون أحمر
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            BaseCardWidget(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        localizations?.output ?? 'Output',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (state.outputText.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: state.outputText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(localizations?.copiedToClipboard ?? 'Copied to clipboard'),
                                backgroundColor: colorScheme.primary,
                              ),
                            );
                          },
                          tooltip: localizations?.copyToClipboard ?? 'Copy to clipboard',
                        ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () {
                            Share.share(state.outputText);
                          },
                          tooltip: localizations?.share ?? 'Share',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInputField(
                    controller: _outputController,
                    label: '',
                    hint: localizations?.outputHint ?? 'Output will appear here...',
                    maxLines: 6,
                    enabled: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOperationModeLabel(OperationMode mode, AppLocalizations? localizations) {
    switch (mode) {
      case OperationMode.encrypt:
        return localizations?.encrypt ?? 'Encrypt';
      case OperationMode.decrypt:
        return localizations?.decrypt ?? 'Decrypt';
      case OperationMode.hide:
        return localizations?.hide ?? 'Hide';
      case OperationMode.reveal:
        return localizations?.reveal ?? 'Reveal';
      case OperationMode.encryptAndHide:
        return localizations?.encryptAndHide ?? 'Encrypt & Hide';
      case OperationMode.revealAndDecrypt:
        return localizations?.revealAndDecrypt ?? 'Reveal & Decrypt';
    }
  }

  String _getSecretInputLabel(OperationMode mode, AppLocalizations? localizations) {
    switch (mode) {
      case OperationMode.encrypt:
      case OperationMode.encryptAndHide:
        return localizations?.secretMessage ?? 'Secret Message';
      case OperationMode.decrypt:
      case OperationMode.revealAndDecrypt:
        return localizations?.encryptedMessage ?? 'Encrypted Message';
      case OperationMode.hide:
        return localizations?.messageToHide ?? 'Message to Hide';
      case OperationMode.reveal:
        return localizations?.textWithHiddenMessage ?? 'Text with Hidden Message';
    }
  }

  String _getSecretInputHint(OperationMode mode, AppLocalizations? localizations) {
    switch (mode) {
      case OperationMode.encrypt:
      case OperationMode.encryptAndHide:
        return localizations?.enterSecretMessage ?? 'Enter your secret message...';
      case OperationMode.decrypt:
      case OperationMode.revealAndDecrypt:
        return localizations?.enterEncryptedMessage ?? 'Enter encrypted message...';
      case OperationMode.hide:
        return localizations?.enterMessageToHide ?? 'Enter message to hide...';
      case OperationMode.reveal:
        return localizations?.enterTextWithHiddenMessage ?? 'Enter text with hidden message...';
    }
  }

  IconData _getOperationIcon(OperationMode mode) {
    switch (mode) {
      case OperationMode.encrypt:
        return Icons.lock;
      case OperationMode.decrypt:
        return Icons.lock_open;
      case OperationMode.hide:
        return Icons.visibility_off;
      case OperationMode.reveal:
        return Icons.visibility;
      case OperationMode.encryptAndHide:
        return Icons.security;
      case OperationMode.revealAndDecrypt:
        return Icons.search;
    }
  }

  String _getOperationButtonLabel(OperationMode mode, AppLocalizations? localizations) {
    switch (mode) {
      case OperationMode.encrypt:
        return localizations?.encryptButton ?? 'Encrypt';
      case OperationMode.decrypt:
        return localizations?.decryptButton ?? 'Decrypt';
      case OperationMode.hide:
        return localizations?.hideButton ?? 'Hide';
      case OperationMode.reveal:
        return localizations?.revealButton ?? 'Reveal';
      case OperationMode.encryptAndHide:
        return localizations?.encryptAndHideButton ?? 'Encrypt & Hide';
      case OperationMode.revealAndDecrypt:
        return localizations?.revealAndDecryptButton ?? 'Reveal & Decrypt';
    }
  }

  Widget _buildGuideItem(String title, String desc) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: title + ' ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: desc,
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: colorScheme.onSurface.withOpacity(0.85),
                      fontSize: 14,
                    ),
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