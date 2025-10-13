import 'dart:ffi';
import 'dart:convert';
import 'dart:io';
import 'package:ffi/ffi.dart';

// --- Определяем типы TDLib функций ---
typedef TdJsonClientCreateNative = Pointer<Void> Function();
typedef TdJsonClientSendNative = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef TdJsonClientReceiveNative = Pointer<Utf8> Function(Pointer<Void>, Double);
typedef TdJsonClientDestroyNative = Void Function(Pointer<Void>);

typedef TdJsonClientCreate = Pointer<Void> Function();
typedef TdJsonClientSend = void Function(Pointer<Void>, Pointer<Utf8>);
typedef TdJsonClientReceive = Pointer<Utf8> Function(Pointer<Void>, double);
typedef TdJsonClientDestroy = void Function(Pointer<Void>);

void main() {
  // Загружаем TDLib
  final tdlib = DynamicLibrary.open('tdlib/libtdjson.so');

  // Ищем функции
  final clientCreate = tdlib
      .lookupFunction<TdJsonClientCreateNative, TdJsonClientCreate>('td_json_client_create');
  final clientSend = tdlib
      .lookupFunction<TdJsonClientSendNative, TdJsonClientSend>('td_json_client_send');
  final clientReceive = tdlib
      .lookupFunction<TdJsonClientReceiveNative, TdJsonClientReceive>('td_json_client_receive');
  final clientDestroy = tdlib
      .lookupFunction<TdJsonClientDestroyNative, TdJsonClientDestroy>('td_json_client_destroy');

  // Создаём клиента
  final client = clientCreate();

  // Отправляем команду для проверки
  final request = jsonEncode({
    '@type': 'getOption',
    'name': 'version',
  });

  final requestPtr = request.toNativeUtf8();
  clientSend(client, requestPtr);
  malloc.free(requestPtr);

  // Ждём ответ
  sleep(const Duration(seconds: 1));

  final responsePtr = clientReceive(client, 1.0);
  if (responsePtr.address != 0) {
    final response = responsePtr.toDartString();
    print('✅ TDLib ответил: $response');
  } else {
    print('⚠️ TDLib не ответил (проверь путь к .so)');
  }

  // Освобождаем ресурсы
  clientDestroy(client);
}
