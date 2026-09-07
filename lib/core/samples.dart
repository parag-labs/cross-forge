import 'mesh.dart';

/// Deterministic sample devices and scenarios for the demo and tests.
///
/// Everything is fixed so the demo tells the same story every run: a phone
/// (self) meets a tablet, a watch, and a laptop, trusts two of them, shares
/// context, and coordinates a reading hand-off and a shared timer.

const selfDevice = Device(
  id: 'self-phone',
  name: 'My Phone',
  kind: DeviceKind.phone,
  trust: Trust.trusted,
);

const peerTablet = Device(
  id: 'tablet-01',
  name: 'Living-room Tablet',
  kind: DeviceKind.tablet,
);

const peerWatch = Device(
  id: 'watch-01',
  name: 'My Watch',
  kind: DeviceKind.watch,
);

const peerLaptop = Device(
  id: 'laptop-01',
  name: 'Work Laptop',
  kind: DeviceKind.laptop,
);

/// Build a mesh in a rich, presentable state:
/// - tablet and watch admitted (trusted, sessions established)
/// - laptop discovered but not yet trusted
/// - a shared context key, a reading hand-off to the tablet, and a shared timer
Mesh demoMesh() {
  final mesh = Mesh(selfId: selfDevice.id);
  mesh.admit(peerTablet);
  mesh.admit(peerWatch);
  mesh.discover(peerLaptop); // present but untrusted
  mesh.shareContext('location', 'home');
  mesh.handoffReading(const ReadingHandoff(
    document: 'The Case for Small Meshes',
    position: 42,
    onDeviceId: 'tablet-01',
  ));
  mesh.startSharedTimer(300);
  return mesh;
}

/// A fresh mesh with only the self device — used to demonstrate the
/// discover→pair→trust flow step by step in the UI.
Mesh emptyMesh() => Mesh(selfId: selfDevice.id);
