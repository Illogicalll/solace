import 'package:flutter/material.dart';
import 'logic.dart';

class GameDetailView extends StatelessWidget {
  final Map<String, dynamic> gameState;
  final String date;
  final int score;
  final bool isWin;
  
  const GameDetailView({
    super.key, 
    required this.gameState, 
    required this.date, 
    required this.score,
    required this.isWin,
  });

  @override
  Widget build(BuildContext context) {
    final game = SolitaireGame.fromJson(gameState);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isWin ? 'victory' : 'defeat',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'CabinetGrotesk',
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 16
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'score: $score',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 18, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isWin ? Colors.green : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: isWin 
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isWin ? Icons.emoji_events : Icons.close,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'final state',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildFoundationsRow(game),
              const SizedBox(height: 16),
              _buildStockAndWasteRow(game),
              const SizedBox(height: 30),
              _buildTableau(game),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoundationsRow(SolitaireGame game) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (index) {
        final foundation = game.foundations[index];
        return Container(
          width: 60,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white30),
            borderRadius: BorderRadius.circular(6),
          ),
          child: foundation.isEmpty 
            ? null 
            : _buildCard(foundation.last),
        );
      }),
    );
  }

  Widget _buildStockAndWasteRow(SolitaireGame game) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white30),
            borderRadius: BorderRadius.circular(6),
          ),
          child: game.stock.isEmpty 
            ? null 
            : _buildCardBack(),
        ),
        const SizedBox(width: 20),
        Container(
          width: 60,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white30),
            borderRadius: BorderRadius.circular(6),
          ),
          child: game.waste.isEmpty 
            ? null 
            : _buildCard(game.waste.last),
        ),
      ],
    );
  }

  Widget _buildTableau(SolitaireGame game) {
    const double cardWidth = 45.0;
    const double cardHeight = 65.0;
    const double cardOffset = 20.0;

    double maxHeight = 0;
    for (final pile in game.tableau) {
      if (pile.isNotEmpty) {
        double pileHeight = cardHeight + (pile.length - 1) * cardOffset;
        maxHeight = pileHeight > maxHeight ? pileHeight : maxHeight;
      }
    }
    maxHeight = maxHeight > 0 ? maxHeight : cardHeight;

    return Container(
      width: double.infinity,
      height: maxHeight + 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          7,
          (index) {
            final pile = game.tableau[index];
            return SizedBox(
              width: cardWidth + 2,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (pile.isEmpty)
                    Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  for (int i = 0; i < pile.length; i++)
                    Positioned(
                      top: i * cardOffset,
                      child: pile[i].faceUp 
                          ? _buildCompactCard(pile[i], cardWidth, cardHeight)
                          : _buildCompactCardBack(cardWidth, cardHeight),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactCard(CardModel card, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: Text(
              card.rankString,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: card.color,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Text(
              card.suitSymbol,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: card.color,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                card.suitSymbol,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: card.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCardBack(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black),
      ),
      child: Center(
        child: Image.asset(
          'assets/icons/cardback.png',
          width: 50,
          height: 59
        ),
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
        child: Image.asset(
          'assets/icons/cardback.png',
          width: 80,
          height: 72
        ),
      ),
    );
  }
}
