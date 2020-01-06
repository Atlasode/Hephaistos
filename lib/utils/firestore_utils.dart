import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUtils {
  static String generateId(){
    return Firestore.instance.collection('groups').document().documentID;
  }
}