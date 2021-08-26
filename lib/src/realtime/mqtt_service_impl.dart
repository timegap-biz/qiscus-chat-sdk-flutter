part of qiscus_chat_sdk.usecase.realtime;

class MessageDeleted {
  final String? messageUniqueId;
  final int? roomId;

  MessageDeleted({
    this.messageUniqueId,
    this.roomId,
  });

  MessageDeletedEvent toResponse() => MessageDeletedEvent(
        roomId: roomId,
        messageUniqueId: messageUniqueId,
      );
}

class MqttServiceImpl implements IRealtimeService {
  final Dio _dio;
  final Logger _logger;
  final MqttClient Function() _getClient;
  MqttClient? __mqtt;
  StreamSubscription<MqttReceivedMessage<MqttMessage>>? _logSubscription;

  final Storage _s;
  final _subscriptions = <String?, int>{};
  final List<String?> _subscriptionBuffer = [];
  final List<String> _unsubscriptionBuffer = [];
  bool _isForceClosed = false;

  MqttServiceImpl(this._getClient, this._s, this._logger, this._dio) {
    _mqtt.onConnected = () {
      log('@mqtt connected to ${_mqtt.server}:${_mqtt.port}');
    };
    _mqtt.onDisconnected = () {
      log('@mqtt.disconnected(${_mqtt.connectionStatus})');
      _onDisconnected(_mqtt.connectionStatus);
    };
    _mqtt.onSubscribed = (topic) {
      _subscriptions.update(topic, (it) => it + 1, ifAbsent: () => 1);
      log('@mqtt.subscribed($topic)');
    };
    _mqtt.onUnsubscribed = (topic) {
      _subscriptions.update(topic, (it) => it - 1, ifAbsent: () => 0);
      _subscriptions.removeWhere((it, count) => it == topic && count <= 0);
      log('@mqtt-unsubscribed($topic)');
    };
    _mqtt.onSubscribeFail = (topic) {
      log('@mqtt.subscribe-fail($topic)');
    };
  }

  @override
  bool get isConnected {
    var mqttConnected = _mqtt.connectionStatus?.state == MqttConnectionState.connected;

    return mqttConnected || _isForceClosed;
  }

  Stream<bool> get isConnected$ {
    var timer = const Duration(seconds: 1);
    return Stream.periodic(timer, (_) => isConnected).distinct();
  }

  Future<bool> get _isConnected {
    if (_s.isRealtimeEnabled!) {
      var timer = const Duration(milliseconds: 10);
      return Stream.periodic(timer, (_) => _mqtt.isConnected)
          .distinct()
          .firstWhere((it) => it == true);
    } else {
      return Future<bool>.value(false);
    }
  }

  MqttClient get _mqtt => __mqtt ??= _getClient();

  @override
  Future<void> connect() async {
    try {
      log('connecting to mqtt (${_mqtt.server})');
      var status = await _mqtt.connect();
      log('connected to mqtt: $status');
    } on NoConnectionException catch (error) {
      log('got mqtt error while connecting: $error');
      log('-> server: ${_mqtt.server}');
      log('-> port: ${_mqtt.port}');
      log('-> clientId: ${_mqtt.clientIdentifier}');
      log('-> status: ${_mqtt.connectionStatus}');
      log('-> appId: ${_s.appId}');
    }

    var stream = _restartSubscription(() => _mqtt.updates);
    _logSubscription = stream.expand((it) => it).listen((data) {
      if (_logger.level == QLogLevel.verbose) {
        log('@mqtt.message(topic=(${data.topic}), payload=(${data.payload}))');
      } else {
        log('@mqtt.message(topic=(${data.topic}))');
      }
    });
  }

  @override
  Future<void> end() async {
    await _logSubscription?.cancel();
    for (var subs in _subscriptions.entries) {
      var status = _mqtt.getSubscriptionsStatus(subs.key!);
      if (status == MqttSubscriptionStatus.active) {
        _mqtt.unsubscribe(subs.key!);
      }
    }

    _subscriptions.clear();
    _mqtt.disconnect();
  }

  void log(String str) => _logger.log('MqttServiceImpl::- $str');

  @override
  Stream<bool> onConnected() async* {
    yield* Stream<void>.periodic(const Duration(milliseconds: 300))
        .asyncMap((_) =>
            _mqtt.connectionStatus!.state == MqttConnectionState.connected)
        .distinct()
        .where((it) => it == true)
        .asBroadcastStream();
  }

  @override
  Stream<bool> onDisconnected() async* {
    yield* Stream<void>.periodic(const Duration(milliseconds: 300))
        .asyncMap((_) =>
            _mqtt.connectionStatus!.state == MqttConnectionState.disconnected)
        .distinct()
        .where((it) => it == true && _s.isRealtimeEnabled!)
        .asBroadcastStream();
  }

  @override
  Stream<bool> onReconnecting() async* {
    yield* Stream<void>.periodic(const Duration(milliseconds: 300))
        .asyncMap((_) =>
            _mqtt.connectionStatus!.state == MqttConnectionState.disconnecting)
        .distinct()
        .where((it) => it == true)
        .asBroadcastStream();
  }

  @override
  Future<void> publishCustomEvent({
    int? roomId,
    Map<String, dynamic>? payload,
  }) async {
    await _mqtt.sendEvent(
      MqttCustomEvent(roomId: roomId, payload: payload),
    );
  }

  @override
  Future<void> publishPresence({
    bool? isOnline,
    DateTime? lastSeen,
    String? userId,
  }) {
    return _mqtt.sendEvent(
      MqttUserPresence(userId: userId, lastSeen: lastSeen, isOnline: isOnline),
    );
  }

  @override
  Future<void> publishTyping({
    bool? isTyping,
    String? userId,
    int? roomId,
  }) {
    return _mqtt.sendEvent(MqttUserTyping(
      roomId: roomId.toString(),
      userId: userId,
      isTyping: isTyping,
    ));
  }

  @override
  Future<void> subscribe(String? topic) async {
    log('mqtt.subscribe($topic)');
    _subscriptionBuffer.add(topic);

    await _isConnected;
    while (_subscriptionBuffer.isNotEmpty) {
      var topic = _subscriptionBuffer.removeAt(0);
      if (topic != null) {
        _mqtt.subscribe$(topic);
      }
    }
  }

  Stream<O> _restartSubscription<O>(Stream<O>? Function() source) {
    var stream = isConnected$;

    StreamSubscription<bool>? subs0;
    StreamSubscription<O>? subs1;
    late StreamController<O> controller;

    controller = StreamController<O>(
      onListen: () {
        subs0 = stream.listen((isConnected) {
          if (!isConnected) {
            subs1?.cancel();
          } else {
            subs1 = source()!.listen((data) => controller.sink.add(data));
          }
        });
      },
      onPause: () {
        subs0?.pause();
        subs1?.pause();
      },
      onResume: () {
        subs0?.resume();
        subs1?.resume();
      },
      onCancel: () {
        subs0?.cancel();
        subs1?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<Tuple2<String, String>> _forTopic(String topic) {
    return _restartSubscription(() => _mqtt.forTopic(topic));
  }

  Stream<O> _onEvent<O>(IMqttReceive<O> event) {
    return _restartSubscription(() => _mqtt.onEvent(event));
  }

  @override
  Stream<Message> subscribeChannelMessage({String? uniqueId}) {
    return _forTopic(TopicBuilder.channelMessageNew(_s.appId, uniqueId))
        .asyncMap((event) {
      // appId/channelId/c;
      var messageData = event.second.toString();
      var messageJson = jsonDecode(messageData) as Map<String, dynamic>;
      return Message.fromJson(messageJson);
    });
  }

  @override
  Stream<CustomEvent> subscribeCustomEvent({int? roomId}) async* {
    yield* _onEvent(MqttCustomEvent(roomId: roomId));
  }

  @override
  Stream<Message> subscribeMessageDeleted() {
    return _onEvent(MqttMessageDeleted(token: _s.token)).map((tuple) {
      return Message(
        id: Option.none(),
        chatRoomId: Option.some(tuple.first),
        uniqueId: Option.some(tuple.second),
      );
    });
  }

  @override
  Stream<Message> subscribeMessageDelivered({int? roomId}) {
    return _forTopic(TopicBuilder.messageDelivered(roomId.toString()))
        .where((it) => int.parse(it.first.split('/')[1]) == roomId)
        .asyncMap((msg) {
      // r/{roomId}/{roomId}/{userId}/d
      // {commentId}:{commentUniqueId}
      var payload = msg.second.toString().split(':');
      var commentId = Option.of(payload[0]);
      var commentUniqueId = Option.of(payload[1]);
      var userId = Option.of(msg.first.split('/')[3]);
      var roomId = Option.of(msg.first.split('/')[1]);

      return Message(
        id: commentId.map((a) => int.parse(a)),
        uniqueId: commentUniqueId,
        sender: Option.some(User(
          id: userId,
        )),
        chatRoomId: roomId.map(int.parse),
      );
    });
  }

  @override
  Stream<Message> subscribeMessageRead({required int? roomId}) async* {
    yield* _onEvent(MqttMessageRead(roomId: roomId.toString()));
  }

  @override
  Stream<Message> subscribeMessageReceived() async* {
    yield* _onEvent(MqttMessageReceived(token: _s.token));
  }

  @override
  Stream<Message> subscribeMessageUpdated() async* {
    yield* _onEvent(MqttMessageUpdated(token: _s.token));
  }

  @override
  Stream<ChatRoom> subscribeRoomCleared() async* {
    yield* _onEvent(MqttRoomCleared(token: _s.token))
        .map((it) => ChatRoom(id: Option.some(it)));
  }

  @override
  Stream<UserPresence> subscribeUserPresence({required String? userId}) async* {
    yield* _onEvent(MqttUserPresence(userId: userId));
  }

  @override
  Stream<Notification> subscribeNotification() async* {
    yield* _onEvent(MqttNotification(token: _s.token));
  }

  @override
  Stream<UserTyping> subscribeUserTyping({int? roomId}) async* {
    yield* _onEvent(MqttUserTyping(roomId: roomId.toString(), userId: '+'));
  }

  @override
  Future<void> synchronize([int? lastMessageId]) async {}

  @override
  Future<void> synchronizeEvent([String? lastEventId]) async {}

  @override
  Future<void> unsubscribe(String topic) async {
    _unsubscriptionBuffer.add(topic);

    await _isConnected;
    while (_unsubscriptionBuffer.isNotEmpty) {
      var topic = _unsubscriptionBuffer.removeAt(0);
      _mqtt.unsubscribe(topic);
    }
  }

  void _onDisconnected(MqttClientConnectionStatus? connectionStatus) async {
    // if forced close connection by calling `closeConnection`
    if (_isForceClosed) {
      log('Mqtt forced disconnection');
      return;
    }

    // if connected state are not disconnected
    if ((_mqtt.connectionStatus?.state ?? false) !=
        MqttConnectionState.disconnected) {
      log('Mqtt disconnected with unknown state: ${connectionStatus!.state}');
      return;
    }

    if (_s.currentUser == null) {
      log('got no user');
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));

    // get a new broker url by calling lb
    var stream = Stream.periodic(
      const Duration(seconds: 2),
      (_) => _mqtt.isConnected,
    );

    // in case of no network connection,
    // we always retry to connect to mqtt server
    await for (var isConnected in stream) {
      if (isConnected) return;

      try {
        var result = await _dio.get<Map<String, dynamic>>(_s.brokerLbUrl!);
        var data = result.data!['data'] as Map<String, dynamic>;
        var url = data['url'] as String?;
        _s.brokerUrl = url;

        log('reconnecting to ${_s.brokerUrl}');
        _mqtt.server = _s.brokerUrl!;
        await _mqtt.connect();

        for (var topic in _subscriptions.keys) {
          var status = _mqtt.getSubscriptionsStatus(topic!);

          if (status != MqttSubscriptionStatus.active) {
            await subscribe(topic);
          }
        }
      } on NoConnectionException catch (err) {
        log('got mqtt error: $err');
        log('-> server: ${_mqtt.server}');
        log('-> port: ${_mqtt.port}');
        log('-> clientId: ${_mqtt.clientIdentifier}');
        log('-> appId: ${_s.appId}');
      } catch (e) {
        log('got error when reconnecting mqtt: $e');
      }
    }
  }

  @override
  Future<bool> closeConnection() async {
    try {
      _isForceClosed = true;
      _mqtt.autoReconnect = false;
      await end();
    } catch (_) {
      return false;
    }

    return true;
  }

  @override
  Future<bool> openConnection() async {
    try {
      _isForceClosed = false;
      _mqtt.autoReconnect = true;
      await connect();
    } catch (_) {
      return false;
    }

    return true;
  }
}

class Notification extends Union2Impl<MessageDeleted, RoomCleared> {
  static final Doublet<MessageDeleted, RoomCleared> _factory =
      const Doublet<MessageDeleted, RoomCleared>();

  factory Notification.message_deleted({
    int? roomId,
    String? messageUniqueId,
  }) {
    return Notification._(_factory.first(MessageDeleted(
      roomId: roomId,
      messageUniqueId: messageUniqueId,
    )));
  }

  factory Notification.room_cleared({
    int? roomId,
  }) {
    return Notification._(_factory.second(RoomCleared(
      roomId: roomId,
    )));
  }

  Notification._(Union2<MessageDeleted, RoomCleared> union) : super(union);

  @override
  String toString() {
    return join(
      (data) => 'Notification.message_deleted('
          'roomId: ${data.roomId}, '
          'messageUniqueId: ${data.messageUniqueId})',
      (data) => 'Notification.room_cleared(roomId: ${data.roomId})',
    );
  }
}

class RoomCleared {
  final int? roomId;

  RoomCleared({
    this.roomId,
  });

  ChatRoom toResponse() => ChatRoom(id: Option.some(roomId));
}
