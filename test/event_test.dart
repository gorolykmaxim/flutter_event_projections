import 'dart:async';

import 'package:flutter_event_projections/src/event.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  group('EventStream', () {
    test('publishes event to underlying stream', () {
      // given
      final controller = StreamController<Event<int>>.broadcast();
      final events = EventStream(controller);
      final expectedEvent = Event('Dummy Event', <String, int>{});
      // when
      events.publish(expectedEvent);
      controller.close();
      // then
      expect(controller.stream, mayEmit(expectedEvent));
    });
  });
  group('Event', () {
    const name = 'Purchase';
    const entity = 'user';
    const expectedId = 15;
    test('copies map of entity names and their IDs during event creation', () {
      // given
      Map<String, int> entityToId = {'user': 1, 'product': 15, 'item': 32};
      // when
      final event = Event(name, entityToId);
      entityToId['sale'] = 43;
      // then
      expect(event.getIdOf('sale'), isNull);
    });
    test('returns ID of entity affected by event', () {
      // given
      final event = Event(name, {entity: expectedId});
      // when
      final id = event.getIdOf(entity);
      // then
      expect(id, expectedId);
    });
    test('two similar events should be equal', () {
      // when
      final one = Event(name, {entity: expectedId});
      final another = Event(name, {entity: expectedId});
      // then
      expect(one, another);
    });
    test('returns map of all entities affected by event to their IDs', () {
      // given
      Map<String, int> expectedMap = {'user': 1, 'product': 15, 'item': 32};
      final event = Event(name, expectedMap);
      // when
      final map = event.toMap();
      // then
      expect(map, expectedMap);
    });
    test('map, returned by the event, should not influence events internal state', () {
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
  });
}