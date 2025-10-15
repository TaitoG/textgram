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
  final int lastMessageDate;

  Chat({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastMessageDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lastMessage': lastMessage,
      'lastMessageDate': lastMessageDate,
    };
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      title: json['title'],
      lastMessage: json['lastMessage'],
      lastMessageDate: json['lastMessageDate'] ?? 0,
    );
  }
}