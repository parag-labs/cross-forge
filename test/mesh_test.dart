import 'package:flutter_test/flutter_test.dart';
import 'package:cross_forge/core/mesh.dart';
import 'package:cross_forge/core/samples.dart';

void main() {
  group('discovery + pairing lifecycle', () {
    test('discover is idempotent by id and preserves trust', () {
      final m = Mesh(selfId: 'self');
      m.discover(peerTablet);
      m.beginPairing(peerTablet.id);
      m.confirmPairing(peerTablet.id);
      final tickAfterTrust = m.tick;
      m.discover(peerTablet); // re-discover known device
      expect(m.tick, tickAfterTrust, reason: 'no-op, tick unchanged');
      expect(m.isTrusted(peerTablet.id), isTrue);
      expect(m.devices.where((d) => d.id == peerTablet.id).length, 1);
    });

    test('trust only advances through valid transitions', () {
      final m = Mesh(selfId: 'self');
      // confirm without pairing → invalid
      m.discover(peerTablet);
      expect(m.confirmPairing(peerTablet.id), isNull);
      expect(m.isTrusted(peerTablet.id), isFalse);
      // proper flow
      expect(m.beginPairing(peerTablet.id), isTrue);
      expect(m.deviceById(peerTablet.id)!.trust, Trust.pairing);
      final s = m.confirmPairing(peerTablet.id);
      expect(s, isNotNull);
      expect(m.isTrusted(peerTablet.id), isTrue);
    });

    test('cannot pair an unknown device', () {
      final m = Mesh(selfId: 'self');
      expect(m.beginPairing('ghost'), isFalse);
    });
  });

  group('secure sessions', () {
    test('session key is order-independent and stable', () {
      final a = Session.between('phone', 'tablet');
      final b = Session.between('tablet', 'phone');
      expect(a.key, b.key);
      expect(a.peerA, b.peerA);
      // deterministic across runs
      expect(Session.between('phone', 'tablet').key, a.key);
    });

    test('different pairs yield different keys', () {
      expect(Session.between('phone', 'tablet').key,
          isNot(Session.between('phone', 'watch').key));
    });

    test('confirmPairing establishes a session with self', () {
      final m = Mesh(selfId: 'self');
      m.admit(peerTablet);
      final s = m.sessionWith(peerTablet.id);
      expect(s, isNotNull);
      expect(s!.involves('self'), isTrue);
      expect(s.other('self'), peerTablet.id);
    });
  });

  group('context sharing consent', () {
    test('sharing is blocked with no trusted peer', () {
      final m = Mesh(selfId: 'self');
      m.discover(peerLaptop); // discovered only
      expect(m.shareContext('location', 'home'), isFalse);
      expect(m.sharedContext.containsKey('location'), isFalse);
    });

    test('sharing works once a peer is trusted', () {
      final m = Mesh(selfId: 'self');
      m.admit(peerTablet);
      expect(m.shareContext('location', 'home'), isTrue);
      expect(m.sharedContext['location'], 'home');
    });
  });

  group('coordinated tasks', () {
    test('reading hand-off requires a trusted, readable device', () {
      final m = Mesh(selfId: 'self');
      m.admit(peerWatch); // watch cannot read
      final toWatch = ReadingHandoff(
          document: 'doc', position: 1, onDeviceId: peerWatch.id);
      expect(m.handoffReading(toWatch), isFalse);

      m.admit(peerTablet);
      final toTablet = ReadingHandoff(
          document: 'doc', position: 10, onDeviceId: peerTablet.id);
      expect(m.handoffReading(toTablet), isTrue);
      expect(m.tasks.whereType<ReadingHandoff>().length, 1);
    });

    test('shared timer is monotonic and clamps at both ends', () {
      const t = SharedTimer(durationSeconds: 60, startedAtTick: 100);
      expect(t.remainingAt(100), 60);
      expect(t.remainingAt(130), 30);
      expect(t.remainingAt(160), 0);
      expect(t.remainingAt(200), 0, reason: 'clamped, never negative');
      expect(t.remainingAt(90), 60, reason: 'clamped, never over duration');
      expect(t.doneAt(160), isTrue);
    });

    test('starting a timer needs a trusted peer and positive duration', () {
      final m = Mesh(selfId: 'self');
      expect(m.startSharedTimer(300), isNull);
      m.admit(peerTablet);
      expect(m.startSharedTimer(0), isNull);
      expect(m.startSharedTimer(300), isNotNull);
    });
  });

  group('revocation', () {
    test('revoke tears down the session and stops trust', () {
      final m = Mesh(selfId: 'self');
      m.admit(peerTablet);
      expect(m.sessionWith(peerTablet.id), isNotNull);
      expect(m.revoke(peerTablet.id), isTrue);
      expect(m.deviceById(peerTablet.id)!.trust, Trust.revoked);
      expect(m.sessionWith(peerTablet.id), isNull);
      expect(m.trustedCount, 0);
    });

    test('cannot revoke a non-trusted device', () {
      final m = Mesh(selfId: 'self');
      m.discover(peerLaptop);
      expect(m.revoke(peerLaptop.id), isFalse);
    });
  });

  group('demo scenario', () {
    test('demoMesh is deterministic and richly populated', () {
      final a = demoMesh();
      final b = demoMesh();
      expect(a.trustedCount, b.trustedCount);
      expect(a.log.length, b.log.length);
      // two trusted (tablet, watch), laptop still discovered
      expect(a.trustedCount, 2);
      expect(a.deviceById('laptop-01')!.trust, Trust.discovered);
      expect(a.tasks.whereType<ReadingHandoff>().length, 1);
      expect(a.tasks.whereType<SharedTimer>().length, 1);
      expect(a.sharedContext['location'], 'home');
      // event log ticks are strictly increasing
      for (var i = 1; i < a.log.length; i++) {
        expect(a.log[i].tick >= a.log[i - 1].tick, isTrue);
      }
    });
  });
}
