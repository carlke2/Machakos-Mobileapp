import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'package:mobileapp/features/home/main_shell.dart';
import 'auth_repository.dart';

/// Responder Phone + OTP login screen.
/// Visual design matches the Machakos County EOC web frontend's login card layout:
///   - Unified card: white bg, 1px border, large shadow, 16px radius
///   - Cobrand header inside card top: white bg, border-bottom, logos centered
///   - Form body: padded area with title, subtitle, inputs, button
///   - Footer: surface-2 bg, border-top, shield icon + copyright
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── OTP state ──────────────────────────────────────────────────────────────
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  bool _isCodeStep = false;
  bool _isSubmitting = false;
  String? _serverError;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _handleRequestOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.length < 9) {
      setState(() => _serverError = 'Please enter a valid phone number');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });
    try {
      await AuthRepository().requestOtp(rawPhone);
      if (!mounted) return;
      setState(() {
        _isCodeStep = true;
        _codeController.clear();
      });
      _startResendCountdown();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _codeFocusNode.requestFocus();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _serverError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _serverError = 'Could not send a code to that number. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _serverError = 'Please enter the complete 6-digit code');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });
    try {
      await AuthRepository().verifyOtp(phone, code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MainShell()),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _serverError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _serverError = 'Incorrect or expired code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Page background: #F4F7F5 matching frontend --bg
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              // max-width: 428px matches frontend .login-card max-width
              constraints: const BoxConstraints(maxWidth: 428),
              child: _buildLoginCard(),
            ),
          ),
        ),
      ),
    );
  }

  /// The unified login card — matches frontend .login-card:
  ///   background: #fff, border: 1px solid #E3E8E5, border-radius: 16px,
  ///   box-shadow: var(--shadow-lg)
  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          // Matches frontend --shadow-lg:
          // 0 18px 50px rgba(16,33,26,.16), 0 6px 16px rgba(16,33,26,.08)
          BoxShadow(
            color: Color(0x29101A1A),
            blurRadius: 50,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x15101A1A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCobrandHeader(),
            _buildFormBody(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// Co-branded header — matches frontend .login-cobrand:
  ///   background: #fff (explicit), border-bottom: 1px solid #E3E8E5,
  ///   padding: 26px 28px, display: flex, align-items: center,
  ///   justify-content: center, gap: 22px
  Widget _buildCobrandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF), // explicit white, same as frontend
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Machakos County logo: height 46, width auto — matches frontend
          Image.asset(
            'assets/images/logo_splash_circle.png',
            height: 46,
            fit: BoxFit.contain,
          ),
          // Gap 22px + 1px divider (40px tall, #E3E8E5) + gap 22px
          // matches frontend: gap: 22px and .login-cobrand-div
          const SizedBox(width: 22),
          const SizedBox(
            width: 1,
            height: 40,
            child: ColoredBox(color: Color(0xFFE3E8E5)),
          ),
          const SizedBox(width: 22),
          // Malteser logo: height 38, width auto — matches frontend
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 38, maxWidth: 160),
              child: Image.asset(
                'assets/images/malteser.png',
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  'Malteser',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Form body — matches frontend .login-body:
  ///   padding: 28px 30px 26px
  Widget _buildFormBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title — matches frontend .login-title: 24px, weight 750
          const Text(
            'Emergency Operations Platform',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),

          // Subtitle — matches frontend .login-sub: 14px, muted, 0 0 24px
          Text(
            _isCodeStep
                ? 'Enter the 6-digit code sent to ${_phoneController.text.trim()}'
                : 'Sign in with your registered phone number',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Error alert
          if (_serverError != null) ...[
            _buildErrorAlert(_serverError!),
            const SizedBox(height: 16),
          ],

          // Phone / OTP form content
          _buildFieldCrewForm(),
        ],
      ),
    );
  }

  /// Error alert — matches frontend .alert-error:
  ///   background: var(--red-soft) #FBEAEA, border: 1px solid ~22% red,
  ///   padding: 12px 14px, border-radius: 8px, font 13px weight 500
  Widget _buildErrorAlert(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.danger,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Phone step or OTP step form — input styling matches frontend .input:
  ///   background: #fff, border: 1px solid #D3DAD6 (border-strong),
  ///   border-radius: 8px, height: 42px (logical), icon padding-left: 40px
  Widget _buildFieldCrewForm() {
    if (!_isCodeStep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Label — matches frontend .label: 11px, weight 600, letter-spacing .06em, muted
          const Text(
            'PHONE NUMBER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.06 * 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 7),
          _buildTextField(
            controller: _phoneController,
            hint: '07XX XXX XXX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            onSubmitted: (_) => _isSubmitting ? null : _handleRequestOtp(),
          ),
          const SizedBox(height: 16),
          _buildPrimaryButton(
            label: 'Send code',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _handleRequestOtp,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Change number" back link — matches frontend inline-flex back button
        GestureDetector(
          onTap: _isSubmitting
              ? null
              : () => setState(() {
                    _isCodeStep = false;
                    _codeController.clear();
                    _serverError = null;
                    _resendSeconds = 0;
                    _resendTimer?.cancel();
                  }),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left,
                size: 14,
                color: _isSubmitting ? AppColors.textMuted : AppColors.textMuted,
              ),
              const SizedBox(width: 2),
              const Text(
                'Change number',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Code label
        const Text(
          'VERIFICATION CODE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.06 * 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 7),
        _buildTextField(
          controller: _codeController,
          focusNode: _codeFocusNode,
          hint: '000000',
          icon: Icons.key_outlined,
          keyboardType: TextInputType.number,
          maxLength: 6,
          // Spaced digits — matches frontend style={{ letterSpacing: 4, fontWeight: 700 }}
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: AppColors.text,
          ),
          onSubmitted: (_) => _isSubmitting ? null : _handleVerifyOtp(),
        ),
        const SizedBox(height: 16),
        _buildPrimaryButton(
          label: 'Verify & sign in',
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _handleVerifyOtp,
        ),
        const SizedBox(height: 12),

        // Resend button — matches frontend secondary bordered btn
        _buildResendButton(),
      ],
    );
  }

  /// Shared input field — matches frontend .input class exactly.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    TextStyle? textStyle,
    void Function(String)? onSubmitted,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.done,
        maxLength: maxLength,
        onSubmitted: onSubmitted,
        style: textStyle ??
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.text,
            ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMutedLight),
          counterText: '',
          // White bg, borderStrong (#D3DAD6), radius 8px — matches .input
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.fromLTRB(40, 0, 13, 0),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 13, right: 9),
            child: Icon(icon, size: 18, color: AppColors.textMutedLight),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 42),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  /// Primary action button — matches frontend .btn.btn-primary.btn-lg.btn-block:
  ///   height: 46px, background: #1B5FAC, color: #fff, font-size: 15px, weight 600
  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.65),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppColors.onPrimary,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(Icons.arrow_forward, size: 16, color: AppColors.onPrimary),
                ],
              ),
      ),
    );
  }

  /// Resend code button — matches frontend secondary bordered btn:
  ///   border: 1px solid var(--border), transparent bg, centered,
  ///   muted color when counting down
  Widget _buildResendButton() {
    final bool disabled = _resendSeconds > 0 || _isSubmitting;
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: disabled ? null : _handleRequestOtp,
        icon: Icon(
          Icons.refresh,
          size: 14,
          color: disabled ? AppColors.textMuted : AppColors.text,
        ),
        label: Text(
          _resendSeconds > 0 ? 'Resend code in ${_resendSeconds}s' : 'Resend code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: disabled ? AppColors.textMuted : AppColors.text,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: disabled ? AppColors.textMuted : AppColors.text,
          side: const BorderSide(color: AppColors.border),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// Footer — matches frontend .login-foot:
  ///   background: var(--surface-2) #F8FAF9, border-top: 1px solid #E3E8E5,
  ///   padding: 14px 30px, font 12px muted, shield icon (green/primary color)
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 14, 30, 14),
      decoration: const BoxDecoration(
        color: AppColors.inputBg, // #F8FAF9 = surface-2
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shield icon in green/primary (matches .login-foot svg { color: var(--green) })
              const Icon(Icons.verified_user_outlined, size: 15, color: AppColors.primary),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Authorized personnel only · All activity is logged and audited',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Copyright — matches frontend .login-copy: 12px, muted-2, centered
          Text(
            '© ${DateTime.now().year} Machakos County Government · In partnership with Malteser International',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMutedLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
