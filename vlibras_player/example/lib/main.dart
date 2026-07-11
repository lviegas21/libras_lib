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

  // Component sized to the avatar frame only (no unused side chrome).
  static const double _maxFrameWidth = 170;
  static const double _maxFrameHeight = 220;
  static const double _stageHeightFraction = 0.26;

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

  ({double frameWidth, double frameHeight}) _layoutFor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final stage = vlibrasAvatarStage(
      maxWidth: _maxFrameWidth,
      maxHeight:
          (size.height * _stageHeightFraction).clamp(170.0, _maxFrameHeight),
    );
    // Card == frame: no empty white band beside the WebView.
    return (frameWidth: stage.width, frameHeight: stage.height);
  }

  Widget _buildCard(double frameWidth, double frameHeight) {
    const radius = 12.0;
    return SizedBox(
      width: frameWidth,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(radius)),
              child: ColoredBox(
                color: _primaryColor,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _pickAvatar,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.settings,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'VLIBRAS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Icon(Icons.info_outline,
                          color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            // WebView fills the frame exactly — component width = avatar width.
            SizedBox(
              height: frameHeight,
              width: frameWidth,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VLibrasPlayerWidget.avatarOnly(
                    config: VLibrasConfig(avatar: _avatar),
                    controller: _playerController,
                    height: frameHeight,
                    visibleWidth: frameWidth,
                    onReady: () => setState(() => _isReady = true),
                  ),
                  if (!_isReady)
                    const ColoredBox(
                      color: Colors.white,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _playerController.skip(),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.skip_next,
                                  size: 14, color: Colors.black87),
                              SizedBox(width: 2),
                              Text('Pular',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.black87)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(radius)),
              child: ColoredBox(
                color: _primaryColor,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      _subtitle,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layoutFor(context);
    final frameWidth = layout.frameWidth;
    final frameHeight = layout.frameHeight;
    // Input stays usable even when the avatar frame is compact.
    final inputWidth =
        (MediaQuery.sizeOf(context).width * 0.85).clamp(frameWidth, 360.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teclado Libras + Player'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Spacer(),
                  _buildCard(frameWidth, frameHeight),
                  const Spacer(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: inputWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Texto digitado em Libras',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _translate,
                          style: FilledButton.styleFrom(
                              backgroundColor: _primaryColor),
                          child: const Icon(Icons.sign_language),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: ClipRect(
                child: LibrasKeyboard(controller: _kbController),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
