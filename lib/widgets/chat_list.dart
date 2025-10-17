// widgets/chat_list_item.dart
import 'package:flutter/material.dart';
import 'package:textgram/models/chat.dart';
import 'widgets.dart';

class ChatListItem extends StatelessWidget {
  final Chat chat;
  final String timeStr;
  final Function(Chat) onTap;
  final Function(BuildContext, Chat) onLongPress;

  const ChatListItem({
    Key? key,
    required this.chat,
    required this.timeStr,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(chat),
      onLongPress: () => onLongPress(context, chat),
      splashColor: terminalGreen.withOpacity(0.1),
      highlightColor: terminalGreen.withOpacity(0.05),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: terminalDarkGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.title.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'JetBrains',
                            fontSize: 14,
                            color: terminalGreen,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          '[$timeStr]',
                          style: TextStyle(
                            fontFamily: 'JetBrains',
                            fontSize: 11,
                            color: terminalDarkGreen,
                            letterSpacing: 1.2,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrains',
                      fontSize: 12,
                      color: terminalDarkGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}