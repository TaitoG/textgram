import '/core/td.dart';
import 'app_controller.dart';
import '/models/models.dart';

class TDReceiver {
  final TdLibService tdLibService;
  final AppController app;

  TDReceiver(this.tdLibService, this.app);

  void startListening(Map<String, dynamic> tdlibParams) async {
    await for (final data in tdLibService.startReceiver()) {
      _handleUpdate(data, tdlibParams);
    }
  }

  void _handleUpdate(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    try {
      final type = data['@type'];
      switch (type) {
        case 'updateAuthorizationState':
          _handleAuthorizationState(data, tdlibParams);
          break;
        case 'updateNewChat':
          _addOrUpdateChat(data['chat']);
          break;
        case 'updateChatLastMessage':
          _updateChatLastMessage(data['chat_id'], data['last_message']);
          break;
        case 'updateChatPosition':
          tdLibService.loadChats();
          break;
        case 'updateNewMessage':
          _handleNewMessage(data['message']);
          break;
        case 'updateMessageContent':
          _handleMessageContentUpdate(data);
          break;
        case 'updateDeleteMessages':
          _handleDeleteMessages(data);
          break;
        case 'updateSupergroup':
          _handleSupergroupUpdate(data);
          break;
        case 'messages':
          _handleMessagesHistory(data['messages']);
          break;
        case 'user':
          _handleUser(data);
          break;
        case 'message':
          _handleSingleMessage(data);
          break;
      }
    } catch (e) {
      print('Ошибка обработки обновления: $e');
      print('Данные: $data');
    }
  }

  void _handleAuthorizationState(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    final state = data['authorization_state']['@type'];

    switch (state) {
      case 'authorizationStateWaitPhoneNumber':
        app.setState(AppState.waitingPhone);
        app.setStatus('Введите номер телефона');
        break;
      case 'authorizationStateWaitCode':
        app.setState(AppState.waitingCode);
        app.setStatus('Введите код из Telegram');
        break;
      case 'authorizationStateWaitPassword':
        final hint = data['authorization_state']['password_hint'] ?? '';
        app.setState(AppState.waitingPassword);
        app.setStatus('Введите пароль${hint.isNotEmpty ? " (подсказка: $hint)" : ""}');
        break;
      case 'authorizationStateReady':
        app.setState(AppState.chatList);
        app.setStatus('✅ Успешно вошли!');
        tdLibService.loadChats();
        break;
      case 'authorizationStateClosed':
        app.setStatus('Соединение закрыто');
        break;
    }
  }

  void _handleNewMessage(Map<String, dynamic>? message) {
    if (message == null) return;
    final chatId = message['chat_id'];
    if (chatId == null) return;

    if (app.selectedChat != null && chatId == app.selectedChat!.id) {
      app.addMessage(message);
    }

    final sender = message['sender_id'];
    if (sender != null && sender['@type'] == 'messageSenderUser') {
      final userId = sender['user_id'];
      if (!app.users.containsKey(userId)) {
        tdLibService.loadUser(userId);
      }
    }

    _updateChatLastMessage(chatId, message);
  }

  void _handleMessageContentUpdate(Map<String, dynamic> data) {
    final chatId = data['chat_id'];
    final messageId = data['message_id'];
    final newContent = data['new_content'];

    if (app.selectedChat != null && chatId == app.selectedChat!.id) {
      app.updateMessageContent(messageId, newContent);
    }
  }

  void _handleDeleteMessages(Map<String, dynamic> data) {
    final chatId = data['chat_id'];
    final messageIdsList = data['message_ids'];

    if (app.selectedChat != null && chatId == app.selectedChat!.id && messageIdsList is List) {
      app.deleteMessages(messageIdsList.cast<int>());
    }
  }

  void _handleMessagesHistory(List? messagesList) {
    if (messagesList == null || messagesList.isEmpty || app.selectedChat == null) return;

    final newMessagesMap = <int, Map<String, dynamic>>{};
    final newMessageIds = <int>[];

    for (var msg in messagesList) {
      if (msg is Map<String, dynamic>) {
        final msgId = msg['id'];
        if (msgId != null) {
          newMessagesMap[msgId] = msg;
          newMessageIds.add(msgId);
        }
      }
    }

    app.updateMessages(newMessagesMap, newMessageIds);

    for (var msg in messagesList) {
      if (msg is Map<String, dynamic>) {
        final sender = msg['sender_id'];
        if (sender != null && sender['@type'] == 'messageSenderUser') {
          final userId = sender['user_id'];
          if (!app.users.containsKey(userId)) {
            tdLibService.loadUser(userId);
          }
        }
      }
    }
  }

  void _handleUser(Map<String, dynamic> data) {
    final id = data['id'];
    final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
    final newName = name.isEmpty ? 'User$id' : name;
    app.users[id] = newName;
    app.notifyListeners();
  }

  void _handleSingleMessage(Map<String, dynamic> data) {
    final msgId = data['id'];
    if (msgId != null && app.selectedChat != null && data['chat_id'] == app.selectedChat!.id) {
      app.addMessage(data);
    }
  }

  void _handleSupergroupUpdate(Map<String, dynamic> data) {
    final s = data['supergroup']['status']['@type'];
    final cid = data['supergroup']['id'];
    final normalizedId = (-100 * 10000000000 - cid).toInt();

    final index = app.chatsStatus.indexWhere((c) => c.chat_id == cid);
    final chat = ChatStatus(chat_id: normalizedId, status: s);

    if (index >= 0) {
      app.chatsStatus[index] = chat;
    } else {
      app.chatsStatus.add(chat);
    }
    app.notifyListeners();
  }

  bool _isChatMember(int chat_id) {
    return app.isChatMember(chat_id);
  }

  void _addOrUpdateChat(Map<String, dynamic> chatData) {
    try {
      final id = chatData['id'];
      if (id == null) return;

      if (chatData['type']['@type'] == 'chatTypeSupergroup' && !_isChatMember(id)) return;

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

      final newChats = List<Chat>.from(app.chats);
      final index = newChats.indexWhere((c) => c.id == id);
      final chat = Chat(
          id: id,
          title: title,
          lastMessage: lastMsg,
          lastMessageDate: lastMsgDate
      );

      if (index >= 0) {
        newChats[index] = chat;
      } else {
        newChats.add(chat);
      }
      newChats.sort((a, b) => b.lastMessageDate.compareTo(a.lastMessageDate));
      app.updateChats(newChats);
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
      app.updateChatLastMessage(chatId, lastMsg, lastMsgDate);
    } catch (e) {
      print('Ошибка при обновлении сообщения чата: $e');
    }
  }
}