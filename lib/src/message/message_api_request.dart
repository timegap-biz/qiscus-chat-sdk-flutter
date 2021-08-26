part of qiscus_chat_sdk.usecase.message;

class SendMessageRequest extends IApiRequest<Message> {
  final int? roomId;
  final String? message;
  final String type;
  final String? uniqueId;
  final Map<String, dynamic>? extras;
  final Map<String, dynamic>? payload;

  SendMessageRequest({
    required this.roomId,
    required this.message,
    this.uniqueId,
    this.type = 'text',
    this.extras,
    this.payload,
  });

  @override
  String get url => 'post_comment';
  @override
  IRequestMethod get method => IRequestMethod.post;
  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'topic_id': roomId.toString(),
        'comment': message,
        'type': type,
        'unique_temp_id': uniqueId,
        'payload': payload,
        'extras': extras,
      };

  @override
  Message format(Map<String, dynamic> json) {
    var data = json['results']['comment'] as Map<String, dynamic>;
    return Message.fromJson(data);
  }
}

class UpdateMessageRequest extends IApiRequest<Message> {
  UpdateMessageRequest({required this.message});
  final QMessage message;

  @override
  IRequestMethod get method => IRequestMethod.post;

  @override
  String get url => 'update_message';

  @override
  Message format(Map<String, dynamic> json) {
    var data = json['results']['comment'] as Map<String, dynamic>;
    return Message.fromJson(data);
  }

  @override
  Map<String, dynamic> get body {
    var m = message;
    var data = <String, dynamic>{
      'room_id': m.chatRoomId,
      'unique_id': m.uniqueId,
      'comment': m.text,
    };
    if (m.payload != null) {
      data['payload'] = m.payload;
    }
    if (m.extras != null) {
      data['extras'] = m.extras;
    }
    return data;
  }
}

class GetMessagesRequest extends IApiRequest<List<Message>> {
  final int? roomId;
  final int? lastMessageId;
  final int? limit;
  final bool? after;

  GetMessagesRequest({
    required this.roomId,
    required this.lastMessageId,
    this.after = false,
    this.limit = 20,
  });

  @override
  String get url => 'load_comments';
  @override
  IRequestMethod get method => IRequestMethod.get;
  @override
  Map<String, dynamic> get params => <String, dynamic>{
        'topic_id': roomId,
        'last_comment_id': lastMessageId,
        'after': after,
        'limit': limit,
      };

  @override
  List<Message> format(Map<String, dynamic> json) {
    var data = (json['results']['comments'] as List) //
        .cast<Map<String, dynamic>>();

    return data.map((it) => Message.fromJson(it)).toList();
  }
}

class UpdateMessageStatusRequest extends IApiRequest<void> {
  final int? roomId;
  final int? lastReadId;
  final int? lastDeliveredId;

  UpdateMessageStatusRequest({
    required this.roomId,
    this.lastReadId,
    this.lastDeliveredId,
  });

  @override
  String get url => 'update_comment_status';
  @override
  IRequestMethod get method => IRequestMethod.post;
  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'room_id': roomId.toString(),
        'last_comment_read_id': lastReadId?.toString(),
        'last_comment_received_id': lastDeliveredId?.toString(),
      };

  @override
  void format(json) {
    return null;
  }
}

UpdateMessageStatusRequest markMessageAsRead({
  required int roomId,
  required int messageId,
}) {
  return UpdateMessageStatusRequest(
    roomId: roomId,
    lastReadId: messageId,
  );
}

UpdateMessageStatusRequest markMessageAsDelivered({
  required int roomId,
  required int messageId,
}) {
  return UpdateMessageStatusRequest(
    roomId: roomId,
    lastDeliveredId: messageId,
  );
}

class DeleteMessagesRequest extends IApiRequest<List<Message>> {
  final List<String> uniqueIds;
  final bool isHardDelete;
  final bool isForEveryone;

  DeleteMessagesRequest({
    required this.uniqueIds,
    this.isForEveryone = true,
    this.isHardDelete = true,
  });

  @override
  String get url => 'delete_messages';
  @override
  IRequestMethod get method => IRequestMethod.delete;
  @override
  Map<String, dynamic> get params => <String, dynamic>{
        'unique_ids': uniqueIds,
        'is_hard_delete': isHardDelete,
        'is_delete_for_everyone': isForEveryone,
      };

  @override
  List<Message> format(Map<String, dynamic> json) {
    var data = (json['results']['comments'] as List) //
        .cast<Map<String, dynamic>>();

    return data.map((m) => Message.fromJson(m)).toList();
  }
}

class FileListRequest extends IApiRequest<Iterable<QMessage>> {
  const FileListRequest({
    this.roomIds,
    this.fileType,
    this.sender,
    this.query,
    this.includeExtensions = const [],
    this.excludeExtensions = const [],
    this.page,
    this.limit,
  });

  final String? query;
  final String? sender;
  final List<int>? roomIds;
  final String? fileType;
  final List<String>? includeExtensions;
  final List<String>? excludeExtensions;
  final int? page;
  final int? limit;

  @override
  IRequestMethod get method => IRequestMethod.post;
  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'query': query,
        'room_ids': roomIds?.map((it) => it.toString()).toList(),
        'sender': sender,
        'file_type': fileType,
        'include_extensions': includeExtensions,
        'exclude_extensions': excludeExtensions,
        'page': page,
        'limit': limit,
      };

  @override
  Iterable<QMessage> format(Map<String, dynamic> json) sync* {
    var results = json['results'] as Map<String, dynamic>;
    var comments = (results['comments'] as List).cast<Map<String, dynamic>>();

    for (var comment in comments) {
      yield Message.fromJson(comment).toModel();
    }
  }

  @override
  String get url => 'file_list';
}
