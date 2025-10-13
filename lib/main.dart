import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';

typedef TdJsonClientCreateNative = Pointer<Void> Function();
typedef TdJsonClientSendNative = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef TdJsonClientReceiveNative = Pointer<Utf8> Function(Pointer<Void>, Double);
typedef TdJsonClientDestroyNative = Void Function(Pointer<Void>);

typedef TdJsonClientCreate = Pointer<Void> Function();
typedef TdJsonClientSend = void Function(Pointer<Void>, Pointer<Utf8>);
typedef TdJsonClientReceive = Pointer<Utf8> Function(Pointer<Void>, double);
typedef TdJsonClientDestroy = void Function(Pointer<Void>);

void main() {
  runApp(MyApp());
}

enum AppState {
  loading,
  waitingPhone,
  waitingCode,
  waitingPassword,
  chatList,
  chat,
}

class Chat {
  final int id;
  final String title;
  final String lastMessage;

  Chat({required this.id, required this.title, required this.lastMessage});
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late DynamicLibrary tdlib;
  late Pointer<Void> client;
  late TdJsonClientSend clientSend;
  late TdJsonClientReceive clientReceive;
  late TdJsonClientDestroy clientDestroy;
  late File chatsFile;

  AppState appState = AppState.loading;
  String status = 'Подключение к TDLib...';
  String phoneNumber = '';
  List<Chat> chats = [];
  Map<int, String> users = {};
  Chat? selectedChat;
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _initTdLib();
  }

  void _initTdLib() async {
    try {
      tdlib = DynamicLibrary.open('tdlib/libtdjson.so');
      final clientCreate = tdlib.lookupFunction<TdJsonClientCreateNative, TdJsonClientCreate>('td_json_client_create');
      clientSend = tdlib.lookupFunction<TdJsonClientSendNative, TdJsonClientSend>('td_json_client_send');
      clientReceive = tdlib.lookupFunction<TdJsonClientReceiveNative, TdJsonClientReceive>('td_json_client_receive');
      clientDestroy = tdlib.lookupFunction<TdJsonClientDestroyNative, TdJsonClientDestroy>('td_json_client_destroy');

      client = clientCreate();
      if (client.address == 0) {
        setState(() {
          status = 'Ошибка создания TDLib клиента';
        });
        return;
      }
      final dir = Directory('./td_db');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      chatsFile = File('${dir.path}/td_chats.json');
      await _loadLocalChats();

      _startReceiver();
    } catch (e) {
      setState(() {
        status = 'Ошибка загрузки TDLib: $e';
      });
    }
  }

  void _startReceiver() async {
    final tdlibParams = {
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': './td_db',
      'files_directory': './td_files',
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': true,
      'api_id': REMOVED,
      'REMOVED': 'REMOVED',
      'system_language_code': 'en',
      'device_model': 'Desktop',
      'system_version': 'Linux',
      'application_version': '0.0.1',
      'enable_storage_optimizer': true
    };

    while (true) {
      final ptr = clientReceive(client, 1.0);
      if (ptr.address != 0) {
        final resp = ptr.toDartString();
        try {
          final data = jsonDecode(resp);
          _handleUpdate(data, tdlibParams);
        } catch (e) {
          print('Ошибка парсинга JSON: $e');
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _handleUpdate(Map<String, dynamic> data, Map<String, dynamic> tdlibParams) {
    try {
      final type = data['@type'];

      if (type == 'updateAuthorizationState') {
        final state = data['authorization_state']['@type'];

        if (state == 'authorizationStateWaitTdlibParameters') {
          _send(tdlibParams);
          setState(() => status = 'Отправили параметры TDLib');
        } else if (state == 'authorizationStateWaitPhoneNumber') {
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
          _loadChats();
        } else if (state == 'authorizationStateClosed') {
          setState(() => status = 'Соединение закрыто');
        }
      } else if (type == 'updateNewChat') {
        _addOrUpdateChat(data['chat']);
      } else if (type == 'updateChatLastMessage') {
        _updateChatLastMessage(data['chat_id'], data['last_message']);
      } else if (type == 'updateChatPosition') {
        // Обновление позиции чата в списке
        _loadChats();
      } else if (type == 'updateNewMessage') {
        final message = data['message'];
        if (message == null) return;

        final chatId = message['chat_id'];
        if (chatId == null) return;

        if (selectedChat != null && chatId == selectedChat!.id) {
          setState(() {
            messages.insert(0, message);
          });
        }
        final sender = message['sender_id'];
        if (sender != null && sender['@type'] == 'messageSenderUser') {
          final userId = sender['user_id'];
          _getUserName(userId);
        }
        // Обновляем последнее сообщение в списке чатов
        _updateChatLastMessage(chatId, message);
      } else if (type == 'messages') {
        // Ответ на getChatHistory
        final messagesList = data['messages'];
        if (messagesList != null && messagesList is List && selectedChat != null) {
          setState(() {
            messages = List<Map<String, dynamic>>.from(messagesList.map((m) => m as Map<String, dynamic>));
          });
        }
      } else if (type == 'user') {
        final id = data['id'];
        final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
        setState(() {
          users[id] = name.isEmpty ? 'User$id' : name;
        });
      }

    } catch (e) {
      print('Ошибка обработки обновления: $e');
      print('Данные: $data');
    }
  }
  Future<void> _saveLocalChats() async {
    try {
      final data = chats.map((c) => {
        'id': c.id,
        'title': c.title,
        'lastMessage': c.lastMessage,
      }).toList();
      await chatsFile.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Ошибка сохранения чатов: $e');
    }
  }

  Future<void> _loadLocalChats() async {
    if (await chatsFile.exists()) {
      try {
        final jsonStr = await chatsFile.readAsString();
        final data = jsonDecode(jsonStr);
        final loaded = (data as List)
            .map((c) => Chat(
          id: c['id'],
          title: c['title'],
          lastMessage: c['lastMessage'],
        ))
            .toList();
        setState(() {
          chats = loaded;
          if (chats.isNotEmpty) {
            appState = AppState.chatList;
            status = 'Загружено локально (${chats.length} чатов)';
          }
        });
      } catch (e) {
        print('Ошибка загрузки чатов: $e');
      }
    }
  }

  void _send(Map<String, dynamic> obj) {
    final jsonStr = jsonEncode(obj);
    final ptr = jsonStr.toNativeUtf8();
    clientSend(client, ptr);
    malloc.free(ptr);
  }

  void _sendPhone(String phone) {
    phoneNumber = phone;
    _send({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phone,
    });
  }

  void _sendCode(String code) {
    _send({
      '@type': 'checkAuthenticationCode',
      'code': code,
    });
  }

  void _sendPassword(String password) {
    _send({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  void _loadChats() {
    _send({
      '@type': 'getChats',
      'limit': 5,
    });
  }

  void _getUserName(int userId) {
    if (users.containsKey(userId)) return;
    _send({
      '@type': 'getUser',
      'user_id': userId
    });
  }

  void _addOrUpdateChat(Map<String, dynamic> chatData) {
    try {
      final id = chatData['id'];
      if (id == null) return;

      final title = chatData['title'] ?? 'Без названия';
      String lastMsg = 'Нет сообщений';

      if (chatData['last_message'] != null) {
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
        final chat = Chat(id: id, title: title, lastMessage: lastMsg);
        if (index >= 0) {
          chats[index] = chat;
        } else {
          chats.add(chat);
        }
        // Сортируем чаты по времени последнего сообщения
        if (chats.length > 1) {
          chats.sort((a, b) => b.id.compareTo(a.id));
        }
      });
      _saveLocalChats();
    } catch (e) {
      print('Ошибка при добавлении чата: $e');
    }
  }

  void _updateChatLastMessage(int chatId, Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return;

    try {
      String lastMsg = 'Сообщение';
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
          );
          // Перемещаем чат наверх
          final chat = chats.removeAt(index);
          chats.insert(0, chat);
        }
      });
      _saveLocalChats();
    } catch (e) {
      print('Ошибка при обновлении сообщения чата: $e');
    }
  }

  void _openChat(Chat chat) {
    setState(() {
      selectedChat = chat;
      appState = AppState.chat;
      messages = [];
    });

    try {
      _send({
        '@type': 'getChatHistory',
        'chat_id': chat.id,
        'from_message_id': 0,
        'limit': 50,
        'offset': -10,
        'only_local': false,
      });
    } catch (e) {
      print('Ошибка при загрузке истории чата: $e');
    }
  }

  void _sendMessage(String text) {
    if (selectedChat == null || text.isEmpty) return;
    _send({
      '@type': 'sendMessage',
      'chat_id': selectedChat!.id,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text}
      }
    });
  }

  void _backToChatList() {
    setState(() {
      appState = AppState.chatList;
      selectedChat = null;
      messages = [];
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
        return 'TDLib Login';
      case AppState.chatList:
        return 'Чаты';
      case AppState.chat:
        return selectedChat?.title ?? 'Чат';
    }
  }

  Widget _buildBody() {
    switch (appState) {
      case AppState.loading:
      case AppState.waitingPhone:
      case AppState.waitingCode:
      case AppState.waitingPassword:
        return _buildAuthScreen();
      case AppState.chatList:
        return _buildChatListScreen();
      case AppState.chat:
        return _buildChatScreen();
    }
  }

  Widget _buildAuthScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(status, style: TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          if (appState == AppState.waitingPhone)
            TextField(
              decoration: InputDecoration(
                labelText: 'Номер телефона',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              onSubmitted: _sendPhone,
            ),
          if (appState == AppState.waitingCode)
            TextField(
              decoration: InputDecoration(
                labelText: 'Код из Telegram',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: _sendCode,
            ),
          if (appState == AppState.waitingPassword)
            TextField(
              decoration: InputDecoration(
                labelText: 'Пароль 2FA',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onSubmitted: _sendPassword,
            ),
        ],
      ),
    );
  }

  Widget _buildChatListScreen() {
    if (chats.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              (chat.title.isNotEmpty ? chat.title[0] : '?').toUpperCase(),
            ),
          ),
          title: Text(chat.title),
          subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _openChat(chat),
        );
      },
    );
  }

  Widget _buildChatScreen() {
    final messageController = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(child: Text('Загрузка сообщений...'))
              : ListView.builder(
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              String text = '';
              final content = msg['content'];

              if (content != null) {
                if (content['@type'] == 'messageText') {
                  text = content['text']?['text'] ?? '';
                } else {
                  text = '[${content['@type']?.toString().replaceAll('message', '')}]';
                }
              }

              final isOutgoing = msg['is_outgoing'] ?? false;

              if (text.isEmpty) return SizedBox.shrink();

              return Align(
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
                          users[(msg['sender_id']?['user_id'] ?? 0)] ?? '...',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                      Text(text),
                    ],
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
                    _sendMessage(text);
                    messageController.clear();
                  },
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  _sendMessage(messageController.text);
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
    clientDestroy(client);
    super.dispose();
  }
}