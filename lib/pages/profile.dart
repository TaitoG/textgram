// pages/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_controller.dart';
import '../models/models.dart';
import '../widgets/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final Chat chat;
  const ProfileScreen({Key? key, required this.chat}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? fullChatInfo;
  Map<String, dynamic>? userInfo;
  Map<String, dynamic>? supergroupInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullInfo();
  }

  void _loadFullInfo() async {
    final app = Provider.of<AppController>(context, listen: false);

    if (widget.chat.id > 0) {
      app.tdLibService.send({
        '@type': 'getUser',
        'user_id': widget.chat.id,
      });
    } else {
      app.tdLibService.send({
        '@type': 'getChat',
        'chat_id': widget.chat.id,
      });

      if (widget.chat.id.toString().startsWith('-100')) {
        final supergroupId = (-widget.chat.id - 1000000000000);
        app.tdLibService.send({
          '@type': 'getSupergroup',
          'supergroup_id': supergroupId,
        });
        app.tdLibService.send({
          '@type': 'getSupergroupFullInfo',
          'supergroup_id': supergroupId,
        });
      }
    }

    final subscription = app.tdLibService.startReceiver().listen((data) {
      if (!mounted) return;

      final type = data['@type'];

      if (type == 'user' && data['id'] == widget.chat.id) {
        setState(() {
          userInfo = data;
          isLoading = false;
        });
      } else if (type == 'chat' && data['id'] == widget.chat.id) {
        setState(() {
          fullChatInfo = data;
        });
      } else if (type == 'supergroup') {
        setState(() {
          supergroupInfo = data;
          isLoading = false;
        });
      } else if (type == 'supergroupFullInfo') {
        setState(() {
          supergroupInfo = {...?supergroupInfo, 'full_info': data};
        });
      }
    });

    Future.delayed(Duration(seconds: 5), () {
      subscription.cancel();
    });

    await Future.delayed(Duration(milliseconds: 800));
    if (mounted && isLoading) {
      setState(() => isLoading = false);
    }
  }

  String _getChatType() {
    if (widget.chat.id > 0) return 'Private Chat';
    if (widget.chat.id.toString().startsWith('-100')) {
      if (supergroupInfo != null) {
        final isChannel = supergroupInfo!['is_channel'] ?? false;
        return isChannel ? 'Channel' : 'Supergroup';
      }
      return 'Supergroup';
    }
    return 'Group';
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Unknown';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        color: terminalBackground,
        child: Center(
          child: Text(
            '> LOADING PROFILE..._',
            style: TextStyle(
              fontFamily: 'JetBrains',
              fontSize: 14,
              color: terminalGreen,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    return Container(
      color: terminalBackground,
      child: Stack(
        children: [
          // Scanline effect
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: List.generate(
                      50,
                          (index) => index.isEven ? scanlineColor : Colors.transparent,
                    ),
                    stops: List.generate(50, (index) => index / 50),
                  ),
                ),
              ),
            ),
          ),
          // Content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 16),

                // MAIN INFO TABLE
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: terminalGreen, width: 2),
                  ),
                  child: Column(
                    children: [
                      _row('> Type', _getChatType()),
                      _divider(),
                      _row('> ID', widget.chat.id.toString()),

                      // USER INFO
                      if (userInfo != null) ...[
                        if (userInfo!['username']?.toString().isNotEmpty ?? false) ...[
                          _divider(),
                          _row('> Username', '@${userInfo!['username']}'),
                        ],
                        if (userInfo!['phone_number']?.toString().isNotEmpty ?? false) ...[
                          _divider(),
                          _row('> Phone', '+${userInfo!['phone_number']}'),
                        ],
                        if (userInfo!['status'] != null) ...[
                          _divider(),
                          _row('> Status', _getUserStatus(userInfo!['status'])),
                        ],
                      ],

                      // SUPERGROUP/CHANNEL INFO
                      if (supergroupInfo != null) ...[
                        if (supergroupInfo!['username']?.toString().isNotEmpty ?? false) ...[
                          _divider(),
                          _row('> Username', '@${supergroupInfo!['username']}'),
                        ],
                        if (supergroupInfo!['member_count'] != null) ...[
                          _divider(),
                          _row('> Members', _formatNumber(supergroupInfo!['member_count'])),
                        ],
                        if (supergroupInfo!['full_info']?['description']?.toString().isNotEmpty ?? false) ...[
                          _divider(),
                          _row('> About', supergroupInfo!['full_info']['description']),
                        ],
                      ],

                      // LAST MESSAGE
                      if (widget.chat.lastMessage.isNotEmpty) ...[
                        _divider(),
                        _row('> Last', widget.chat.lastMessage),
                        _divider(),
                        _row('> Time', _formatTimestamp(widget.chat.lastMessageDate)),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // SEND MESSAGE BUTTON
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Consumer<AppController>(
                    builder: (context, app, child) {
                      return GestureDetector(
                        onTap: () => app.openChat(widget.chat),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: terminalGreen, width: 2),
                            color: terminalGreen.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Text(
                              '[ ✉ SEND MESSAGE ]',
                              style: TextStyle(
                                fontFamily: 'JetBrains',
                                fontSize: 14,
                                color: terminalGreen,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getUserStatus(Map<String, dynamic> status) {
    final type = status['@type'];
    switch (type) {
      case 'userStatusOnline':
        return 'Online';
      case 'userStatusOffline':
        final wasOnline = status['was_online'];
        if (wasOnline != null) {
          final time = DateTime.fromMillisecondsSinceEpoch(wasOnline * 1000);
          final now = DateTime.now();
          final diff = now.difference(time);

          if (diff.inMinutes < 1) return 'Just now';
          if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
          if (diff.inHours < 24) return '${diff.inHours}h ago';
          if (diff.inDays < 7) return '${diff.inDays}d ago';
          return 'Long time ago';
        }
        return 'Offline';
      case 'userStatusRecently':
        return 'Recently';
      case 'userStatusLastWeek':
        return 'Last week';
      case 'userStatusLastMonth':
        return 'Last month';
      default:
        return 'Unknown';
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.split(' ')[0],
            style: TextStyle(
              fontFamily: 'JetBrains',
              color: terminalGreen,
              fontSize: 13,
            ),
          ),
          SizedBox(width: 8),
          Text(
            label.split(' ')[1],
            style: TextStyle(
              fontFamily: 'JetBrains',
              color: terminalDarkGreen,
              fontSize: 13,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrains',
                color: terminalGreen,
                fontSize: 13,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: terminalDarkGreen.withOpacity(0.3),
    );
  }
}