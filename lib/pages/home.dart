import 'package:flutter/material.dart';
import 'package:textgram/models/models.dart';
import 'package:provider/provider.dart';
import 'package:textgram/core/app_controller.dart';
import 'package:textgram/widgets/app_theme.dart';
import 'package:textgram/widgets/modalmenu.dart';

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
      return weekdays[(messageDate.weekday % 7)];
    } else {
      final day = messageDate.day.toString().padLeft(2, '0');
      final month = messageDate.month.toString().padLeft(2, '0');
      final year = messageDate.year.toString().substring(2);
      return '$day.$month.$year';
    }
  }

  void _showMessageMenu(BuildContext context, Chat chat) {
    final chatId = chat.id;
    final chatType = chat.id < 0 ? 'supergroup' : 'private';
    final actions = [
      if (chatType == 'supergroup')
        MenuAction(
          icon: '⛔',
          label: 'ПОКИНУТЬ ГРУППУ',
          color: terminalGreen,
          onTap: (ctx) {
            final appController = Provider.of<AppController>(ctx, listen: false);
            appController.tdLibService.leaveChat(chatId);
          },
        ),
      MenuAction(
        icon: '>',
        label: 'УДАЛИТЬ ЧАТ',
        color: Colors.red[400]!,
        onTap: (ctx) {
          final appController = Provider.of<AppController>(ctx, listen: false);
          appController.tdLibService.deleteChat(chatId);
          appController.deleteChatFromList(chatId);
        },
      ),
    ];

    MessageMenu.show(context, actions, title: '[ ДЕЙСТВИЯ ]');
  }

  @override
  Widget build(BuildContext context) {

    if (chats.isEmpty) {
      return Container(
        color: terminalBackground,
        child: Center(
          child: Text(
            '> NO ACTIVE CONNECTIONS_',
            style: TextStyle(
              fontFamily: 'JetBrains',
              fontSize: 16,
              color: terminalGreen,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    return Container(
      color: terminalBackground,
      child: Stack(
        children: [
          // Scanline effect overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: List.generate(
                      50,
                          (index) => index.isEven
                          ? scanlineColor
                          : Colors.transparent,
                    ),
                    stops: List.generate(50, (index) => index / 50),
                  ),
                ),
              ),
            ),
          ),
          // Chat list
          ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final timeStr = _formatMessageTime(chat.lastMessageDate);
              return InkWell(
                onTap: () => onChatTap(chat),
                onLongPress: () => _showMessageMenu(context, chat),
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
                      // Terminal prompt style prefix
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
            },
          ),
        ],
      ),
    );
  }
}