import 'dart:async';

import 'package:collection/collection.dart';

const _mapEquality = MapEquality();

/// An event that is sent from the domain model to the outer world.
///
/// Each event indicates that something has happened in the domain model.
///
/// Since entities of the domain model can gain and loose attributes frequently
/// during development, events do not references any of those attributes.
/// Event should only reference an object, that identifies the entity, related
/// to that event. This could be an ID of that entity. Though, passing IDs
/// of entities in events is possible only in an applications with simple IDs
/// (like where every entity has a UUID type as it's ID).
/// In bigger applications the recommended approach is to pass a DDD repository
/// specification, that describes the entity.
class Event<T> {

  /// Name of the event.
  final String name;
  final Map<String, T> _entityToId;

  /// Create an event with a [name].
  ///
  /// Describe all entities, that are related to this event, in [entityToId]
  /// map, where each key is an entity name and value is the object, that
  /// identifies it.
  Event(this.name, Map<String, T> entityToId): _entityToId = Map.from(entityToId);

  /// Get identification object of the [entity], that is related to this event.
  T getIdOf(String entity) {
    return _entityToId[entity];
  }

  /// Return a map of all entities, affected by this event and their IDs.
  Map<String, T> toMap() {
    return Map.from(_entityToId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Event &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              _mapEquality.equals(_entityToId, other._entityToId);

  @override
  int get hashCode =>
      name.hashCode ^
      _entityToId.hashCode;



}

/// Simple proxy to [StreamController].
///
/// It is advised to pass this object into domain model classes, since it only
/// provides an ability to publish events and doesn't allow any other
/// [StreamController] related actions.
class EventStream<T> {
  final StreamController<Event<T>> _controller;

  /// Create a proxy to the [_controller].
  EventStream(this._controller);

  /// Publish [event] to this stream.
  void publish(Event<T> event) {
    _controller.add(event);
  }
}