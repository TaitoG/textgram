// core/app_controller.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:textgram/models/models.dart';
import 'package:textgram/pages/pages.dart';
import 'td.dart';
import 'td_receiver.dart';
import 'package:path_provider/path_provider.dart';

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
  Set<int> messageIdsSet = {};
  List<int> messageIdsList = [];
  int? replyToMessageId;

  Timer? _notifyTimer;
  bool _hasPendingNotification = false;

  bool isLoadingHistory = false;
  bool hasMoreHistory = true;
  int? oldestMessageId;

  Set<int> _loadingUsers = {};
  Set<int> _loadedChats = {};

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

      final appDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory('${appDir.path}/td_db');
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      final tdlibParams = {
        ...tdLibService.getTdlibParameters(),
        'database_directory': dbDir.path,
        'files_directory': '${appDir.path}/td_files',
      };
      tdLibService.send(tdlibParams);
      setStatus('Отправили параметры TDLib');

      tdReceiver.startListening(tdlibParams);
    } catch (e) {
      setStatus('Ошибка загрузки TDLib: $e');
    }
  }

  void _scheduleNotification() {
    _hasPendingNotification = true;
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 50), () {
      if (_hasPendingNotification) {
        notifyListeners();
        _hasPendingNotification = false;
      }
    });
  }

  void setState(AppState newState) {
    appState = newState;
    notifyListeners();
  }

  void setStatus(String newStatus) {
    status = newStatus;
    _scheduleNotification();
  }

  void openProfile(Chat chat) {
    selectedChat = chat;
    setState(AppState.profile);
    notifyListeners();
  }

  void openChat(Chat chat) {
    selectedChat = chat;
    setState(AppState.chat);
    messagesMap.clear();
    messageIdsSet.clear();
    messageIdsList.clear();
    replyToMessageId = null;
    hasMoreHistory = true;
    oldestMessageId = null;
    isLoadingHistory = false;

    tdLibService.loadChatHistory(chat.id, limit: 50);
    notifyListeners();
  }

  void sendMessage(String text) {
    if (selectedChat == null || text.trim().isEmpty) return;
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
    messageIdsSet.clear();
    messageIdsList.clear();
    replyToMessageId = null;
    hasMoreHistory = true;
    oldestMessageId = null;
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
      case AppState.profile:
        return 'Profile';
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
      case AppState.profile:
        return ProfileScreen(chat: selectedChat!);
      case AppState.chat:
        return ListenableBuilder(
          listenable: this,
          builder: (context, child) {
            return ChatScreen(
              messageIds: messageIdsList,
              messagesMap: messagesMap,
              users: users,
              replyToMessageId: replyToMessageId,
              onSendMessage: sendMessage,
              onLongPressMessage: (msgId) {
                replyToMessageId = msgId;
                notifyListeners();
              },
              onCancelReply: () {
                replyToMessageId = null;
                notifyListeners();
              },
              onEditMessage: (msgId, txt) =>
                  tdLibService.editMsg(selectedChat!.id, msgId, txt),
              onDeleteMessage: (msgId) => deleteMessages([msgId]),
              onLoadMore: loadMoreHistory,
            );
          },
        );
    }
  }

  void loadMoreHistory() {
    if (selectedChat == null || isLoadingHistory || !hasMoreHistory) return;

    isLoadingHistory = true;
    notifyListeners();

    tdLibService.loadChatHistory(
      selectedChat!.id,
      fromMessageId: oldestMessageId ?? 0,
      limit: 50,
      offset: 0,
    );
  }

  void updateChats(List<Chat> newChats) {
    chats = newChats;
    _scheduleNotification();
  }

  void updateUsers(Map<int, String> newUsers) {
    users = newUsers;
    _scheduleNotification();
  }

  void updateSelectedChat(Chat? chat) {
    selectedChat = chat;
    _scheduleNotification();
  }

  void updateMessages(Map<int, Map<String, dynamic>> newMessages, List<int> newMessageIds) {
    messagesMap.addAll(newMessages);

    for (var id in newMessageIds) {
      if (!messageIdsSet.contains(id)) {
        messageIdsSet.add(id);
      }
    }

    messageIdsList = messageIdsSet.toList()..sort((a, b) => b.compareTo(a));

    if (messageIdsList.isNotEmpty) {
      oldestMessageId = messageIdsList.last;
    }

    isLoadingHistory = false;

    if (newMessageIds.length < 50) {
      hasMoreHistory = false;
    }

    _scheduleNotification();
  }

  void updateChatLastMessage(int chatId, String lastMsg, int lastMsgDate) {
    final index = chats.indexWhere((c) => c.id == chatId);
    if (index >= 0) {
      final updatedChat = Chat(
        id: chatId,
        title: chats[index].title,
        lastMessage: lastMsg,
        lastMessageDate: lastMsgDate,
      );

      chats[index] = updatedChat;

      if (index > 0 && chats[index].lastMessageDate > chats[index - 1].lastMessageDate) {
        chats.sort((a, b) => b.lastMessageDate.compareTo(a.lastMessageDate));
      }

      _scheduleNotification();
    }
  }

  void addMessage(Map<String, dynamic> message) {
    final msgId = message['id'];
    if (msgId == null) return;

    messagesMap[msgId] = message;

    if (!messageIdsSet.contains(msgId)) {
      messageIdsSet.add(msgId);
      messageIdsList.insert(0, msgId);
    }

    _scheduleNotification();
  }

  void deleteMessages(List<int> messageIdsToDelete) {
    if (messageIdsToDelete.isEmpty || selectedChat == null) return;

    for (var msgId in messageIdsToDelete) {
      messagesMap.remove(msgId);
      messageIdsSet.remove(msgId);
      messageIdsList.remove(msgId);
    }
    tdLibService.deleteMsg(selectedChat!.id, messageIdsToDelete);

    _scheduleNotification();
  }

  void updateMessageContent(int messageId, Map<String, dynamic> newContent) {
    if (messagesMap.containsKey(messageId)) {
      messagesMap[messageId]!['content'] = newContent;
      _scheduleNotification();
    }
  }

  bool isChatMember(int chatId) {
    return chatsStatus.any(
          (c) => c.chat_id == chatId && c.status != 'chatMemberStatusLeft',
    );
  }

  void deleteChatFromList(int chatId) {
    chats.removeWhere((chat) => chat.id == chatId);
    _loadedChats.remove(chatId);
    _scheduleNotification();
  }

  void joinChatByInvite(String url) {
    tdLibService.joinChatByLink(url);
    setStatus('> Присоединяемся к чату...');
  }

  void loadUserIfNeeded(int userId) {
    if (!users.containsKey(userId) && !_loadingUsers.contains(userId)) {
      _loadingUsers.add(userId);
      tdLibService.loadUser(userId);
    }
  }

  void onUserLoaded(int userId) {
    _loadingUsers.remove(userId);
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    tdLibService.stopReceiver();
    tdLibService.destroy();
    super.dispose();
  }
}