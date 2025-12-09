// lib/utils/event_bus.dart
import 'dart:async';

/// Simple event type used across the app.
class PlayerEvent {
  final String action; // 'added', 'deleted', 'updated', 'installment_created', etc.
  final Map<String, dynamic>? payload;
  PlayerEvent(this.action, {this.payload});
}

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _controller = StreamController<PlayerEvent>.broadcast();

  Stream<PlayerEvent> get stream => _controller.stream;

  void fire(PlayerEvent event) => _controller.add(event);

  void dispose() => _controller.close();
}
