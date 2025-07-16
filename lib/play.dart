import 'package:flutter/material.dart';
import 'package:solace/logic.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DragData {
  final CardModel card;
  final int pileIndex;
  final int cardIndex;
  
  DragData(this.card, this.pileIndex, this.cardIndex);
}

class PlayPage extends StatefulWidget {
  const PlayPage({super.key});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  SolitaireGame? _game;
  int? _draggingPileIndex;
  int? _draggingCardIndex;
  bool _isDragging = false;
  int _moveCount = 0;
  int _score = 0;
  int _stockCycles = 1;
  int _foundationStreak = 0;
  late DateTime _startTime;
  Duration _elapsed = Duration.zero;
  DateTime? _pauseTime;
  int _lastScoreDeductionTime = 0;
  Ticker? _ticker;
  final Map<String, AnimationController> _flipControllers = {};
  bool _isAutoCompleting = false;

  final List<Map<String, dynamic>> _gameHistory = [];

  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  bool _showTimelineSlider = false;
  int _timelineIndex = -1;
  Map<String, dynamic>? _originalStateBeforeTimeline;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _moveCount = 0;
    _score = 0;
    _stockCycles = 1;
    _foundationStreak = 0;
    _startTime = DateTime.now();
    _elapsed = Duration.zero;
    _lastScoreDeductionTime = 0;
    _ticker = Ticker(_updateTimer);

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 2.0, end: 5.0).animate(
      CurvedAnimation(
        parent: _glowController!,
        curve: Curves.easeInOut,
      ),
    );
    
    _restoreGameState();
  }

  @override
  void dispose() {
    for (var controller in _flipControllers.values) {
      controller.dispose();
    }
    _saveGameState();
    _pauseTimer();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    _glowController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseTimer();
      _saveGameState();
    } else if (state == AppLifecycleState.resumed) {
      _resumeTimer();
    }
  }

  void _pauseTimer() {
    _ticker?.stop();
    _pauseTime = DateTime.now();
  }

  void _resumeTimer() {
    if (_pauseTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseTime!);
      _startTime = _startTime.add(pauseDuration);
      _pauseTime = null;
    }
    _ticker?.start();
  }

  Future<void> _restoreGameState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('solace_game_state');
    final moveCount = prefs.getInt('solace_move_count');
    final score = prefs.getInt('solace_score');
    final stockCycles = prefs.getInt('solace_stock_cycles');
    final foundationStreak = prefs.getInt('solace_foundation_streak');
    final elapsedMillis = prefs.getInt('solace_elapsed_time');
    final lastScoreDeductionTime = prefs.getInt('solace_last_deduction_time');
    if (saved != null) {
      setState(() {
        _game = SolitaireGame.fromJson(jsonDecode(saved));
        _moveCount = moveCount ?? 0;
        _score = score ?? 0;
        _stockCycles = stockCycles ?? 1;
        _foundationStreak = foundationStreak ?? 0;
        if (elapsedMillis != null) {
          _elapsed = Duration(milliseconds: elapsedMillis);
          _startTime = DateTime.now().subtract(_elapsed);
        } else {
          _startTime = DateTime.now();
          _elapsed = Duration.zero;
        }
        _lastScoreDeductionTime = lastScoreDeductionTime ?? 0;
      });
    } else {
      setState(() {
        _game = SolitaireGame();
        _moveCount = 0;
        _score = 0;
        _stockCycles = 1;
        _foundationStreak = 0;
        _startTime = DateTime.now();
        _elapsed = Duration.zero;
        _lastScoreDeductionTime = 0;
      });
    }

    if (_game != null) {
      _saveInitialStateToHistory();
    }
    
    _ticker?.start();
  }

  void _saveInitialStateToHistory() {
    _gameHistory.clear();
    _gameHistory.add({
      'gameState': _game!.toJson(),
      'score': _score,
      'moveCount': _moveCount,
      'stockCycles': _stockCycles,
      'foundationStreak': _foundationStreak,
    });
  }
  
  Future<void> _saveGameState() async {
    if (_game != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('solace_game_state', jsonEncode(_game!.toJson()));
      await prefs.setInt('solace_move_count', _moveCount);
      await prefs.setInt('solace_elapsed_time', _elapsed.inMilliseconds);
      await prefs.setInt('solace_score', _score);
      await prefs.setInt('solace_stock_cycles', _stockCycles);
      await prefs.setInt('solace_foundation_streak', _foundationStreak);
      await prefs.setInt('solace_last_deduction_time', _lastScoreDeductionTime);
    }
  }

  Future<void> _clearGameState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('solace_game_state');
    await prefs.remove('solace_move_count');
    await prefs.remove('solace_elapsed_time');
    await prefs.remove('solace_score');
    await prefs.remove('solace_stock_cycles');
    await prefs.remove('solace_foundation_streak');
    await prefs.remove('solace_last_deduction_time');
  }

  void _updateTimer(Duration _) {
    setState(() {
      _elapsed = DateTime.now().difference(_startTime);
      int currentSeconds = _elapsed.inSeconds;
      int lastDeductionInterval = (_lastScoreDeductionTime / 10).floor() * 10;
      int currentInterval = (currentSeconds / 10).floor() * 10;
      
      if (currentInterval > lastDeductionInterval) {
        int intervalsToDeduct = (currentInterval - lastDeductionInterval) ~/ 10;
        if (intervalsToDeduct > 0) {
          _score = (_score - (5 * intervalsToDeduct)).clamp(0, double.infinity).toInt();
          _lastScoreDeductionTime = currentInterval;
        }
      }
    });
  }

  void _scoreWasteToTableau() {
    setState(() {
      _score += 5;
      _foundationStreak = 0;
    });
  }

  void _scoreToFoundation() {
    setState(() {
      _foundationStreak++;
      int streakBonus = _foundationStreak > 1 ? 5 : 0;
      _score += 10 + streakBonus;
    });
  }

  void _scoreFromFoundation() {
    setState(() {
      _score = (_score - 10).clamp(0, double.infinity).toInt();
      _foundationStreak = 0;
    });
  }

  void _scoreStockCycle() {
    if (_stockCycles > 1) {
      setState(() {
        _score = (_score - 50).clamp(0, double.infinity).toInt();
      });
    }
    _stockCycles++;
  }

  void _toggleTimelineSlider() {
    setState(() {
      if (!_showTimelineSlider) {
        _originalStateBeforeTimeline = {
          'gameState': _game!.toJson(),
          'score': _score,
          'moveCount': _moveCount,
          'stockCycles': _stockCycles,
          'foundationStreak': _foundationStreak,
        };
        _timelineIndex = _gameHistory.length - 1;
      } else {
        _originalStateBeforeTimeline = null;
      }
      _showTimelineSlider = !_showTimelineSlider;
    });
    if (_timelineIndex == -1) {
      _gameHistory.clear();
    }
  }

  void _setTimelinePosition(int index) {    
    if (index == _gameHistory.length - 1 && _originalStateBeforeTimeline != null) {
      setState(() {
        _game = SolitaireGame.fromJson(_originalStateBeforeTimeline!['gameState']);
        _score = _originalStateBeforeTimeline!['score'];
        _moveCount = _originalStateBeforeTimeline!['moveCount'];
        _stockCycles = _originalStateBeforeTimeline!['stockCycles'];
        _foundationStreak = _originalStateBeforeTimeline!['foundationStreak'];
        _timelineIndex = index;
      });
    } else {
      final state = _gameHistory[index + 1];
      setState(() {
        _game = SolitaireGame.fromJson(state['gameState']);
        if (state.containsKey('score')) _score = state['score'];
        if (state.containsKey('stockCycles')) _stockCycles = state['stockCycles'];
        if (state.containsKey('foundationStreak')) _foundationStreak = state['foundationStreak'];
        _timelineIndex = index;
      });
    }
  }

  bool _hasCardPositionsChanged(Map<String, dynamic> oldState, Map<String, dynamic> newState) {
    final oldGame = SolitaireGame.fromJson(oldState);
    final newGame = SolitaireGame.fromJson(newState);

    for (int i = 0; i < oldGame.tableau.length; i++) {
      if (oldGame.tableau[i].length != newGame.tableau[i].length) return true;
      for (int j = 0; j < oldGame.tableau[i].length; j++) {
        if (oldGame.tableau[i][j].suit != newGame.tableau[i][j].suit || 
            oldGame.tableau[i][j].rank != newGame.tableau[i][j].rank ||
            oldGame.tableau[i][j].faceUp != newGame.tableau[i][j].faceUp) {
          return true;
        }
      }
    }

    for (int i = 0; i < oldGame.foundations.length; i++) {
      if (oldGame.foundations[i].length != newGame.foundations[i].length) return true;
    }

    if (oldGame.waste.length != newGame.waste.length) return true;
    if (oldGame.stock.length != newGame.stock.length) return true;
    
    return false;
  }

  void _saveToHistory() {
    if (_game != null) {
      final newState = {
        'gameState': _game!.toJson(),
        'score': _score,
        'moveCount': _moveCount,
        'stockCycles': _stockCycles,
        'foundationStreak': _foundationStreak,
      };

      if (_timelineIndex != -1 && _timelineIndex < _gameHistory.length - 1) {
        _gameHistory.removeRange(_timelineIndex + 1, _gameHistory.length);
        _timelineIndex = -1;
      }

      bool shouldAddToHistory = true;
      if (_gameHistory.isNotEmpty) {
        final lastState = _gameHistory.last;
        shouldAddToHistory = _hasCardPositionsChanged(
          lastState['gameState'] as Map<String, dynamic>, 
          newState['gameState'] as Map<String, dynamic>
        );
      }
      
      if (shouldAddToHistory) {
        _gameHistory.add(newState);
        if (_gameHistory.length > 50) {
          _gameHistory.removeAt(0);
        }
      } else {
        if (_gameHistory.isNotEmpty) {
          _gameHistory.last['score'] = _score;
          _gameHistory.last['moveCount'] = _moveCount;
          _gameHistory.last['stockCycles'] = _stockCycles;
          _gameHistory.last['foundationStreak'] = _foundationStreak;
        }
      }
    }
  }

  void _undoMove() {
    if (_gameHistory.isEmpty) return;
    
    final lastState = _gameHistory.removeLast();
    
    setState(() {
      _game = SolitaireGame.fromJson(lastState['gameState']);
      _score = lastState['score'];
      _stockCycles = lastState['stockCycles'];
      _foundationStreak = lastState['foundationStreak'];
      _moveCount++;
    });
    
    _saveGameState();
    if (_gameHistory.isEmpty) {
      _saveInitialStateToHistory();
    }
  }
  void _moveTableauToTableau(int fromPile, int cardIndex, int toPile) {
    _game!.moveTableauToTableau(fromPile, cardIndex, toPile);
    _triggerFlipIfNeeded(fromPile);
    _foundationStreak = 0;
    _saveGameState();
  }

  void _moveTableauToFoundation(int fromPile, int foundationIndex) {
    _game!.moveTableauToFoundation(fromPile, foundationIndex);
    _triggerFlipIfNeeded(fromPile);
    _scoreToFoundation();
    _saveGameState();
  }

  void _incrementMove() {
    setState(() {
      _moveCount++;
    });
    _saveGameState();
  }
  
  void _autoCompleteGame() {
    if (_game == null) return;

    setState(() {
      _isAutoCompleting = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () => _processNextAutoCompleteMove());
  }

  void _processNextAutoCompleteMove() {
    if (_game == null || !_isAutoCompleting) return;
    
    bool moveMade = false;

    for (int pileIndex = 0; pileIndex < _game!.tableau.length; pileIndex++) {
      var pile = _game!.tableau[pileIndex];
      if (pile.isEmpty) continue;
      
      var card = pile.last;

      for (int foundationIndex = 0; foundationIndex < _game!.foundations.length; foundationIndex++) {
        if (_game!.canPlaceOnFoundation(card, _game!.foundations[foundationIndex])) {
          _moveTableauToFoundation(pileIndex, foundationIndex);
          _incrementMove();
          moveMade = true;
          break;
        }
      }
      
      if (moveMade) break;
    }
    
    if (!moveMade && _game!.waste.isNotEmpty) {
      var card = _game!.waste.last;
      
      for (int foundationIndex = 0; foundationIndex < _game!.foundations.length; foundationIndex++) {
        if (_game!.canPlaceOnFoundation(card, _game!.foundations[foundationIndex])) {
          setState(() {
            _game!.moveWasteToFoundation(foundationIndex);
            _scoreToFoundation();
          });
          _incrementMove();
          moveMade = true;
          break;
        }
      }
    }

    if (!moveMade && !_game!.stock.isEmpty) {
      setState(() {
        _game!.drawFromStock();
      });
      _incrementMove();
      moveMade = true;
    }

    if (!moveMade && _game!.stock.isEmpty && _game!.waste.isNotEmpty) {
      setState(() {
        _scoreStockCycle();
        _game!.drawFromStock();
      });
      _incrementMove();
      moveMade = true;
    }
 
    if (_game!.isWin()) {
      setState(() {
        _isAutoCompleting = false;
      });
      _checkWin();
      return;
    }

    if (moveMade) {
      Future.delayed(const Duration(milliseconds: 150), () => _processNextAutoCompleteMove());
    } else {
      setState(() {
        _isAutoCompleting = false;
      });
    }
  }

  void _resetGame() {
    setState(() {
      _game = SolitaireGame();
      _moveCount = 0;
      _score = 0;
      _stockCycles = 1;
      _foundationStreak = 0;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
      _pauseTime = null;
      _lastScoreDeductionTime = 0;
      _revealedCards.clear();
      _isAutoCompleting = false;
      _gameHistory.clear();
    });

    _saveInitialStateToHistory();
    
    _glowController?.repeat(reverse: true);
    _clearGameState();
    _ticker?.start();
  }

  void _checkWin() {
    if (_game != null && _game!.isWin()) {
      _pauseTimer();
      Future.microtask(() {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text(
              'Congratulations!',
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'CabinetGrotesk',
                fontSize: 32,
                fontWeight: FontWeight.w200,
              ),
            ),
            content: Text(
              'Score: $_score',
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'CabinetGrotesk',
                fontSize: 32,
                fontWeight: FontWeight.w200,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetGame();
                },
                child: const Text('Play Again'),
              ),
            ],
          ),
        );
      });
    }
  }

  String _cardKey(int pileIndex, int cardIndex) => '$pileIndex-$cardIndex';

  void _triggerFlipIfNeeded(int pileIndex) {
    final pile = _game!.tableau[pileIndex];
    if (pile.isNotEmpty && pile.last.faceUp) {
      final card = pile.last;
      if (!_revealedCards.contains(card)) {
        _revealedCards.add(card);
        
        final cardIndex = pile.length - 1;
        final key = _cardKey(pileIndex, cardIndex);
        if (!_flipControllers.containsKey(key)) {
          final controller = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 350),
          );
          _flipControllers[key] = controller;
          controller.forward().then((_) {
            controller.dispose();
            _flipControllers.remove(key);
            setState(() {});
          });
          setState(() {});
        }
      }
    }
  }

  final Set<CardModel> _revealedCards = {};

  bool _allTableauCardsFaceUp() {
    if (_game == null) return false;
    for (final pile in _game!.tableau) {
      for (final card in pile) {
        if (!card.faceUp) return false;
      }
    }
    return true;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    String timerText =
        '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                'Moves: $_moveCount',
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  overflow: TextOverflow.visible
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                'Score: $_score',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  overflow: TextOverflow.visible
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                'Time: $timerText',
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.black
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopRow(),
              const SizedBox(height: 30),
              _buildTableauRow(),
            ],
          ),
          if (_allTableauCardsFaceUp() && !_isAutoCompleting)
            AnimatedBuilder(
              animation: _glowAnimation!,
              builder: (context, child) {
                return Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.6),
                            spreadRadius: _glowAnimation!.value,
                            blurRadius: _glowAnimation!.value * 2,
                            offset: const Offset(0, 0),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ElevatedButton(
                        onPressed: _autoCompleteGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Auto-Complete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'undoButton',
              onPressed: _gameHistory.isNotEmpty ? _undoMove : null,
              backgroundColor: _gameHistory.isNotEmpty ? Colors.blueAccent : Colors.grey[700],
              child: const Icon(
                Icons.undo,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'timelineButton',
              onPressed: _gameHistory.isNotEmpty ? _toggleTimelineSlider : null,
              backgroundColor: _gameHistory.isNotEmpty ? Colors.purple : Colors.grey[700],
              child: const Icon(
                Icons.history,
                color: Colors.white,
              ),
            ),
          ),
          if (_showTimelineSlider)
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.black.withOpacity(0.85),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Move Timeline",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: _toggleTimelineSlider,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text("Start", style: TextStyle(color: Colors.white70)),
                          Expanded(
                            child: Slider(
                              value: _timelineIndex.toDouble(),
                              min: -1,
                              max: (_gameHistory.length - 1).toDouble(),
                              divisions: _gameHistory.length > 1 ? _gameHistory.length : 1,
                              activeColor: Colors.blueAccent,
                              inactiveColor: Colors.white24,
                              onChanged: (value) {
                                _setTimelinePosition(value.round());
                              },
                            ),
                          ),
                          Text("Current", style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.fast_rewind, color: Colors.white),
                            onPressed: _timelineIndex > -1 ? () => _setTimelinePosition(-1) : null,
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_previous, color: Colors.white),
                            onPressed: _timelineIndex > -1 ? () => _setTimelinePosition(_timelineIndex - 1) : null,
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_next, color: Colors.white),
                            onPressed: _timelineIndex < _gameHistory.length - 1
                              ? () => _setTimelinePosition(_timelineIndex + 1)
                              : null,
                          ),
                          IconButton(
                            icon: Icon(Icons.fast_forward, color: Colors.white),
                            onPressed: _timelineIndex < _gameHistory.length - 1
                              ? () => _setTimelinePosition(_gameHistory.length - 1)
                              : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
        children: [
          ...List.generate(4, (index) => _buildFoundation(index)),
          const Spacer(),
          _buildWaste(),
          const SizedBox(width: 4.5),
          _buildStock(),
        ],
      );
  }

  Widget _buildStock() {
    return GestureDetector(
      onTap: () {
        if (_game!.stock.isEmpty && _game!.waste.isNotEmpty) {
          _saveToHistory();

          setState(() {
            _scoreStockCycle();
            _game!.drawFromStock();
            _moveCount++;
            _checkWin();
          });
          _saveGameState();
        } else if (!_game!.stock.isEmpty) {
          _saveToHistory();
          
          setState(() {
            _game!.drawFromStock();
            _moveCount++;
            _checkWin();
          });
          _saveGameState();
        }
      },
      child: SizedBox(
        width: 58,
        height: 78,
        child: _game!.stock.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30),
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            : Material(
                color: Colors.transparent,
                child: _buildCardBack(),
              ),
      ),
    );
  }

  Widget _buildWaste() {
    final isDraggingWasteTop = _game!.waste.isNotEmpty &&
      _isDragging &&
      _draggingPileIndex == -2 &&
      _draggingCardIndex == -1 &&
      _game!.waste.last == (_game!.waste.isNotEmpty ? _game!.waste.last : null);

    return SizedBox(
      width: 58,
      height: 78,
      child: _game!.waste.isEmpty
          ? Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30),
                borderRadius: BorderRadius.circular(6),
              ),
            )
          : Stack(
              children: [
                if (isDraggingWasteTop && _game!.waste.length > 1)
                  Material(
                    color: Colors.transparent,
                    child: _buildCard(_game!.waste[_game!.waste.length - 2]),
                  ),
                if (isDraggingWasteTop && _game!.waste.length == 1)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                if (!isDraggingWasteTop)
                  Draggable<CardModel>(
                    data: _game!.waste.last,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _buildCard(_game!.waste.last),
                    ),
                    childWhenDragging: Container(),
                    child: Material(
                      color: Colors.transparent,
                      child: _buildCard(_game!.waste.last),
                    ),
                    onDragStarted: () {
                      setState(() {
                        _draggingPileIndex = -2;
                        _draggingCardIndex = -1;
                        _isDragging = true;
                      });
                    },
                    onDragEnd: (details) {
                      setState(() {
                        _draggingPileIndex = null;
                        _draggingCardIndex = null;
                        _isDragging = false;
                      });
                    },
                    onDragCompleted: () {
                      setState(() {
                        _draggingPileIndex = null;
                        _draggingCardIndex = null;
                        _isDragging = false;
                      });
                    },
                    onDraggableCanceled: (velocity, offset) {
                      setState(() {
                        _draggingPileIndex = null;
                        _draggingCardIndex = null;
                        _isDragging = false;
                      });
                    },
                  ),
              ],
            ),
    );
  }

  Widget _buildFoundation(int index) {
    List<CardModel> pile = _game!.foundations[index];
    final isDraggingThisFoundation = pile.isNotEmpty &&
      _isDragging &&
      _draggingPileIndex == index &&
      _draggingCardIndex == -1 &&
      pile.last == (_game!.foundations[index].isNotEmpty ? _game!.foundations[index].last : null);

    return DragTarget<Object>(
      onWillAccept: (data) {
        if (data == null) return false;
        CardModel card;
        if (data is CardModel) {
          card = data;
        } else if (data is DragData) {
          card = data.card;
          if (data.pileIndex >= 0) {
            final movingCards = _game!.tableau[data.pileIndex].sublist(data.cardIndex);
            if (movingCards.length > 1) return false;
          }
          if (data.pileIndex == -1) return false;
        } else {
          return false;
        }
        return _game!.canPlaceOnFoundation(card, pile);
      },
      onAccept: (data) {
        _saveToHistory();
        
        setState(() {
          if (data is CardModel) {
            if (_game!.waste.isNotEmpty && _game!.waste.last == data) {
              _game!.moveWasteToFoundation(index);
              _scoreToFoundation();
            } else {
              for (int i = 0; i < 7; i++) {
                if (_game!.tableau[i].contains(data)) {
                  _moveTableauToFoundation(i, index);
                  break;
                }
              }
            }
          } else if (data is DragData) {
            _moveTableauToFoundation(data.pileIndex, index);
          }
          _moveCount++;
          _checkWin();
        });
        _saveGameState();
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 58,
          height: 78,
          margin: const EdgeInsets.only(right: 4.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white30),
          ),
          child: pile.isEmpty
              ? null
              : Stack(
                  children: [
                    if (isDraggingThisFoundation && pile.length > 1)
                      Material(
                        color: Colors.transparent,
                        child: _buildCard(pile[pile.length - 2]),
                      ),
                    if (isDraggingThisFoundation && pile.length == 1)
                      const SizedBox(),
                    if (!isDraggingThisFoundation)
                      Draggable<DragData>(
                        data: DragData(pile.last, -1, -1),
                        feedback: Material(
                          color: Colors.transparent,
                          child: _buildCard(pile.last),
                        ),
                        childWhenDragging: Container(),
                        child: Material(
                          color: Colors.transparent,
                          child: _buildCard(pile.last),
                        ),
                        onDragStarted: () {
                          setState(() {
                            _draggingPileIndex = index;
                            _draggingCardIndex = -1;
                            _isDragging = true;
                          });
                        },
                        onDragEnd: (details) {
                          setState(() {
                            _draggingPileIndex = null;
                            _draggingCardIndex = null;
                            _isDragging = false;
                          });
                        },
                        onDragCompleted: () {
                          setState(() {
                            _draggingPileIndex = null;
                            _draggingCardIndex = null;
                            _isDragging = false;
                          });
                        },
                        onDraggableCanceled: (velocity, offset) {
                          setState(() {
                            _draggingPileIndex = null;
                            _draggingCardIndex = null;
                            _isDragging = false;
                          });
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTableauRow() {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final gap = 6.0;
          final pilesCount = 7;
          final pileWidth = (maxWidth - gap * (pilesCount - 1)) / pilesCount;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              pilesCount,
              (index) => SizedBox(
                width: pileWidth,
                child: _buildTableauPile(index, width: pileWidth),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableauPile(int index, {double width = 60}) {
    final pile = _game!.tableau[index];

    return DragTarget<Object>(
      onWillAccept: (data) {
        if (data == null) return false;
        CardModel card;
        if (data is CardModel) {
          card = data;
        } else if (data is DragData) {
          card = data.card;
        } else {
          return false;
        }
        return _game!.canPlaceOnTableau(card, pile.isNotEmpty ? pile.last : null);
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        _saveToHistory();
        
        setState(() {
          if (data is DragData) {
            if (data.pileIndex == -1) {
              _game!.moveFoundationToTableau(data.card, index);
              _scoreFromFoundation();
            } else {
              _moveTableauToTableau(data.pileIndex, data.cardIndex, index);
            }
          } else if (data is CardModel) {
            for (int i = 0; i < 7; i++) {
              if (_game!.tableau[i].contains(data)) {
                final cardIndex = _game!.tableau[i].indexOf(data);
                _moveTableauToTableau(i, cardIndex, index);
                return;
              }
            }
            if (_game!.waste.isNotEmpty && _game!.waste.last == data) {
              _game!.moveWasteToTableau(index);
              _scoreWasteToTableau();
            }
          }
          _incrementMove();
          _checkWin();
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
            children: [
              for (int i = 0; i < pile.length; i++)
                Positioned(
                  top: i * 32,
                  child: SizedBox(
                    width: width,
                    child: (_isDragging && _draggingPileIndex == index && _draggingCardIndex != -1 && i >= _draggingCardIndex!)
                        ? Container()
                        : _buildAnimatedTableauCard(pile[i], index, i, pile),
                  ),
                ),
              if (pile.isEmpty ||
                  (_isDragging &&
                   _draggingPileIndex == index &&
                   _draggingCardIndex != -1 &&
                   pile.length == 1))
                Container(
                  width: width,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
            ],
          );
      },
    );
  }

  Widget _buildAnimatedTableauCard(CardModel card, int pileIndex, int cardIndex, List<CardModel> pile) {
    final key = _cardKey(pileIndex, cardIndex);
    final controller = _flipControllers[key];
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final value = controller.value;
          final angle = value * 3.14159;
          if (value < 0.5) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: _buildCardBack(),
            );
          } else {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(3.14159 - angle),
              child: _buildCard(card),
            );
          }
        },
      );
    }
    return _buildDraggableCard(card,
      pileIndex: pileIndex,
      cardIndex: cardIndex,
      pile: pile,
    );
  }

  Widget _buildDraggableCard(CardModel card,
      {required int pileIndex, required int cardIndex, required List<CardModel> pile}) {
    if (!card.faceUp) {
      return _buildCardBack();
    }

    return Draggable<DragData>(
      data: DragData(card, pileIndex, cardIndex),
      feedback: Material(
        color: Colors.transparent,
        child: _buildMultiCardFeedback(pileIndex, cardIndex),
      ),
      childWhenDragging: Container(),
      child: _buildCard(card),
      onDragStarted: () {
        setState(() {
          _draggingPileIndex = pileIndex;
          _draggingCardIndex = cardIndex;
          _isDragging = true;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _draggingPileIndex = null;
          _draggingCardIndex = null;
          _isDragging = false;
        });
      },
      onDragCompleted: () {
        setState(() {
          _draggingPileIndex = null;
          _draggingCardIndex = null;
          _isDragging = false;
        });
      },
      onDraggableCanceled: (velocity, offset) {
        setState(() {
          _draggingPileIndex = null;
          _draggingCardIndex = null;
          _isDragging = false;
        });
      },
    );
  }

  Widget _buildMultiCardFeedback(int pileIndex, int cardIndex) {
    final pile = _game!.tableau[pileIndex];
    final movingCards = pile.sublist(cardIndex);
    return SizedBox(
      width: 60,
      height: 80 + (movingCards.length - 1) * 32,
      child: Stack(
        children: [
          for (int i = 0; i < movingCards.length; i++)
            Positioned(
              top: i * 32,
              child: _buildCard(movingCards[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(CardModel card) {
    return Container(
      width: 60,
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 6,
            left: 6,
            child: Text(
              card.rankString,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: card.color,
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Text(
              card.suitSymbol,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: card.color,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: Text(
                card.suitSymbol,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                  color: card.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.4,
          child: SvgPicture.asset(
            'assets/icons/cardback.svg',
            width: 48,
            height: 48,
          ),
        ),
      ),
    );
  }
}