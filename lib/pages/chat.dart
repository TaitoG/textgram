import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final List<int> messageIds;
  final Map<int, Map<String, dynamic>> messagesMap;
  final Map<int, String> users;
  final int? replyToMessageId;
  final Function(String) onSendMessage;
  final Function(int) onLongPressMessage;
  final VoidCallback onCancelReply;

  final Function(int, String)? onEditMessage;
  final Function(int)? onDeleteMessage;

  const ChatScreen({
    Key? key,
    required this.messageIds,
    required this.messagesMap,
    required this.users,
    required this.replyToMessageId,
    required this.onSendMessage,
    required this.onLongPressMessage,
    required this.onCancelReply,
    this.onEditMessage,
    this.onDeleteMessage,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int? _editingMessageId;

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

  void _showMessageMenu(BuildContext context, int messageId, Map<String, dynamic> msg) {
    final isOutgoing = msg['is_outgoing'] ?? false;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.reply),
              title: Text('Ответить'),
              onTap: () {
                Navigator.pop(context);
                widget.onLongPressMessage(messageId);
              },
            ),
            if (isOutgoing && widget.onEditMessage != null) ...[
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Редактировать'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessageId = messageId;
                    messageController.text = _getMessageText(msg);
                  });

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _focusNode.requestFocus();
                  });
                },
              ),
            ],
            if (isOutgoing && widget.onDeleteMessage != null) ...[
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, messageId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, int messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить сообщение?'),
        content: Text('Это действие нельзя отменить'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onDeleteMessage != null) {
                widget.onDeleteMessage!(messageId);
              } else {
                // если нет колбэка — можно логировать или показать Snack
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('onDeleteMessage не реализован')),
                );
              }
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleSendOrEdit() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessageId != null) {
      if (widget.onEditMessage != null) {
        widget.onEditMessage!(_editingMessageId!, text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('onEditMessage не реализован')),
        );
      }
      setState(() {
        _editingMessageId = null;
      });
    } else {
      widget.onSendMessage(text);
    }

    messageController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                onTap: () {
                  // можно использовать обычный тап для показа деталей/реакций
                },
                onLongPress: () => _showMessageMenu(context, msgId, msg),
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
        // Input
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: _editingMessageId != null ? 'Редактирование сообщения...' : 'Введите сообщение...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _handleSendOrEdit(),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(_editingMessageId != null ? Icons.check : Icons.send),
                onPressed: _handleSendOrEdit,
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
    _focusNode.dispose();
    super.dispose();
  }
}
