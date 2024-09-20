import 'dart:io';

import 'package:rock_paper_scissors_demo_app/game_logic.dart';
import 'package:rock_paper_scissors_demo_app/inference.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lizardSpockEnabled = ref.watch(
        gameStateNotifierProvider.select((state) => state.lizardSpockEnabled));
    return Scaffold(
      appBar: AppBar(
        title: Text('🪨 📄 ✂️ ${lizardSpockEnabled ? ' 🦎 🖖' : ''}'),
        actions: [
          IconButton(
            icon: Icon(lizardSpockEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              ref.read(gameStateNotifierProvider.notifier).toggleLizardSpock();
            },
          ),
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: () =>
                ref.read(_cameraControllerProvider.notifier).switchCamera(),
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final gameState = ref.watch(gameStateNotifierProvider);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text("Round:\t${gameState.roundNumber}"),
                    Text(
                        "Scores:\t${gameState.playerScore} (Player) - ${gameState.computerScore} (Computer)"),
                    gameState.playerMove == null ||
                            gameState.computerMove == null
                        ? const Text("Moves:")
                        : Text(
                            "Moves:\t${gameState.playerMove!.emoji} (Player) - ${gameState.computerMove!.emoji} (Computer)"),
                    Text(gameState.roundMessage ?? ""),
                  ],
                ),
              ),
              const Expanded(child: Center(child: VideoFeed())),
              ElevatedButton(
                  onPressed: () async {
                    final cameraController =
                        ref.read(_cameraControllerProvider).value;
                    if (cameraController == null) return;
                    final file = await cameraController.takePicture();

                    ref
                        .read(gestureDetectionResultProvider.notifier)
                        .predictGesture(File(file.path));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 24)),
                  child: const Text('Play round')),
              Consumer(builder: (context, ref, _) {
                final predictedGesture =
                    ref.watch(gestureDetectionResultProvider);
                return Text(predictedGesture.map(
                  data: (data) => 'Predicted gesture: ${data.value.name}',
                  error: (error) => 'Error: ${error.error}',
                  loading: (_) => 'Loading ...',
                ));
              })
            ],
          );
        },
      ),
    );
  }
}

class VideoFeed extends ConsumerStatefulWidget {
  const VideoFeed({super.key});

  @override
  VideoFeedState createState() => VideoFeedState();
}

class VideoFeedState extends ConsumerState<VideoFeed> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(_cameraControllerProvider).value;
    return (controller?.value.isInitialized ?? false)
        ? CameraPreview(controller!)
        : const Center(child: CircularProgressIndicator());
  }
}

final _cameraControllerProvider = AsyncNotifierProvider.autoDispose<
    _CameraControllerNotifier, CameraController?>(
  () => _CameraControllerNotifier(),
);

class _CameraControllerNotifier
    extends AutoDisposeAsyncNotifier<CameraController?> {
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;

  @override
  Future<CameraController?> build() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      print('Warning: There are no cameras available :(');
      return null;
    }

    _selectedCamera = _cameras.first;
    final controller =
        CameraController(_selectedCamera!, ResolutionPreset.high);
    await controller.initialize();

    ref.onDispose(controller.dispose);

    return controller;
  }

  Future<void> switchCamera() async {
    if (_cameras.isNotEmpty) {
      state = const AsyncValue.loading();
      _selectedCamera =
          (_selectedCamera == _cameras.first) ? _cameras.last : _cameras.first;
      final controller =
          CameraController(_selectedCamera!, ResolutionPreset.high);
      await controller.initialize();

      ref.onDispose(controller.dispose);
      state = AsyncValue.data(controller);
    }
  }
}
