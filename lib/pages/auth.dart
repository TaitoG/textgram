import 'package:flutter/material.dart';
import 'package:textgram/models/models.dart';
import 'package:textgram/widgets/app_theme.dart';

// AUTH SCREEN
class AuthScreen extends StatelessWidget {
  final AppState appState;
  final String status;
  final Function(String) onPhoneSubmit;
  final Function(String) onCodeSubmit;
  final Function(String) onPasswordSubmit;

  const AuthScreen({
    Key? key,
    required this.appState,
    required this.status,
    required this.onPhoneSubmit,
    required this.onCodeSubmit,
    required this.onPasswordSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: terminalBackground,
      child: Stack(
        children: [
          // Scanline effect
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: List.generate(
                      50,
                          (index) => index.isEven ? scanlineColor : Colors.transparent,
                    ),
                    stops: List.generate(50, (index) => index / 50),
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                      '╔═══════════════════════╗\n'
                      '║                       ║\n'
                      '║    TEXTGRAM v0.0.4    ║\n'
                      '║                       ║\n'
                      '╚═══════════════════════╝',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'JetBrains',
                    fontSize: 12,
                    color: terminalGreen,
                    height: 1.5,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 40),
                // Status
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: terminalDarkGreen, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '> ',
                        style: TextStyle(
                          fontFamily: 'JetBrains',
                          fontSize: 16,
                          color: terminalGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'JetBrains',
                            fontSize: 14,
                            color: terminalGreen,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Input field
                if (appState == AppState.waitingPhone)
                  _buildTerminalInput(
                    context: context,
                    label: 'НОМЕР ТЕЛЕФОНА',
                    hint: '+380XXXXXXXXX_',
                    keyboardType: TextInputType.phone,
                    onSubmit: onPhoneSubmit,
                  ),
                if (appState == AppState.waitingCode)
                  _buildTerminalInput(
                    context: context,
                    label: 'КОД ИЗ TELEGRAM',
                    hint: 'XXXXX_',
                    keyboardType: TextInputType.number,
                    onSubmit: onCodeSubmit,
                  ),
                if (appState == AppState.waitingPassword)
                  _buildTerminalInput(
                    context: context,
                    label: 'ПАРОЛЬ 2FA',
                    hint: '********_',
                    obscureText: true,
                    onSubmit: onPasswordSubmit,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalInput({
    required BuildContext context,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    required Function(String) onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '[ $label ]',
          style: TextStyle(
            fontFamily: 'JetBrains',
            fontSize: 12,
            color: terminalDarkGreen,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Text(
              '> ',
              style: TextStyle(
                fontFamily: 'JetBrains',
                fontSize: 18,
                color: terminalGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: TextField(
                style: TextStyle(
                  fontFamily: 'JetBrains',
                  color: terminalGreen,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontFamily: 'JetBrains',
                    color: terminalDarkGreen,
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: terminalDarkGreen, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: terminalDarkGreen, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: terminalGreen, width: 2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  filled: true,
                  fillColor: terminalBackground,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                keyboardType: keyboardType,
                obscureText: obscureText,
                onSubmitted: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}