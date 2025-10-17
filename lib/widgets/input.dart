import 'package:flutter/material.dart';
import 'app_theme.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmitted;
  final Function() onSend;
  final bool isEditing;

  const ChatInput({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onSend,
    this.isEditing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: terminalDarkGreen, width: 2),
        ),
      ),
      child: Row(
        children: [
          Text(
            '>',
            style: TextStyle(
              fontFamily: 'JetBrains',
              color: terminalGreen,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              focusNode: focusNode,
              controller: controller,
              style: TextStyle(
                fontFamily: 'JetBrains',
                color: terminalGreen,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                hintText: isEditing ? 'РЕДАКТИРОВАНИЕ..._' : 'ВВЕДИТЕ СООБЩЕНИЕ..._',
                hintStyle: TextStyle(
                  fontFamily: 'JetBrains',
                  color: terminalDarkGreen,
                  fontSize: 13,
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
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: terminalGreen, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                isEditing ? '[OK]' : '[>>]',
                style: TextStyle(
                  fontFamily: 'JetBrains',
                  color: terminalGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}