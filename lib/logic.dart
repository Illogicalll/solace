import 'package:flutter/material.dart';

enum Suit { hearts, diamonds, clubs, spades }

class CardModel {
  final Suit suit;
  final int rank;
  bool faceUp;

  CardModel(this.suit, this.rank, {this.faceUp = false});

  String get rankString {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return rank.toString();
    }
  }

  Color get color =>
      (suit == Suit.hearts || suit == Suit.diamonds) ? Colors.red : Colors.black;

  String get suitSymbol {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }

  Map<String, dynamic> toJson() => {
    'suit': suit.index,
    'rank': rank,
    'faceUp': faceUp,
  };

  static CardModel fromJson(Map<String, dynamic> json) {
    return CardModel(
      Suit.values[json['suit']],
      json['rank'],
      faceUp: json['faceUp'],
    );
  }
}

class SolitaireGame {
  List<CardModel> deck = [];
  List<List<CardModel>> tableau = List.generate(7, (_) => []);
  List<List<CardModel>> foundations = List.generate(4, (_) => []);
  List<CardModel> stock = [];
  List<CardModel> waste = [];

  SolitaireGame() {
    init();
  }

  void init() {
    deck = [];
    for (var suit in Suit.values) {
      for (int rank = 1; rank <= 13; rank++) {
        deck.add(CardModel(suit, rank));
      }
    }
    deck.shuffle();

    for (int i = 0; i < 7; i++) {
      tableau[i].clear();
      for (int j = 0; j <= i; j++) {
        var card = deck.removeLast();
        card.faceUp = j == i;
        tableau[i].add(card);
      }
    }

    foundations.forEach((f) => f.clear());
    stock = deck.toList();
    waste.clear();
  }

  bool canPlaceOnTableau(CardModel movingCard, CardModel? targetCard) {
    if (targetCard == null) {
      return movingCard.rank == 13;
    }
    bool differentColor = movingCard.color != targetCard.color;
    bool oneLessRank = movingCard.rank == targetCard.rank - 1;
    return differentColor && oneLessRank;
  }

  bool canPlaceOnFoundation(CardModel movingCard, List<CardModel> foundation) {
    if (foundation.isEmpty) {
      return movingCard.rank == 1;
    }
    var top = foundation.last;
    bool sameSuit = movingCard.suit == top.suit;
    bool oneHigher = movingCard.rank == top.rank + 1;
    return sameSuit && oneHigher;
  }

  void moveTableauToTableau(int fromPile, int cardIndex, int toPile) {
    List<CardModel> from = tableau[fromPile];
    List<CardModel> to = tableau[toPile];

    var movingCards = from.sublist(cardIndex);
    if (movingCards.isEmpty) return;

    if (!canPlaceOnTableau(movingCards[0], to.isEmpty ? null : to.last)) return;

    tableau[toPile].addAll(movingCards);
    tableau[fromPile].removeRange(cardIndex, from.length);

    if (tableau[fromPile].isNotEmpty) {
      tableau[fromPile].last.faceUp = true;
    }
  }

  void moveWasteToTableau(int toPile) {
    if (waste.isEmpty) return;
    var card = waste.last;
    if (!canPlaceOnTableau(card, tableau[toPile].isEmpty ? null : tableau[toPile].last)) {
      return;
    }
    tableau[toPile].add(card);
    waste.removeLast();
  }

  void moveWasteToFoundation(int foundationIndex) {
    if (waste.isEmpty) return;
    var card = waste.last;
    if (!canPlaceOnFoundation(card, foundations[foundationIndex])) return;
    foundations[foundationIndex].add(card);
    waste.removeLast();
  }

  void moveTableauToFoundation(int fromPile, int foundationIndex) {
    var pile = tableau[fromPile];
    if (pile.isEmpty) return;
    var card = pile.last;
    if (!canPlaceOnFoundation(card, foundations[foundationIndex])) return;
    foundations[foundationIndex].add(card);
    pile.removeLast();

    if (pile.isNotEmpty) pile.last.faceUp = true;
  }

  void drawFromStock() {
    if (stock.isEmpty) {
      stock = waste.reversed.map((c) {
        c.faceUp = false;
        return c;
      }).toList();
      waste.clear();
      return;
    }
    var card = stock.removeLast();
    card.faceUp = true;
    waste.add(card);
  }

  void moveFoundationToTableau(CardModel card, int toPile) {
    int foundationIndex = -1;
    for (int i = 0; i < foundations.length; i++) {
      if (foundations[i].isNotEmpty && foundations[i].last == card) {
        foundationIndex = i;
        break;
      }
    }
    if (foundationIndex == -1) return;
    if (!canPlaceOnTableau(card, tableau[toPile].isNotEmpty ? tableau[toPile].last : null)) return;
    foundations[foundationIndex].removeLast();
    tableau[toPile].add(card);
  }

  bool isWin() {
    return foundations.every((f) => f.length == 13);
  }

  Map<String, dynamic> toJson() => {
    'deck': deck.map((c) => c.toJson()).toList(),
    'tableau': tableau.map((pile) => pile.map((c) => c.toJson()).toList()).toList(),
    'foundations': foundations.map((pile) => pile.map((c) => c.toJson()).toList()).toList(),
    'stock': stock.map((c) => c.toJson()).toList(),
    'waste': waste.map((c) => c.toJson()).toList(),
  };

  static SolitaireGame fromJson(Map<String, dynamic> json) {
    SolitaireGame game = SolitaireGame();
    game.deck = (json['deck'] as List).map((c) => CardModel.fromJson(c)).toList();
    game.tableau = (json['tableau'] as List)
        .map((pile) => (pile as List).map((c) => CardModel.fromJson(c)).toList())
        .toList();
    game.foundations = (json['foundations'] as List)
        .map((pile) => (pile as List).map((c) => CardModel.fromJson(c)).toList())
        .toList();
    game.stock = (json['stock'] as List).map((c) => CardModel.fromJson(c)).toList();
    game.waste = (json['waste'] as List).map((c) => CardModel.fromJson(c)).toList();
    return game;
  }
}
