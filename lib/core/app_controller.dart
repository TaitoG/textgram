// core/app_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:textgram/models/models.dart';
import 'package:textgram/pages/pages.dart';
import 'td.dart';
import 'td_receiver.dart';

class AppController extends ChangeNotifier {
  final TdLibService tdLibService = TdLibService();
  late TDReceiver tdReceiver;

  AppState appState = AppState.loading;
  String status = 'Connecting to TDLib...';
  List<Chat> chats = [];
  List<ChatStatus> chatsStatus = [];
  Map<int, String> users = {};
  Chat? selectedChat;

  Map<int, Map<String, dynamic>> messagesMap = {};
  List<int> messageIds = [];
  int? replyToMessageId;

  AppController() {
    tdReceiver = TDReceiver(tdLibService, this);
    _initTdLib();
  }

  void _initTdLib() async {
    try {
      if (!tdLibService.initialize()) {
        setStatus('Error');
        return;
      }
      tdLibService.setLogVerbLvl(2);

      final dir = Directory('./td_db');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final tdlibParams = tdLibService.getTdlibParameters();
      tdLibService.send(tdlibParams);
      setStatus('Отправили параметры TDLib');

      tdReceiver.startListening(tdlibParams);
    } catch (e) {
      setStatus('Ошибка загрузки TDLib: $e');
    }
  }

  // Публичные методы
  void setState(AppState newState) {
    appState = newState;
    notifyListeners();
  }

  void setStatus(String newStatus) {
    status = newStatus;
    notifyListeners();
  }

  void openChat(Chat chat) {
    selectedChat = chat;
    setState(AppState.chat);
    messagesMap.clear();
    messageIds.clear();
    replyToMessageId = null;
    tdLibService.loadChatHistory(chat.id);
    notifyListeners();
  }

  void sendMessage(String text) {
    if (selectedChat == null || text.isEmpty) return;
    tdLibService.sendMessage(
      selectedChat!.id,
      text,
      replyToMessageId: replyToMessageId,
    );
    replyToMessageId = null;
    notifyListeners();
  }

  void backToChatList() {
    setState(AppState.chatList);
    selectedChat = null;
    messagesMap.clear();
    messageIds.clear();
    replyToMessageId = null;
    notifyListeners();
  }

  String getTitle() {
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

  Widget buildBody(BuildContext context) {
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
          onChatTap: openChat,
        );
      case AppState.chat:
        return ChatScreen(
          messageIds: messageIds,
          messagesMap: messagesMap,
          users: users,
          replyToMessageId: replyToMessageId,
          onSendMessage: sendMessage,
          onLongPressMessage: (msgId) => replyToMessageId = msgId,
          onCancelReply: () => replyToMessageId = null,
          onEditMessage: (msgId, txt) =>
              tdLibService.editMsg(selectedChat!.id, msgId, txt),
          onDeleteMessage: (msgId) => deleteMessages([msgId])
        );
    }
  }

  void updateChats(List<Chat> newChats) {
    chats = newChats;
    notifyListeners();
  }

  void updateUsers(Map<int, String> newUsers) {
    users = newUsers;
    notifyListeners();
  }

  void updateSelectedChat(Chat? chat) {
    selectedChat = chat;
    notifyListeners();
  }

  void updateMessages(Map<int, Map<String, dynamic>> newMessages, List<int> newMessageIds) {
    messagesMap = newMessages;
    messageIds = newMessageIds;
    notifyListeners();
  }

  void updateChatLastMessage(int chatId, String lastMsg, int lastMsgDate) {
    final index = chats.indexWhere((c) => c.id == chatId);
    if (index >= 0 && chats.isNotEmpty) {
      chats[index] = Chat(
        id: chatId,
        title: chats[index].title,
        lastMessage: lastMsg,
        lastMessageDate: lastMsgDate,
      );
      chats.sort((a, b) => b.lastMessageDate.compareTo(a.lastMessageDate));
      notifyListeners();
    }
  }

  void addMessage(Map<String, dynamic> message) {
    final msgId = message['id'];
    if (msgId == null) return;

    messagesMap[msgId] = message;
    if (!messageIds.contains(msgId)) {
      messageIds.insert(0, msgId);
    }
    notifyListeners();
  }

  void deleteMessages(List<int> messageIdsToDelete) {
    for (var msgId in messageIdsToDelete) {
      messagesMap.remove(msgId);
      messageIds.remove(msgId);

      tdLibService.deleteMsg(selectedChat!.id, [msgId]);
    }
    notifyListeners();
  }

  void updateMessageContent(int messageId, Map<String, dynamic> newContent) {
    if (messagesMap.containsKey(messageId)) {
      messagesMap[messageId]!['content'] = newContent;
      notifyListeners();
    }
  }

  bool isChatMember(int chatId) {
    return chatsStatus.any(
          (c) => c.chat_id == chatId && c.status != 'chatMemberStatusLeft',
    );
  }

  void deleteChatFromList(int chatId) {
    chats.removeWhere((chat) => chat.id == chatId);
    notifyListeners();
  }

  void joinChatByInvite(String url) {
    tdLibService.joinChatByLink(url);
    setStatus('> Присоединяемся к чату...');
  }

  @override
  void dispose() {
    tdLibService.destroy();
    super.dispose();
  }
}