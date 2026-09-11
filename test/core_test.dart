import 'dart:async';

import 'package:eburon_hub/src/models.dart';
import 'package:eburon_hub/src/runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ModelDescriptor round-trips runtime and format independently', () {
    const model = ModelDescriptor(
      id: 'qwen-local',
      name: 'Qwen Local',
      type: ModelType.llm,
      runtime: RuntimeKind.llamaCpp,
      architecture: 'qwen',
      format: ModelFormat.gguf,
      sizeBytes: 1234,
      path: '/models/qwen.gguf',
      languages: ['en'],
      quantization: 'Q4_K_M',
      capabilities: ['chat', 'streaming'],
    );

    final restored = ModelDescriptor.fromJson(model.toJson());
    expect(restored.id, model.id);
    expect(restored.type, ModelType.llm);
    expect(restored.runtime, RuntimeKind.llamaCpp);
    expect(restored.format, ModelFormat.gguf);
    expect(restored.quantization, 'Q4_K_M');
  });

  test('wire parsing keeps Whisper separate from llama.cpp GGUF', () {
    expect(RuntimeKindWire.fromWire('whisper.cpp'), RuntimeKind.whisperCpp);
    expect(ModelFormatWire.fromWire('ggml-bin'), ModelFormat.ggmlBin);
    expect(RuntimeKindWire.fromWire('llama.cpp'), RuntimeKind.llamaCpp);
    expect(ModelFormatWire.fromWire('gguf'), ModelFormat.gguf);
  });

  test('queued scheduler request can be cancelled without hanging', () async {
    final scheduler = InferenceScheduler();
    final gate = Completer<void>();

    final first = scheduler.schedule<void>(
      id: 'first',
      label: 'blocking',
      priority: InferencePriority.sttRealtime,
      task: (_) => gate.future,
    );

    final second = scheduler.schedule<String>(
      id: 'second',
      label: 'queued',
      priority: InferencePriority.imageGeneration,
      task: (_) async => 'should-not-run',
    );

    scheduler.cancel('second');
    await expectLater(second, throwsA(isA<InferenceCancelledException>()));

    gate.complete();
    await first;
    await scheduler.dispose();
  });
}
