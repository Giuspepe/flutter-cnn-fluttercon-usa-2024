import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

enum Gesture {
  call,
  dislike,
  fist,
  four,
  like,
  mute,
  noGesture,
  ok,
  one,
  palm,
  peace,
  peaceInverted,
  rock,
  stop,
  stopInverted,
  three,
  three2,
  twoUp,
  twoUpInverted;

  // Method to create an enum instance from a prediction tensor (returns highest probability class)
  static Gesture predictedByTensor(List<List<double>> output) {
    final classProbabilities = output[0];
    var maxKey = 0;
    var maxValue = -double.infinity;

    for (final (index, value) in classProbabilities.indexed) {
      if (value > maxValue) {
        maxValue = value;
        maxKey = index;
      }
    }

    return Gesture.values[maxKey];
  }
}

final gestureDetectionResultProvider =
    NotifierProvider<GestureDetectionNotifier, AsyncValue<Gesture>>(
        () => GestureDetectionNotifier());

final modelIsolateInterpreterProvider =
    FutureProvider<IsolateInterpreter>((ref) async {
  final interpreter = await Interpreter.fromAsset('assets/mobilenetv3.tflite');
  return IsolateInterpreter.create(address: interpreter.address);
});

final lastPlayerImage = StateProvider<File?>((ref) => null);

class GestureDetectionNotifier extends Notifier<AsyncValue<Gesture>> {
  late Future<IsolateInterpreter> _isolateInterpreterFuture;

  @override
  AsyncValue<Gesture> build() {
    _isolateInterpreterFuture =
        ref.watch(modelIsolateInterpreterProvider.future);

    return const AsyncValue.loading();
  }

  Future<void> predictGesture(File imageFile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Preprocess the image file to get the input tensor for the model
      final inputTensor = await preprocessImage(imageFile);
      // Run inference with the preprocessed input tensor
      final outputTensor = [List<double>.filled(19, 0)];
      final isolateInterpreter = await _isolateInterpreterFuture;
      await isolateInterpreter.run(inputTensor, outputTensor);
      ref.read(lastPlayerImage.notifier).state = imageFile;
      // Return the gesture from the prediction tensor
      return Gesture.predictedByTensor(outputTensor);
    });
  }
}

// Preprocess image file to get the input tensor for the model
Future<List> preprocessImage(File imageFile) {
  return compute<File, List>((imageFile) async {
    const channels = 3;
    const width = 300;
    const height = 300;

    // Load the image from the file
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Unable to decode image');
    }

    // Resize the image to 300x300
    img.Image resized = img.copyResize(image, width: width, height: height);

    // Get the pixel data as List<int> in RGB format (Uint8List for 300x300x3)
    List<int> pixels = resized.getBytes(order: img.ChannelOrder.rgb);

    // Convert the pixel data to Float32List and normalize
    Float32List floatPixels = Float32List.fromList(
      pixels.map((pixel) => pixel.toDouble() / 255).toList(),
    );

    // Convert the pixel data to CHW format
    final rearrangedPixels =
        rearrangeHWCToCHW(floatPixels, width, height, channels);

    // Reshape flat Float32List to 4D tensor [1, 3, 300, 300]
    final inputTensor = rearrangedPixels
        .reshape([1, 3, 300, 300]); // Reshape to [1, 3, 300, 300]

    return inputTensor;
  }, imageFile);
}

// Image data is stored in HWC format: Height x Width x Channels
// I.e. for each pixel, the RGB values are stored sequentially
// But neural networks like MobileNetV3 expect the data in CHW format: Channels x Height x Width.
// So we need to rearrange the pixel data so that all pixels for the cth channel are stored contiguously (so first all red pixels, then all green pixels, then all blue pixels)
Float32List rearrangeHWCToCHW(
    Float32List array, int width, int height, int channels) {
  Float32List newArray = Float32List(channels * width * height);

  for (int i = 0; i < width * height; i++) {
    for (int c = 0; c < channels; c++) {
      newArray[c * width * height + i] = array[i * channels + c];
    }
  }

  return newArray;
}
