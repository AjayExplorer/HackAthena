import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Future<UserModel?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      
      if (user != null) {
        await _updatePresence(user.uid, true);
        return await getUserData(user.uid);
      }
      return null;
    } catch (e) {
      print('Error logging in: $e');
      return null;
    }
  }

  Future<UserModel?> register(String name, String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        // Generate a random AEGIS ID
        String aegisId = 'USER-${Random().nextInt(9000) + 1000}';
        
        UserModel newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          aegisId: aegisId,
          isOnline: true,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toJson());
        return newUser;
      }
      return null;
    } catch (e) {
      print('Error registering: $e');
      return null;
    }
  }

  Future<void> logout() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _updatePresence(user.uid, false);
    }
    await _auth.signOut();
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  Future<void> _updatePresence(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating presence: $e');
    }
  }
}
