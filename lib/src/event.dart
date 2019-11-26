import 'dart:async';

import 'package:collection/collection.dart';

const _mapEquality = MapEquality();

/// An event, that is sent from the domain model to the outer world.
///
/// Each event indicates that something has happened in the domain model.
///
/// Since entities of the domain model can gain and loose attributes frequently
/// during development, events do not reference any of those attributes.
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

  /// Return a map of all entities, affected by this event, and their IDs.
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

  @override
  String toString() {
    return 'Event{name: $name, _entityToId: $_entityToId}';
  }
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

  /// Publish [exception] to this stream.
  void error(Exception exception) {
    _controller.addError(exception);
  }
}

/// Mapping between names of entities, that are present in events, being
/// aggregated, and their names in the resulting aggregating event.
class EntityMapping {
  final Map<String, Map<String, String>> _eventTypeToOriginalEntityToTargetEntity = {};

  /// Specify that while aggregating event with [eventType], ID of
  /// [originalEntity] from the source event should be transferred to
  /// [targetEntity] in the aggregating event.
  void set(String eventType, String originalEntity, String targetEntity) {
    _eventTypeToOriginalEntityToTargetEntity.putIfAbsent(eventType, () => {});
    _eventTypeToOriginalEntityToTargetEntity[eventType][originalEntity] = targetEntity;
  }

  /// Get a name, by which ID of [originalEntity] in event of [eventType]
  /// should be stored in the aggregating event.
  String get(String eventType, String originalEntity) {
    final originalEntityToTargetEntity = _eventTypeToOriginalEntityToTargetEntity[eventType];
    if (originalEntityToTargetEntity != null) {
      return originalEntityToTargetEntity[originalEntity] ?? originalEntity;
    } else {
      return originalEntity;
    }
  }
}

/// Strategy of creating event aggregations.
///
/// Life cycle of strategy instance is directly bound to a life cycle of a
/// [ObservableEventStream], on which the strategy continuously aggregates
/// events. This means, that if a strategy has a state, it should properly
/// manage it while creating different aggregations.
abstract class AggregationStrategy<T> {
  /// Try to create an aggregation of events when [event] happens.
  ///
  /// If [event] finishes the process of aggregation of multiple events,
  /// that were previously passed to this strategy, the strategy should emit
  /// an event that represents an aggregation of all previously happened events
  /// that should belong to it.
  ///
  /// If [event] does not finish any aggregation, strategy should return null.
  Event<T> tryToAggregateOn(Event<T> event);

  /// Create an event with [newEventName], that is an aggregation of all
  /// [events].
  ///
  /// Each name of each entity, specified in the aggregating event, is
  /// determined using [mapping].
  Event<T> aggregate(Iterable<Event<T>> events, String newEventName, EntityMapping mapping) {
    final entityToId = <String, T>{};
    for (var event in events) {
      final entitiesOfEvent = event.toMap();
      for (var entity in entitiesOfEvent.keys) {
        entityToId[mapping.get(event.name, entity)] = entitiesOfEvent[entity];
      }
    }
    return Event(newEventName, entityToId);
  }
}

/// The most basic [AggregationStrategy], that assumes that all aggregations
/// happen sequentially: if there are event types A and B, that should form
/// an aggregation C, than only the following flow of events is possible:
/// A, B, A, B, B, A, A, B
///
/// This strategy will not work in cases when there can be multiple aggregations
/// happening at the same time:
/// A, A, B, B, A, A, A, B, B, B
class Sequential<T> extends AggregationStrategy<T> {
  final Set<String> _expectedEventTypes;
  final String _newEventName;
  final EntityMapping _mapping;
  final Set<Event<T>> _occurredEvents = Set();
  final int _timeout;
  int _lastMatchingEventOccurrenceTime = 0;

  /// Create strategy which creates aggregation of [_expectedEventTypes].
  ///
  /// Use [_factory] to create an event, that represents an aggregation of
  /// occurred events.
  ///
  /// If event, that belongs to an aggregation, that is currently being
  /// constructed, does not happen for a [timeout], than the current aggregation
  /// will be discarded and a new one will be built instead.
  ///
  /// If [timeout] is set to 0 - incomplete aggregations will not get discarded
  /// over time.
  Sequential(Iterable<String> expectedEventTypes, this._newEventName, {EntityMapping mapping, int timeout = 0}):
        _expectedEventTypes = Set.from(expectedEventTypes),
        _mapping = mapping ?? EntityMapping(),
        _timeout = timeout;

  Event<T> tryToAggregateOn(Event<T> event) {
    int currentTimeStamp = DateTime.now().millisecondsSinceEpoch;
    if (_timeout > 0 && currentTimeStamp > _lastMatchingEventOccurrenceTime + _timeout) {
      _occurredEvents.clear();
    }
    if (_expectedEventTypes.contains(event.name)) {
      _occurredEvents.add(event);
      _lastMatchingEventOccurrenceTime = currentTimeStamp;
    }
    final occurredEventTypes = _occurredEvents.map((e) => e.name).toSet();
    if (occurredEventTypes.containsAll(_expectedEventTypes)) {
      final aggregation = aggregate(_occurredEvents, _newEventName, _mapping);
      _occurredEvents.clear();
      return aggregation;
    } else {
      return null;
    }
  }
}

/// [EventStream] that can be observed.
///
/// Besides all the usual ways of observing a plain [Stream], this event stream
/// provides more options of observing events, such as aggregating multiple
/// events into one.
class ObservableEventStream<T> extends EventStream<T> {

  /// Create observable event stream, based of the specified [controller].
  ObservableEventStream(StreamController<Event<T>> controller) : super(controller);

  /// Get stream of all events, that occur on this events stream.
  Stream<Event<T>> get stream => _controller.stream;

  /// Get stream, that produces events that aggregate multiple separate events
  /// in one.
  ///
  /// Create event aggregations using [strategy].
  ///
  /// Only aggregated events will be published to the returned stream.
  Stream<Event<T>> aggregate(AggregationStrategy<T> strategy) {
    return stream.map(strategy.tryToAggregateOn).where((e) => e != null);
  }
}