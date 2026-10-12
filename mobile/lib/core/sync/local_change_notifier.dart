import 'dart:async';

/// Repositories call [notify] after every local write, so sync can start soon after.
class LocalChangeNotifier {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}