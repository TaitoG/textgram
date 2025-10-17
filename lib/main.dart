import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_controller.dart';
import 'widgets/app_theme.dart';
import 'widgets/app_bar.dart';
import 'widgets/app_body.dart';

void main() {
  runApp(TextGram());
}

class TextGram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController(),
      child: MaterialApp(
        theme: appTheme(),
        home: Consumer<AppController>(
          builder: (context, app, child) => Scaffold(
            appBar: AppBarWidget(app: app),
            body: AppBodyWidget(app: app),
          ),
        ),
      ),
    );
  }
}