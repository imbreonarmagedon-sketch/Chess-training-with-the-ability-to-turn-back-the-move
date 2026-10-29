import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'dart:math';

void main() {
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Шахматы AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const ChessScreen(),
    );
  }
}

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  late chess_lib.Chess _game;
  final List<String> _fenHistory = [];
  String? _selectedSquare;
  List<String> _legalDestinations = [];
  String _difficulty = 'Средний';
  bool _showAnalysis = false;
  bool _isThinking = false;
  List> _analysisList = [];

  final List<String> _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  @override
  void initState() {
    super.initState();
    _initNewGame();
  }

  void _initNewGame() {
    _game = chess_lib.Chess();
    _fenHistory.clear();
    _fenHistory.add(_game.fen);
    _selectedSquare = null;
    _legalDestinations.clear();
    _calculateAnalysis();
    setState(() {});
  }

  void _undoMove() {
    if (_fenHistory.length <= 1 || _isThinking) return;
    setState(() {
      // Отменяем ход компьютера и ход игрока, чтобы очередь снова была за белыми
      if (_game.turn == chess_lib.Color.WHITE && _fenHistory.length >= 3) {
        _fenHistory.removeLast();
        _fenHistory.removeLast();
      } else {
        _fenHistory.removeLast();
      }
      _game.load(_fenHistory.last);
      _selectedSquare = null;
      _legalDestinations.clear();
      _calculateAnalysis();
    });
  }

  String _indexToSquare(int index) {
    int row = 8 - (index ~/ 8);
    int col = index % 8;
    return '${_files[col]}$row';
  }

  void _onSquareTapped(String square) {
    if (_game.game_over || _isThinking || _game.turn != chess_lib.Color.WHITE) return;

    if (_selectedSquare == null) {
      final piece = _game.get(square);
      if (piece != null && piece.color == chess_lib.Color.WHITE) {
        setState(() {
          _selectedSquare = square;
          _legalDestinations = _getMovesForSquare(square);
        });
      }
    } else {
      if (_selectedSquare == square) {
        setState(() {
          _selectedSquare = null;
          _legalDestinations.clear();
        });
        return;
      }

      if (_legalDestinations.contains(square)) {
        _game.move({'from': _selectedSquare, 'to': square, 'promotion': 'q'});
        setState(() {
          _fenHistory.add(_game.fen);
          _selectedSquare = null;
          _legalDestinations.clear();
        });

        if (!_game.game_over) {
          _triggerAiMove();
        } else {
          _calculateAnalysis();
        }
      } else {
        final piece = _game.get(square);
        if (piece != null && piece.color == chess_lib.Color.WHITE) {
          setState(() {
            _selectedSquare = square;
            _legalDestinations = _getMovesForSquare(square);
          });
        } else {
          setState(() {
            _selectedSquare = null;
            _legalDestinations.clear();
          });
        }
      }
    }
  }

  List<String> _getMovesForSquare(String square) {
    final moves = _game.moves({'square': square, 'verbose': true});
    return moves.map<String>((m) => m['to'].toString()).toList();
  }

  void _triggerAiMove() {
    setState(() {
      _isThinking = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final moves = _game.moves({'verbose': true});
      if (moves.isNotEmpty) {
        Map<String, dynamic> chosenMove = _selectAiMove(moves);
        _game.move({
          'from': chosenMove['from'],
          'to': chosenMove['to'],
          'promotion': 'q'
        });
        _fenHistory.add(_game.fen);
      }

      setState(() {
        _isThinking = false;
        _calculateAnalysis();
      });
    });
  }

  Map<String, dynamic> _selectAiMove(List<dynamic> moves) {
    final rng = Random();
    if (_difficulty == 'Лёгкий') {
      return Map<String, dynamic>.from(moves[rng.nextInt(moves.length)]);
    }

    int depth = 1;
    if (_difficulty == 'Средний') depth = 1;
    if (_difficulty == 'Сложный') depth = 2;
    if (_difficulty == 'Суперсложный') depth = 3;

    dynamic bestMove = moves.first;
    int bestValue = -999999;

    final shuffledMoves = List<dynamic>.from(moves)..shuffle(rng);

    for (var m in shuffledMoves) {
      _game.move({'from': m['from'], 'to': m['to'], 'promotion': 'q'});
      int boardValue = -_minimax(depth - 1, -1000000, 1000000, false);
      _game.undo();

      if (boardValue > bestValue) {
        bestValue = boardValue;
        bestMove = m;
      }
    }
    return Map<String, dynamic>.from(bestMove);
  }

  int _minimax(int depth, int alpha, int beta, bool isMaximizing) {
    if (depth == 0 || _game.game_over) {
      return _evaluateBoard();
    }

    final moves = _game.moves({'verbose': true});
    if (isMaximizing) {
      int maxEval = -999999;
      for (var m in moves) {
        _game.move({'from': m['from'], 'to': m['to'], 'promotion': 'q'});
        int eval = _minimax(depth - 1, alpha, beta, false);
        _game.undo();
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 999999;
      for (var m in moves) {
        _game.move({'from': m['from'], 'to': m['to'], 'promotion': 'q'});
        int eval = _minimax(depth - 1, alpha, beta, true);
        _game.undo();
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  int _evaluateBoard() {
    if (_game.in_checkmate) {
      return _game.turn == chess_lib.Color.WHITE ? -90000 : 90000;
    }
    if (_game.in_draw) return 0;

    const weights = {
      chess_lib.PieceType.PAWN: 100,
      chess_lib.PieceType.KNIGHT: 320,
      chess_lib.PieceType.BISHOP: 330,
      chess_lib.PieceType.ROOK: 500,
      chess_lib.PieceType.QUEEN: 900,
      chess_lib.PieceType.KING: 20000,
    };

    int score = 0;
    for (int i = 0; i < 64; i++) {
      String sq = _indexToSquare(i);
      final piece = _game.get(sq);
      if (piece != null) {
        int val = weights[piece.type] ?? 0;
        int row = i ~/ 8;
        int col = i % 8;
        if ((row == 3 || row == 4) && (col == 3 || col == 4)) {
          val += 25; // Бонус за контроль центра
        }
        if (piece.color == chess_lib.Color.WHITE) {
          score += val;
        } else {
          score -= val;
        }
      }
    }
    return _game.turn == chess_lib.Color.WHITE ? score : -score;
  }

  void _calculateAnalysis() {
    if (_game.game_over || _game.turn != chess_lib.Color.WHITE) {
      _analysisList = [];
      return;
    }

    final moves = _game.moves({'verbose': true});
    if (moves.isEmpty) {
      _analysisList = [];
      return;
    }

    List> scoredMoves = [];
    for (var m in moves) {
      _game.move({'from': m['from'], 'to': m['to'], 'promotion': 'q'});
      int score = -_minimax(1, -1000000, 1000000, false);
      _game.undo();

      scoredMoves.add({
        'from': m['from'],
        'to': m['to'],
        'san': m['san'],
        'score': score,
      });
    }

    scoredMoves.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    List> results = [];
    int count = min(5, scoredMoves.length);

    for (int i = 0; i < count; i++) {
      var item = scoredMoves[i];
      int rawScore = item['score'] as int;
      double prob = 1.0 / (1.0 + exp(-rawScore / 400.0));
      int percentage = (prob * 100).round().clamp(5, 98);

      String desc;
      if (i == 0) {
        desc = 'Оптимальный ход. Максимальный шанс на успех.';
      } else if (percentage >= 50) {
        desc = 'Хорошее продолжение с крепкой позицией.';
      } else {
        desc = 'Невыгодный ход, ведет к потере инициативы.';
      }

      results.add({
        'move': '${item['from']} → ${item['to']} (${item['san']})',
        'pct': percentage,
        'desc': desc,
      });
    }

    _analysisList = results;
  }

  String _pieceEmoji(chess_lib.Piece piece) {
    final isW = piece.color == chess_lib.Color.WHITE;
    switch (piece.type) {
      case chess_lib.PieceType.PAWN:
        return isW ? '♙' : '♟';
      case chess_lib.PieceType.KNIGHT:
        return isW ? '♘' : '♞';
      case chess_lib.PieceType.BISHOP:
        return isW ? '♗' : '♝';
      case chess_lib.PieceType.ROOK:
        return isW ? '♖' : '♜';
      case chess_lib.PieceType.QUEEN:
        return isW ? '♕' : '♛';
      case chess_lib.PieceType.KING:
        return isW ? '♔' : '♚';
      default:
        return '';
    }
  }

  String _statusMessage() {
    if (_game.in_checkmate) {
      return _game.turn == chess_lib.Color.WHITE
          ? 'Мат! Победил компьютер.'
          : 'Мат! Вы одержали победу!';
    }
    if (_game.in_draw) return 'Ничья!';
    if (_isThinking) return 'Компьютер думает...';
    if (_game.in_check) return 'Шах! Ваш ход (Белые)';
    return 'Ваш ход (Белые) | Ходов в истории: ${_fenHistory.length - 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE6),
      appBar: AppBar(
        title: const Text('Шахматы AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Новая партия',
            onPressed: _initNewGame,
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _showAnalysis ? Colors.amber.shade800 : Colors.brown.shade600,
            ),
            icon: Icon(_showAnalysis ? Icons.visibility_off : Icons.analytics_outlined, size: 18),
            label: Text(_showAnalysis ? 'Скрыть' : 'Подсказки', style: const TextStyle(fontSize: 12)),
            onPressed: () {
              setState(() {
                _showAnalysis = !_showAnalysis;
              });
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Верхняя панель с уровнем сложности и бесконечной отменой хода
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.brown.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Уровень: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    DropdownButton<String>(
                      value: _difficulty,
                      isDense: true,
                      items: ['Лёгкий', 'Средний', 'Сложный', 'Суперсложный']
                          .map((lvl) => DropdownMenuItem(
                                value: lvl,
                                child: Text(lvl, style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _difficulty = val);
                        }
                      },
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: (_fenHistory.length > 1 && !_isThinking) ? _undoMove : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Назад', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          if (_isThinking) const LinearProgressIndicator(color: Colors.brown, minHeight: 3),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Text(
              _statusMessage(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _game.in_check ? Colors.red.shade800 : Colors.brown.shade900,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Основная часть: Доска слева + Боковая панель подсказок справа
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: _showAnalysis ? 6 : 10,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.brown.shade900, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                            ],
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                            ),
                            itemCount: 64,
                            itemBuilder: (context, index) {
                              int row = index ~/ 8;
                              int col = index % 8;
                              bool isLight = (row + col) % 2 == 0;
                              String sq = _indexToSquare(index);
                              bool isSelected = _selectedSquare == sq;
                              bool isLegal = _legalDestinations.contains(sq);
                              final piece = _game.get(sq);

                              Color bgColor = isLight
                                  ? const Color(0xFFF0D9B5)
                                  : const Color(0xFFB58863);
                              if (isSelected) {
                                bgColor = Colors.amber.shade400;
                              } else if (isLegal) {
                                bgColor = isLight
                                    ? const Color(0xFFCDD26A)
                                    : const Color(0xFFAAA23A);
                              }

                              return GestureDetector(
                                onTap: () => _onSquareTapped(sq),
                                child: Container(
                                  color: bgColor,
                                  child: Stack(
                                    children: [
                                      if (col == 0)
                                        Positioned(
                                          top: 1,
                                          left: 2,
                                          child: Text(
                                            '${8 - row}',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: isLight ? const Color(0xFFB58863) : const Color(0xFFF0D9B5),
                                            ),
                                          ),
                                        ),
                                      if (row == 7)
                                        Positioned(
                                          bottom: 1,
                                          right: 2,
                                          child: Text(
                                            _files[col],
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: isLight ? const Color(0xFFB58863) : const Color(0xFFF0D9B5),
                                            ),
                                          ),
                                        ),
                                      Center(
                                        child: piece != null
                                            ? FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  _pieceEmoji(piece),
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    color: piece.color == chess_lib.Color.WHITE
                                                        ? Colors.white
                                                        : Colors.black,
                                                    shadows: const [
                                                      Shadow(
                                                        blurRadius: 3,
                                                        color: Colors.black87,
                                                        offset: Offset(0.5, 0.5),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : (isLegal
                                                ? Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.black38,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  )
                                                : null),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Выдвижная панель анализа справа
                if (_showAnalysis)
                  Expanded(
                    flex: 5,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.brown.shade300, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade700,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Прогноз ИИ',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _showAnalysis = false),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _analysisList.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Ожидание хода...', style: TextStyle(fontSize: 11)),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(6),
                                    itemCount: _analysisList.length,
                                    separatorBuilder: (_, __) => const Divider(height: 10),
                                    itemBuilder: (context, idx) {
                                      final item = _analysisList[idx];
                                      final int pct = item['pct'] as int;
                                      final Color barColor = pct >= 60
                                          ? Colors.green.shade700
                                          : (pct >= 45 ? Colors.orange.shade700 : Colors.red.shade700);

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item['move'],
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                              ),
                                              Text(
                                                '$pct%',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: barColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: LinearProgressIndicator(
                                              value: pct / 100.0,
                                              minHeight: 5,
                                              color: barColor,
                                              backgroundColor: Colors.grey.shade200,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item['desc'],
                                            style: const TextStyle(fontSize: 10, color: Colors.black87),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
