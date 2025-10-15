import 'package:flutter/material.dart';
import 'package:textgram/models/models.dart';

class ChatListScreen extends StatelessWidget {
  final List<Chat> chats;
  final Function(Chat) onChatTap;

  const ChatListScreen({
    Key? key,
    required this.chats,
    required this.onChatTap,
  }) : super(key: key);

  String _formatMessageTime(int timestamp) {
    if (timestamp == 0) return '';

    final messageDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDay = DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (messageDay == today) {
      final hour = messageDate.hour.toString().padLeft(2, '0');
      final minute = messageDate.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (messageDay == yesterday) {
      return 'вчера';
    } else if (now.difference(messageDate).inDays < 7) {
      const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return weekdays[messageDate.weekday - 1];
    } else {
      final day = messageDate.day.toString().padLeft(2, '0');
      final month = messageDate.month.toString().padLeft(2, '0');
      final year = messageDate.year.toString().substring(2);
      return '$day.$month.$year';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final timeStr = _formatMessageTime(chat.lastMessageDate);
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              (chat.title.isNotEmpty ? chat.title[0] : '?').toUpperCase(),
            ),
          ),
          title: Row(
            children: [
              Expanded(child: Text(chat.title)),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
          subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onChatTap(chat),
        );
      },
    );
  }
}