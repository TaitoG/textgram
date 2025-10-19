import 'package:flutter/material.dart';
import 'package:textgram/core/app_controller.dart';
import 'package:provider/provider.dart';
import 'package:textgram/widgets/widgets.dart' hide AppBodyWidget, AppBarWidget;

class ChatScreen extends StatefulWidget {
  final List<int> messageIds;
  final Map<int, Map<String, dynamic>> messagesMap;
  final Map<int, String> users;
  final int? replyToMessageId;
  final Function(String) onSendMessage;
  final Function(int) onLongPressMessage;
  final VoidCallback onCancelReply;
  final VoidCallback? onLoadMore;

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
    this.onLoadMore,
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
  String _getMessageTime(Map<String, dynamic> msg) {
    final date = msg['date'];
    if (date == null) return '';
    final now = DateTime.now();
    final msgTime = DateTime.fromMillisecondsSinceEpoch(date * 1000);
    final diff = now.difference(msgTime);

    if (diff.inDays > 0) {
      return '${msgTime.day}/${msgTime.month} ${msgTime.hour.toString().padLeft(2, '0')}:${msgTime.minute.toString().padLeft(2, '0')}';
    }
    return '${msgTime.hour.toString().padLeft(2, '0')}:${msgTime.minute.toString().padLeft(2, '0')}';
  }

  bool _isInviteLink(String text) {
    return text.contains(RegExp(r't\.me/[+\w]+')) ||
        text.contains('joinchat');
  }

  void _showJoinMenu(BuildContext context, String inviteLink) {
    final actions = [
      MenuAction(
          icon: '✅',
          label: 'JOIN CHAT',
          color: terminalGreen,
          onTap: (ctx) {
            final appController = Provider.of<AppController>(ctx, listen: false);
            appController.joinChatByInvite(inviteLink);
          }),
    ];
    MessageMenu.show(context, actions, title: '[ INVITE LINK ]');
  }

  void _showMessageMenu(BuildContext context, int messageId, Map<String, dynamic> msg) {
    final isOutgoing = msg['is_outgoing'] ?? false;
    final actions = [
      MenuAction(
        icon: '>',
        label: 'REPLY',
        color: terminalGreen,
        onTap: (ctx) => widget.onLongPressMessage(messageId),
      ),
      if (isOutgoing && widget.onEditMessage != null)
        MenuAction(
          icon: '>',
          label: 'EDIT',
          color: terminalGreen,
          onTap: (ctx) {
            setState(() {
              _editingMessageId = messageId;
              messageController.text = _getMessageText(msg);
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _focusNode.requestFocus();
            });
          },
        ),
      if (isOutgoing && widget.onDeleteMessage != null)
        MenuAction(
          icon: '>',
          label: 'DELETE',
          color: Colors.red[400]!,
          onTap: (ctx) => _confirmDelete(context, messageId),
        ),
    ];
    MessageMenu.show(context, actions);
  }


  void _confirmDelete(BuildContext context, int messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: terminalBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: terminalGreen, width: 2),
        ),
        title: Text(
          '[ ! WARNING ! ]',
          style: TextStyle(
            fontFamily: 'JetBrains',
            color: Colors.red[400],
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        content: Text(
          'ARE YOU SURE YOU WANT\n\nTO DELETE THIS MESSAGE?',
          style: TextStyle(
            fontFamily: 'JetBrains',
            color: terminalGreen,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '[ CANCEL ]',
              style: TextStyle(fontFamily: 'JetBrains', color: terminalGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onDeleteMessage != null) {
                widget.onDeleteMessage!(messageId);
              }
            },
            child: Text(
              '[ DELETE ]',
              style: TextStyle(fontFamily: 'JetBrains', color: Colors.red[400]),
            ),
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
          Column(
            children: [
              // Reply banner
              if (widget.replyToMessageId != null && widget.messagesMap.containsKey(widget.replyToMessageId))
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: terminalBackground,
                    border: Border(
                      bottom: BorderSide(color: terminalDarkGreen, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '>>',
                        style: TextStyle(
                          fontFamily: 'JetBrains',
                          color: terminalGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REPLY:',
                              style: TextStyle(
                                fontFamily: 'JetBrains',
                                fontSize: 10,
                                color: terminalDarkGreen,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              _getMessageText(widget.messagesMap[widget.replyToMessageId]!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'JetBrains',
                                fontSize: 12,
                                color: terminalGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onCancelReply,
                        child: Text(
                          '[X]',
                          style: TextStyle(
                            fontFamily: 'JetBrains',
                            color: Colors.red[400],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Messages
              Expanded(
                child: widget.messageIds.isEmpty
                    ? Center(
                  child: Text(
                    '> LOADING DATA..._',
                    style: TextStyle(
                      fontFamily: 'JetBrains',
                      fontSize: 14,
                      color: terminalGreen,
                      letterSpacing: 1.2,
                    ),
                  ),
                )
                    : ListView.builder(
                  reverse: true,
                  itemCount: widget.messageIds.length,
                  itemBuilder: (context, index) {
                    if (index == 0 && widget.onLoadMore != null) {
                      widget.onLoadMore!();
                    }
                    final msgId = widget.messageIds[index];
                    final msg = widget.messagesMap[msgId];
                    if (msg == null) return SizedBox.shrink();

                    final text = _getMessageText(msg);
                    final isOutgoing = msg['is_outgoing'] ?? false;

                    if (text.isEmpty) return SizedBox.shrink();

                    // Reply check
                    final replyTo = msg['reply_to'];
                    Map<String, dynamic>? repliedMessage;
                    if (replyTo != null && replyTo['@type'] == 'messageReplyToMessage') {
                      final repliedMsgId = replyTo['message_id'];
                      if (repliedMsgId != null) {
                        repliedMessage = widget.messagesMap[repliedMsgId];
                      }
                    }

                    return GestureDetector(
                      onLongPress: () => _showMessageMenu(context, msgId, msg),
                      child: Align(
                        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          padding: EdgeInsets.all(10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: terminalBackground,
                            border: Border.all(
                              color: isOutgoing ? terminalGreen : terminalDarkGreen,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isOutgoing)
                                Text(
                                  '> ${widget.users[(msg['sender_id']?['user_id'] ?? 0)] ?? 'USER'}·${_getMessageTime(msg)}',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains',
                                    fontSize: 10,
                                    color: terminalDarkGreen,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              if (_isInviteLink(text)) ...[
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: GestureDetector(
                                    onTap: () => _showJoinMenu(context, text),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: terminalDarkGreen.withOpacity(0.3),
                                        border: Border.all(color: terminalGreen, width: 1),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('JOIN ', style: TextStyle(fontFamily: 'JetBrains', color: terminalGreen, fontSize: 11)),
                                          Text('CHAT', style: TextStyle(fontFamily: 'JetBrains', color: terminalGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (repliedMessage != null)
                                Container(
                                  margin: EdgeInsets.only(top: 4, bottom: 8),
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    border: Border(
                                      left: BorderSide(color: terminalDarkGreen, width: 3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '>> ${widget.users[(repliedMessage['sender_id']?['user_id'] ?? 0)] ?? 'USER'}',
                                        style: TextStyle(
                                          fontFamily: 'JetBrains',
                                          fontSize: 10,
                                          color: terminalDarkGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        _getMessageText(repliedMessage),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'JetBrains',
                                          fontSize: 11,
                                          color: terminalDarkGreen.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                text,
                                style: TextStyle(
                                  fontFamily: 'JetBrains',
                                  fontSize: 13,
                                  color: terminalGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              ChatInput(
                controller: messageController,
                focusNode: _focusNode,
                onSubmitted: (_) => _handleSendOrEdit(),
                onSend: _handleSendOrEdit,
                isEditing: _editingMessageId != null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onLoadMore != null) widget.onLoadMore!();
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
