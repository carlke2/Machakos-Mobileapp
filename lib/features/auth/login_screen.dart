import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'package:mobileapp/features/home/main_shell.dart';
import 'auth_repository.dart';

enum _Step { phone, code }

/// Responder OTP login screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  _Step _step = _Step.phone;
  bool _isSubmitting = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown([int seconds = 45]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else {
        if (mounted) setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _handleSendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar('Enter your phone number', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await AuthRepository().requestOtp(phone);

      if (!mounted) return;
      setState(() {
        _step = _Step.code;
        _codeController.clear();
      });
      _startCooldown(45);

      final mins = (result.expiresInSeconds / 60).round();
      _showSnackBar(
        'Code sent — enter the 6-digit code sent to your phone. It expires in $mins minutes.',
        isError: false,
      );

      // Auto focus code field
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _codeFocusNode.requestFocus();
      });
    } on ApiException catch (e) {
      if (mounted) _showSnackBar('Could not send code: ${e.message}', isError: true);
    } catch (e) {
      if (mounted) _showSnackBar('Could not send code. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleVerifyCode() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (code.length != 6) {
      _showSnackBar('Enter the 6-digit code', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await AuthRepository().verifyOtp(phone, code);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const MainShell(),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnackBar('Verification failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.onPrimary),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneStep = _step == _Step.phone;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  const _LogoRow(),
                  const SizedBox(height: 32),
                  const Text(
                    'Emergency Operations Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPhoneStep
                        ? 'Enter your registered phone number to receive a sign-in code.'
                        : 'Enter the 6-digit code sent to ${_phoneController.text.trim()}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (isPhoneStep) ...[
                    _EocTextField(
                      controller: _phoneController,
                      hintText: 'e.g. 0712 345 678',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _isSubmitting ? null : _handleSendCode(),
                      prefixIcon: const Icon(
                        Icons.call_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PrimaryButton(
                      label: 'Send code',
                      isSubmitting: _isSubmitting,
                      onPressed: _isSubmitting ? null : _handleSendCode,
                    ),
                  ] else ...[
                    _EocTextField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      hintText: '000000',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (val) {
                        final cleaned = val.replaceAll(RegExp(r'[^0-9]'), '');
                        if (cleaned != val) {
                          _codeController.value = TextEditingValue(
                            text: cleaned,
                            selection: TextSelection.collapsed(offset: cleaned.length),
                          );
                        }
                      },
                      onSubmitted: (_) => _isSubmitting ? null : _handleVerifyCode(),
                      prefixIcon: const Icon(
                        Icons.pin_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PrimaryButton(
                      label: 'Verify & sign in',
                      isSubmitting: _isSubmitting,
                      onPressed: _isSubmitting ? null : _handleVerifyCode,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _step = _Step.phone;
                                    _codeController.clear();
                                  });
                                },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Change number',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: (_isSubmitting || _cooldown > 0)
                              ? null
                              : _handleSendCode,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _cooldown > 0
                                ? 'Resend code in ${_cooldown}s'
                                : 'Resend code',
                            style: TextStyle(
                              color: _cooldown > 0
                                  ? AppColors.textMuted
                                  : AppColors.brandNavy,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'For Drivers, EMTs, and Nurses only.\n'
                    'Contact your dispatcher if you need an account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoRow extends StatelessWidget {
  const _LogoRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140, maxHeight: 46),
          child: Image.asset(
            'assets/images/logo_machakos.jpg',
            fit: BoxFit.contain,
            semanticLabel: 'Machakos County',
          ),
        ),
        Container(
          width: 1,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: AppColors.border,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120, maxHeight: 38),
          child: Image.asset(
            'assets/images/logo_partner.png',
            fit: BoxFit.contain,
            semanticLabel: 'Malteser International',
          ),
        ),
      ],
    );
  }
}

class _EocTextField extends StatelessWidget {
  const _EocTextField({
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.keyboardType,
    this.maxLength,
    this.textInputAction,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLength: maxLength,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: style ??
            const TextStyle(
              color: AppColors.text,
              fontSize: 15,
            ),
        decoration: InputDecoration(
          counterText: '',
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.textMuted,
            fontSize: style?.fontSize ?? 15,
            letterSpacing: 0,
            fontWeight: FontWeight.normal,
          ),
          filled: true,
          fillColor: AppColors.inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: prefixIcon,
                )
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isSubmitting,
    required this.onPressed,
  });

  final String label;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandNavy,
          disabledBackgroundColor: AppColors.brandNavy.withValues(alpha: 0.6),
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.onPrimary,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

