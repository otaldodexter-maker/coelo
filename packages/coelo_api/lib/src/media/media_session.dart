import 'dart:async';

/// Lifetime boundary for private media belonging to one authorised session and
/// realm/context. Create a new instance only after the new context is authorised.
///
/// Gateways wrap asynchronous requests in [run]; caches and players register
/// their cleanup in [registerPurge]. Auth awaits [invalidate] on logout,
/// revocation or sensitive context changes before releasing the next context.
/// This local boundary does not replace server authorization, ticket expiry or
/// server-side revocation. Consumers must not persist results inside [run]'s
/// callback: consume its returned value only after the boundary check.
final class MediaSession {
  bool _invalidated = false;
  final Map<Object, FutureOr<void> Function()> _purges = {};
  Future<void>? _invalidation;

  bool get isInvalidated => _invalidated;

  /// Rejects new operations and results from an invalidated lifetime.
  Future<T> run<T>(Future<T> Function() operation) async {
    _checkActive();
    final result = await operation();
    _checkActive();
    return result;
  }

  /// Returns an idempotent unregister function for an already-disposed consumer.
  /// Cleanup callbacks must finish without awaiting [invalidate] itself.
  void Function() registerPurge(FutureOr<void> Function() purge) {
    _checkActive();
    final key = Object();
    _purges[key] = purge;
    return () => _purges.remove(key);
  }

  /// Marks this lifetime invalid synchronously, then attempts every registered
  /// cleanup. Repeated calls share completion (including cleanup failure).
  /// A failed cleanup never reactivates this session.
  Future<void> invalidate() {
    final existing = _invalidation;
    if (existing != null) return existing;
    _invalidated = true;
    final completion = Completer<void>();
    _invalidation = completion.future;
    final callbacks = _purges.values.toList(growable: false);
    _purges.clear();
    unawaited(_purge(callbacks, completion));
    return completion.future;
  }

  Future<void> _purge(List<FutureOr<void> Function()> callbacks, Completer<void> completion) async {
    var failed = false;
    // Each callback starts independently: one asynchronous purge must not delay
    // invalidating another consumer's in-memory tickets or player.
    await Future.wait(
      callbacks.map((callback) async {
        try {
          await callback();
        } catch (_) {
          // Continue purging even if a consumer throws. Never expose a callback's
          // private URLs, tokens or payload in the outward failure.
          failed = true;
        }
      }),
    );
    if (failed) {
      completion.completeError(const MediaSessionPurgeException());
    } else {
      completion.complete();
    }
  }

  void _checkActive() {
    if (_invalidated) throw const MediaSessionInvalidatedException();
  }
}

final class MediaSessionInvalidatedException implements Exception {
  const MediaSessionInvalidatedException();

  @override
  String toString() => 'Media session invalidated.';
}

final class MediaSessionPurgeException implements Exception {
  const MediaSessionPurgeException();

  @override
  String toString() => 'Private media cleanup failed.';
}
