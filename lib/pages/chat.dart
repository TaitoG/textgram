import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final List<int> messageIds;
  final Map<int, Map<String, dynamic>> messagesMap;
  final Map<int, String> users;
  final int? replyToMessageId;
  final Function(String) onSendMessage;
  final Function(int) onLongPressMessage;
  final VoidCallback onCancelReply;

  const ChatScreen({
    Key? key,
    required this.messageIds,
    required this.messagesMap,
    required this.users,
    required this.replyToMessageId,
    required this.onSendMessage,
    required this.onLongPressMessage,
    required this.onCancelReply,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();

  String _getMessageText(Map<String, dynamic> msg) {
    final content = msg['content'];
    if (content == null) return '';

    if (content['@type'] == 'messageText') {
      return content['text']?['text'] ?? '';
    } else {
      final caption = content['caption']?['text'] ?? '';
      final type = content['@type']?.toString().replaceAll('message', '') ?? '';
      return '[${type}] ${caption}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Индикатор реплая
        if (widget.replyToMessageId != null && widget.messagesMap.containsKey(widget.replyToMessageId))
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.blue[900],
            child: Row(
              children: [
                Icon(Icons.reply, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ответ на:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      Text(
                        _getMessageText(widget.messagesMap[widget.replyToMessageId]!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20),
                  onPressed: widget.onCancelReply,
                ),
              ],
            ),
          ),
        Expanded(
          child: widget.messageIds.isEmpty
              ? Center(child: Text('Загрузка сообщений...'))
              : ListView.builder(
            reverse: true,
            itemCount: widget.messageIds.length,
            itemBuilder: (context, index) {
              final msgId = widget.messageIds[index];
              final msg = widget.messagesMap[msgId];
              if (msg == null) return SizedBox.shrink();

              final text = _getMessageText(msg);
              final isOutgoing = msg['is_outgoing'] ?? false;

              if (text.isEmpty) return SizedBox.shrink();

              // Проверяем реплай
              final replyTo = msg['reply_to'];
              Map<String, dynamic>? repliedMessage;
              if (replyTo != null && replyTo['@type'] == 'messageReplyToMessage') {
                final repliedMsgId = replyTo['message_id'];
                if (repliedMsgId != null) {
                  repliedMessage = widget.messagesMap[repliedMsgId];
                }
              }

              return GestureDetector(
                onLongPress: () => widget.onLongPressMessage(msgId),
                child: Align(
                  alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    decoration: BoxDecoration(
                      color: isOutgoing ? Colors.blue[700] : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isOutgoing)
                          Text(
                            widget.users[(msg['sender_id']?['user_id'] ?? 0)] ?? '...',
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          ),
                        if (repliedMessage != null)
                          Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(color: Colors.blue, width: 3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.users[(repliedMessage['sender_id']?['user_id'] ?? 0)] ?? 'Пользователь',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[300],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  _getMessageText(repliedMessage),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                                ),
                              ],
                            ),
                          ),
                        Text(text),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: 'Введите сообщение...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (text) {
                    widget.onSendMessage(text);
                    messageController.clear();
                  },
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  widget.onSendMessage(messageController.text);
                  messageController.clear();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }
}