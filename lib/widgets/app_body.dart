import 'package:flutter/material.dart';
import '../core/app_controller.dart';

class AppBodyWidget extends StatelessWidget {
  final AppController app;

  const AppBodyWidget({Key? key, required this.app}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return app.buildBody(context);
  }
}