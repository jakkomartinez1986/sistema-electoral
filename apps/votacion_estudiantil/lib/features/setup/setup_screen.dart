import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/enrollment/enrollment_repository.dart';
import '../../core/providers.dart';
import '../provisioning/provisioning_screen.dart';

/// Configuración inicial del dispositivo.
///
/// Regla dura de la especificación: **un dispositivo no se autoriza a sí
/// mismo**. El personal electoral registra este equipo en Administración y
/// genera un código de un solo uso; aquí se digita para vincularlo. Es el mismo
/// nivel de seguridad que escanear un QR, sin cámara.
class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    final session = ref.watch(authSessionProvider).value;
    if (session != null) {
      return ProvisioningScreen(email: session.user.email);
    }
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KiteSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: const _EnrollCard(),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnrollCard extends ConsumerStatefulWidget {
  const _EnrollCard();

  @override
  ConsumerState<_EnrollCard> createState() => _EnrollCardState();
}

class _EnrollCardState extends ConsumerState<_EnrollCard> {
  final TextEditingController _code = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    final cleaned = value
        .toUpperCase()
        .replaceAll(RegExp('[^0-9A-F]'), '');
    if (cleaned != value) {
      _code.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
    setState(() => _canSubmit = cleaned.length >= 8);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(enrollmentControllerProvider.notifier)
        .enroll(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    final c = KiteColors.of(context);
    final uid = ref.watch(deviceUidProvider);
    final enrollment = ref.watch(enrollmentControllerProvider);
    final loading = enrollment.isLoading;

    ref.listen(enrollmentControllerProvider, (previous, next) {
      if (next.hasValue &&
          !next.isLoading &&
          previous?.hasValue == false) {
        KiteToast.show(
          context,
          title: 'Dispositivo vinculado',
          tone: KiteTone.success,
        );
      }
    });

    return KiteCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.tablet_android_outlined, size: 64, color: c.primary),
          const SizedBox(height: KiteSpace.lg),
          Text(
            'Autorizar este dispositivo',
            textAlign: TextAlign.center,
            style: t.h3,
          ),
          const SizedBox(height: KiteSpace.sm),
          Text(
            'Mientras no esté vinculado, el equipo no puede votar. Pide al '
            'personal electoral que registre el identificador de abajo y '
            'genere un código de emparejamiento.',
            textAlign: TextAlign.center,
            style: t.muted,
          ),
          const SizedBox(height: KiteSpace.xl),
          _DeviceUid(uid: uid),
          const SizedBox(height: KiteSpace.lg),
          KiteField(
            label: 'Código de emparejamiento',
            hint: '12 caracteres (0-9, A-F). Vence en pocos minutos y es de un '
                'solo uso.',
            child: KiteInput(
              controller: _code,
              placeholder: 'A1B2C3D4E5F6',
              onChanged: _onCodeChanged,
            ),
          ),
          if (enrollment.hasError) ...[
            KiteAlert(
              title: 'No se pudo vincular',
              description: _messageOf(enrollment.error!),
              tone: KiteTone.danger,
            ),
            const SizedBox(height: KiteSpace.lg),
          ],
          KiteButton(
            expands: true,
            enabled: _canSubmit && !loading,
            onPressed: _submit,
            leading: const Icon(Icons.link),
            child: Text(loading ? 'Vinculando…' : 'Vincular dispositivo'),
          ),
        ],
      ),
    );
  }

  static String _messageOf(Object error) =>
      error is EnrollmentException ? error.message : '$error';
}

class _DeviceUid extends ConsumerWidget {
  const _DeviceUid({required this.uid});

  final AsyncValue<String> uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final c = KiteColors.of(context);
    return KiteField(
      label: 'Identificador de este equipo',
      hint: 'Regístralo en Administración → Dispositivos.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: KiteSpace.md,
          vertical: KiteSpace.md,
        ),
        decoration: BoxDecoration(
          color: c.muted,
          borderRadius: KiteRadius.allMd,
        ),
        child: uid.when(
          loading: () => Text('Generando…', style: t.muted),
          error: (error, _) => Text('No disponible: $error', style: t.muted),
          data: (value) => Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: t.p.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) {
                    KiteToast.show(
                      context,
                      title: 'Identificador copiado',
                      tone: KiteTone.success,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
