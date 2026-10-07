import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _callStatusSubscription;

  Future<String> createCall(String callerId, String recipientId) async {
    DocumentReference callDoc = _firestore.collection('calls').doc();
    await callDoc.set({
      'callerId': callerId,
      'recipientId': recipientId,
      'status': 'CALLING',
      'createdAt': DateTime.now().toIso8601String(),
      'threatScore': 0.0,
    });
    return callDoc.id;
  }

  Future<void> sendOffer(String callId, RTCSessionDescription offer) async {
    await _firestore.collection('calls').doc(callId).update({
      'offer': {'type': offer.type, 'sdp': offer.sdp},
      'status': 'RINGING',
    });
  }

  Future<void> sendAnswer(String callId, RTCSessionDescription answer) async {
    await _firestore.collection('calls').doc(callId).update({
      'answer': {'type': answer.type, 'sdp': answer.sdp},
      'status': 'CONNECTED',
    });
  }

  // Returns a stream that emits true when the remote party answers
  Stream<RTCSessionDescription?> listenForAnswer(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      var data = snapshot.data();
      if (data != null && data['answer'] != null) {
        var answer = data['answer'];
        return RTCSessionDescription(answer['sdp'], answer['type']);
      }
      return null;
    });
  }

  void listenForOffer(String recipientId, Function(String, RTCSessionDescription) onOffer) {
    _firestore
        .collection('calls')
        .where('recipientId', isEqualTo: recipientId)
        .where('status', isEqualTo: 'RINGING')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          var data = change.doc.data();
          if (data != null && data['offer'] != null) {
            var offer = data['offer'];
            onOffer(change.doc.id, RTCSessionDescription(offer['sdp'], offer['type']));
          }
        }
      }
    });
  }

  Future<void> addIceCandidate(
      String callId, String collectionName, RTCIceCandidate candidate) async {
    await _firestore
        .collection('calls')
        .doc(callId)
        .collection(collectionName)
        .add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  void listenForIceCandidates(String callId, String collectionName,
      Function(RTCIceCandidate) onCandidate) {
    _firestore
        .collection('calls')
        .doc(callId)
        .collection(collectionName)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data();
          if (data != null) {
            onCandidate(RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ));
          }
        }
      }
    });
  }

  /// Listen for the remote party hanging up (status → ENDED).
  /// Returns a StreamSubscription so you can cancel it.
  StreamSubscription listenForHangup(String callId, void Function() onHangup) {
    _callStatusSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        onHangup();
        return;
      }
      final data = snapshot.data();
      if (data != null && data['status'] == 'ENDED') {
        onHangup();
      }
    });
    return _callStatusSubscription!;
  }

  Future<void> endCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'ENDED',
      'endedAt': DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    _callStatusSubscription?.cancel();
  }
}
