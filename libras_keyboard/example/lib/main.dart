import 'package:flutter/material.dart';
import 'package:libras_keyboard/libras_keyboard.dart';

void main() {
  runApp(const LibrasKeyboardExampleApp());
}

class LibrasKeyboardExampleApp extends StatelessWidget {
  const LibrasKeyboardExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libras Keyboard Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libras Keyboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.sign_language,
              title: 'Teclado com SVGs embutidos',
              subtitle:
                  'Toque no ícone de Libras ao lado do campo para abrir o teclado.',
            ),
            const SizedBox(height: 12),

            // --- Example 1: bundled SVG builder (default) ---
            LibrasTextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Digite usando Libras',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 24),

            _SectionHeader(
              icon: Icons.edit_note,
              title: 'Múltiplas linhas',
              subtitle: 'O teclado funciona em campos de texto multi-linha.',
            ),
            const SizedBox(height: 12),

            // --- Example 2: multiline ---
            LibrasTextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mensagem',
                hintText: 'Digite sua mensagem...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.message_outlined),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _SectionHeader(
              icon: Icons.palette_outlined,
              title: 'Builder personalizado',
              subtitle:
                  'Substitua os SVGs embutidos por suas próprias imagens ou widgets.',
            ),
            const SizedBox(height: 12),

            // --- Example 3: custom builder (text fallback for demo) ---
            LibrasTextField(
              controller: TextEditingController(),
              letterBuilder: _customLetterBuilder,
              decoration: const InputDecoration(
                labelText: 'Builder customizado',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            _CodeSnippet(),
          ],
        ),
      ),
    );
  }
}

/// Custom builder example: renders a colored circle with the letter.
/// Replace with Image.asset(...) or SvgPicture.asset(...) in a real app.
Widget _customLetterBuilder(String letter, bool isPressed) {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: isPressed ? Colors.teal.shade700 : Colors.teal.shade100,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      letter.toUpperCase(),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isPressed ? Colors.white : Colors.teal.shade800,
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CodeSnippet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uso básico',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LibrasTextField(\n'
            '  controller: myController,\n'
            '  decoration: InputDecoration(\n'
            '    labelText: \'Campo Libras\',\n'
            '  ),\n'
            ')',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
