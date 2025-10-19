// widgets/app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:textgram/core/app_controller.dart';
import 'package:textgram/models/models.dart';
import 'app_theme.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final AppController app;

  const AppBarWidget({Key? key, required this.app}) : super(key: key);

  void _handleLogout(BuildContext context) {
    final tdLibService = Provider.of<AppController>(context, listen: false).tdLibService;
    tdLibService.logOut();
    app.appState = AppState.waitingPhone;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Text(
            '> ',
            style: TextStyle(
              fontFamily: 'JetBrains',
              fontSize: 18,
              color: terminalGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              app.getTitle().toUpperCase(),
              style: TextStyle(
                fontFamily: 'JetBrains',
                fontSize: 16,
                color: terminalGreen,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
      leading: (app.appState == AppState.chat || app.appState == AppState.profile)
          ? IconButton(
        icon: Text(
          '<',
          style: TextStyle(
            fontFamily: 'JetBrains',
            fontSize: 24,
            color: terminalGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: app.backToChatList,
      )
          : null,
      actions: [
        if (app.appState == AppState.chatList)
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => _handleLogout(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: terminalGreen.withOpacity(0.5)),
                ),
              ),
              child: Text(
                'LOGOUT',
                style: TextStyle(
                  fontFamily: 'JetBrains',
                  fontSize: 12,
                  color: terminalGreen,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: Container(height: 2, color: Color(0xFF00AA2B)),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 2);
}