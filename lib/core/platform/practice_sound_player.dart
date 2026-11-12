import 'package:flutter/services.dart';

enum PracticeSound { correct, wrong, finished }

abstract class PracticeSoundPlayer {
  /// Plays [sound] at [volume], where 0 is silent and 1 is the maximum.
  Future<void> play(PracticeSound sound, {double volume = 1});
}

/// Plays a short native sound on Android.
///
/// The tones are app resources, so no third-party audio plugin is involved.
/// Their WAV files carry a +6 dB (2× amplitude) boost over the original cues,
/// and both this channel and SoundPool clamp the volume to 0..1. That keeps
/// the boosted playback below full scale, so it is louder without clipping.
/// Other platforms and tests fall back to silence.
class MethodChannelPracticeSoundPlayer implements PracticeSoundPlayer {
  MethodChannelPracticeSoundPlayer([MethodChannel? channel])
    : _channel =
          channel ?? const MethodChannel('link.nzrs.questionpractice/sounds');

  final MethodChannel _channel;

  @override
  Future<void> play(PracticeSound sound, {double volume = 1}) async {
    try {
      await _channel.invokeMethod<void>('play', {
        'sound': sound.name,
        'volume': volume.clamp(0.0, 1.0),
      });
    } on PlatformException {
      // Sound is a nicety; playback failures must not block practice.
    } on MissingPluginException {
      // Desktop and test builds have no native sound channel.
    }
  }
}

class SilentPracticeSoundPlayer implements PracticeSoundPlayer {
  const SilentPracticeSoundPlayer();

  @override
  Future<void> play(PracticeSound sound, {double volume = 1}) async {}
}
