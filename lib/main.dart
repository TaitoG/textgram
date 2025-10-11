import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'mtproto_dh.dart';
import 'parse_respq.dart';
import 'mtproto_reqpq.dart';

void main() async {
  await reqpq();
}