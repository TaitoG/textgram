// td_client.dart
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:async';
import 'package:ffi/ffi.dart';

typedef TdJsonClientCreateNative = Pointer<Void> Function();
typedef TdJsonClientSendNative = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef TdJsonClientReceiveNative = Pointer<Utf8> Function(Pointer<Void>, Double);
typedef TdJsonClientDestroyNative = Void Function(Pointer<Void>);
typedef TdJsonClientExecuteNative = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);

typedef TdJsonClientCreate = Pointer<Void> Function();
typedef TdJsonClientSend = void Function(Pointer<Void>, Pointer<Utf8>);
typedef TdJsonClientReceive = Pointer<Utf8> Function(Pointer<Void>, double);
typedef TdJsonClientDestroy = void Function(Pointer<Void>);
typedef TdJsonClientExecute = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);

class TdLibService {
  late DynamicLibrary tdlib;
  late Pointer<Void> client;
  late TdJsonClientSend clientSend;
  late TdJsonClientReceive clientReceive;
  late TdJsonClientDestroy clientDestroy;
  late TdJsonClientExecute clientExecute;

  StreamController<Map<String, dynamic>>? _updateController;
  bool _isRunning = false;

  bool initialize() {
    try {
      tdlib = DynamicLibrary.open('tdlib/libtdjson.so');
      final clientCreate = tdlib.lookupFunction<TdJsonClientCreateNative, TdJsonClientCreate>('td_json_client_create');
      clientSend = tdlib.lookupFunction<TdJsonClientSendNative, TdJsonClientSend>('td_json_client_send');
      clientReceive = tdlib.lookupFunction<TdJsonClientReceiveNative, TdJsonClientReceive>('td_json_client_receive');
      clientDestroy = tdlib.lookupFunction<TdJsonClientDestroyNative, TdJsonClientDestroy>('td_json_client_destroy');
      clientExecute = tdlib.lookupFunction<TdJsonClientExecuteNative, TdJsonClientExecute>('td_json_client_execute');

      client = clientCreate();
      return client.address != 0;
    } catch (e) {
      print('Ошибка инициализации TDLib: $e');
      return false;
    }
  }

  void send(Map<String, dynamic> obj) {
    if (client.address == 0) {
      print('⚠️ Попытка отправки в неинициализированный клиент');
      return;
    }

    Pointer<Utf8>? ptr;
    try {
      final jsonStr = jsonEncode(obj);
      ptr = jsonStr.toNativeUtf8();
      clientSend(client, ptr);
    } catch (e) {
      print('Ошибка отправки запроса: $e');
    } finally {
      if (ptr != null) {
        malloc.free(ptr);
      }
    }
  }

  String? receive(double timeout) {
    if (client.address == 0) return null;

    try {
      final ptr = clientReceive(client, timeout);
      if (ptr.address != 0) {
        final result = ptr.toDartString();
        return result;
      }
    } catch (e) {
      print('Ошибка получения данных: $e');
    }
    return null;
  }

  void destroy() {
    _isRunning = false;
    _updateController?.close();

    if (client.address != 0) {
      try {
        clientDestroy(client);
      } catch (e) {
        print('Ошибка при уничтожении клиента: $e');
      }
    }
  }

  Stream<Map<String, dynamic>> startReceiver() {
    if (_updateController != null && !_updateController!.isClosed) {
      return _updateController!.stream;
    }

    _updateController = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () {
        _isRunning = false;
      },
    );

    _isRunning = true;
    _receiveLoop();

    return _updateController!.stream;
  }

  void _receiveLoop() async {
    const timeout = 0.5;

    while (_isRunning && client.address != 0) {
      try {
        final resp = receive(timeout);
        if (resp != null && resp.isNotEmpty) {
          try {
            final data = jsonDecode(resp);
            if (data is Map<String, dynamic>) {
              _updateController?.add(data);
            }
          } catch (e) {
            print('Ошибка парсинга JSON: $e');
            print('Проблемные данные: ${resp.substring(0, resp.length > 200 ? 200 : resp.length)}...');
          }
        }

        await Future.delayed(const Duration(milliseconds: 10));
      } catch (e) {
        print('Ошибка в цикле получения: $e');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    print('🛑 Цикл получения остановлен');
  }

  void stopReceiver() {
    _isRunning = false;
    _updateController?.close();
    _updateController = null;
  }

  Map<String, dynamic> getTdlibParameters() {
    return {
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': true,
      'api_id': REMOVED,
      'REMOVED': 'REMOVED',
      'system_language_code': 'en',
      'device_model': 'Textgram',
      'system_version': 'Android',
      'application_version': '0.0.4',
      'enable_storage_optimizer': true
    };
  }

  void setLogVerbLvl(int lvl) {
    send({
      '@type': 'setLogVerbosityLevel',
      'new_verbosity_level': lvl
    });
  }

  // AUTH
  void sendPhoneNumber(String phone) {
    send({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phone,
    });
  }

  void sendCode(String code) {
    send({
      '@type': 'checkAuthenticationCode',
      'code': code,
    });
  }

  void sendPassword(String password) {
    send({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  void logOut() {
    send({
      '@type': 'logOut'
    });
  }

  // CHATS
  void loadChat(int chatId) {
    send({
      '@type': 'getChat',
      'chat_id': chatId
    });
  }

  void loadChats({int limit = 20, int offsetOrder = 9223372036854775807, int offsetChatId = 0}) {
    send({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': limit,
    });
  }

  void loadChatHistory(int chatId, {int fromMessageId = 0, int limit = 50, int offset = 0}) {
    send({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': fromMessageId,
      'limit': limit,
      'offset': offset,
      'only_local': false,
    });
  }

  void joinChat(int chatId) {
    send({
      '@type': 'joinChat',
      'chat_id': chatId
    });
  }

  void joinChatByLink(String url) {
    send({
      '@type': 'joinChatByInviteLink',
      'invite_link': url
    });
  }

  void leaveChat(int chatId) {
    send({
      '@type': 'leaveChat',
      'chat_id': chatId
    });
  }

  void deleteChat(int chatId) {
    send({
      '@type': 'deleteChat',
      'chat_id': chatId
    });
  }

  void getMember(int chatId, int userId) {
    send({
      '@type': 'getChatMember',
      'chat_id': chatId,
      'member_id': {
        '@type': 'messageSenderUser',
        'user_id': userId
      }
    });
  }

  // MESSAGES
  void sendMessage(int chatId, String text, {int? replyToMessageId}) {
    final messageData = {
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text}
      }
    };

    if (replyToMessageId != null) {
      messageData['reply_to'] = {
        '@type': 'inputMessageReplyToMessage',
        'message_id': replyToMessageId,
      };
    }

    send(messageData);
  }

  void loadMessage(int chatId, int messageId) {
    send({
      '@type': 'getMessage',
      'chat_id': chatId,
      'message_id': messageId,
    });
  }

  void deleteMsg(int chatId, List<int> msgIds, {bool revoke = true}) {
    if (msgIds.isEmpty) return;

    send({
      '@type': 'deleteMessages',
      'chat_id': chatId,
      'message_ids': msgIds,
      'revoke': revoke
    });
  }

  void editMsg(int chatId, int msgId, String text) {
    send({
      '@type': 'editMessageText',
      'chat_id': chatId,
      'message_id': msgId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {
          '@type': 'formattedText',
          'text': text
        }
      }
    });
  }

  // USERS
  void loadUser(int userId) {
    send({
      '@type': 'getUser',
      'user_id': userId
    });
  }

  Future<void> start() async {
    print('🚀 STARTING TDLib...');
    if (!initialize()) {
      print('❌ TDLib init failed');
      return;
    }
    await Future.delayed(Duration(milliseconds: 100));
    setLogVerbLvl(1);
    final params = getTdlibParameters();
    send(params);
    startReceiver().listen((update) {
    });
  }
}