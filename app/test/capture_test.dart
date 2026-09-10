/// Verrous sur la capture d'un raccourci.
///
/// Le cas qui a casse : sur un clavier francais, la touche `*` s'annonce `\`
/// — le libelle d'une touche logique est celui de la disposition americaine.
/// On demandait donc a Windows la touche qui ecrit `\`, qui est AltGr+8 en
/// francais : le raccourci enregistre n'etait pas celui qu'on avait presse, et
/// il ne repondait jamais.
library;

import 'package:dofus_tracker/modele/raccourci.dart';
import 'package:dofus_tracker/source/organizer.dart';
import 'package:dofus_tracker/source/raccourcis.dart';
import 'package:dofus_tracker/vue/standard/pages/organizer_dialogues.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

/// Rend ce que Windows dirait d'un caractere sur un clavier francais.
class _PontFrancais extends PontOrganizer {
  _PontFrancais() : super(canal: const MethodChannel('test/capture'));

  final List<String> demandes = [];

  @override
  void ecoute() {}

  @override
  Future<Set<String>> applique(List<LiaisonNative> liaisons) async => {};

  @override
  Future<void> suspend({required bool suspendu}) async {}

  @override
  Future<int> toucheDuCaractere(String caractere) async {
    demandes.add(caractere);
    return switch (caractere) {
      // `*` est sur la touche que QWERTY nomme « backslash ».
      '*' => 0xDC,
      // `\` s'obtient avec AltGr+8 : c'est la touche du chiffre 8.
      r'\' => 0x38,
      _ => 0,
    };
  }
}

void main() {
  test('le caractere ecrit prime sur le libelle americain', () {
    expect(caractereEcrit(LogicalKeyboardKey.backslash, '*'), '*');
    // Rien d'ecrit : le libelle reste le seul indice.
    expect(caractereEcrit(LogicalKeyboardKey.f1, null), 'F1');
    expect(caractereEcrit(LogicalKeyboardKey.space, ' '), ' ');
  });

  testWidgets('la touche etoile d un clavier francais est bien celle-la', (
    tester,
  ) async {
    final pont = _PontFrancais();
    final raccourcis = Raccourcis(pont: pont);
    ChoixRaccourci? choix;

    await tester.pumpWidget(
      ShadApp.custom(
        themeMode: ThemeMode.dark,
        darkTheme: themeSombre(),
        appBuilder: (context) => MaterialApp(
          theme: themeMaterial(),
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          builder: habille,
          home: Builder(
            builder: (contexte) => Scaffold(
              body: ShadButton(
                onPressed: () async {
                  choix = await captureUnRaccourci(
                    contexte,
                    raccourcis,
                    titre: 'Touche',
                  );
                },
                child: const Text('ouvre'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvre'));
    await tester.pumpAndSettle();

    // Ce que Flutter rapporte d'un `*` presse sur un clavier francais : la
    // touche logique de la disposition americaine, et le caractere de la
    // disposition reelle.
    await simulateKeyDownEvent(
      LogicalKeyboardKey.backslash,
      character: '*',
    );
    await simulateKeyUpEvent(LogicalKeyboardKey.backslash);
    await tester.pumpAndSettle();

    expect(pont.demandes, ['*'], reason: 'c est le caractere ecrit qu on resout');
    expect(find.text('*'), findsOneWidget);

    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(choix!.raccourci, const Raccourci(touche: 0xDC, libelle: '*'));
  });
}
