import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'firebase_service.dart';
import 'main.dart'; // Importa o nicknameGlobal

class JogoRegiao extends StatefulWidget {
  @override
  _JogoRegiaoState createState() => _JogoRegiaoState();
}

class _JogoRegiaoState extends State<JogoRegiao> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _controller = TextEditingController();
  List<StateData> _states = [];
  StateData? _currentState;
  String _message = '';
  bool _loading = true;
  int _score = 0;
  int _questionsAnswered = 0;
  int _timeLeft = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchStates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchStates() async {
    setState(() => _loading = true);
    final response = await http.get(
      Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/estados'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      Map<String, String> regioes = {
        'Acre': 'Norte',
        'Alagoas': 'Nordeste',
        'Amapá': 'Norte',
        'Amazonas': 'Norte',
        'Bahia': 'Nordeste',
        'Ceará': 'Nordeste',
        'Distrito Federal': 'Centro-Oeste',
        'Espírito Santo': 'Sudeste',
        'Goiás': 'Centro-Oeste',
        'Maranhão': 'Nordeste',
        'Mato Grosso': 'Centro-Oeste',
        'Mato Grosso do Sul': 'Centro-Oeste',
        'Minas Gerais': 'Sudeste',
        'Pará': 'Norte',
        'Paraíba': 'Nordeste',
        'Paraná': 'Sul',
        'Pernambuco': 'Nordeste',
        'Piauí': 'Nordeste',
        'Rio de Janeiro': 'Sudeste',
        'Rio Grande do Norte': 'Nordeste',
        'Rio Grande do Sul': 'Sul',
        'Rondônia': 'Norte',
        'Roraima': 'Norte',
        'Santa Catarina': 'Sul',
        'São Paulo': 'Sudeste',
        'Sergipe': 'Nordeste',
        'Tocantins': 'Norte',
      };

      _states = data
          .where((state) => regioes.containsKey(state['nome']))
          .map<StateData>((state) {
        return StateData(
          name: state['nome'],
          abbreviation: state['sigla'],
          regiao: regioes[state['nome']]!,
        );
      }).toList();

      _states.shuffle();
      _states = _states.take(10).toList();

      _nextQuestion();
    } else {
      throw Exception('Falha ao carregar estados');
    }

    setState(() => _loading = false);
  }

  void _nextQuestion() {
    if (_questionsAnswered >= 10) {
      _showGameOverDialog();
      return;
    }

    if (_states.isEmpty) {
      _showGameOverDialog();
      return;
    }

    setState(() {
      _currentState = _states.removeAt(0);
      _controller.clear();
      _message = '';
      _timeLeft = 10;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _message =
              'Tempo esgotado! :O ${_currentState!.name} pertence à região ${_currentState!.regiao}.';
          _questionsAnswered++;
        });
        Future.delayed(Duration(seconds: 2), _nextQuestion);
      }
    });
  }

  void _checkAnswer() {
    if (_timeLeft == 0) return;

    final answer = _controller.text.trim();
    final correctAnswer = _currentState!.regiao;
    _timer?.cancel();
    setState(() {
      if (answer.toLowerCase() == correctAnswer.toLowerCase()) {
        _message = 'Acertou! :D';
        _score++;
      } else {
        _message =
            'Errou! :( ${_currentState!.name} pertence à região ${_currentState!.regiao}.';
      }
      _questionsAnswered++;
    });
    Future.delayed(Duration(seconds: 2), _nextQuestion);
  }

  void _showGameOverDialog() async {
    // Salva pontuação no Firebase
    await _firebaseService.salvarPontuacao(
      nickname: nicknameGlobal,
      pontos: _score,
      colecao: 'players_regioes',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Fim de jogo!'),
        content: Text('Sua pontuação final foi $_score de 10.'),
        actions: [
          TextButton(
            child: Text('Jogar novamente'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _score = 0;
                _questionsAnswered = 0;
                _fetchStates();
              });
            },
          ),
          TextButton(
            child: Text('Voltar ao menu'),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Adivinhe a Região!', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _currentState == null
              ? Center(child: Text('Erro ao carregar dados'))
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pontuação: $_score | Respondidas: $_questionsAnswered',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Tempo restante: $_timeLeft s',
                        style: TextStyle(
                          fontSize: 18,
                          color: _timeLeft <= 3 ? Colors.red : Colors.black,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Em qual região está:',
                        style: TextStyle(fontSize: 22),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _currentState!.name,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: 'Digite a região',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Responda com Norte, Nordeste, Centro-Oeste, Sudeste ou Sul.',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _checkAnswer,
                        child: Text('Responder'),
                      ),
                      SizedBox(height: 20),
                      Text(
                        _message,
                        style: TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class StateData {
  final String name;
  final String abbreviation;
  final String regiao;

  StateData({
    required this.name,
    required this.abbreviation,
    required this.regiao,
  });
}
