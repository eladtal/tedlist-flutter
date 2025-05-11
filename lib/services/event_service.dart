import 'dart:async';
import 'package:flutter/foundation.dart';

enum AppEvent {
  itemDeleted,
  itemAdded,
  itemUpdated,
  refreshNeeded,
}

class EventData {
  final AppEvent event;
  final dynamic data;

  EventData(this.event, [this.data]);
}

/// A simple event bus to handle global events across the app
class EventService {
  // Singleton pattern
  EventService._();
  static final EventService _instance = EventService._();
  factory EventService() => _instance;

  // Stream controller for events
  final _eventController = StreamController<EventData>.broadcast();

  // Stream getter
  Stream<EventData> get onEvent => _eventController.stream;

  // Fire an event
  void fireEvent(AppEvent event, [dynamic data]) {
    debugPrint('🔥 Firing event: $event with data: $data');
    _eventController.add(EventData(event, data));
  }

  // Dispose method to clean up resources
  void dispose() {
    _eventController.close();
  }
}

// Provide global access
final eventService = EventService(); 