import 'package:flutter/material.dart';
import 'core/mesh.dart';
import 'core/samples.dart';

void main() => runApp(const CrossForgeApp());

const _bg = Color(0xFF0B1020);
const _panel = Color(0xFF141B2E);
const _panel2 = Color(0xFF1B2540);
const _accent = Color(0xFF5B8DEF);
const _accentSoft = Color(0xFF2A3A63);
const _good = Color(0xFF3ECF8E);
const _warn = Color(0xFFF2B84B);
const _muted = Color(0xFF8A94AD);
const _text = Color(0xFFEAF0FF);

class CrossForgeApp extends StatelessWidget {
  const CrossForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrossForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          surface: _panel,
        ),
      ),
      home: const MeshHome(),
    );
  }
}

class MeshHome extends StatefulWidget {
  const MeshHome({super.key});
  @override
  State<MeshHome> createState() => _MeshHomeState();
}

class _MeshHomeState extends State<MeshHome> {
  late Mesh mesh;

  @override
  void initState() {
    super.initState();
    mesh = demoMesh();
  }

  void _reset() => setState(() => mesh = demoMesh());

  void _advanceLaptop() {
    setState(() {
      final laptop = mesh.deviceById('laptop-01');
      if (laptop == null) return;
      switch (laptop.trust) {
        case Trust.discovered:
          mesh.beginPairing(laptop.id);
        case Trust.pairing:
          mesh.confirmPairing(laptop.id);
        case Trust.trusted:
          mesh.revoke(laptop.id);
        case Trust.revoked:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryRow(),
                      const SizedBox(height: 18),
                      _sectionLabel('Devices on your mesh'),
                      const SizedBox(height: 10),
                      ...mesh.devices.map(_deviceCard),
                      const SizedBox(height: 20),
                      _sectionLabel('Coordinated right now'),
                      const SizedBox(height: 10),
                      ..._taskCards(),
                      const SizedBox(height: 20),
                      _sectionLabel('Activity'),
                      const SizedBox(height: 10),
                      _activityLog(),
                      const SizedBox(height: 18),
                      _privacyNote(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_panel2, _bg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.hub_rounded, color: _accent, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('CrossForge',
                  style: TextStyle(
                      color: _text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded, color: _muted),
                tooltip: 'Reset demo',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Your devices, meshed — private by consent.',
            style: TextStyle(color: _muted, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow() {
    return Row(
      children: [
        _stat('${mesh.trustedCount}', 'trusted', _good),
        const SizedBox(width: 10),
        _stat('${mesh.devices.length}', 'discovered', _accent),
        const SizedBox(width: 10),
        _stat('${mesh.tasks.length}', 'shared tasks', _warn),
      ],
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
        t.toUpperCase(),
        style: const TextStyle(
            color: _muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1),
      );

  Widget _deviceCard(Device d) {
    final (icon, iconColor) = switch (d.kind) {
      DeviceKind.phone => (Icons.smartphone_rounded, _accent),
      DeviceKind.tablet => (Icons.tablet_mac_rounded, _accent),
      DeviceKind.watch => (Icons.watch_rounded, _accent),
      DeviceKind.laptop => (Icons.laptop_mac_rounded, _accent),
    };
    final self = d.id == mesh.selfId;
    final session = mesh.sessionWith(d.id);
    final tappable = d.id == 'laptop-01';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(d.name,
                          style: const TextStyle(
                              color: _text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (self)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('(this device)',
                            style: TextStyle(color: _muted, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                if (session != null)
                  Text('secure session · ${session.key}',
                      style: const TextStyle(color: _muted, fontSize: 11.5))
                else
                  Text(_trustSubtitle(d.trust),
                      style: const TextStyle(color: _muted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _trustBadge(d.trust),
          if (tappable)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                onPressed: _advanceLaptop,
                icon: Icon(_laptopActionIcon(d.trust), color: _accent, size: 20),
                tooltip: _laptopActionLabel(d.trust),
              ),
            ),
        ],
      ),
    );
  }

  IconData _laptopActionIcon(Trust t) => switch (t) {
        Trust.discovered => Icons.link_rounded,
        Trust.pairing => Icons.check_circle_outline_rounded,
        Trust.trusted => Icons.link_off_rounded,
        Trust.revoked => Icons.block_rounded,
      };

  String _laptopActionLabel(Trust t) => switch (t) {
        Trust.discovered => 'Begin pairing',
        Trust.pairing => 'Confirm trust',
        Trust.trusted => 'Revoke',
        Trust.revoked => 'Revoked',
      };

  String _trustSubtitle(Trust t) => switch (t) {
        Trust.discovered => 'nearby · not yet paired',
        Trust.pairing => 'authenticating…',
        Trust.trusted => 'trusted',
        Trust.revoked => 'trust revoked',
      };

  Widget _trustBadge(Trust t) {
    final (label, color) = switch (t) {
      Trust.discovered => ('NEARBY', _muted),
      Trust.pairing => ('PAIRING', _warn),
      Trust.trusted => ('TRUSTED', _good),
      Trust.revoked => ('REVOKED', const Color(0xFFE06C75)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  List<Widget> _taskCards() {
    if (mesh.tasks.isEmpty) {
      return [
        Text('Nothing coordinated yet.',
            style: TextStyle(color: _muted.withOpacity(0.8), fontSize: 13)),
      ];
    }
    return mesh.tasks.map((t) {
      if (t is ReadingHandoff) {
        final target = mesh.deviceById(t.onDeviceId);
        return _taskCard(
          Icons.menu_book_rounded,
          'Reading hand-off',
          '“${t.document}” @ ${t.position} → ${target?.name ?? t.onDeviceId}',
        );
      }
      if (t is SharedTimer) {
        return _taskCard(
          Icons.timer_rounded,
          'Shared timer',
          '${t.durationSeconds ~/ 60} min, mirrored on every trusted device',
        );
      }
      return const SizedBox.shrink();
    }).toList();
  }

  Widget _taskCard(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(color: _muted, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityLog() {
    final entries = mesh.log.reversed.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 10),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _logColor(e.kind),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(e.message,
                        style:
                            const TextStyle(color: _text, fontSize: 12.5)),
                  ),
                  Text('#${e.tick}',
                      style: const TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _logColor(String kind) => switch (kind) {
        'discover' => _accent,
        'pair' => _warn,
        'trust' => _good,
        'context' => _accent,
        'task' => _warn,
        'revoke' => const Color(0xFFE06C75),
        _ => _muted,
      };

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _good.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _good.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_rounded, color: _good, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Context is only ever shared with devices you have explicitly '
              'trusted. Nothing leaves the mesh, and you can revoke any device '
              'at any time.',
              style: TextStyle(
                  color: _text.withOpacity(0.85),
                  fontSize: 12,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
