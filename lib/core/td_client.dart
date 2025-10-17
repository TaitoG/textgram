import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef TdJsonClientCreateNative = Pointer<Void> Function();
typedef TdJsonClientSendNative = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef TdJsonClientReceiveNative = Pointer<Utf8> Function(Pointer<Void>, Double);
typedef TdJsonClientDestroyNative = Void Function(Pointer<Void>);

typedef TdJsonClientCreate = Pointer<Void> Function();
typedef TdJsonClientSend = void Function(Pointer<Void>, Pointer<Utf8>);
typedef TdJsonClientReceive = Pointer<Utf8> Function(Pointer<Void>, double);
typedef TdJsonClientDestroy = void Function(Pointer<Void>);

class TdLibService {
  late DynamicLibrary tdlib;
  late Pointer<Void> client;
  late TdJsonClientSend clientSend;
  late TdJsonClientReceive clientReceive;
  late TdJsonClientDestroy clientDestroy;

  bool initialize() {
    try {
      tdlib = DynamicLibrary.open('tdlib/libtdjson.so');
      final clientCreate = tdlib.lookupFunction<TdJsonClientCreateNative, TdJsonClientCreate>('td_json_client_create');
      clientSend = tdlib.lookupFunction<TdJsonClientSendNative, TdJsonClientSend>('td_json_client_send');
      clientReceive = tdlib.lookupFunction<TdJsonClientReceiveNative, TdJsonClientReceive>('td_json_client_receive');
      clientDestroy = tdlib.lookupFunction<TdJsonClientDestroyNative, TdJsonClientDestroy>('td_json_client_destroy');

      client = clientCreate();
      return client.address != 0;
    } catch (e) {
      print('Ошибка инициализации TDLib: $e');
      return false;
    }
  }

  void send(Map<String, dynamic> obj) {
    final jsonStr = jsonEncode(obj);
    final ptr = jsonStr.toNativeUtf8();
    clientSend(client, ptr);
    malloc.free(ptr);
  }

  String? receive(double timeout) {
    final ptr = clientReceive(client, timeout);
    if (ptr.address != 0) {
      return ptr.toDartString();
    }
    return null;
  }

  void destroy() {
    clientDestroy(client);
  }

  Stream<Map<String, dynamic>> startReceiver() async* {
    while (true) {
      final resp = receive(1.0);
      if (resp != null) {
        try {
          final data = jsonDecode(resp);
          yield data;
        } catch (e) {
          print('Ошибка парсинга JSON: $e');
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Map<String, dynamic> getTdlibParameters() {
    return {
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
      'application_version': '0.0.4',
      'enable_storage_optimizer': true
    };
  }
  void setLogVerbLvl(int lvl) {
    send({'@type': 'setLogVerbosityLevel',
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

  void logOut(){
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

  void loadChats({int limit = 5}) {
    send({
      '@type': 'getChats',
      'limit': limit,
    });
  }

  void loadChatHistory(int chatId, {int limit = 20}) {
    send({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': 0,
      'limit': limit,
      'offset': 0,
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
      'user_id': userId
    });
  }

  // MESSAGES MESSAGES MESSAGES

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
}