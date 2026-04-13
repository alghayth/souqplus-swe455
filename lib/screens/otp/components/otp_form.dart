import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants.dart';

class OtpForm extends StatefulWidget {
  const OtpForm({super.key, required this.onSubmit, this.isLoading = false});

  final ValueChanged<String> onSubmit;
  final bool isLoading;

  @override
  State<OtpForm> createState() => _OtpFormState();
}

class _OtpFormState extends State<OtpForm> with WidgetsBindingObserver {
  static const int _otpLength = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Automatically save data when the window is closed or backgrounded.
      final currentCode = _buildCode();
      debugPrint('Auto-saving OTP progress: $currentCode');
    }
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste of multiple characters
      for (var i = 0; i < value.length && (index + i) < _otpLength; i++) {
        _controllers[index + i].text = value[i];
      }
      _focusNodes[(_otpLength - 1).clamp(0, _otpLength - 1)].requestFocus();
      return;
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _buildCode() {
    return _controllers.map((c) => c.text.trim()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            _otpLength,
            (index) => SizedBox(
              width: 46,
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: !widget.isLoading,
                autofocus: index == 0,
                style: const TextStyle(fontSize: 24),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: otpInputDecoration.copyWith(counterText: ''),
                onChanged: (value) => _onChanged(index, value),
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        ElevatedButton(
          onPressed: widget.isLoading
              ? null
              : () {
                  final code = _buildCode();
                  if (code.length != _otpLength) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter the 6-digit OTP.'),
                      ),
                    );
                    return;
                  }
                  widget.onSubmit(code);
                },
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}
