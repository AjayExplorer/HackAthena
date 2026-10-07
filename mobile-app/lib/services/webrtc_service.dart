import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  final SignalingService _signalingService = SignalingService();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _hangupSubscription;

  Function(MediaStream)? onAddRemoteStream;
  Function(RTCSessionDescription)? onIncomingCall;
  void Function()? onCallEnded;
  String? currentCallId;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> _initLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(
      String callId, bool isCaller) async {
    currentCallId = callId;
    RTCPeerConnection pc = await createPeerConnection(_configuration);

    // Add all local audio tracks
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    // onTrack fires when remote media arrives (unified-plan)
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onAddRemoteStream?.call(_remoteStream!);
      }
    };

    // ICE gathering
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      final collection = isCaller ? 'callerCandidates' : 'calleeCandidates';
      _signalingService.addIceCandidate(callId, collection, candidate);
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      print('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onCallEnded?.call();
      }
    };

    return pc;
  }

  Future<String> makeCall(String callerId, String recipientId) async {
    await _initLocalStream();
    final callId = await _signalingService.createCall(callerId, recipientId);
    _peerConnection = await _createPeerConnection(callId, true);

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peerConnection!.setLocalDescription(offer);
    await _signalingService.sendOffer(callId, offer);

    // Listen for answer
    bool _answerApplied = false;
    _answerSubscription =
        _signalingService.listenForAnswer(callId).listen((answer) async {
      if (answer != null && !_answerApplied) {
        _answerApplied = true;
        await _peerConnection?.setRemoteDescription(answer);
      }
    });

    // Listen for callee ICE candidates
    _signalingService.listenForIceCandidates(callId, 'calleeCandidates',
        (candidate) {
      _peerConnection?.addCandidate(candidate);
    });

    // Listen for hangup from the other side
    _hangupSubscription =
        _signalingService.listenForHangup(callId, () => onCallEnded?.call());

    return callId;
  }

  Future<void> answerCall(String callId, RTCSessionDescription offer) async {
    currentCallId = callId;
    await _initLocalStream();
    _peerConnection = await _createPeerConnection(callId, false);

    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peerConnection!.setLocalDescription(answer);
    await _signalingService.sendAnswer(callId, answer);

    // Listen for caller ICE candidates
    _signalingService.listenForIceCandidates(callId, 'callerCandidates',
        (candidate) {
      _peerConnection?.addCandidate(candidate);
    });

    // Listen for hangup from the other side
    _hangupSubscription =
        _signalingService.listenForHangup(callId, () => onCallEnded?.call());
  }

  void listenForIncomingCalls(String recipientId) {
    _signalingService.listenForOffer(recipientId, (callId, offer) {
      currentCallId = callId;
      onIncomingCall?.call(offer);
    });
  }

  void toggleMicrophone(bool mute) {
    for (final track in _localStream?.getAudioTracks() ?? []) {
      track.enabled = !mute;
    }
  }

  Future<void> endCall() async {
    _hangupSubscription?.cancel();
    _answerSubscription?.cancel();
    if (currentCallId != null) {
      try {
        await _signalingService.endCall(currentCallId!);
      } catch (_) {}
    }
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
    currentCallId = null;
  }
}
