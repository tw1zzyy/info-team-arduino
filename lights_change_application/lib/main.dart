import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const LedControllerApp());
}

class LedControllerApp extends StatelessWidget {
  const LedControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const LoginPage(),
    );
  }
}

class UserAccount {
  final String username;
  final String password;
  final String role;
  Set<int> allowed;

  UserAccount(this.username, this.password, this.role, this.allowed);
}

final List<UserAccount> accounts = [
  UserAccount('admin', 'admin123', 'admin', {0, 1, 2, 3, 4, 5, 6, 7, 8}),
  UserAccount('user1', 'u1pass', 'user', {0, 1}),
  UserAccount('user2', 'u2pass', 'user', {2, 3}),
  UserAccount('user3', 'u3pass', 'user', {4, 5}),
];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  String? _error;

  void _login() {
    final u = _userController.text.trim();
    final p = _passController.text.trim();

    final acc = accounts.firstWhere(
      (a) => a.username == u && a.password == p,
      orElse: () => UserAccount('', '', '', {}),
    );

    if (acc.username.isEmpty) {
      setState(() => _error = 'Wrong login or password');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ControllerPage(account: acc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authorization')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _login, child: const Text('Login')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

class ControllerPage extends StatefulWidget {
  final UserAccount account;
  const ControllerPage({required this.account, super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;
  bool scanning = false;
  bool connecting = false;

  Future<void> scan() async {
    setState(() => scanning = true);
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((event) async {
      for (var r in event) {
        if (r.device.name == 'HC-05') {
          device = r.device;
          FlutterBluePlus.stopScan();
          setState(() => scanning = false);
          await connect();
          break;
        }
      }
    });
  }

  Future<void> connect() async {
    if (device == null) return;
    setState(() => connecting = true);

    try {
      await device!.connect(autoConnect: false);
    } catch (_) {}

    final services = await device!.discoverServices();

    for (var s in services) {
      for (var c in s.characteristics) {
        if (c.properties.write) {
          characteristic = c;
        }
      }
    }

    setState(() => connecting = false);
  }

  Future<void> send(int index) async {
    if (characteristic == null) return;
    await characteristic!.write([index]);
  }

  void _openAdminPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPanel(onUpdate: () => setState(() {})),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User: ${widget.account.username}'),
        actions: [
          if (widget.account.role == 'admin')
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openAdminPanel,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              device?.disconnect();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: scanning ? null : scan,
            child: Text(scanning ? 'Scanning...' : 'Scan for HC-05'),
          ),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 9,
              itemBuilder: (c, i) {
                final allowed =
                    widget.account.allowed.contains(i) ||
                    widget.account.role == 'admin';
                return ElevatedButton(
                  onPressed: allowed ? () => send(i) : null,
                  child: Text('LED ${i + 2}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPanel extends StatefulWidget {
  final VoidCallback onUpdate;
  const AdminPanel({required this.onUpdate, super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Permissions')),
      body: ListView.builder(
        itemCount: accounts.length,
        itemBuilder: (c, idx) {
          final acc = accounts[idx];
          if (acc.role == 'admin') return const SizedBox();

          return ExpansionTile(
            title: Text(acc.username),
            children: [
              Wrap(
                spacing: 8,
                children: List.generate(9, (i) {
                  final enabled = acc.allowed.contains(i);
                  return FilterChip(
                    label: Text('LED ${i + 2}'),
                    selected: enabled,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          acc.allowed.add(i);
                        } else {
                          acc.allowed.remove(i);
                        }
                      });
                      widget.onUpdate();
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
