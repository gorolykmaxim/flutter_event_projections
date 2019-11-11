import 'dart:async';

import 'package:flutter_event_projections/flutter_event_projections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class QueryMock<T, D> extends Mock implements Query<T, D> {}

void main() {
  group('Projection', () {
    Projection<int, Object> projection;
    Object firstQueryResponse, queryResponse;
    QueryMock<int, Object> query;
    Event<int> event = Event('Event', {});
    Stream<Event<int>> stream;
    setUp(() {
      stream = Stream.value(event);
      query = QueryMock();
      firstQueryResponse = Object();
      queryResponse = Object();
      when(query.execute()).thenAnswer((_) => Future.value(firstQueryResponse));
      when(query.executeOn(event)).thenAnswer((_) => Future.value(queryResponse));
      projection = Projection(query, event.name, sync: true);
    });
    test('should not fail when stopping without starting first', () {
      projection.stop();
    });
    test('should execute query for the first time when projection is started', () {
      // given
      stream = Stream.empty();
      // when
      projection.start(stream);
      // then
      expect(projection.stream, emitsInOrder([firstQueryResponse]));
    });
    test('should execute query for the first time and not call a callback for a null response', () {
      // given
      when(query.execute()).thenAnswer((_) => Future.value(null));
      // when
      projection.start(stream);
      // then
      expect(projection.stream, emitsInOrder([
        // should contain only query.executeOn() result and not contain null
        // from query.execute()
        queryResponse
      ]));
    });
    test('should execute query when event with specified name occurs', () {
      // when
      projection.start(stream);
      // then
      expect(projection.stream, emitsInOrder([
        firstQueryResponse,
        queryResponse
      ]));
    });
    test('should not execute query when event with name different from the specified one occurs', () {
      // given
      stream = Stream.value(Event('Other event', {}));
      // when
      projection.start(stream);
      // then
      expect(projection.stream, emitsInOrder([firstQueryResponse]));
    });
    test('should execute query when event with specified name occurs and not call a callback for a null response', () {
      // given
      when(query.executeOn(event)).thenAnswer((_) => Future.value(null));
      // when
      projection.start(stream);
      // then
      expect(projection.stream, emitsInOrder([firstQueryResponse]));
    });
    test('should stop listening to events', () async {
      // given
      final controller = StreamController<Event<int>>(sync: true);
      // when
      projection.start(stream);
      expect(await projection.stream.first, firstQueryResponse);
      controller.add(event);
      expect(await projection.stream.first, queryResponse);
      await projection.stop();
      controller.add(event);
      // then
      expect(projection.stream, emitsDone);
    });
  });
}