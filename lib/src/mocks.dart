import 'package:mockito/mockito.dart';

import '../flutter_event_projections.dart';

class ObservableEventStreamMock<T> extends Mock implements ObservableEventStream<T> {}

class ProjectionFactoryMock extends Mock implements ProjectionFactory {}

class ProjectionMock<T, D> extends Mock implements Projection<T, D> {}