/// CrossForge — a privacy-respecting multi-device personal mesh.
///
/// This file is the deterministic heart of the app. It has **no Flutter
/// dependency**, so the whole protocol — discovery, secure pairing, context
/// exchange, and coordinated tasks — is unit-tested and reproducible. The UI
/// layer only renders the state this engine produces.
///
/// Nothing here talks to a real network. It is a faithful *simulation* of a
/// personal mesh: the shapes, ordering, and trust rules match what a real
/// Bluetooth / Wi-Fi-Aware implementation would enforce, but every step is
/// deterministic so it can be asserted in tests and replayed in a demo.
library;

/// A stable, non-cryptographic fingerprint of [input], rendered as an 8-char
/// hex string. Used to derive a deterministic session id from a device pair.
/// This is *not* a security primitive — a real build would use the shared
/// secret from an authenticated key exchange — but it gives the simulation a
/// reproducible, session-like identifier.
String _fingerprint(String input) {
  // FNV-1a 32-bit — small, fast, deterministic.
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// The kind of a device on the mesh. Only affects presentation and a couple of
/// capability checks (a watch can't be the primary reading surface).
enum DeviceKind { phone, tablet, watch, laptop }

/// Trust state of a peer, from this device's point of view.
///
/// The order matters: trust only ever moves forward through
/// [discovered] → [pairing] → [trusted], and can drop to [revoked].
enum Trust { discovered, pairing, trusted, revoked }

/// A device visible on the mesh.
class Device {
  final String id;
  final String name;
  final DeviceKind kind;
  final Trust trust;

  const Device({
    required this.id,
    required this.name,
    required this.kind,
    this.trust = Trust.discovered,
  });

  Device copyWith({Trust? trust}) => Device(
        id: id,
        name: name,
        kind: kind,
        trust: trust ?? this.trust,
      );

  /// Can this device act as the primary reading surface for a hand-off?
  bool get canRead => kind != DeviceKind.watch;
}

/// A secure session between two trusted devices.
///
/// The [key] is a stable, order-independent fingerprint derived from both
/// device ids. In a real build this would be the shared secret from an
/// authenticated key exchange; here it is deterministic so pairing the same two
/// devices always yields the same session — which is exactly what the tests and
/// the demo rely on.
class Session {
  final String peerA;
  final String peerB;
  final String key;

  const Session._(this.peerA, this.peerB, this.key);

  factory Session.between(String a, String b) {
    // Sort so the pair (a,b) and (b,a) produce the same session key.
    final lo = a.compareTo(b) <= 0 ? a : b;
    final hi = a.compareTo(b) <= 0 ? b : a;
    return Session._(lo, hi, _fingerprint('$lo|$hi'));
  }

  bool involves(String id) => id == peerA || id == peerB;

  /// The peer of [id] in this session, or null if [id] isn't a member.
  String? other(String id) =>
      id == peerA ? peerB : (id == peerB ? peerA : null);
}

/// A coordinated experience running across trusted devices.
sealed class Task {
  const Task();
}

/// A reading position handed from one device to another (e.g. pick up an
/// article on your tablet exactly where you left it on your phone).
class ReadingHandoff extends Task {
  final String document;
  final int position; // e.g. scroll offset or paragraph index
  final String onDeviceId;
  const ReadingHandoff({
    required this.document,
    required this.position,
    required this.onDeviceId,
  });
}

/// A timer shared across every trusted device. All members see the same
/// remaining time because it's derived from a single start + duration.
class SharedTimer extends Task {
  final int durationSeconds;
  final int startedAtTick;
  const SharedTimer({required this.durationSeconds, required this.startedAtTick});

  /// Seconds left at [tick]; clamped to [0, durationSeconds].
  int remainingAt(int tick) {
    final elapsed = tick - startedAtTick;
    final left = durationSeconds - elapsed;
    if (left < 0) return 0;
    if (left > durationSeconds) return durationSeconds;
    return left;
  }

  bool doneAt(int tick) => remainingAt(tick) == 0;
}

/// One entry in the mesh's human-readable activity log.
class MeshEvent {
  final int tick;
  final String kind; // discover | pair | trust | context | task | revoke
  final String message;
  const MeshEvent(this.tick, this.kind, this.message);
}

/// The mesh coordinator. Owns the set of devices, active sessions, shared
/// tasks, and an append-only event log. Every mutation advances a logical
/// [tick] so ordering is total and reproducible.
class Mesh {
  final String selfId;
  final List<Device> _devices = [];
  final List<Session> _sessions = [];
  final List<MeshEvent> _log = [];
  final Map<String, Object> _context = {};
  final List<Task> _tasks = [];
  int _tick = 0;

  Mesh({required this.selfId});

  List<Device> get devices => List.unmodifiable(_devices);
  List<Session> get sessions => List.unmodifiable(_sessions);
  List<MeshEvent> get log => List.unmodifiable(_log);
  List<Task> get tasks => List.unmodifiable(_tasks);
  Map<String, Object> get sharedContext => Map.unmodifiable(_context);
  int get tick => _tick;

  int get trustedCount =>
      _devices.where((d) => d.trust == Trust.trusted).length;

  Device? deviceById(String id) {
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  int _advance() => ++_tick;

  void _record(String kind, String message) =>
      _log.add(MeshEvent(_tick, kind, message));

  int _indexOf(String id) => _devices.indexWhere((d) => d.id == id);

  void _setTrust(String id, Trust t) {
    final i = _indexOf(id);
    if (i >= 0) _devices[i] = _devices[i].copyWith(trust: t);
  }

  /// A device appears on the mesh. Idempotent by id — re-discovering a known
  /// device is a no-op (its existing trust is preserved).
  void discover(Device device) {
    if (_indexOf(device.id) >= 0) return;
    _advance();
    _devices.add(device);
    _record('discover', 'Discovered ${device.name}');
  }

  /// Begin an authenticated pairing with a discovered device. Moves it to
  /// [Trust.pairing]. Returns false if the device is unknown or not eligible.
  bool beginPairing(String id) {
    final d = deviceById(id);
    if (d == null || d.trust != Trust.discovered) return false;
    _advance();
    _setTrust(id, Trust.pairing);
    _record('pair', 'Pairing with ${d.name}…');
    return true;
  }

  /// Complete pairing: establish a [Session] and mark the peer [Trust.trusted].
  /// Requires the device to be mid-[Trust.pairing]. Returns the session, or
  /// null if the transition isn't valid.
  Session? confirmPairing(String id) {
    final d = deviceById(id);
    if (d == null || d.trust != Trust.pairing) return null;
    _advance();
    _setTrust(id, Trust.trusted);
    final s = Session.between(selfId, id);
    _sessions.add(s);
    _record('trust', 'Trusted ${d.name} (session ${s.key})');
    return s;
  }

  /// Convenience: discover→pair→confirm in one call for the demo/tests.
  Session? admit(Device device) {
    discover(device);
    beginPairing(device.id);
    return confirmPairing(device.id);
  }

  bool isTrusted(String id) => deviceById(id)?.trust == Trust.trusted;

  Session? sessionWith(String id) {
    for (final s in _sessions) {
      if (s.involves(selfId) && s.involves(id)) return s;
    }
    return null;
  }

  /// Share a piece of context with the mesh. Only permitted once at least one
  /// peer is trusted — you never broadcast to strangers. Returns false if
  /// there's no trusted peer to share with.
  bool shareContext(String key, Object value) {
    if (trustedCount == 0) return false;
    _advance();
    _context[key] = value;
    _record('context', 'Shared "$key" across $trustedCount trusted device(s)');
    return true;
  }

  /// Hand a reading position to a trusted device that can display it.
  bool handoffReading(ReadingHandoff task) {
    final target = deviceById(task.onDeviceId);
    if (target == null || target.trust != Trust.trusted || !target.canRead) {
      return false;
    }
    _advance();
    _tasks.removeWhere((t) => t is ReadingHandoff);
    _tasks.add(task);
    _record('task',
        'Handed "${task.document}" @${task.position} to ${target.name}');
    return true;
  }

  /// Start a timer shared across every trusted device. Requires a trusted peer.
  SharedTimer? startSharedTimer(int durationSeconds) {
    if (trustedCount == 0 || durationSeconds <= 0) return null;
    _advance();
    final t = SharedTimer(durationSeconds: durationSeconds, startedAtTick: _tick);
    _tasks.removeWhere((x) => x is SharedTimer);
    _tasks.add(t);
    _record('task', 'Started a $durationSeconds s shared timer');
    return t;
  }

  /// Revoke trust in a device: tear down its session, drop it to
  /// [Trust.revoked], and stop sharing context with it.
  bool revoke(String id) {
    final d = deviceById(id);
    if (d == null || d.trust != Trust.trusted) return false;
    _advance();
    _setTrust(id, Trust.revoked);
    _sessions.removeWhere((s) => s.involves(id));
    _record('revoke', 'Revoked trust in ${d.name}');
    return true;
  }
}
