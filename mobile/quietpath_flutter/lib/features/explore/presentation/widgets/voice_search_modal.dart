import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/core/widgets/quietpath_logo.dart';
import 'package:quietpath_flutter/features/navigation/services/tts_service.dart';

/// Sensory-optimized Voice Search Modal with real-time Speech-to-Text,
/// animated acoustic pulse waves, and low-stimulation vocal prompts.
class VoiceSearchModal extends StatefulWidget {
  final String? initialQuery;

  const VoiceSearchModal({super.key, this.initialQuery});

  /// Static helper to display the modal and return recognized destination text.
  static Future<String?> show(BuildContext context, {String? initialQuery}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceSearchModal(initialQuery: initialQuery),
    );
  }

  @override
  State<VoiceSearchModal> createState() => _VoiceSearchModalState();
}

class _VoiceSearchModalState extends State<VoiceSearchModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late TextEditingController _textController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _statusText = 'Listening with calm sensitivity...';

  final List<String> _calmSuggestions = [
    'Amanora Mall',
    'Empress Botanical Garden',
    'Kamala Nehru Park',
    'Quiet Park Nearby',
    'Phoenix Marketcity',
    'Shaniwar Wada',
    'Westend Mall Aundh',
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialQuery ?? '');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Initial gentle sensory voice prompt
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        TtsService().speakCalm('Listening. Where would you like to walk?');
      }
    });

    // Initialize real on-device hardware microphone speech recognizer
    _initAndStartSpeech();
  }

  Future<void> _initAndStartSpeech() async {
    try {
      // 1. Check and request native microphone runtime permission
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }

      // 2. Initialize the platform speech recognition engine
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (err) => _onSpeechError(err.errorMsg),
        debugLogging: false,
      );

      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });

        if (available) {
          await _startListening();
        } else {
          setState(() {
            _isListening = false;
            _statusText = 'Tap mic to speak or choose below';
            _pulseController.stop();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _speechAvailable = false;
          _isListening = false;
          _statusText = 'Tap mic to speak or choose below';
          _pulseController.stop();
        });
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'listening') {
      setState(() {
        _isListening = true;
        _statusText = 'Listening with calm sensitivity...';
      });
      _pulseController.repeat(reverse: true);
    } else if (status == 'notListening' || status == 'done') {
      setState(() {
        _isListening = false;
        if (_textController.text.trim().isNotEmpty) {
          _statusText = 'Destination captured';
        } else {
          _statusText = 'Tap mic to speak or choose below';
        }
      });
      _pulseController.stop();
    }
  }

  void _onSpeechError(String errorMsg) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _statusText = 'Didn\'t catch that. Tap mic or choose below';
    });
    _pulseController.stop();
  }

  Future<void> _startListening() async {
    try {
      if (!_speechAvailable) {
        final available = await _speech.initialize(
          onStatus: _onSpeechStatus,
          onError: (err) => _onSpeechError(err.errorMsg),
        );
        _speechAvailable = available;
        if (!available) {
          setState(() {
            _statusText = 'Speech service not ready. Type or choose below.';
          });
          return;
        }
      }

      setState(() {
        _isListening = true;
        _statusText = 'Listening with calm sensitivity...';
      });
      _pulseController.repeat(reverse: true);

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!mounted) return;
          setState(() {
            _textController.text = result.recognizedWords;
          });

          // Auto-select when final result has recognized destination
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _selectDestination(result.recognizedWords.trim());
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.search,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = 'Tap mic to speak or choose below';
          _pulseController.stop();
        });
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusText = 'Tap mic to speak or choose below';
        _pulseController.stop();
      });
    }
  }

  @override
  void dispose() {
    try {
      _speech.stop();
    } catch (_) {}
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _selectDestination(String text) {
    HapticFeedback.mediumImpact();
    setState(() {
      _textController.text = text;
      _isListening = false;
      _statusText = 'Destination selected';
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        Navigator.of(context).pop(text);
      }
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset > 0 ? bottomInset + 16 : 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE2DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const QuietPathLogo(size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Sensory Voice Search',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: QuietColors.primaryDark,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: QuietColors.textMuted, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Acoustic Pulsing Wave Rings Visualizer
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _isListening ? 1.0 + (_pulseController.value * 0.18) : 1.0;
              final outerScale = _isListening ? 1.0 + (_pulseController.value * 0.35) : 1.0;
              final waveAlpha = _isListening ? (0.25 - (_pulseController.value * 0.18)).clamp(0.04, 0.25) : 0.04;

              return SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ripple
                    Transform.scale(
                      scale: outerScale,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: QuietColors.primary.withValues(alpha: waveAlpha),
                        ),
                      ),
                    ),
                    // Inner ripple
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: QuietColors.primaryLight.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    // Center Mic Button
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isListening
                                ? [QuietColors.primaryDark, QuietColors.primary]
                                : [const Color(0xFF6B7280), const Color(0xFF4B5563)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isListening
                                  ? QuietColors.primary.withValues(alpha: 0.4)
                                  : Colors.black12,
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Status indication
          Text(
            _statusText,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isListening ? QuietColors.primaryDark : QuietColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Speak clearly or tap a calm suggested destination below',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: QuietColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Manual speech query input field with instant search button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDFE5DF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: QuietColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: GoogleFonts.inter(fontSize: 14, color: QuietColors.textCharcoal),
                    decoration: InputDecoration(
                      hintText: 'Type or speak destination...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: QuietColors.textMuted),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _selectDestination(val.trim());
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: QuietColors.primaryDark, size: 20),
                  onPressed: () {
                    final text = _textController.text.trim();
                    if (text.isNotEmpty) {
                      _selectDestination(text);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Rapid Calm Destination Chips
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rapid Calm Prompts',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: QuietColors.textCharcoal,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _calmSuggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.volume_up_rounded, size: 14, color: QuietColors.primaryDark),
                    label: Text(
                      suggestion,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: QuietColors.textCharcoal,
                      ),
                    ),
                    backgroundColor: const Color(0xFFEDF4ED),
                    side: const BorderSide(color: Color(0xFFCCE0CB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () => _selectDestination(suggestion),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
