part of qiscus_chat_sdk.usecase.room;

@sealed
@immutable
class ClearRoomMessagesParams {
  const ClearRoomMessagesParams(this.uniqueIds);
  final List<String> uniqueIds;
}

class ClearRoomMessagesUseCase
    extends UseCase<IRoomRepository, Unit, ClearRoomMessagesParams> {
  ClearRoomMessagesUseCase(IRoomRepository repository) : super(repository);

  @override
  Task<Either<QError, Unit>> call(params) {
    return repository.clearMessages(uniqueIds: params.uniqueIds);
  }
}

class OnRoomMessagesCleared
    with SubscriptionMixin<IRealtimeService, TokenParams, Option<int>> {
  OnRoomMessagesCleared._(this._service);
  factory OnRoomMessagesCleared(IRealtimeService s) =>
      _instance ??= OnRoomMessagesCleared._(s);
  static OnRoomMessagesCleared _instance;
  final IRealtimeService _service;

  @override
  IRealtimeService get repository => _service;

  @override
  mapStream(_) => repository //
      .subscribeRoomCleared()
      .asyncMap((it) => it.id);

  @override
  Option<String> topic(_) => some(TopicBuilder.notification(_.token));
}
