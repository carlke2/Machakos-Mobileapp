import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobileapp/core/network/api_client.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'package:mobileapp/features/home/main_shell.dart';
import 'auth_repository.dart';

/// Phone + OTP sign-in for field crew.
///
/// Sized for use inside a moving ambulance: 56px controls, 17px input text and
/// segmented OTP digits, on a dark ground that stays legible in direct sun.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _otpLength = 6;
  static const _resendCooldown = 60;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  bool _isCodeStep = false;
  bool _isSubmitting = false;
  String? _serverError;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    // The active-box highlight tracks focus, so repaint when it changes.
    _codeFocusNode.addListener(_onCodeFocusChanged);
  }

  void _onCodeFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _codeFocusNode.removeListener(_onCodeFocusChanged);
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = _resendCooldown);
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
    if (rawPhone.replaceAll(RegExp(r'\D'), '').length < 9) {
      setState(() => _serverError = 'Enter a valid phone number');
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
      _codeFocusNode.requestFocus();
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
    if (code.length != _otpLength) {
      setState(() => _serverError = 'Enter the complete 6-digit code');
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
      if (mounted) {
        setState(() => _serverError = e.message);
        _codeController.clear();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _serverError = 'Incorrect or expired code. Please try again.');
        _codeController.clear();
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _backToPhoneStep() {
    setState(() {
      _isCodeStep = false;
      _codeController.clear();
      _serverError = null;
      _resendSeconds = 0;
    });
    _resendTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _buildLoginCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 44,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCobrandHeader(),
            Container(height: 3, color: AppColors.brandGold),
            _buildFormBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildCobrandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 44, maxWidth: 200),
              child: Image.asset(
                'assets/images/machakos_logo.jpg',
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  'Machakos County',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          const SizedBox(
            width: 1,
            height: 42,
            child: ColoredBox(color: AppColors.border),
          ),
          const SizedBox(width: 20),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 40, maxWidth: 160),
              child: Image.asset(
                'assets/images/malteser.png',
                height: 40,
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

  Widget _buildFormBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isCodeStep ? 'Enter your code' : 'Sign in to your shift',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.text,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _isCodeStep
                ? 'We sent a 6-digit code to ${_phoneController.text.trim()}'
                : 'Use the phone number registered with the Emergency Operations Centre.',
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          if (_serverError != null) ...[
            _buildErrorAlert(_serverError!),
            const SizedBox(height: 18),
          ],
          if (_isCodeStep) _buildCodeStep() else _buildPhoneStep(),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 16),
          _buildCardFooter(),
        ],
      ),
    );
  }

  Widget _buildErrorAlert(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('PHONE NUMBER'),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              LengthLimitingTextInputFormatter(15),
            ],
            onSubmitted: (_) => _isSubmitting ? null : _handleRequestOtp(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              letterSpacing: 0.3,
            ),
            decoration: InputDecoration(
              hintText: '07XX XXX XXX',
              hintStyle: const TextStyle(
                color: AppColors.textMutedLight,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
              filled: true,
              fillColor: AppColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 10),
                child: Icon(Icons.phone_outlined, size: 21, color: AppColors.primary),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 45, minHeight: 56),
              border: _inputBorder(AppColors.borderStrong),
              enabledBorder: _inputBorder(AppColors.borderStrong),
              focusedBorder: _inputBorder(AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Send code',
          icon: Icons.arrow_forward,
          onPressed: _isSubmitting ? null : _handleRequestOtp,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOtpField(),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Verify & start shift',
          icon: Icons.login,
          onPressed: _isSubmitting ? null : _handleVerifyOtp,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : _backToPhoneStep,
                icon: const Icon(Icons.chevron_left, size: 19),
                label: const Text('Change number'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(46),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: (_resendSeconds > 0 || _isSubmitting)
                    ? null
                    : _handleRequestOtp,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend code',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.textMutedLight,
                  minimumSize: const Size.fromHeight(46),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Six segmented digit boxes. A single transparent [TextField] sits over them
  /// so platform SMS autofill and the numeric keypad keep working, while the
  /// boxes give a digit count that is readable at a glance on a bumpy road.
  Widget _buildOtpField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('VERIFICATION CODE'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _codeFocusNode.requestFocus(),
          child: Stack(
            children: [
              Row(
                children: List.generate(_otpLength, (i) {
                  final digits = _codeController.text;
                  final filled = i < digits.length;
                  final isNext = i == digits.length && _codeFocusNode.hasFocus;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == _otpLength - 1 ? 0 : 8),
                      child: Container(
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: filled ? AppColors.primaryLight : AppColors.inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isNext
                                ? AppColors.primary
                                : filled
                                    ? AppColors.primary.withValues(alpha: 0.45)
                                    : AppColors.borderStrong,
                            width: isNext ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          filled ? digits[i] : '',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_otpLength),
                    ],
                    style: const TextStyle(fontSize: 25),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      if (value.length == _otpLength && !_isSubmitting) {
                        _handleVerifyOtp();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: disabled ? AppColors.borderStrong : AppColors.primary,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.onPrimary,
                    strokeWidth: 2.4,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(icon, size: 19, color: AppColors.onPrimary),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCardFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 14,
              color: AppColors.textMutedLight,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'Authorized personnel only · All activity is logged and audited',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMutedLight,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '© ${DateTime.now().year} Machakos County Government · In partnership with Malteser International',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMutedLight,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        color: AppColors.textMuted,
      ),
    );
  }
}
