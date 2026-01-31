import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

enum ArmchairStyle { modern, cozy, vintage, clay, love }

class RoomDecorationState extends Equatable {
  final ArmchairStyle armchairStyle;

  const RoomDecorationState({this.armchairStyle = ArmchairStyle.modern});

  RoomDecorationState copyWith({ArmchairStyle? armchairStyle}) {
    return RoomDecorationState(
      armchairStyle: armchairStyle ?? this.armchairStyle,
    );
  }

  @override
  List<Object> get props => [armchairStyle];
}

class RoomDecorationCubit extends Cubit<RoomDecorationState> {
  RoomDecorationCubit() : super(const RoomDecorationState());

  void setArmchairStyle(ArmchairStyle style) {
    emit(state.copyWith(armchairStyle: style));
  }
}
