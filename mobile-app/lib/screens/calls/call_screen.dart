import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:js' as js;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/webrtc_service.dart';
import '../../services/sidecar_service.dart';
import '../security/security_report_screen.dart';
import '../../theme/design_system.dart';

class CallScreen extends StatefulWidget {
  final UserModel currentUser;
  final String targetAegisId;
  final bool isIncoming;
  final RTCSessionDescription? offer;
  final String? callId;

  const CallScreen({
    Key? key,
    required this.currentUser,
    required this.targetAegisId,
    this.isIncoming = false,
    this.offer,
    this.callId,
  }) : super(key: key);

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  final SidecarService _sidecarService = SidecarService();

  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _rendererReady = false;

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  double _threatScore = 0.0;
  double _syntheticProbability = 0.0;
  double _pitchVariance = 0.0;
  double _speakingRate = 0.0;
  double _semanticThreatProbability = 0.0;
  bool _isIntercepted = false;
  bool _callEnded = false;
  String _callStatus = 'Connecting...';
  List<Map<String, String>> _transcript = [];

  final TextEditingController _victimInputController = TextEditingController();
  DateTime? _lastSpeechStartTime;
  int _lastSpeechDurationMs = 0;

  // Speech Recognition
  js.JsObject? _recognition;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _setupAndCall();
  }

  Future<void> _setupAndCall() async {
    // 1. Init renderer
    await _remoteRenderer.initialize();
    setState(() => _rendererReady = true);

    // 2. Callback: remote stream arrives → attach to renderer
    _webRTCService.onAddRemoteStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
        _callStatus = 'Connected';
      });
    };

    // 3. Callback: remote party hung up
    _webRTCService.onCallEnded = () {
      if (mounted && !_callEnded) {
        _onRemoteHangup();
      }
    };

    // 4. Initiate or answer call
    try {
      if (widget.isIncoming && widget.offer != null && widget.callId != null) {
        setState(() => _callStatus = 'Answering...');
        await _webRTCService.answerCall(widget.callId!, widget.offer!);
        setState(() => _callStatus = 'Connected');
      } else {
        setState(() => _callStatus = 'Ringing...');
        await _webRTCService.makeCall(
            widget.currentUser.aegisId, widget.targetAegisId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _callStatus = 'Failed: $e');
        print('[CallScreen] Error: $e');
      }
    }

    // 5. Connect Detection Sidecar (silently — fail if not running)
    try {
      _sidecarService.connect('ws://localhost:8000/ws/audio');
      // Handshake: callee MUST be the victim (USER-5722)
      final victimId = widget.isIncoming ? widget.currentUser.aegisId : widget.targetAegisId;
      final scammerId = widget.isIncoming ? widget.targetAegisId : widget.currentUser.aegisId;
      _sidecarService.sendHandshake(
        scammerId,
        victimId,
      );
      _sidecarService.onThreatScoreUpdate = (score) {
        if (mounted) setState(() => _threatScore = score);
      };
      _sidecarService.onRiskStateUpdate = (state) {
        if (mounted) {
          setState(() {
            _syntheticProbability = (state['synthetic_probability'] as num?)?.toDouble() ?? 0.0;
            _pitchVariance = (state['temporal_variance'] as num?)?.toDouble() ?? 0.0;
            _semanticThreatProbability = (state['semantic_threat_probability'] as num?)?.toDouble() ?? 0.0;
            _speakingRate = (state['speaking_rate'] as num?)?.toDouble() ?? 0.0;
          });
        }
      };
      _sidecarService.onIntercept = (data) {
        if (!mounted) return;
        setState(() {
          _isIntercepted = true;
          _isMuted = true;
        });
        _webRTCService.toggleMicrophone(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("🛡️ Evelyn intercepted the call: ${data['reason']}", style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ));
      };
      _sidecarService.onTranscriptUpdate = (speaker, text) {
        if (mounted) {
          setState(() => _transcript.add({'speaker': speaker, 'text': text}));
        }
      };
      _sidecarService.onCallReport = (report) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          AegisPageTransition.fadeTransition(SecurityReportScreen(report: report)),
        );
      };
      // Wire up browser TTS for scammer and Evelyn voices
      _sidecarService.onSpeech = (text, isEvelyn) {
        _speakText(text, isEvelyn: isEvelyn);
      };
    } catch (_) {
      print('[CallScreen] Sidecar not available — skipping.');
    }

    // 6. Initialize Victim Speech Recognition
    _initSpeechRecognition();
  }

  void _initSpeechRecognition() {
    try {
      if (js.context.hasProperty('webkitSpeechRecognition')) {
        _recognition = js.JsObject(js.context['webkitSpeechRecognition']);
        _recognition!['continuous'] = true;
        _recognition!['interimResults'] = false;
        _recognition!['lang'] = 'en-US';

        _recognition!['onresult'] = js.allowInterop((event) {
          final jsEvent = js.JsObject.fromBrowserObject(event);
          final results = jsEvent['results'] as js.JsObject;
          final lastResultIndex = jsEvent['resultIndex'] as int;
          final lastResult = results[lastResultIndex] as js.JsObject;
          final isFinal = lastResult['isFinal'] as bool;

          if (isFinal) {
            final transcript = (lastResult[0] as js.JsObject)['transcript'] as String;
            _onVictimSpeech(transcript.trim());
          }
        });

        _recognition!['onerror'] = js.allowInterop((event) {
          final jsEvent = js.JsObject.fromBrowserObject(event);
          print('[SpeechRecognition] Error: ${jsEvent['error']}');
        });

        _recognition!['onend'] = js.allowInterop((event) {
          if (_isListening && !_isIntercepted && !_callEnded) {
            // Restart if it stopped unexpectedly but should still be listening
            _recognition?.callMethod('start', []);
          }
        });

        _startListening();
      } else {
        print('[SpeechRecognition] Not supported in this browser.');
      }
    } catch (e) {
      print('[SpeechRecognition] Setup error: $e');
    }
  }

  void _startListening() {
    if (_recognition != null && !_isListening && !_isIntercepted) {
      _isListening = true;
      try {
        _recognition!.callMethod('start', []);
      } catch (e) {
        print('[SpeechRecognition] Start error: $e');
      }
    }
  }

  void _stopListening() {
    if (_recognition != null && _isListening) {
      _isListening = false;
      try {
        _recognition!.callMethod('stop', []);
      } catch (e) {
        print('[SpeechRecognition] Stop error: $e');
      }
    }
  }

  void _onVictimSpeech(String text) {
    final cleanText = text.trim();
    if (cleanText.isEmpty || cleanText.length < 2 || _isIntercepted) return;
    
    // Add to local transcript immediately
    setState(() {
      _transcript.add({'speaker': 'YOU', 'text': cleanText});
    });

    // Send to detection server
    _sidecarService.sendUserSpeech(cleanText);
  }

  /// Uses the browser's Web Speech API with non-overlapping speech delay and female Evelyn voice.
  void _speakText(String text, {bool isEvelyn = false}) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    try {
      final synth = js.context['speechSynthesis'];
      if (synth == null) return;

      _executeSpeak(cleanText, isEvelyn: isEvelyn, durationMs: 0);
    } catch (e) {
      print('[CallScreen] TTS error: $e');
    }
  }

  void _executeSpeak(String text, {required bool isEvelyn, required int durationMs}) {
    try {
      final synth = js.context['speechSynthesis'];
      if (synth == null) return;

      _lastSpeechStartTime = DateTime.now();
      _lastSpeechDurationMs = durationMs;

      final utterance = js.JsObject(js.context['SpeechSynthesisUtterance'], [text]);
      
      // Female voice tuning for Evelyn (warm female pitch, natural rate)
      // Scammer voice tuning (lower pitch)
      utterance['rate']   = isEvelyn ? 0.92 : 0.88;
      utterance['pitch']  = isEvelyn ? 1.15 : 0.85;
      utterance['volume'] = 1.0;

      // Find female voice for Evelyn and male voice for Scammer
      final voices = synth.callMethod('getVoices', []) as js.JsArray?;
      if (voices != null && voices.length > 0) {
        js.JsObject? selectedVoice;
        
        final femaleKeywords = [
          'zira', 'hazel', 'eva', 'susan', 'jenny', 'aria',
          'samantha', 'victoria', 'karen', 'fiona', 'moira', 'veena',
          'female', 'woman', 'google us english', 'natural'
        ];
        
        final maleKeywords = [
          'david', 'mark', 'george', 'richard', 'james', 'guy',
          'stefan', 'male', 'man', 'google uk english male'
        ];

        for (var i = 0; i < voices.length; i++) {
          final voice = voices[i] as js.JsObject;
          final name = (voice['name'] as String).toLowerCase();

          if (isEvelyn) {
            if (femaleKeywords.any((k) => name.contains(k))) {
              selectedVoice = voice;
              break;
            }
          } else {
            if (maleKeywords.any((k) => name.contains(k))) {
              selectedVoice = voice;
              break;
            }
          }
        }

      if (selectedVoice != null) {
          utterance['voice'] = selectedVoice;
        }
      }

      if (isEvelyn) {
        utterance['onend'] = js.allowInterop((_) {
          _sidecarService.sendEvelynTtsEnd();
        });
      }

      synth.callMethod('speak', [utterance]);
    } catch (e) {
      print('[CallScreen] _executeSpeak error: $e');
    }
  }

  void _onRemoteHangup() {
    _stopListening();
    setState(() => _callEnded = true);
    showAegisDialog(
      context: context,
      child: Center(
        child: AegisGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Call Ended', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('The other party has ended the call.',
                  style: GoogleFonts.inter(color: AegisColors.textSecondary)),
              const SizedBox(height: 32),
              AegisButton(
                text: 'OK',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _endCall() async {
    _stopListening();
    try {
      js.context['speechSynthesis']?.callMethod('cancel', []);
    } catch (_) {}
    setState(() => _callEnded = true);
    await _webRTCService.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _webRTCService.toggleMicrophone(_isMuted);
  }

  @override
  void dispose() {
    _victimInputController.dispose();
    _stopListening();
    try {
      js.context['speechSynthesis']?.callMethod('cancel', []);
    } catch (_) {}
    _webRTCService.onCallEnded = null;
    _webRTCService.onAddRemoteStream = null;
    if (!_callEnded) _webRTCService.endCall();
    _sidecarService.disconnect();
    _remoteRenderer.dispose();
    super.dispose();
  }

  Color get _threatColor => _threatScore > 0.7
      ? Colors.redAccent
      : (_threatScore > 0.4 ? Colors.orange : AegisColors.accentGreen);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF132020), Color(0xFF080B0D)],
          ),
        ),
        child: Stack(
          children: [
            // Radar / Aura Effect
            Center(
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF82E8B9).withValues(alpha: 0.05),
                      const Color(0xFF82E8B9).withValues(alpha: 0.01),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Hidden audio renderer
                  if (_rendererReady)
                    SizedBox(width: 1, height: 1, child: RTCVideoView(_remoteRenderer, mirror: false)),

                  // HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isIntercepted ? 'Protected Mode — Observer' : 'Active Call',
                        style: GoogleFonts.inter(
                          color: _isIntercepted ? Colors.redAccent : const Color(0xFF82E8B9).withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Text("CALLGUARD AI", style: GoogleFonts.inter(color: Colors.white, fontSize: 18, letterSpacing: 2.0, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("REAL-TIME CALL PROTECTION", style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11, letterSpacing: 1.5)),
                            const SizedBox(height: 32),

                            // MAIN THREAT SCORE CARD
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: _isIntercepted ? Colors.redAccent.withValues(alpha: 0.15) : const Color(0xFF82E8B9).withValues(alpha: 0.15),
                                    blurRadius: 60,
                                    spreadRadius: -10,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: _isIntercepted ? Colors.redAccent.withValues(alpha: 0.3) : const Color(0xFF82E8B9).withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Waveform behind text
                                        SizedBox(
                                          height: 80,
                                          width: double.infinity,
                                          child: LiveWaveform(
                                            color: _isIntercepted ? Colors.redAccent : const Color(0xFF82E8B9),
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              "${(_threatScore * 100).toStringAsFixed(0)} / 100",
                                              style: GoogleFonts.inter(
                                                color: _isIntercepted ? Colors.redAccent : const Color(0xFF82E8B9),
                                                fontSize: 64,
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    color: _isIntercepted ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFF82E8B9).withValues(alpha: 0.5),
                                                    blurRadius: 20,
                                                  )
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text("THREAT SCORE", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, letterSpacing: 2)),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _isIntercepted ? "CRITICAL RISK" : (_threatScore > 0.7 ? "ELEVATED RISK" : "MONITORING"),
                                                  style: GoogleFonts.inter(
                                                    color: _isIntercepted ? Colors.redAccent : const Color(0xFF82E8B9),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                PulsingStatusDot(color: _isIntercepted ? Colors.redAccent : const Color(0xFF82E8B9)),
                                              ],
                                            ),
                                            const SizedBox(height: 24),
                                            Text("MULTI-MODAL RISK FUSION", style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 10, letterSpacing: 1.5)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),
                            Text("LIVE SECURITY ANALYSIS", style: GoogleFonts.inter(color: Colors.white, fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 20),

                            // THREE CARDS ROW
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnalysisCard(
                                    title: "LIVENESS",
                                    subtitle: "Voice Authenticity",
                                    status: _syntheticProbability < 0 ? "ANALYZING" : (_syntheticProbability > 0.7 ? "SYNTHETIC" : (_syntheticProbability >= 0.4 ? "UNCERTAIN" : "HUMAN")),
                                    isCritical: _syntheticProbability > 0.7,
                                    icon: Icons.mic_none,
                                    details: _syntheticProbability < 0 ? ["Gathering data..."] : [
                                      "Human: ${((1.0 - _syntheticProbability) * 100).toStringAsFixed(0)}%",
                                      "Synth: ${(_syntheticProbability * 100).toStringAsFixed(0)}%",
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnalysisCard(
                                    title: "BEHAVIORAL",
                                    subtitle: "Acoustic + Temporal",
                                    status: _threatScore == 0 ? "CALIBRATING" : (_speakingRate > 150 ? "SUSPICIOUS" : "NORMAL"),
                                    isCritical: _speakingRate > 150,
                                    icon: Icons.graphic_eq,
                                    details: [
                                      "Pitch Var: ${_pitchVariance.toStringAsFixed(3)}",
                                      "WPM: ${_speakingRate.toStringAsFixed(0)}",
                                      _speakingRate > 150 ? "Stress: HIGH" : "Stress: LOW"
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnalysisCard(
                                    title: "SEMANTIC",
                                    subtitle: "Conversation Intent",
                                    status: _threatScore == 0 ? "ANALYZING" : (_semanticThreatProbability > 0.7 ? "HIGH RISK" : "LOW RISK"),
                                    isCritical: _semanticThreatProbability > 0.7,
                                    icon: Icons.text_fields,
                                    details: [
                                      "Threat: ${(_semanticThreatProbability * 100).toStringAsFixed(0)}%",
                                      if (_semanticThreatProbability > 0.7) "⚠ Urgency",
                                      if (_semanticThreatProbability > 0.7) "⚠ Extraction",
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 40),

                            // TRANSCRIPT SECTION (If Intercepted)
                            if (_isIntercepted) ...[
                              Divider(color: Colors.white.withValues(alpha: 0.1)),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text("AGENT HANDOFF ACTIVE", style: GoogleFonts.inter(color: const Color(0xFF82E8B9), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                ),
                                child: SizedBox(
                                  height: 200,
                                  width: double.infinity,
                                  child: _transcript.isEmpty
                                      ? Center(child: Text('Waiting for Evelyn...', style: GoogleFonts.inter(color: Colors.grey[500])))
                                      : ListView.builder(
                                          itemCount: _transcript.length,
                                          itemBuilder: (ctx, i) {
                                            final item = _transcript[i];
                                            final isEvelyn = item['speaker'] == 'Evelyn';
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12.0),
                                              child: RichText(
                                                text: TextSpan(children: [
                                                  TextSpan(
                                                    text: '${item['speaker']}: ',
                                                    style: GoogleFonts.inter(
                                                      color: isEvelyn ? const Color(0xFF82E8B9) : Colors.redAccent,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: item['text'],
                                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                                                  ),
                                                ]),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],

                            // FALLBACK INPUT FIELD
                            if (!_isIntercepted && !_callEnded)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A0F11),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(left: 20.0, right: 12.0),
                                      child: Icon(Icons.keyboard_outlined, color: Colors.white54, size: 20),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _victimInputController,
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'Type reply if mic STT fails...',
                                          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        onSubmitted: (text) {
                                          if (text.trim().isNotEmpty) {
                                            _onVictimSpeech(text.trim());
                                            _victimInputController.clear();
                                          }
                                        },
                                      ),
                                    ),
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          final text = _victimInputController.text.trim();
                                          if (text.isNotEmpty) {
                                            _onVictimSpeech(text);
                                            _victimInputController.clear();
                                          }
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 20.0, left: 12.0),
                                          child: Icon(Icons.send, color: Color(0xFF82E8B9), size: 20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // CALL CONTROLS (BOTTOM DOCK)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ControlButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            label: 'Mute',
                            color: _isMuted ? Colors.white54 : Colors.white,
                            onTap: _isIntercepted ? null : _toggleMute,
                          ),
                          const SizedBox(width: 24),
                          _ControlButton(
                            icon: Icons.call_end,
                            label: 'End',
                            color: Colors.white,
                            background: const Color(0xFFEF4444),
                            isEndCall: true,
                            size: 64,
                            onTap: _endCall,
                          ),
                          const SizedBox(width: 24),
                          _ControlButton(
                            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                            label: 'Speaker',
                            color: _isSpeakerOn ? Colors.white : Colors.white54,
                            onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                          ),
                        ],
                      ),
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

  Widget _buildAnalysisCard({required String title, required String subtitle, required String status, required bool isCritical, required IconData icon, required List<String> details}) {
    Color statusColor = isCritical ? Colors.redAccent : (status.contains("ANALYZING") || status.contains("CALIBRATING") ? const Color(0xFF38BDF8) : const Color(0xFF82E8B9));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              Icon(icon, color: Colors.white24, size: 16),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 9)),
          const SizedBox(height: 16),
          Row(
            children: [
              PulsingStatusDot(color: statusColor, size: 6),
              const SizedBox(width: 6),
              Expanded(child: Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          ...details.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(d, style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 10)),
          )),
        ],
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? background;
  final double size;
  final bool isEndCall;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.background,
    this.size = 56,
    this.isEndCall = false,
    this.onTap,
  });

  @override
  _ControlButtonState createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.onTap == null ? 0.4 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.background ?? Colors.white.withValues(alpha: 0.05),
                  boxShadow: widget.isEndCall
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: _isHovered ? 0.6 : 0.3),
                            blurRadius: _isHovered ? 24 : 16,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                transform: _isHovered && widget.onTap != null ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
                transformAlignment: Alignment.center,
                child: Icon(widget.icon, color: widget.color, size: widget.size * 0.45),
              ),
              const SizedBox(height: 8),
              Text(widget.label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class PulsingStatusDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulsingStatusDot({Key? key, required this.color, this.size = 8}) : super(key: key);
  @override
  _PulsingStatusDotState createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<PulsingStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}

class LiveWaveform extends StatefulWidget {
  final Color color;
  const LiveWaveform({Key? key, required this.color}) : super(key: key);
  @override
  _LiveWaveformState createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WaveformPainter(_controller.value, widget.color),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WaveformPainter(this.animationValue, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final int bars = 40;
    final spacing = size.width / bars;

    // Fade out edges using a shader mask effect drawn manually
    for (int i = 0; i < bars; i++) {
      double x = i * spacing;
      
      // Calculate fade based on distance from center
      double distFromCenter = (i - (bars / 2)).abs() / (bars / 2);
      double edgeFade = (1.0 - distFromCenter).clamp(0.0, 1.0);
      
      // Calculate random-looking height based on animation and position
      double noise = math.sin((i * 0.5) + (animationValue * math.pi * 4)) * 
                     math.cos((i * 0.2) - (animationValue * math.pi * 2));
      
      double height = (20 + (noise * 20)) * edgeFade;
      
      paint.color = color.withValues(alpha: 0.15 * edgeFade);
      canvas.drawLine(Offset(x, centerY - height), Offset(x, centerY + height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
