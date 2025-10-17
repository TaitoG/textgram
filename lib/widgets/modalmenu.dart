import 'package:flutter/material.dart';
import 'app_theme.dart';

class MessageMenu {
  static void show(BuildContext context, List<MenuAction> actions, {String title = '[ ACTIONS ]'}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: terminalBackground,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: terminalDarkGreen, width: 2)),
              ),
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'JetBrains',
                    fontSize: 14,
                    color: terminalGreen,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            ...actions.map((action) => ListTile(
              leading: Text(
                action.icon,
                style: TextStyle(fontFamily: 'JetBrains', color: action.color, fontSize: 18),
              ),
              title: Text(
                action.label,
                style: TextStyle(fontFamily: 'JetBrains', color: action.color, letterSpacing: 1.5),
              ),
              onTap: () => action.onTap(context),
            )),
          ],
        ),
      ),
    );
  }
}

class MenuAction {
  final String icon;
  final String label;
  final Color color;
  final Function(BuildContext) onTap;

  MenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}