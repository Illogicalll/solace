import 'package:flutter/material.dart';
import 'package:solace/logic.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

class _PlayPageState extends State<PlayPage> {
  late SolitaireGame game;
  int? _draggingPileIndex;
  int? _draggingCardIndex;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    game = SolitaireGame();
  }

  void _checkWin() {
    if (game.isWin()) {
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
                  setState(() {
                    game.init();
                  });
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Play'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                game.init();
              });
            },
          )
        ],
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
          game.drawFromStock();
          _checkWin();
        });
      },
      child: SizedBox(
        width: 58,
        height: 78,
        child: game.stock.isEmpty
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
    final isDraggingWasteTop = game.waste.isNotEmpty &&
      _isDragging &&
      _draggingPileIndex == -2 &&
      _draggingCardIndex == -1 &&
      game.waste.last == (game.waste.isNotEmpty ? game.waste.last : null);

    return SizedBox(
      width: 58,
      height: 78,
      child: game.waste.isEmpty
          ? Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30),
                borderRadius: BorderRadius.circular(6),
              ),
            )
          : Stack(
              children: [
                // Show the next card in the waste if dragging the top card
                if (isDraggingWasteTop && game.waste.length > 1)
                  _buildCard(game.waste[game.waste.length - 2]),
                if (isDraggingWasteTop && game.waste.length == 1)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                if (!isDraggingWasteTop)
                  Draggable<CardModel>(
                    data: game.waste.last,
                    feedback: _buildCard(game.waste.last),
                    childWhenDragging: Container(),
                    child: _buildCard(game.waste.last),
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
    List<CardModel> pile = game.foundations[index];
    // Only show next card if dragging from this foundation
    final isDraggingThisFoundation = pile.isNotEmpty &&
      _isDragging &&
      _draggingPileIndex == index &&
      _draggingCardIndex == -1 &&
      pile.last == (game.foundations[index].isNotEmpty ? game.foundations[index].last : null);

    return DragTarget<Object>(
      onWillAccept: (data) {
        if (data == null) return false;
        CardModel card;
        if (data is CardModel) {
          card = data;
        } else if (data is DragData) {
          card = data.card;
          if (data.pileIndex >= 0) {
            final movingCards = game.tableau[data.pileIndex].sublist(data.cardIndex);
            if (movingCards.length > 1) return false;
          }
          if (data.pileIndex == -1) return false;
        } else {
          return false;
        }
        return game.canPlaceOnFoundation(card, pile);
      },
      onAccept: (data) {
        setState(() {
          if (data is CardModel) {
            // Check if from waste
            if (game.waste.isNotEmpty && game.waste.last == data) {
              game.moveWasteToFoundation(index);
            } else {
              // From tableau
              for (int i = 0; i < 7; i++) {
                if (game.tableau[i].contains(data)) {
                  game.moveTableauToFoundation(i, index);
                  break;
                }
              }
            }
          } else if (data is DragData) {
            game.moveTableauToFoundation(data.pileIndex, index);
          }
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
    final pile = game.tableau[index];

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
        return game.canPlaceOnTableau(card, pile.isNotEmpty ? pile.last : null);
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        setState(() {
          if (data is DragData) {
            if (data.pileIndex == -1) {
              // From foundation
              game.moveFoundationToTableau(data.card, index);
            } else {
              game.moveTableauToTableau(data.pileIndex, data.cardIndex, index);
            }
          } else if (data is CardModel) {
            // Check if moving from tableau
            for (int i = 0; i < 7; i++) {
              if (game.tableau[i].contains(data)) {
                final cardIndex = game.tableau[i].indexOf(data);
                game.moveTableauToTableau(i, cardIndex, index);
                return;
              }
            }
            // Else from waste
            if (game.waste.isNotEmpty && game.waste.last == data) {
              game.moveWasteToTableau(index);
            }
          }
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
    final pile = game.tableau[pileIndex];
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