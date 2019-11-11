import 'dart:async';

import 'package:flutter_event_projections/flutter_event_projections.dart';
import 'package:flutter_repository/flutter_repository.dart';

class UserSentMessage extends Event<Specification> {
  static final type = 'User sent message';

  UserSentMessage(String name, Map<String, Specification> entityToId) : super(name, entityToId);

  UserSentMessage.create(String userName): super(type, {'user': Specification().equals('name', userName)});
  UserSentMessage.from(Event<Specification> origin): super(type, origin.toMap());

  Specification get user => getIdOf('user');
}

class User {
  String name;
  String avatarUrl;
  EventStream<Specification> _events;

  User(this._events);

  void postMessage() {
    _events.publish(UserSentMessage.create(name));
  }
}

class Message {
  String senderName;
  String body;
  DateTime dateTime;
}

class GetUserAndHisLastMessage extends Query<Specification, Map<User, Message>> {
  ImmutableCollection<User> _users;
  ImmutableCollection<Message> _messages;

  GetUserAndHisLastMessage(this._users, this._messages);

  @override
  Future<Map<User, Message>> executeOn(Event<Specification> e) async {
    final event = UserSentMessage.from(e);
    final findUserByName = event.user;
    final sender = await _users.findOne(findUserByName);
    final findLastMessageOfUser = Specification()
        .equals('senderName', sender.name)
        .appendOrderDefinition(Order.descending('dateTime'))
        .setLimit(1);
    final lastMessage = await _messages.findOne(findLastMessageOfUser);
    return {sender: lastMessage};
  }
}

void main() async {
  // Initialize
  ImmutableCollection<User> users;
  ImmutableCollection<Message> messages;
  final controller = StreamController<Event<Specification>>.broadcast();
  final events = EventStream<Specification>(controller);
  final sender = User(events);
  // Projection
  final query = GetUserAndHisLastMessage(users, messages);
  final projection = Projection(query, UserSentMessage.type);
  projection.start(controller.stream);
  // Post message
  sender.postMessage();
  // Get notifications about query result change
  await for (var userToLatestMessage in projection.stream) {
    // re-render UI for example.
  }
}