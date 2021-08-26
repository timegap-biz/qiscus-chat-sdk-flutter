part of qiscus_chat_sdk.usecase.user;

class AuthenticateRequest extends IApiRequest<Tuple2<String?, Account>> {
  AuthenticateRequest({
    required this.userId,
    required this.userKey,
    this.name,
    this.avatarUrl,
    this.extras,
  });

  final String? userId, userKey, name, avatarUrl;
  final Map<String, dynamic>? extras;

  @override
  String get url => 'login_or_register';
  @override
  IRequestMethod get method => IRequestMethod.post;
  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'email': userId,
        'password': userKey,
        'username': name,
        'avatar_url': avatarUrl,
        'extras': extras,
      };

  @override
  Tuple2<String?, Account> format(Map<String, dynamic> json) {
    var token = json['results']['user']['token'] as String?;
    var user = Account //
        .fromJson(json['results']['user'] as Map<String, dynamic>);

    return Tuple2(token, user);
  }
}

class AuthenticateWithTokenRequest
    extends IApiRequest<Tuple2<String?, Account>> {
  AuthenticateWithTokenRequest({
    required this.identityToken,
  });

  final String? identityToken;

  @override
  String get url => 'auth/verify_identity_token';
  @override
  IRequestMethod get method => IRequestMethod.post;
  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'identity_token': identityToken,
      };

  @override
  Tuple2<String?, Account> format(Map<String, dynamic> json) {
    var token = json['results']['user']['token'] as String?;
    var user = Account.fromJson(
      json['results']['user'] as Map<String, dynamic>,
    );

    return Tuple2(token, user);
  }
}

class BlockUserRequest extends IApiRequest<User> {
  BlockUserRequest({
    required this.userId,
  });
  final String userId;

  @override
  String get url => 'block_user';
  @override
  IRequestMethod get method => IRequestMethod.post;
  @override
  Map<String, dynamic> get body => <String, dynamic>{'user_email': userId};

  @override
  User format(Map<String, dynamic> json) {
    return User.fromJson(json['results']['user'] as Map<String, dynamic>);
  }
}

class UnblockUserRequest extends IApiRequest<User> {
  UnblockUserRequest({
    required this.userId,
  });
  final String? userId;

  @override
  String get url => 'unblock_user';
  @override
  IRequestMethod get method => IRequestMethod.post;
  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'user_email': userId,
      };

  @override
  User format(Map<String, dynamic> json) {
    return User.fromJson(json['results']['user'] as Map<String, dynamic>);
  }
}

class GetBlockedUsersRequest extends IApiRequest<List<User>> {
  GetBlockedUsersRequest({
    this.page,
    this.limit,
  });
  final int? page;
  final int? limit;

  @override
  String get url => 'get_blocked_users';
  @override
  IRequestMethod get method => IRequestMethod.get;
  @override
  Map<String, dynamic> get params => <String, dynamic>{
        'page': page,
        'limit': limit,
      };

  @override
  List<User> format(Map<String, dynamic> json) {
    var blockedUsers = json['results']['blocked_users'] as List;
    return blockedUsers
        .cast<Map<String, dynamic>>()
        .map((it) => User.fromJson(it))
        .toList();
  }
}

class GetNonceRequest extends IApiRequest<String?> {
  @override
  String get url => 'auth/nonce';
  @override
  IRequestMethod get method => IRequestMethod.post;

  @override
  String? format(Map<String, dynamic> json) {
    return json['results']['nonce'] as String?;
  }
}

class GetUserDataRequest extends IApiRequest<Account> {
  @override
  String get url => 'my_profile';
  @override
  IRequestMethod get method => IRequestMethod.get;

  @override
  Account format(Map<String, dynamic> json) {
    return Account.fromJson(json['results']['user'] as Map<String, dynamic>);
  }
}

class GetUserListRequest extends IApiRequest<List<User>> {
  GetUserListRequest({
    this.query,
    this.page,
    this.limit,
  });
  final String? query;
  final int? page;
  final int? limit;

  @override
  String get url => 'get_user_list';
  @override
  IRequestMethod get method => IRequestMethod.get;
  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'page': page,
        'limit': limit,
        'query': query,
      };

  @override
  List<User> format(Map<String, dynamic> json) {
    var users = json['results']['users'] as List;
    var _users = users
        .cast<Map<String, dynamic>>()
        .map((it) => User.fromJson(it))
        .toList();
    return _users;
  }
}

class SetDeviceTokenRequest extends IApiRequest<bool?> {
  SetDeviceTokenRequest({
    required this.token,
    this.isDevelopment = false,
    this.platform = 'flutter',
  });
  final String? token;
  final bool? isDevelopment;
  final String platform;

  @override
  String get url => 'set_user_device_token';

  @override
  IRequestMethod get method => IRequestMethod.post;

  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'device_token': token,
        'is_development': isDevelopment,
        'device_platform': platform,
      };

  @override
  bool? format(Map<String, dynamic> json) {
    return json['results']['changed'] as bool?;
  }
}

class UnsetDeviceTokenRequest extends IApiRequest<bool?> {
  UnsetDeviceTokenRequest({
    required this.token,
    this.isDevelopment = false,
    this.platform = 'flutter',
  });
  final String? token;
  final bool? isDevelopment;
  final String platform;

  @override
  String get url => 'remove_user_device_token';

  @override
  IRequestMethod get method => IRequestMethod.post;

  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'device_token': token,
        'is_development': isDevelopment,
        'device_platform': platform,
      };

  @override
  bool? format(Map<String, dynamic> json) {
    return json['results']['success'] as bool?;
  }
}

class UpdateUserDataRequest extends IApiRequest<Account> {
  UpdateUserDataRequest({
    this.name,
    this.avatarUrl,
    this.extras,
  });
  final String? name;
  final String? avatarUrl;
  final Map<String, dynamic>? extras;

  @override
  String get url => 'my_profile';

  @override
  IRequestMethod get method => IRequestMethod.patch;

  @override
  Map<String, dynamic> get body => <String, dynamic>{
        'name': name,
        'avatar_url': avatarUrl,
        'extras': extras,
      };

  @override
  Account format(Map<String, dynamic> json) {
    return Account.fromJson(json['results']['user'] as Map<String, dynamic>);
  }
}
