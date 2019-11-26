import 'dart:async';

import 'package:class_test/class_test.dart';
import 'package:flutter_event_projections/src/event.dart';
import 'package:flutter_test/flutter_test.dart';

class EventStreamTest extends Test {
  StreamController<Event<int>> controller;
  Stream<Event<int>> stream;
  EventStream<int> events;

  EventStreamTest({name = 'EventStream'}) : super(name);

  @override
  void setUp() {
    controller = StreamController.broadcast();
    stream = controller.stream;
    events = EventStream(controller);
  }

  @override
  void declareTests() {
    declareTest('publishes event to underlying stream', () {
      // given
      final expectedEvent = Event('Dummy Event', <String, int>{});
      // when
      stream.listen(expectAsync1((event) {
        expect(event, expectedEvent);
      }));
      events.publish(expectedEvent);
    });
    declareTest('publishes error to underlying stream', () {
      // given
      final expectedException = Exception('Error has happenned');
      // when
      stream
          .handleError(expectAsync1((e) {
              expect(e, expectedException);
          }))
          .listen((e) {});
      events.error(expectedException);
    });
  }
}

class ObservableEventStreamTest extends EventStreamTest {
  static final int bread1 = 1, butter1 = 2, sausage1 = 3, bread2 = 4,
      butter2 = 5, sausage2 = 6;
  static final String breadIsPlasteredWithButter = 'bread is plastered with butter';
  static final String sausageIsPlacedOnBread = 'sausage is placed on bread';
  static final String sandwichIsReady = 'sandwich is ready';
  final expectedEvents = <Event<int>>[
    Event(breadIsPlasteredWithButter, {'bread': bread1, 'butter': butter1}),
    Event(sausageIsPlacedOnBread, {'bread': bread1, 'sausage': sausage1}),
    Event('some random event', {}),
    Event(breadIsPlasteredWithButter, {'bread': bread2, 'butter': butter2}),
    Event('some random event', {}),
    Event(sausageIsPlacedOnBread, {'bread': bread2, 'sausage': sausage2})
  ];
  final expectedAggregations = <Event<int>>[
    Event(sandwichIsReady, {
      'breadWithSausage': bread1,
      'breadPlasteredWithButter': bread1,
      'butter': butter1,
      'sausage': sausage1
    }),
    Event(sandwichIsReady, {
      'breadWithSausage': bread2,
      'breadPlasteredWithButter': bread2,
      'butter': butter2,
      'sausage': sausage2
    })
  ];
  final mapping = EntityMapping();
  ObservableEventStream<int> observableEvents;
  List<Event<int>> receivedEvents;

  ObservableEventStreamTest(): super(name: 'ObservableEventStreamTest');

  @override
  void setUp() {
    super.setUp();
    observableEvents = ObservableEventStream(controller);
    events = observableEvents;
    stream = observableEvents.stream;
    mapping.set(breadIsPlasteredWithButter, 'bread', 'breadPlasteredWithButter');
    mapping.set(sausageIsPlacedOnBread, 'bread', 'breadWithSausage');
    receivedEvents = [];
  }

  @override
  void declareTests() {
    super.declareTests();
    declareTest('aggregates multiple events into one sequentially', () {
      // when
      stream = observableEvents.aggregate(Sequential([breadIsPlasteredWithButter, sausageIsPlacedOnBread], sandwichIsReady, mapping: mapping));
      stream.listen(expectAsync1((e) {
        receivedEvents.add(e);
        if (receivedEvents.length == expectedAggregations.length) {
          expect(receivedEvents, expectedAggregations);
        }
      }, count: expectedAggregations.length));
      expectedEvents.forEach((e) => observableEvents.publish(e));
    });
    declareTest('aggregates mutliple events into one sequentially keeping track of timeout', () {
      // when
      stream = observableEvents.aggregate(Sequential([breadIsPlasteredWithButter, sausageIsPlacedOnBread], sandwichIsReady, mapping: mapping, timeout: 500));
      stream.listen(expectAsync1((e) {
        receivedEvents.add(e);
        if (receivedEvents.length == expectedAggregations.length) {
          expect(receivedEvents, expectedAggregations);
        }
      }, count: expectedAggregations.length));
      expectedEvents.forEach((e) => observableEvents.publish(e));
    });
    declareTest('aggregates multiple events without explicit mapping', () {
      // given
      final expectedAggregations = [
        Event(sandwichIsReady, {
          'bread': bread1,
          'butter': butter1,
          'sausage': sausage1
        }),
        Event(sandwichIsReady, {
          'bread': bread2,
          'butter': butter2,
          'sausage': sausage2
        })
      ];
      // when
      stream = observableEvents.aggregate(Sequential([breadIsPlasteredWithButter, sausageIsPlacedOnBread], sandwichIsReady));
      stream.listen(expectAsync1((e) {
        receivedEvents.add(e);
        if (expectedAggregations.length == receivedEvents.length) {
          expect(receivedEvents, expectedAggregations);
        }
      }, count: expectedAggregations.length));
      expectedEvents.forEach((e) => observableEvents.publish(e));
    });
    declareTest('does not aggregate first portion of events due to timeout, but aggregates the second portion', () async {
      // when
      stream = observableEvents.aggregate(Sequential([breadIsPlasteredWithButter, sausageIsPlacedOnBread], sandwichIsReady, mapping: mapping, timeout: 500));
      stream.listen(expectAsync1((event) {
        expect(event, expectedAggregations[1]);
      }));
      for (var i = 0; i < expectedEvents.length; i++) {
        // Emulate second event missing
        if (i == 1) {
          await Future.delayed(Duration(milliseconds: 600));
          continue;
        }
        observableEvents.publish(expectedEvents[i]);
      }
    });
  }
}

class EventTest extends Test {
  final name = 'Purchase';
  final entity = 'user';
  final expectedId = 15;

  EventTest() : super('Event');

  @override
  void declareTests() {
    declareTest('copies map of entity names and their IDs during event creation', () {
      // given
      Map<String, int> entityToId = {'user': 1, 'product': 15, 'item': 32};
      // when
      final event = Event(name, entityToId);
      entityToId['sale'] = 43;
      // then
      expect(event.getIdOf('sale'), isNull);
    });
    declareTest('returns ID of entity affected by event', () {
      // given
      final event = Event(name, {entity: expectedId});
      // when
      final id = event.getIdOf(entity);
      // then
      expect(id, expectedId);
    });
    declareTest('two similar events should be equal', () {
      // when
      final one = Event(name, {entity: expectedId});
      final another = Event(name, {entity: expectedId});
      // then
      expect(one, another);
    });
    declareTest('returns map of all entities affected by event to their IDs', () {
      // given
      Map<String, int> expectedMap = {'user': 1, 'product': 15, 'item': 32};
      final event = Event(name, expectedMap);
      // when
      final map = event.toMap();
      // then
      expect(map, expectedMap);
    });
    declareTest('map, returned by the event, should not influence events internal state', () {
      // given
      Map<String, int> expectedMap = {'user': 1, 'product': 15, 'item': 32};
      final event = Event(name, expectedMap);
      // when
      final map = event.toMap();
      map['sale'] = 32;
      // then
      expect(event.toMap(), expectedMap);
      expect(event.getIdOf('sale'), isNull);
    });
  }
}

void main() {
  EventStreamTest().run();
  ObservableEventStreamTest().run();
  EventTest().run();
}