import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:emotional/features/room/domain/repositories/room_repository.dart';

enum ArmchairStyle {
  esce,
  fwhite,
  mor,
  yesIl,
  lacivert,
  modern,
  vintage,
  clay,
  love,
}

class RoomDecorationState extends Equatable {
  final ArmchairStyle armchairStyle;

  const RoomDecorationState({this.armchairStyle = ArmchairStyle.fwhite});

  RoomDecorationState copyWith({ArmchairStyle? armchairStyle}) {
    return RoomDecorationState(
      armchairStyle: armchairStyle ?? this.armchairStyle,
    );
  }

  @override
  List<Object> get props => [armchairStyle];
}

class RoomDecorationCubit extends Cubit<RoomDecorationState> {
  final RoomRepository? _roomRepository;
  final String? _roomId;

  RoomDecorationCubit({RoomRepository? roomRepository, String? roomId})
    : _roomRepository = roomRepository,
      _roomId = roomId,
      super(const RoomDecorationState());

  void setArmchairStyle(ArmchairStyle style) {
    emit(state.copyWith(armchairStyle: style));
    if (_roomRepository != null && _roomId != null) {
      _roomRepository.updateArmchairStyle(_roomId, style.name);
    }
  }

  void updateFromSync(String styleName) {
    try {
      final style = ArmchairStyle.values.firstWhere((e) => e.name == styleName);
      if (state.armchairStyle != style) {
        emit(state.copyWith(armchairStyle: style));
      }
    } catch (_) {
      // Ignore unknown styles
    }
  }
}
