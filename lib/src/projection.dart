import 'dart:async';

import 'event.dart';

/// A query that can be executed by a [Projection] asynchronously.
///
/// This a typical query, you would send to some kind of a data source to get
/// necessary data in response. The difference is that this query will be
/// automatically executed each time a data in the data source changes.
class Query<T, D> {
  /// Execute this query at the moment of it's [Projection] start.
  ///
  /// Must never return null. [Projection] ignores null results and does not
  /// notify it's listeners about them.
  Future<D> execute() => Future.value(null);

  /// Execute this query when it's [Projection] receives a corresponding [Event].
  ///
  /// The fact that an [event] has happened may or may not mean that the data,
  /// being queried by this query, has changed in the data sources.
  ///
  /// Must never return null. [Projection] ignores null results and does not
  /// notify it's listeners about them.
  Future<D> executeOn(Event<T> event) => Future.value(null);
}

/// Projection of a [Stream] of [Event]s onto a [Query] response.
///
/// Projection represents a persistent query of data, that is being continuously
/// changed. As a result of continuous data change, the response to this query
/// continuously changes over time as well.
///
/// Treat it as an observable query. You create it ones and it keeps notifying
/// you about the data, being queried.
///
/// Each projection reacts to events from the specified [Stream], that have
/// specific name. When such event is received by the projection, the latter one
/// executes it's query against the received event and notifies it's listeners
/// about the queried data.
///
/// Projection also executes it's query at the moment of it's [start].
class Projection<T, D> {
  Stream<Event<T>> _incomingStream;
  StreamController<D> _outgoingStreamController;
  StreamSubscription _subscription;
  final Query<T, D> _query;
  Set<String> _eventNames;

  /// Create a projection, that will execute a [_query] each time an event with
  /// [_eventName] happens.
  ///
  /// If [sync] is set to true, then a synchronous version of underlying
  /// [StreamController] will be used to post query responses to a corresponding
  /// stream.
  Projection(this._query, dynamic eventNames, {sync: false}) {
    _outgoingStreamController = StreamController.broadcast(sync: sync);
    if (eventNames is String) {
      eventNames = [eventNames];
    }
    _eventNames = Set.from(eventNames);
  }

  /// Start listening to event with the specified name on the [stream].
  Future<void> start(Stream<Event<T>> stream) async {
    _incomingStream = stream;
    _subscription = _incomingStream
        .where((event) => _eventNames.contains(event.name))
        .asyncMap(_query.executeOn)
        .where((response) => response != null)
        .listen((response) => _outgoingStreamController.add(response));
    _incomingStream = null;
    final data = await _query.execute();
    if (data != null) {
      _outgoingStreamController.add(data);
    }
  }

  /// Stop listening to events on the stream.
  Future<void> stop() async {
    if (_subscription != null) {
      await _subscription.cancel();
      _subscription = null;
    }
    await _outgoingStreamController.close();
  }

  /// Stream of all query responses.
  Stream<D> get stream => _outgoingStreamController.stream;
}