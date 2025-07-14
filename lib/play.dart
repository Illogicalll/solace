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

class _PlayPageState extends State<PlayPage> with WidgetsBindingObserver {
  SolitaireGame? _game;
  int? _draggingPileIndex;
  int? _draggingCardIndex;
  bool _isDragging = false;

  int _moveCount = 0;
  late DateTime _startTime;
  Duration _elapsed = Duration.zero;
  DateTime? _pauseTime;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _moveCount = 0;
    _startTime = DateTime.now();
    _elapsed = Duration.zero;
    _ticker = Ticker(_updateTimer);
    _restoreGameState();
  }

  @override
  void dispose() {
    _saveGameState();
    _pauseTimer();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
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
    final elapsedMillis = prefs.getInt('solace_elapsed_time');

    if (saved != null) {
      setState(() {
        _game = SolitaireGame.fromJson(jsonDecode(saved));
        _moveCount = moveCount ?? 0;
        if (elapsedMillis != null) {
          _elapsed = Duration(milliseconds: elapsedMillis);
          _startTime = DateTime.now().subtract(_elapsed);
        } else {
          _startTime = DateTime.now();
          _elapsed = Duration.zero;
        }
      });
    } else {
      setState(() {
        _game = SolitaireGame();
        _startTime = DateTime.now();
        _elapsed = Duration.zero;
      });
    }
    _ticker?.start();
  }

  Future<void> _saveGameState() async {
    if (_game != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('solace_game_state', jsonEncode(_game!.toJson()));
      await prefs.setInt('solace_move_count', _moveCount);
      await prefs.setInt('solace_elapsed_time', _elapsed.inMilliseconds);
    }
  }

  Future<void> _clearGameState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('solace_game_state');
    await prefs.remove('solace_move_count');
    await prefs.remove('solace_elapsed_time');
  }

  void _updateTimer(Duration _) {
    setState(() {
      _elapsed = DateTime.now().difference(_startTime);
    });
  }

  void _incrementMove() {
    setState(() {
      _moveCount++;
    });
    _saveGameState();
  }

  void _resetGame() {
    setState(() {
      _game = SolitaireGame();
      _moveCount = 0;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
      _pauseTime = null;
    });
    _clearGameState();
    _ticker?.start();
  }

  void _checkWin() {
    if (_game != null && _game!.isWin()) {
      Future.microtask(() {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Congratulations!'),
            content: const Text('You have beaten the game!'),
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
        automaticallyImplyLeading: false, // Remove back button
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
      body: Column(
        children: [
          _buildTopRow(),
          const SizedBox(height: 30),
          _buildTableauRow(),
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
        setState(() {
          _game!.drawFromStock();
          _incrementMove();
          _checkWin();
        });
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
            : _buildCardBack(),
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
                // Show the next card in the waste if dragging the top card
                if (isDraggingWasteTop && _game!.waste.length > 1)
                  _buildCard(_game!.waste[_game!.waste.length - 2]),
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
                    feedback: _buildCard(_game!.waste.last),
                    childWhenDragging: Container(),
                    child: _buildCard(_game!.waste.last),
                    onDragStarted: () {
                      setState(() {
                        _draggingPileIndex = -2; // -2 for waste
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
        setState(() {
          if (data is CardModel) {
            if (_game!.waste.isNotEmpty && _game!.waste.last == data) {
              _game!.moveWasteToFoundation(index);
            } else {
              for (int i = 0; i < 7; i++) {
                if (_game!.tableau[i].contains(data)) {
                  _game!.moveTableauToFoundation(i, index);
                  break;
                }
              }
            }
          } else if (data is DragData) {
            _game!.moveTableauToFoundation(data.pileIndex, index);
          }
          _incrementMove();
          _checkWin();
        });
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
                      _buildCard(pile[pile.length - 2]),
                    if (isDraggingThisFoundation && pile.length == 1)
                      const SizedBox(),
                    if (!isDraggingThisFoundation)
                      Draggable<DragData>(
                        data: DragData(pile.last, -1, -1),
                        feedback: _buildCard(pile.last),
                        childWhenDragging: Container(),
                        child: _buildCard(pile.last),
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
        setState(() {
          if (data is DragData) {
            if (data.pileIndex == -1) {
              _game!.moveFoundationToTableau(data.card, index);
            } else {
              _game!.moveTableauToTableau(data.pileIndex, data.cardIndex, index);
            }
          } else if (data is CardModel) {
            for (int i = 0; i < 7; i++) {
              if (_game!.tableau[i].contains(data)) {
                final cardIndex = _game!.tableau[i].indexOf(data);
                _game!.moveTableauToTableau(i, cardIndex, index);
                return;
              }
            }
            if (_game!.waste.isNotEmpty && _game!.waste.last == data) {
              _game!.moveWasteToTableau(index);
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
                        : _buildDraggableCard(
                            pile[i],
                            pileIndex: index,
                            cardIndex: i,
                            pile: pile,
                          ),
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

  Widget _buildDraggableCard(CardModel card,
      {required int pileIndex, required int cardIndex, required List<CardModel> pile}) {
    if (!card.faceUp) {
      return _buildCardBack();
    }

    return Draggable<DragData>(
      data: DragData(card, pileIndex, cardIndex),
      feedback: _buildMultiCardFeedback(pileIndex, cardIndex),
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