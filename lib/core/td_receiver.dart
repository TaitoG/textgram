// td_receiver.dart
import 'dart:async';
import '/core/td.dart';
import 'app_controller.dart';
import '/models/models.dart';

class TDReceiver {
  final TdLibService tdLibService;
  final AppController app;
  StreamSubscription? _subscription;

  final Set<int> _processedChatIds = {};

  Timer? _chatsUpdateTimer;
  bool _needsChatsUpdate = false;

  TDReceiver(this.tdLibService, this.app);

  void startListening(Map<String, dynamic> tdlibParams) {
    _subscription?.cancel();

    _subscription = tdLibService.startReceiver().listen(
          (data) => _handleUpdate(data, tdlibParams),
      onError: (error) {
        print('❌ Ошибка в потоке обновлений: $error');
      },
      onDone: () {
        print('✅ Поток обновлений завершён');
      },
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _chatsUpdateTimer?.cancel();
  }

  void _handleUpdate(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    try {
      final type = data['@type'];
      if (type == null) return;

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
          _scheduleChatsUpdate();
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
        case 'chat':
          _addOrUpdateChat(data);
          break;
        case 'error':
          _handleError(data);
          break;
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка обработки обновления: $e');
      print('Стек: $stackTrace');
      print('Данные: ${data.toString().substring(0, data.toString().length > 500 ? 500 : data.toString().length)}');
    }
  }

  void _scheduleChatsUpdate() {
    _needsChatsUpdate = true;
    _chatsUpdateTimer?.cancel();

    _chatsUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      if (_needsChatsUpdate) {
        tdLibService.loadChats(limit: 20);
        _needsChatsUpdate = false;
      }
    });
  }

  void _handleAuthorizationState(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    final authState = data['authorization_state'];
    if (authState == null) return;

    final state = authState['@type'];

    switch (state) {
      case 'authorizationStateWaitPhoneNumber':
        app.setState(AppState.waitingPhone);
        app.setStatus('Enter phone number..._');
        break;
      case 'authorizationStateWaitCode':
        app.setState(AppState.waitingCode);
        app.setStatus('Enter code from Telegram..._');
        break;
      case 'authorizationStateWaitPassword':
        final hint = authState['password_hint'] ?? '';
        app.setState(AppState.waitingPassword);
        app.setStatus('Enter password${hint.isNotEmpty ? " (hint: $hint)" : ""}');
        break;
      case 'authorizationStateReady':
        app.setState(AppState.chatList);
        app.setStatus('✅ Logged in!');
        tdLibService.loadChats(limit: 20);
        break;
      case 'authorizationStateClosed':
        app.setStatus('Connection closed.');
        break;
      case 'authorizationStateLoggingOut':
        app.setStatus('Sign out...');
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
      if (userId != null) {
        app.loadUserIfNeeded(userId);
      }
    }

    _updateChatLastMessage(chatId, message);
  }

  void _handleMessageContentUpdate(Map<String, dynamic> data) {
    final chatId = data['chat_id'];
    final messageId = data['message_id'];
    final newContent = data['new_content'];

    if (chatId == null || messageId == null || newContent == null) return;

    if (app.selectedChat != null && chatId == app.selectedChat!.id) {
      app.updateMessageContent(messageId, newContent);
    }
  }

  void _handleDeleteMessages(Map<String, dynamic> data) {
    final chatId = data['chat_id'];
    final messageIdsList = data['message_ids'];

    if (chatId == null || messageIdsList == null) return;

    if (app.selectedChat != null && chatId == app.selectedChat!.id && messageIdsList is List) {
      final idsToDelete = messageIdsList.cast<int>();
      for (var id in idsToDelete) {
        app.messagesMap.remove(id);
        app.messageIdsSet.remove(id);
        app.messageIdsList.remove(id);
      }
      app.notifyListeners();
    }
  }

  void _handleMessagesHistory(List? messagesList) {
    if (messagesList == null || messagesList.isEmpty || app.selectedChat == null) {
      app.isLoadingHistory = false;
      app.hasMoreHistory = false;
      return;
    }

    final newMessagesMap = <int, Map<String, dynamic>>{};
    final newMessageIds = <int>[];
    final userIdsToLoad = <int>{};

    for (var msg in messagesList) {
      if (msg is! Map<String, dynamic>) continue;

      final msgId = msg['id'];
      if (msgId == null) continue;

      newMessagesMap[msgId] = msg;
      newMessageIds.add(msgId);

      final sender = msg['sender_id'];
      if (sender != null && sender['@type'] == 'messageSenderUser') {
        final userId = sender['user_id'];
        if (userId != null && !app.users.containsKey(userId)) {
          userIdsToLoad.add(userId);
        }
      }
    }

    app.updateMessages(newMessagesMap, newMessageIds);

    for (var userId in userIdsToLoad) {
      app.loadUserIfNeeded(userId);
    }
  }

  void _handleUser(Map<String, dynamic> data) {
    final id = data['id'];
    if (id == null) return;

    final firstName = data['first_name'] ?? '';
    final lastName = data['last_name'] ?? '';
    final username = data['username'] ?? '';

    String name = '$firstName $lastName'.trim();
    if (name.isEmpty && username.isNotEmpty) {
      name = '@$username';
    }
    if (name.isEmpty) {
      name = 'User$id';
    }

    app.users[id] = name;
    app.onUserLoaded(id);
    app.notifyListeners();
  }

  void _handleSingleMessage(Map<String, dynamic> data) {
    final msgId = data['id'];
    final chatId = data['chat_id'];

    if (msgId == null || chatId == null) return;

    if (app.selectedChat != null && chatId == app.selectedChat!.id) {
      app.addMessage(data);
    }
  }

  void _handleSupergroupUpdate(Map<String, dynamic> data) {
    final supergroup = data['supergroup'];
    if (supergroup == null) return;

    final status = supergroup['status'];
    final id = supergroup['id'];

    if (status == null || id == null) return;

    final statusType = status['@type'];

    final normalizedId = -1000000000000 - id;

    final index = app.chatsStatus.indexWhere((c) => c.chat_id == normalizedId.toInt());
    final chat = ChatStatus(chat_id: normalizedId.toInt(), status: statusType);

    if (index >= 0) {
      app.chatsStatus[index] = chat;
    } else {
      app.chatsStatus.add(chat);
    }

    if (statusType == 'chatMemberStatusLeft' || statusType == 'chatMemberStatusBanned') {
      app.deleteChatFromList(normalizedId.toInt());
    }

    app.notifyListeners();
  }

  void _handleError(Map<String, dynamic> data) {
    final code = data['code'] ?? 0;
    final message = data['message'] ?? 'Unknown error';
    print('⚠️ TDLib Error [$code]: $message');

    if (code == 401) {
      app.setState(AppState.waitingPhone);
      app.setStatus('Need to log in');
    }
  }

  bool _isChatMember(int chatId) {
    return app.isChatMember(chatId);
  }

  void _addOrUpdateChat(Map<String, dynamic>? chatData) {
    if (chatData == null) return;

    try {
      final id = chatData['id'];
      if (id == null) return;

      final chatType = chatData['type'];
      if (chatType == null) return;

      if (chatType['@type'] == 'chatTypeSupergroup' && !_isChatMember(id)) {
        return;
      }

      final title = chatData['title'] ?? 'Noname';
      String lastMsg = 'No messages';
      int lastMsgDate = 0;

      final lastMessage = chatData['last_message'];
      if (lastMessage != null) {
        lastMsgDate = (lastMessage['date'] ?? 0).toInt();
        lastMsg = _extractMessageText(lastMessage);
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
        _processedChatIds.add(id);
      }

      if (index < 0 || (index > 0 && newChats[index].lastMessageDate > newChats[index - 1].lastMessageDate)) {
        newChats.sort((a, b) => b.lastMessageDate.compareTo(a.lastMessageDate));
      }

      app.updateChats(newChats);
    } catch (e, stackTrace) {
      print('❌ Ошибка при добавлении чата: $e');
      print('Стек: $stackTrace');
    }
  }

  void _updateChatLastMessage(int chatId, Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return;

    try {
      final lastMsgDate = (lastMessage['date'] ?? 0).toInt();
      final lastMsg = _extractMessageText(lastMessage);

      app.updateChatLastMessage(chatId, lastMsg, lastMsgDate);
    } catch (e) {
      print('❌ Ошибка при обновлении сообщения чата: $e');
    }
  }

  String _extractMessageText(Map<String, dynamic> message) {
    final content = message['content'];
    if (content == null) return '[Message]';

    final contentType = content['@type'];

    switch (contentType) {
      case 'messageText':
        final text = content['text'];
        if (text != null && text['text'] != null) {
          return text['text'].toString();
        }
        return '[Text]';

      case 'messagePhoto':
        final caption = content['caption'];
        if (caption != null && caption['text'] != null && caption['text'].toString().isNotEmpty) {
          return '[Photo] ${caption['text']}';
        }
        return '[Photo]';

      case 'messageVideo':
        return '[Video]';

      case 'messageVoiceNote':
        return '[Voice]';

      case 'messageAudio':
        return '[Audio]';

      case 'messageDocument':
        final doc = content['document'];
        final fileName = doc?['file_name'] ?? 'файл';
        return '[File] $fileName';

      case 'messageSticker':
        final emoji = content['sticker']?['emoji'] ?? '';
        return '[$emoji Sticker]';

      case 'messageAnimation':
        return '[GIF]';

      case 'messageLocation':
        return '[Location]';

      case 'messageContact':
        return '[Contact]';

      case 'messagePoll':
        final question = content['poll']?['question'] ?? 'Опрос';
        return '[Poll] $question';

      case 'messageVideoNote':
        return '[VideoNote]';

      case 'messageCall':
        return '[Call]';

      default:
        return contentType.toString().replaceFirst('message', '');
    }
  }

  void dispose() {
    stopListening();
    _chatsUpdateTimer?.cancel();
  }
}