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
        splashFactory: InkRipple.splashFactory,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: VLibrasPlayerWidget(
                config: const VLibrasConfig(avatar: VLibrasAvatar.icaro),
                controller: _playerController,
                height: 220,
                avatarViewportHeight: 280,
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
            ),
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
  static const _primaryColor = Color(0xFF1351B4);

  // The VLibras content is 320 CSS px wide and scales by height / viewport.
  // The avatar's natural rendered width is height * (320 / viewport). The
  // avatar figure sits in the centre with empty scene space on the sides, so
  // we render it at full width and crop the sides to a narrower visible card —
  // trimming lateral space without shrinking the avatar (height untouched).
  static const double _avatarHeight = 240;
  static const double _avatarViewport = 280;
  static const double _avatarFullWidth =
      _avatarHeight * (320.0 / _avatarViewport);
  static const double _cardWidth = 200;

  final _textController = TextEditingController();
  late final LibrasKeyboardController _kbController;
  final _playerController = VLibrasPlayerController();
  bool _isReady = false;
  String _subtitle = 'Digite uma palavra e toque em ▶';
  VLibrasAvatar _avatar = VLibrasAvatar.guga;

  @override
  void initState() {
    super.initState();
    _kbController = LibrasKeyboardController(_textController);
    _playerController.eventStream.listen(_onEvent);
  }

  void _onEvent(VLibrasEvent e) {
    if (!mounted) return;
    if (e.type == VLibrasEventType.ready) {
      setState(() => _isReady = true);
    }
  }

  void _translate() {
    final t = _textController.text.trim();
    if (t.isNotEmpty) {
      setState(() => _subtitle = t);
      _playerController.translate(t);
    }
  }

  Future<void> _pickAvatar() async {
    final selected = await showModalBottomSheet<VLibrasAvatar>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Escolher avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...VLibrasAvatar.values.map(
              (avatar) => ListTile(
                title: Text(avatar.displayName),
                subtitle: Text(avatar.description),
                trailing: _avatar == avatar
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, avatar),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null && selected != _avatar && mounted) {
      setState(() {
        _avatar = selected;
        _isReady = false;
      });
    }
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
      appBar: AppBar(
        title: const Text('Teclado Libras + Player'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── VLibras panel card ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: _cardWidth,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                shadowColor: Colors.black26,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    ColoredBox(
                      color: _primaryColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: _pickAvatar,
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.settings,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.translate,
                                color: Colors.white, size: 20),
                            const Expanded(
                              child: Text(
                                'VLIBRAS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const Icon(Icons.info_outline,
                                color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                    // Avatar area
                    SizedBox(
                      height: _avatarHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Render the avatar at its full natural width and crop
                          // the empty side scene to the narrower card width.
                          ColoredBox(
                            color: Colors.white,
                            child: ClipRect(
                              child: OverflowBox(
                                // Negative x shifts the iframe content rightward
                                // within the cropped view.
                                alignment: const Alignment(0.70, 0),
                                minWidth: _avatarFullWidth,
                                maxWidth: _avatarFullWidth,
                                child: VLibrasPlayerWidget(
                                  config: VLibrasConfig(avatar: _avatar),
                                  controller: _playerController,
                                  width: _avatarFullWidth,
                                  height: _avatarHeight,
                                  avatarViewportHeight: _avatarViewport,
                                  borderRadius: BorderRadius.zero,
                                  onReady: () =>
                                      setState(() => _isReady = true),
                                ),
                              ),
                            ),
                          ),
                          if (!_isReady)
                            const ColoredBox(
                              color: Colors.white,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              elevation: 2,
                              child: InkWell(
                                onTap: () => _playerController.skip(),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.skip_next,
                                          size: 16, color: Colors.black87),
                                      SizedBox(width: 4),
                                      Text('Pular',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Subtitle bar
                    ColoredBox(
                      color: _primaryColor,
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Text(
                            _subtitle,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Input row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: _cardWidth,
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
                    onPressed: _translate,
                    style:
                        FilledButton.styleFrom(backgroundColor: _primaryColor),
                    child: const Icon(Icons.sign_language),
                  ),
                ],
              ),
            ),
          ),

          // ── Keyboard ──────────────────────────────────────────────────
          Flexible(
            child: LibrasKeyboard(controller: _kbController),
          ),
        ],
      ),
    );
  }
}
