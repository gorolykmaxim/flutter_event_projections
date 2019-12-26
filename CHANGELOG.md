## [1.3.1]
* Fix Projections, that listen for multiple event types

## [1.3.0]
* Event name now can be specified as any dynamic value. This allows
setting event name to a Dart Type

## [1.2.2]
* Fix description of Sequential()
* Allow passing Clock inside the Sequential() in order to be able to
control time inside of it

## [1.2.1]
* You can now listen to errors, that occur inside Query.execute() and
Query.executeOn(Event), on Projection.stream.

## [1.2.0]
* Iterable of event names can now be passed to Projection, meaning any
of those events will trigger it
* ObservableEventStream is introduced which allows aggregating multiple
events into one new event and listening to it

## [1.1.0]
* EventStream can notify about errors 

## [1.0.1]
* Added example
* Event can now be converted to a map
* Added proper license

## [1.0.0]
Initial implementation.