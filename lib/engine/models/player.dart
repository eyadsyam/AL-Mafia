import 'enums.dart';

enum PlayerGender { unspecified, male, female }

/// A reference to when a player was eliminated.
/// Reference: data-model.md §2
class PhaseRef {
  final GamePhase phase;
  final int number; // day number or night number depending on phase

  const PhaseRef({required this.phase, required this.number});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseRef &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          number == other.number;

  @override
  int get hashCode => phase.hashCode ^ number.hashCode;

  @override
  String toString() => 'PhaseRef($phase, $number)';
}

/// A player in the game. Contains secret information (role).
/// Reference: data-model.md §2
class Player {
  final int seat;
  final String name;
  final PlayerGender gender;
  final Role role;
  final PlayerStatus status;
  final PhaseRef? eliminatedOn;

  const Player({
    required this.seat,
    required this.name,
    this.gender = PlayerGender.unspecified,
    required this.role,
    required this.status,
    this.eliminatedOn,
  });

  /// Create a copy with optional field overrides.
  Player copyWith({
    int? seat,
    String? name,
    PlayerGender? gender,
    Role? role,
    PlayerStatus? status,
    PhaseRef? eliminatedOn,
  }) => Player(
    seat: seat ?? this.seat,
    name: name ?? this.name,
    gender: gender ?? this.gender,
    role: role ?? this.role,
    status: status ?? this.status,
    eliminatedOn: eliminatedOn ?? this.eliminatedOn,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          seat == other.seat &&
          name == other.name &&
          gender == other.gender &&
          role == other.role &&
          status == other.status &&
          eliminatedOn == other.eliminatedOn;

  @override
  int get hashCode =>
      seat.hashCode ^
      name.hashCode ^
      gender.hashCode ^
      role.hashCode ^
      status.hashCode ^
      eliminatedOn.hashCode;

  @override
  String toString() =>
      'Player(seat=$seat, name=$name, role=$role, status=$status, eliminatedOn=$eliminatedOn)';
}

/// A public view of a player that excludes secret information (role).
/// This is the anti-leakage guarantee: PublicPlayer never exposes role.
/// Reference: data-model.md §2, game-engine.contract.md
class PublicPlayer {
  final int seat;
  final String name;
  final PlayerGender gender;
  final PlayerStatus status;

  const PublicPlayer({
    required this.seat,
    required this.name,
    this.gender = PlayerGender.unspecified,
    required this.status,
  });

  /// Factory to construct a PublicPlayer from a Player, dropping the role.
  factory PublicPlayer.from(Player player) => PublicPlayer(
    seat: player.seat,
    name: player.name,
    gender: player.gender,
    status: player.status,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicPlayer &&
          runtimeType == other.runtimeType &&
          seat == other.seat &&
          name == other.name &&
          gender == other.gender &&
          status == other.status;

  @override
  int get hashCode =>
      seat.hashCode ^ name.hashCode ^ gender.hashCode ^ status.hashCode;

  @override
  String toString() => 'PublicPlayer(seat=$seat, name=$name, status=$status)';
}
