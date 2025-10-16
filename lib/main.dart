import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'core/td.dart';
import 'models/models.dart';
import 'pages/pages.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TdLibService tdLibService = TdLibService();
  late File chatsFile;

  AppState appState = AppState.loading;
  String status = 'Подключение к TDLib...';
  List<Chat> chats = [];
  List<ChatStatus> chatsStatus = [];
  Map<int, String> users = {};
  Chat? selectedChat;

  Map<int, Map<String, dynamic>> messagesMap = {};
  List<int> messageIds = [];
  int? replyToMessageId;

  @override
  void initState() {
    super.initState();
    _initTdLib();
  }

  void _initTdLib() async {
    try {
      if (!tdLibService.initialize()) {
        setState(() {
          status = 'Ошибка создания TDLib клиента';
        });
        return;
      }
      tdLibService.setLogVerbLvl(2);
      final dir = Directory('./td_db');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final tdlibParams = tdLibService.getTdlibParameters();
      tdLibService.send(tdlibParams);
      setState(() => status = 'Отправили параметры TDLib');

      _listenToUpdates(tdlibParams);
    } catch (e) {
      setState(() {
        status = 'Ошибка загрузки TDLib: $e';
      });
    }
  }

  void _listenToUpdates(Map<String, dynamic> tdlibParams) async {
    await for (final data in tdLibService.startReceiver()) {
      _handleUpdate(data, tdlibParams);
    }
  }

  void _handleUpdate(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    try {
      final type = data['@type'];
      if (type == 'updateAuthorizationState') {
        _handleAuthorizationState(data, tdlibParams);
      } else if (type == 'updateNewChat') {
        _addOrUpdateChat(data['chat']);
      } else if (type == 'updateChatLastMessage') {
        _updateChatLastMessage(data['chat_id'], data['last_message']);
      } else if (type == 'updateChatPosition') {
        tdLibService.loadChats();
      } else if (type == 'updateNewMessage') {
        _handleNewMessage(data['message']);
      } else if (type == 'updateMessageContent') {
        _handleMessageContentUpdate(data);
      } else if (type == 'updateDeleteMessages') {
        _handleDeleteMessages(data);
      } else if (type == 'updateSupergroup') {
        final s = data['supergroup']['status']['@type'];
        final cid = data['supergroup']['id'];
        final normalizedId = -100 * 10000000000 - cid;
        final index = chatsStatus.indexWhere((c) => c.chat_id == cid);
        final chat = ChatStatus(
            chat_id: normalizedId.toInt(),
            status: s
        );
        if (index >= 0) {
          chatsStatus[index] = chat;
        } else {
          chatsStatus.add(chat);
        }
      } else if (type == 'messages') {
        _handleMessagesHistory(data['messages']);
      } else if (type == 'user') {
        _handleUser(data);
      } else if (type == 'message') {
        _handleSingleMessage(data);
      }
    } catch (e) {
      print('Ошибка обработки обновления: $e');
      print('Данные: $data');
    }
  }

  void _handleAuthorizationState(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    final state = data['authorization_state']['@type'];

    if (state == 'authorizationStateWaitPhoneNumber') {
      setState(() {
        appState = AppState.waitingPhone;
        status = 'Введите номер телефона';
      });
    } else if (state == 'authorizationStateWaitCode') {
      setState(() {
        appState = AppState.waitingCode;
        status = 'Введите код из Telegram';
      });
    } else if (state == 'authorizationStateWaitPassword') {
      final hint = data['authorization_state']['password_hint'] ?? '';
      setState(() {
        appState = AppState.waitingPassword;
        status = 'Введите пароль${hint.isNotEmpty ? " (подсказка: $hint)" : ""}';
      });
    } else if (state == 'authorizationStateReady') {
      setState(() {
        appState = AppState.chatList;
        status = '✅ Успешно вошли!';
      });
      tdLibService.loadChats();
    } else if (state == 'authorizationStateClosed') {
      setState(() => status = 'Соединение закрыто');
    }
  }

  void _handleNewMessage(Map<String, dynamic>? message) {
    if (message == null) return;

    final chatId = message['chat_id'];
    if (chatId == null) return;

    if (selectedChat != null && chatId == selectedChat!.id) {
      _addMessageToChat(message);
    }

    final sender = message['sender_id'];
    if (sender != null && sender['@type'] == 'messageSenderUser') {
      final userId = sender['user_id'];
      if (!users.containsKey(userId)) {
        tdLibService.loadUser(userId);
      }
    }

    _updateChatLastMessage(chatId, message);
  }

  void _handleMessageContentUpdate(Map<String, dynamic> data) {
    final chatId = data['chat_id'];
    final messageId = data['message_id'];
    final newContent = data['new_content'];

    if (selectedChat != null && chatId == selectedChat!.id && messagesMap.containsKey(messageId)) {
      setState(() {
        messagesMap[messageId]!['content'] = newContent;
      });
    }
  }

  void _handleDeleteMessages(Map<String, dynamic> data) {
    final chatId = data['chat_id'];
    final messageIdsList = data['message_ids'];

    if (selectedChat != null && chatId == selectedChat!.id && messageIdsList is List) {
      setState(() {
        for (var msgId in messageIdsList) {
          messagesMap.remove(msgId);
          messageIds.remove(msgId);
        }
      });
    }
  }

  void _handleMessagesHistory(List? messagesList) {
    if (messagesList == null || messagesList.isEmpty || selectedChat == null) return;

    setState(() {
      messagesMap.clear();
      messageIds.clear();

      for (var msg in messagesList) {
        if (msg is Map<String, dynamic>) {
          final msgId = msg['id'];
          if (msgId != null) {
            messagesMap[msgId] = msg;
            messageIds.add(msgId);
          }
        }
      }
    });

    for (var msg in messagesList) {
      if (msg is Map<String, dynamic>) {
        final sender = msg['sender_id'];
        if (sender != null && sender['@type'] == 'messageSenderUser') {
          final userId = sender['user_id'];
          if (!users.containsKey(userId)) {
            tdLibService.loadUser(userId);
          }
        }
      }
    }
  }

  void _handleUser(Map<String, dynamic> data) {
    final id = data['id'];
    final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
    setState(() {
      users[id] = name.isEmpty ? 'User$id' : name;
    });
  }

  void _handleSingleMessage(Map<String, dynamic> data) {
    final msgId = data['id'];
    if (msgId != null && selectedChat != null && data['chat_id'] == selectedChat!.id) {
      setState(() {
        messagesMap[msgId] = data;
        if (!messageIds.contains(msgId)) {
          messageIds.add(msgId);
        }
      });
    }
  }

  void _addMessageToChat(Map<String, dynamic> message) {
    final msgId = message['id'];
    if (msgId == null) return;

    setState(() {
      messagesMap[msgId] = message;
      if (!messageIds.contains(msgId)) {
        messageIds.insert(0, msgId);
      }
    });

    final replyTo = message['reply_to'];
    if (replyTo != null && replyTo['@type'] == 'messageReplyToMessage') {
      final repliedMsgId = replyTo['message_id'];
      if (repliedMsgId != null && !messagesMap.containsKey(repliedMsgId)) {
        tdLibService.loadMessage(selectedChat!.id, repliedMsgId);
      }
    }
  }

  void _sortChats() {
    chats.sort((a, b) => b.lastMessageDate.compareTo(a.lastMessageDate));
  }

  bool _isChatMember(int chat_id) {
    return chatsStatus.any(
          (c) => c.chat_id == chat_id && c.status != 'chatMemberStatusLeft',
    );
  }

  void _addOrUpdateChat(Map<String, dynamic> chatData) {
    try {
      final id = chatData['id'];
      if (id == null) return;
      if (chatData['type']['@type'] == 'chatTypeSupergroup') {
        if (!_isChatMember(id)) return;
    }
      final title = chatData['title'] ?? 'Без названия';
      String lastMsg = 'Нет сообщений';
      int lastMsgDate = 0;

      if (chatData['last_message'] != null) {
        lastMsgDate = chatData['last_message']['date'] ?? 0;
        final content = chatData['last_message']['content'];
        if (content != null) {
          if (content['@type'] == 'messageText') {
            lastMsg = content['text']?['text'] ?? '';
          } else {
            lastMsg = content['@type']?.toString().replaceAll('message', '') ?? 'Медиа';
          }
        }
      }
      setState(() {
        final index = chats.indexWhere((c) => c.id == id);
        final chat = Chat(
          id: id,
          title: title,
          lastMessage: lastMsg,
          lastMessageDate: lastMsgDate
        );
        if (index >= 0) {
          chats[index] = chat;
        } else {
          chats.add(chat);
        }
        _sortChats();
      });
    } catch (e) {
      print('Ошибка при добавлении чата: $e');
    }
  }

  void _updateChatLastMessage(int chatId, Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return;

    try {
      String lastMsg = 'Сообщение';
      int lastMsgDate = lastMessage['date'] ?? 0;
      final content = lastMessage['content'];
      if (content != null) {
        if (content['@type'] == 'messageText') {
          lastMsg = content['text']?['text'] ?? '';
        } else {
          lastMsg = content['@type']?.toString().replaceAll('message', '') ?? 'Медиа';
        }
      }

      setState(() {
        final index = chats.indexWhere((c) => c.id == chatId);
        if (index >= 0 && chats.isNotEmpty) {
          chats[index] = Chat(
            id: chatId,
            title: chats[index].title,
            lastMessage: lastMsg,
            lastMessageDate: lastMsgDate,
          );
          _sortChats();
        }
      });
    } catch (e) {
      print('Ошибка при обновлении сообщения чата: $e');
    }
  }

  void _openChat(Chat chat) {
    setState(() {
      selectedChat = chat;
      appState = AppState.chat;
      messagesMap.clear();
      messageIds.clear();
      replyToMessageId = null;
    });

    tdLibService.loadChatHistory(chat.id);
  }

  void _sendMessage(String text) {
    if (selectedChat == null || text.isEmpty) return;

    tdLibService.sendMessage(
      selectedChat!.id,
      text,
      replyToMessageId: replyToMessageId,
    );

    setState(() {
      replyToMessageId = null;
    });
  }

  void _backToChatList() {
    setState(() {
      appState = AppState.chatList;
      selectedChat = null;
      messagesMap.clear();
      messageIds.clear();
      replyToMessageId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: Text(_getTitle()),
          leading: appState == AppState.chat
              ? IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _backToChatList,
          )
              : null,
        ),
        body: _buildBody(),
      ),
    );
  }

  String _getTitle() {
    switch (appState) {
      case AppState.loading:
      case AppState.waitingPhone:
      case AppState.waitingCode:
      case AppState.waitingPassword:
        return 'Textgram';
      case AppState.chatList:
        return 'Chats';
      case AppState.chat:
        return selectedChat?.title ?? 'Chat';
    }
  }

  Widget _buildBody() {
    switch (appState) {
      case AppState.loading:
      case AppState.waitingPhone:
      case AppState.waitingCode:
      case AppState.waitingPassword:
        return AuthScreen(
          appState: appState,
          status: status,
          onPhoneSubmit: tdLibService.sendPhoneNumber,
          onCodeSubmit: tdLibService.sendCode,
          onPasswordSubmit: tdLibService.sendPassword,
        );
      case AppState.chatList:
        return ChatListScreen(
          chats: chats,
          onChatTap: _openChat,
        );
      case AppState.chat:
        return ChatScreen(
          messageIds: messageIds,
          messagesMap: messagesMap,
          users: users,
          replyToMessageId: replyToMessageId,
          onSendMessage: _sendMessage,
          onLongPressMessage: (msgId) {
            setState(() {
              replyToMessageId = msgId;
            });
          },
          onCancelReply: () {
            setState(() {
              replyToMessageId = null;
            });
          },
          onEditMessage: (msgId, txt) {
            tdLibService.editMsg(selectedChat!.id, msgId, txt);
          },
          onDeleteMessage: (msgId) {
            tdLibService.deleteMsg(selectedChat!.id, [msgId]);
          },
        );
    }
  }

  @override
  void dispose() {
    tdLibService.destroy();
    super.dispose();
  }
}