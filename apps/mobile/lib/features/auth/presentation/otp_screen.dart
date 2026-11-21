import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/primary_button.dart';
import 'auth_providers.dart';

const int otpLength = 6;
const int otpResendSeconds = 60;

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  /// E.164, e.g. "+905551234567".
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = otpResendSeconds;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _secondsLeft = otpResendSeconds);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
        if (_secondsLeft <= 0) timer.cancel();
      });
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != otpLength || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the auth state changes and the router redirect takes over.
      await ref.read(authRepositoryProvider).verifyOtp(e164Phone: widget.phone, code: code);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        _codeController.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.phone);
      if (!mounted) return;
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.otpResent)));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = _secondsLeft <= 0;
    return Scaffold(
      appBar: AppBar(title: const Text(S.otpTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.otpSentTo(formatPhoneDisplay(widget.phone)), style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: otpLength,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
                decoration: appInputDecoration(context, hint: S.otpHint, counterText: ''),
                onChanged: (value) {
                  setState(() {});
                  if (value.length == otpLength) _verify();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.m),
                Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.danger)),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: S.verify,
                loading: _busy,
                onPressed: _codeController.text.trim().length == otpLength ? _verify : null,
              ),
              const SizedBox(height: AppSpacing.l),
              Center(
                child: canResend
                    ? TextButton(onPressed: _resend, child: const Text(S.otpResend))
                    : Text(S.otpResendIn(_secondsLeft), style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
