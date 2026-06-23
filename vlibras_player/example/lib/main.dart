import 'package:flutter/material.dart';
import 'package:libras_keyboard/libras_keyboard.dart';
import 'package:vlibras_player/vlibras_player.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VLibras Player Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VLibras Player Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoCard(
            title: 'Player Inline',
            subtitle: 'Avatar VLibras embutido na tela',
            icon: Icons.play_circle_outline,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const _InlinePlayerPage())),
          ),
          const SizedBox(height: 12),
          _DemoCard(
            title: 'Overlay Button',
            subtitle: 'Botão flutuante de acessibilidade',
            icon: Icons.accessibility_new,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const _OverlayPage())),
          ),
          const SizedBox(height: 12),
          _DemoCard(
            title: 'Teclado Libras + Player',
            subtitle: 'Digite em datilologia e traduza',
            icon: Icons.keyboard,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _KeyboardWithPlayerPage())),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: cs.primary, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ── Inline player ─────────────────────────────────────────────────────────────

class _InlinePlayerPage extends StatefulWidget {
  const _InlinePlayerPage();

  @override
  State<_InlinePlayerPage> createState() => _InlinePlayerPageState();
}

class _InlinePlayerPageState extends State<_InlinePlayerPage> {
  final _textController = TextEditingController();
  final _playerController = VLibrasPlayerController();

  @override
  void dispose() {
    _textController.dispose();
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Player Inline')),
      body: Column(
        children: [
          VLibrasPlayerWidget(
            config: const VLibrasConfig(avatar: VLibrasAvatar.icaro),
            controller: _playerController,
            height: 340,
            onReady: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('VLibras pronto!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            onError: (msg) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro: $msg')),
              );
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Digite o texto para traduzir',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final text = _textController.text.trim();
                      if (text.isNotEmpty) {
                        _playerController.translate(text);
                      }
                    },
                    icon: const Icon(Icons.sign_language),
                    label: const Text('Traduzir em Libras'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overlay button ─────────────────────────────────────────────────────────────

class _OverlayPage extends StatelessWidget {
  const _OverlayPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay Button')),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 20,
            itemBuilder: (_, i) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text('Item de lista #${i + 1}'),
                subtitle: const Text(
                    'Toque no botão azul ↘ para abrir o player de Libras'),
              ),
            ),
          ),
          VLibrasOverlayButton(
            config: const VLibrasConfig(avatar: VLibrasAvatar.hosana),
            initialText: 'Bem-vindo ao leitor de Libras',
          ),
        ],
      ),
    );
  }
}

// ── Keyboard + player ─────────────────────────────────────────────────────────

class _KeyboardWithPlayerPage extends StatefulWidget {
  const _KeyboardWithPlayerPage();

  @override
  State<_KeyboardWithPlayerPage> createState() =>
      _KeyboardWithPlayerPageState();
}

class _KeyboardWithPlayerPageState extends State<_KeyboardWithPlayerPage> {
  final _textController = TextEditingController();
  late final LibrasKeyboardController _kbController;
  final _playerController = VLibrasPlayerController();

  @override
  void initState() {
    super.initState();
    _kbController = LibrasKeyboardController(_textController);
  }

  @override
  void dispose() {
    _textController.dispose();
    _kbController.dispose();
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teclado Libras + Player')),
      body: Column(
        children: [
          VLibrasPlayerWidget(
            config: const VLibrasConfig(avatar: VLibrasAvatar.guga),
            controller: _playerController,
            height: 300,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Texto digitado em Libras',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final t = _textController.text.trim();
                    if (t.isNotEmpty) _playerController.translate(t);
                  },
                  child: const Icon(Icons.sign_language),
                ),
              ],
            ),
          ),
          // Keyboard fills remaining space; no scroll needed (fixed height keys)
          Flexible(
            child: LibrasKeyboard(controller: _kbController),
          ),
        ],
      ),
    );
  }
}
