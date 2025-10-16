import 'package:flutter/foundation.dart';
import 'package:textgram/models/models.dart';

class AppController extends ChangeNotifier {
  AppState appState = AppState.loading;
  String status = 'Инициализация...';
  List<Chat> chats = [];
  Chat? selectedChat;
  Map<int, Map<String, dynamic>> messagesMap = {};
  List<int> messageIds = [];
  Map<int, String> users = {};

  void setState(AppState newState) {
    appState = newState;
    notifyListeners();
  }

  void setStatus(String text) {
    status = text;
    notifyListeners();
  }

  void updateChats(List<Chat> newChats) {
    chats = newChats;
    notifyListeners();
  }

  void updateMessages(Map<int, Map<String, dynamic>> newMessages, List<int> ids) {
    messagesMap = newMessages;
    messageIds = ids;
    notifyListeners();
  }

  void addUser(int id, String name) {
    users[id] = name;
    notifyListeners();
  }
}
