import 'td.dart';
import 'app_controller.dart';
import 'package:textgram/models/models.dart';

class TDReceiver {
  final TdLibService tdLibService;
  final AppController app;

  TDReceiver(this.tdLibService, this.app);

  void listen() async {
    final tdlibParams = tdLibService.getTdlibParameters();

    await for (final data in tdLibService.startReceiver()) {
      _handleUpdate(data, tdlibParams);
    }
  }

  void _handleUpdate(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    final type = data['@type'];
    switch (type) {
      case 'updateAuthorizationState':
        _handleAuthorizationState(data, tdlibParams);
        break;
      case 'updateNewChat':
        _handleNewChat(data['chat']);
        break;
      case 'updateNewMessage':
        _handleNewMessage(data['message']);
        break;
      case 'user':
        _handleUser(data);
        break;
    // остальные типы при необходимости
    }
  }

  void _handleAuthorizationState(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    final state = data['authorization_state']['@type'];

    switch (state) {
      case 'authorizationStateWaitTdlibParameters':
        tdLibService.send(tdlibParams);
        app.setStatus('Отправили параметры TDLib');
        break;
      case 'authorizationStateWaitPhoneNumber':
        app.setState(AppState.waitingPhone);
        app.setStatus('Введите номер телефона');
        break;
      case 'authorizationStateWaitCode':
        app.setState(AppState.waitingCode);
        app.setStatus('Введите код из Telegram');
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

  void _handleNewChat(Map<String, dynamic> chatData) {
    final chat = Chat(
      id: chatData['id'],
      title: chatData['title'] ?? 'Без названия',
      lastMessage: chatData['last_message']?['content']?['text']?['text'] ?? '',
      lastMessageDate: chatData['last_message']?['date'] ?? 0,
    );
    app.chats.add(chat);
    app.notifyListeners();
  }

  void _handleNewMessage(Map<String, dynamic> message) {
    final chatId = message['chat_id'];
    final msgId = message['id'];
    app.messagesMap[msgId] = message;
    if (!app.messageIds.contains(msgId)) app.messageIds.insert(0, msgId);
    app.notifyListeners();
  }

  void _handleUser(Map<String, dynamic> data) {
    final id = data['id'];
    final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
    app.addUser(id, name.isEmpty ? 'User$id' : name);
  }
}
