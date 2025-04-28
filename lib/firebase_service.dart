import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> salvarPontuacao({
    required String nickname,
    required int pontos,
    required String colecao,
  }) async {
    try {
      await _firestore.collection(colecao).add({
        'nickname': nickname,
        'score': pontos,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erro ao salvar pontuação: $e');
    }
  }

  Stream<QuerySnapshot> getRanking(String colecao) {
    return _firestore
        .collection(colecao)
        .orderBy('score', descending: true)
        .snapshots();
  }
}
