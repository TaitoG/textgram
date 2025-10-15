import 'package:flutter/material.dart';
import 'package:textgram/models/models.dart';

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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(status, style: TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          if (appState == AppState.waitingPhone)
            TextField(
              decoration: InputDecoration(
                labelText: 'Номер телефона',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              onSubmitted: onPhoneSubmit,
            ),
          if (appState == AppState.waitingCode)
            TextField(
              decoration: InputDecoration(
                labelText: 'Код из Telegram',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: onCodeSubmit,
            ),
          if (appState == AppState.waitingPassword)
            TextField(
              decoration: InputDecoration(
                labelText: 'Пароль 2FA',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onSubmitted: onPasswordSubmit,
            ),
        ],
      ),
    );
  }
}