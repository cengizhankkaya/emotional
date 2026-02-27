import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CallQualityMenu {
  CallQualityMenu._();

  static void show(BuildContext context, CallBloc callBloc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsCustom.darkABlue,
      builder: (modalContext) => BlocProvider.value(
        value: callBloc,
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) return const SizedBox.shrink();
            return _CallQualityMenuContent(state: state, callBloc: callBloc);
          },
        ),
      ),
    );
  }
}

class _CallQualityMenuContent extends StatelessWidget {
  final CallConnected state;
  final CallBloc callBloc;

  const _CallQualityMenuContent({required this.state, required this.callBloc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const SizedBox(height: 10),
          Flexible(child: _buildQualityList()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            // Ayarlar sayfasına geri dön
            // Not: CallSettingsSheet.show(context, state) çağrısı
            // döngüsel bağımlılık oluşturur, bu yüzden Navigator ile geri dönüyoruz.
          },
        ),
        Expanded(
          child: Text(
            LocaleKeys.call_streamQuality.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildQualityList() {
    return ListView(
      shrinkWrap: true,
      children: CallQualityPreset.values.map((q) {
        final isSelected = q == state.currentQuality;
        return ListTile(
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? ColorsCustom.cream : Colors.white30,
          ),
          title: Text(
            q.displayName,
            style: TextStyle(
              color: isSelected ? ColorsCustom.cream : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            debugPrint('[CallQualityMenu] Quality selected: $q');
            callBloc.add(ChangeQuality(q));
          },
        );
      }).toList(),
    );
  }
}
