import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rock_paper_scissors_demo_app/inference.dart';

enum Move {
  rock,
  paper,
  scissors,
  lizard,
  spock;

  // key: winner, value: (loser, interaction)
  static const Map<Move, List<({Move move, String interaction})>>
      moveInteractions = {
    Move.rock: [
      (move: Move.scissors, interaction: "crushes"),
      (move: Move.lizard, interaction: "crushes")
    ],
    Move.paper: [
      (move: Move.rock, interaction: "covers"),
      (move: Move.spock, interaction: "disproves")
    ],
    Move.scissors: [
      (move: Move.paper, interaction: "cuts"),
      (move: Move.lizard, interaction: "decapitates")
    ],
    Move.lizard: [
      (move: Move.paper, interaction: "eats"),
      (move: Move.spock, interaction: "poisons")
    ],
    Move.spock: [
      (move: Move.rock, interaction: "vaporizes"),
      (move: Move.scissors, interaction: "smashes")
    ],
  };

  get emoji {
    switch (this) {
      case Move.rock:
        return "🪨";
      case Move.paper:
        return "📄";
      case Move.scissors:
        return "✂️";
      case Move.lizard:
        return "🦎";
      case Move.spock:
        return "🖖";
    }
  }

  static Move? fromGestureOrNull(Gesture gesture, bool lizardSpockEnabled) {
    switch (gesture) {
      case Gesture.call:
        if (lizardSpockEnabled) {
          return spock;
        }
        return null;
      case Gesture.ok:
        if (lizardSpockEnabled) {
          return lizard;
        }
        return null;
      case Gesture.fist:
        return rock;
      case Gesture.stop:
      case Gesture.stopInverted:
      case Gesture.palm:
        return paper;
      case Gesture.peace:
      case Gesture.peaceInverted:
        return scissors;
      default:
        return null;
    }
  }

  static Move getRandomMove(bool lizardSpockEnabled) {
    final moves = List<Move>.from(Move.values);
    if (!lizardSpockEnabled) {
      moves.removeWhere((element) => element == spock || element == lizard);
    }
    return moves[Random().nextInt(moves.length)];
  }
}

enum RoundOutcome {
  playerWins,
  tie,
  playerLoses;
}

({RoundOutcome outcome, String message}) determineRoundResult(
    Move playerMove, Move computerMove) {
  if (playerMove == computerMove) {
    return (
      outcome: RoundOutcome.tie,
      message: "both picked ${playerMove.name} - it's a tie!"
    );
  }

  final playerWins = Move.moveInteractions[playerMove]!
      .where((element) => element.move == computerMove)
      .firstOrNull;
  if (playerWins != null) {
    return (
      outcome: RoundOutcome.playerWins,
      message:
          "${playerMove.name} ${playerWins.interaction} ${computerMove.name} - you win!"
    );
  }

  final playerLoses = Move.moveInteractions[computerMove]!
      .where((element) => element.move == playerMove)
      .first;
  return (
    outcome: RoundOutcome.playerLoses,
    message:
        "${computerMove.name} ${playerLoses.interaction} ${playerMove.name} - you lose!"
  );
}

class GameState {
  final bool lizardSpockEnabled;
  final int roundNumber;
  final int playerScore;
  final int computerScore;
  final Move? computerMove;
  final Move? playerMove;
  final RoundOutcome? roundOutcome;
  final String? roundMessage;

  GameState({
    required this.lizardSpockEnabled,
    required this.roundNumber,
    required this.playerScore,
    required this.computerScore,
    this.computerMove,
    this.playerMove,
    this.roundOutcome,
    this.roundMessage,
  });

  GameState copyWith({
    bool? lizardSpockEnabled,
    int? roundNumber,
    int? playerScore,
    int? computerScore,
    Move? computerMove,
    Move? playerMove,
    RoundOutcome? roundOutcome,
    String? roundMessage,
  }) {
    return GameState(
      lizardSpockEnabled: lizardSpockEnabled ?? this.lizardSpockEnabled,
      roundNumber: roundNumber ?? this.roundNumber,
      playerScore: playerScore ?? this.playerScore,
      computerScore: computerScore ?? this.computerScore,
      computerMove: computerMove ?? this.computerMove,
      playerMove: playerMove ?? this.playerMove,
      roundOutcome: roundOutcome ?? this.roundOutcome,
      roundMessage: roundMessage ?? this.roundMessage,
    );
  }
}

final gameStateNotifierProvider =
    NotifierProvider<GameStateNotifier, GameState>(() => GameStateNotifier());

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    ref.listen(gestureDetectionResultProvider, (previous, next) {
      next.whenData((gesture) {
        final playerMove =
            Move.fromGestureOrNull(gesture, state.lizardSpockEnabled);
        if (playerMove == null) {
          state =
              state.copyWith(roundMessage: "Invalid gesture: ${gesture.name}");
          return;
        }

        playRound(playerMove);
      });
    });

    return GameState(
        lizardSpockEnabled: false,
        roundNumber: 0,
        playerScore: 0,
        computerScore: 0);
  }

  void playRound(Move playerMove) async {
    final computerMove = Move.getRandomMove(state.lizardSpockEnabled);
    final result = determineRoundResult(playerMove, computerMove);

    state = state.copyWith(
      roundNumber: state.roundNumber + 1,
      playerMove: playerMove,
      computerMove: computerMove,
      roundOutcome: result.outcome,
      roundMessage: result.message,
    );

    switch (result.outcome) {
      case RoundOutcome.playerWins:
        state = state.copyWith(playerScore: state.playerScore + 1);
        break;
      case RoundOutcome.playerLoses:
        state = state.copyWith(computerScore: state.computerScore + 1);
        break;
      case RoundOutcome.tie:
        break;
    }
  }

  void toggleLizardSpock() {
    state = state.copyWith(lizardSpockEnabled: !state.lizardSpockEnabled);
  }
}
