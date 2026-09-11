import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'models.dart';
import 'storage.dart';

class HubShell extends StatefulWidget {
  const HubShell({super.key});

  @override
  State<HubShell> createState() => _HubShellState();
}

class _HubShellState extends State<HubShell> {
  int index = 0;

  static const destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
    NavigationDestination(icon: Icon(Icons.mic_none), label: 'Voice'),
    NavigationDestination(icon: Icon(Icons.image_outlined), label: 'Images'),
    NavigationDestination(icon: Icon(Icons.memory_outlined), label: 'Models'),
    NavigationDestination(icon: Icon(Icons.dns_outlined), label: 'Server'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
  ];

  static const pages = <Widget>[
    ChatPage(),
    VoicePage(),
    ImagesPage(),
    ModelsPage(),
    ServerPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (value) => setState(() => index = value),
                  extended: constraints.maxWidth >= 1180,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: _BrandMark(),
                  ),
                  destinations: destinations
                      .map((e) => NavigationRailDestination(
                            icon: e.icon,
                            label: Text(e.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[index]),
              ],
            ),
          );
        }

        return Scaffold(
          body: pages[index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: destinations,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
            ),
          ),
          child: const Icon(Icons.hub_outlined, color: Colors.white),
        ),
        const SizedBox(width: 10),
        const Text('Eburon Hub', style: TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const _BrandMark(),
                  const Spacer(),
                  _StatusPill(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(runtimeHealthProvider);
    final available = health.valueOrNull?.any((e) => e.available) ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: available ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 7),
          Text(available ? 'Native ready' : 'Core ready', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.title, this.trailing});

  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final controller = TextEditingController();
  final messages = <({bool user, String text})>[];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final llm = ref.read(modelsProvider).where((m) => m.type == ModelType.llm && m.loaded).toList();
    setState(() {
      messages.add((user: true, text: text));
      messages.add((
        user: false,
        text: llm.isEmpty
            ? 'Import and load a GGUF LLM from Models. The UI and server are ready; inference requires libeburon_runtime.'
            : 'LLM ${llm.first.name} is marked loaded. Native token streaming is delegated to the Eburon runtime bridge.',
      ));
    });
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Chat',
      subtitle: 'Local LLM conversations with streaming-ready architecture.',
      child: Column(
        children: [
          _SectionCard(
            child: SizedBox(
              height: 380,
              child: messages.isEmpty
                  ? const Center(child: Text('No conversation yet. Add a local model and start chatting.'))
                  : ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final message = messages[i];
                        return Align(
                          alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 620),
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: message.user
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(message.text),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => send(),
                  decoration: const InputDecoration(
                    hintText: 'Message your local model…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: send, icon: const Icon(Icons.arrow_upward)),
            ],
          ),
        ],
      ),
    );
  }
}

class VoicePage extends ConsumerWidget {
  const VoicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelsProvider);
    ModelDescriptor? loaded(ModelType type) {
      for (final model in models) {
        if (model.type == type && model.loaded) return model;
      }
      return null;
    }

    final stt = loaded(ModelType.stt);
    final llm = loaded(ModelType.llm);
    final tts = loaded(ModelType.tts);
    final ready = stt != null && llm != null && tts != null;

    return _Page(
      title: 'Voice',
      subtitle: 'Mic → VAD → STT → LLM stream → sentence queue → TTS → speaker.',
      child: Column(
        children: [
          _SectionCard(
            title: 'Pipeline',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PipelineChip('STT', stt?.name),
                const Icon(Icons.arrow_forward, size: 18),
                _PipelineChip('LLM', llm?.name),
                const Icon(Icons.arrow_forward, size: 18),
                _PipelineChip('TTS', tts?.name),
              ],
            ),
          ),
          _SectionCard(
            title: 'Realtime assistant',
            child: Column(
              children: [
                Icon(ready ? Icons.mic : Icons.mic_off, size: 72),
                const SizedBox(height: 10),
                Text(ready ? 'Voice runtime ready' : 'Load STT + LLM + TTS models first'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: ready ? () => _snack(context, 'Native voice session hooks are ready for the bridge implementation.') : null,
                  icon: const Icon(Icons.graphic_eq),
                  label: const Text('Start voice session'),
                ),
              ],
            ),
          ),
          const _SectionCard(
            title: 'Latency strategy',
            child: Text('LLM tokens are buffered only until a complete sentence/clause. TTS starts immediately, while the next sentence synthesizes in parallel into the PCM playback queue.'),
          ),
        ],
      ),
    );
  }
}

class _PipelineChip extends StatelessWidget {
  const _PipelineChip(this.label, this.model);
  final String label;
  final String? model;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(model == null ? Icons.circle_outlined : Icons.check_circle, size: 17),
      label: Text(model == null ? '$label · unloaded' : '$label · $model'),
    );
  }
}

class ImagesPage extends ConsumerStatefulWidget {
  const ImagesPage({super.key});

  @override
  ConsumerState<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends ConsumerState<ImagesPage> {
  final prompt = TextEditingController();
  final negative = TextEditingController();

  @override
  void dispose() {
    prompt.dispose();
    negative.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final imageModel = ref.watch(modelsProvider).where((m) => m.type == ModelType.image && m.loaded).toList();
    return _Page(
      title: 'Images',
      subtitle: 'Local txt2img/img2img through stable-diffusion.cpp.',
      child: Column(
        children: [
          _SectionCard(
            title: 'Generate',
            child: Column(
              children: [
                TextField(controller: prompt, maxLines: 4, decoration: const InputDecoration(labelText: 'Prompt', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: negative, maxLines: 2, decoration: const InputDecoration(labelText: 'Negative prompt', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('Size ${settings.imageSize} · ${settings.imageSteps} steps · CFG ${settings.imageCfg.toStringAsFixed(1)}')),
                    FilledButton.icon(
                      onPressed: imageModel.isEmpty ? null : () => _snack(context, 'Image request queued for ${imageModel.first.name}.'),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _SectionCard(
            title: 'Gallery',
            child: SizedBox(height: 180, child: Center(child: Text('Generated images will appear here.'))),
          ),
        ],
      ),
    );
  }
}

class ModelsPage extends ConsumerWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelsProvider);
    return _Page(
      title: 'Models',
      subtitle: 'Import the format required by each native runtime—not GGUF-only.',
      child: Column(
        children: ModelType.values.map((type) {
          final entries = models.where((m) => m.type == type).toList();
          return _SectionCard(
            title: _modelTypeTitle(type),
            trailing: FilledButton.tonalIcon(
              onPressed: () => _importModel(context, ref, type),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add model'),
            ),
            child: entries.isEmpty
                ? Text(_emptyModelHint(type))
                : Column(children: entries.map((m) => _ModelTile(model: m)).toList()),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _importModel(BuildContext context, WidgetRef ref, ModelType type) async {
    try {
      final model = await ref.read(modelsProvider.notifier).import(type: type);
      if (context.mounted && model != null) _snack(context, 'Imported ${model.name} → ${model.runtime.wireName}');
    } catch (error) {
      if (context.mounted) _snack(context, error.toString());
    }
  }
}

class _ModelTile extends ConsumerWidget {
  const _ModelTile({required this.model});
  final ModelDescriptor model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(_modelIcon(model.type))),
      title: Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${model.runtime.wireName} · ${model.format.wireName} · ${_bytes(model.sizeBytes)}${model.quantization == null ? '' : ' · ${model.quantization}'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model.isDefault) const Tooltip(message: 'Default model', child: Icon(Icons.star, size: 18)),
          Switch(
            value: model.loaded,
            onChanged: (_) async {
              try {
                await ref.read(modelsProvider.notifier).toggleLoaded(model.id);
              } catch (error) {
                if (context.mounted) _snack(context, error.toString());
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'default') await ref.read(modelsProvider.notifier).setDefault(model.id);
              if (value == 'delete') await ref.read(modelsProvider.notifier).delete(model.id);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'default', child: Text('Set default')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class ServerPage extends ConsumerWidget {
  const ServerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serverStateProvider);
    final settings = ref.watch(settingsProvider);
    final models = ref.watch(modelsProvider);
    final url = state.lanUrl ?? 'http://127.0.0.1:${settings.serverPort}';

    return _Page(
      title: 'Server',
      subtitle: 'Turn this phone or tablet into an OpenAI-compatible LAN AI server.',
      child: Column(
        children: [
          _SectionCard(
            title: 'API server',
            trailing: Switch(
              value: state.running,
              onChanged: (value) async {
                try {
                  if (value) {
                    await ref.read(serverStateProvider.notifier).start();
                  } else {
                    await ref.read(serverStateProvider.notifier).stop();
                  }
                } catch (error) {
                  if (context.mounted) _snack(context, error.toString());
                }
              },
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Status', state.running ? 'Running' : 'Stopped'),
                _kv('Requests', '${state.activeRequests} active'),
                if (state.lastRequest != null) _kv('Last', state.lastRequest!),
                if (state.error != null) Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
          _SectionCard(
            title: 'Loaded models',
            child: Column(
              children: ModelType.values.map((type) {
                final model = models.where((m) => m.type == type && m.loaded).toList();
                return _kv(_modelTypeTitle(type), model.isEmpty ? 'Unloaded' : model.first.name);
              }).toList(),
            ),
          ),
          _SectionCard(
            title: 'Security',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require API key'),
                  value: settings.requireApiKey,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setRequireApiKey(v),
                ),
                Row(
                  children: [
                    Expanded(child: SelectableText(settings.apiKey.isEmpty ? 'No API key generated' : settings.apiKey)),
                    IconButton(onPressed: settings.apiKey.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: settings.apiKey)), icon: const Icon(Icons.copy)),
                    FilledButton.tonal(onPressed: () => ref.read(settingsProvider.notifier).generateApiKey(), child: const Text('Generate')),
                  ],
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Network',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(url, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: url)), icon: const Icon(Icons.copy), label: const Text('Copy URL')),
                    OutlinedButton.icon(onPressed: state.running ? () => _testServer(context, url) : null, icon: const Icon(Icons.health_and_safety_outlined), label: const Text('Test server')),
                  ],
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Endpoints',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SelectableText('GET  /health\nGET  /v1/models\nGET  /v1/server/capabilities\nPOST /v1/chat/completions\nPOST /v1/completions\nPOST /v1/audio/transcriptions\nPOST /v1/audio/speech\nPOST /v1/images/generations\nWS   /v1/realtime/transcription\nWS   /v1/realtime/speech', style: TextStyle(fontFamily: 'monospace')),
              ],
            ),
          ),
          _SectionCard(
            title: 'cURL',
            child: SelectableText(
              "curl $url/v1/chat/completions -H 'Content-Type: application/json'${settings.requireApiKey ? " -H 'Authorization: Bearer ${settings.apiKey}'" : ''} -d '{\"model\":\"local\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":true}'",
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testServer(BuildContext context, String baseUrl) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/health'));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (context.mounted) _snack(context, 'HTTP ${response.statusCode}: $body');
    } catch (error) {
      if (context.mounted) _snack(context, 'Health check failed: $error');
    } finally {
      client.close(force: true);
    }
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return _Page(
      title: 'Settings',
      subtitle: 'Runtime defaults, local storage behavior and server policy.',
      child: Column(
        children: [
          _SectionCard(
            title: 'General',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: settings.themeMode,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: const [
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                  ],
                  onChanged: (v) { if (v != null) notifier.setTheme(v); },
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'LLM',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Context', '${settings.llmContextSize} tokens'),
                _kv('Threads', '${settings.llmThreads}'),
                _kv('GPU layers', '${settings.llmGpuLayers}'),
                _kv('Max tokens', '${settings.llmMaxTokens}'),
                _kv('Temperature', settings.llmTemperature.toStringAsFixed(2)),
                const SizedBox(height: 8),
                Text('System prompt: ${settings.systemPrompt}'),
              ],
            ),
          ),
          _SectionCard(
            title: 'STT / TTS',
            child: Column(
              children: [
                _kv('STT language', settings.sttLanguage),
                _kv('VAD', settings.sttVad ? 'On' : 'Off'),
                _kv('Silence timeout', '${settings.sttSilenceTimeoutMs} ms'),
                _kv('TTS voice', settings.ttsVoice),
                _kv('TTS speed', '${settings.ttsSpeed}×'),
                _kv('Sentence chunking', settings.ttsSentenceChunking ? 'On' : 'Off'),
              ],
            ),
          ),
          _SectionCard(
            title: 'Image generation',
            child: Column(
              children: [
                _kv('Size', settings.imageSize),
                _kv('Steps', '${settings.imageSteps}'),
                _kv('CFG', '${settings.imageCfg}'),
                _kv('Sampler', settings.imageSampler),
                _kv('Scheduler', settings.imageScheduler),
              ],
            ),
          ),
          _SectionCard(
            title: 'Server',
            child: Column(
              children: [
                TextFormField(
                  initialValue: settings.serverPort.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Port'),
                  onFieldSubmitted: (value) {
                    final port = int.tryParse(value);
                    if (port != null && port > 0 && port <= 65535) notifier.setServerPort(port);
                  },
                ),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('LAN access'), value: settings.lanAccess, onChanged: notifier.setLanAccess),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('CORS'), value: settings.cors, onChanged: notifier.setCors),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Start server automatically'), value: settings.autoStartServer, onChanged: notifier.setAutoStart),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _kv(String key, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(key)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );

String _modelTypeTitle(ModelType type) => switch (type) {
      ModelType.llm => 'LLM',
      ModelType.stt => 'STT',
      ModelType.tts => 'TTS',
      ModelType.image => 'Image Generation',
    };

IconData _modelIcon(ModelType type) => switch (type) {
      ModelType.llm => Icons.psychology_outlined,
      ModelType.stt => Icons.hearing_outlined,
      ModelType.tts => Icons.record_voice_over_outlined,
      ModelType.image => Icons.image_outlined,
    };

String _emptyModelHint(ModelType type) => switch (type) {
      ModelType.llm => 'Import a .gguf LLM for llama.cpp.',
      ModelType.stt => 'Import a sherpa-onnx .eburonmodel/.zip package or Whisper ggml-*.bin.',
      ModelType.tts => 'Import a Kokoro/Piper/VITS sherpa-onnx model package.',
      ModelType.image => 'Import .safetensors, .ckpt, image GGUF, or an .eburonmodel package.',
    };

String _bytes(int value) {
  if (value >= 1024 * 1024 * 1024) return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  if (value >= 1024 * 1024) return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  return '$value B';
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
