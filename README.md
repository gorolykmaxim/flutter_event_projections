# flutter_event_projections

Create queries for specific sets of data, that are updated asynchronously like streams.

## Getting Started

[flutter_repository](https://pub.dev/packages/flutter_repository) package
is used in scope of this example to help implement the domain model.
This library is intended to be used in conjunction with repositories.

Let's imagine we have a messenger app. Our domain model would look like
this:
```dart
class User {
  String name;
  String avatarUrl;
}

class Message {
  String senderName;
  String body;
  DateTime dateTime;
}
```

When one user sends a message to another user, we would want to know
about that in our widgets to re-render the status of the user, that is
sending it.
Let's create a class that represents this event.
```dart
class UserSentMessage extends Event<Specification> {
  static final type = 'User sent message';

  UserSentMessage(String name, Map<String, Specification> entityToId) : super(name, entityToId);

  UserSentMessage.create(String userName): super(type, {'user': Specification().equals('name', userName)});
  UserSentMessage.from(Event<Specification> origin): super(type, origin.toMap());

  Specification get user => getIdOf('user');
}
```

Now let's extend our User class, so that it would be able to publish
such events.
```dart
class User {
  String name;
  String avatarUrl;
  EventStream<Specification> _events;

  User(this._events);

  void postMessage() {
    _events.publish(UserSentMessage.create(name));
  }
}
```

Since our app needs to display a user, sending message, and the latest
message sent, let's create a query for this set of data.
```dart
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
```

Let's initialize our application.
```dart
// Initialize
ImmutableCollection<User> users;
ImmutableCollection<Message> messages;
final controller = StreamController<Event<Specification>>.broadcast();
final events = ObservableEventStream(controller);
final sender = User(events);
```

To initialize the query, we've previously created, so that it would
be continuously executed when the UserSentMessage event happens, let's
create a projection of that event.
```dart
final query = GetUserAndHisLastMessage(users, messages);
final projection = Projection(query, UserSentMessage.type);
projection.start(events.stream);
``` 

From now on, when a user will publish UserSentMessage event
```dart
sender.postMessage();
```
the GetUserAndHisLastMessage query will be executed automatically and
it's result will be published to projection's stream, that can be 
accessed like:
```dart
await for (var userToLatestMessage in projection.stream) {
// re-render UI for example.
}
```