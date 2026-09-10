/// Verrous sur l'editeur de macro.
///
/// Les lignes sont designees par leur **position**, et c'est la que tout se
/// joue : une ligne qui ecrit ce qu'elle contenait au moment de disparaitre
/// ecrit a la place d'une autre. Les deux cas ci-dessous sont arrives.
library;

import 'package:dofus_tracker/config.dart';
import 'package:dofus_tracker/modele/macro.dart';
import 'package:dofus_tracker/source/macros.dart';
import 'package:dofus_tracker/source/organizer.dart';
import 'package:dofus_tracker/source/raccourcis.dart';
import 'package:dofus_tracker/vue/standard/pages/macro_editeur.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

Future<Macros> monte(WidgetTester tester, Macro macro) async {
  final config = Config(macros: [macro]);
  final macros = Macros(
    config: config,
    raccourcis: Raccourcis(pont: PontOrganizer()),
  );
  addTearDown(macros.dispose);

  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
        home: Scaffold(body: PageMacro(macros: macros, id: macro.id)),
      ),
    ),
  );
  await tester.pump();
  return macros;
}


void main() {
  testWidgets('supprimer une variable ne la fait pas revenir', (tester) async {
    // La ligne s'ecrivait depuis `dispose`, a son rang — celui qu'elle
    // n'occupait plus. La variable reapparaissait aussitot, vide.
    final macros = await monte(
      tester,
      const Macro(
        id: 'm',
        nom: 'Inviter',
        variables: [Variable(nom: 'mes_persos', valeurs: ['A', 'B'])],
      ),
    );

    expect(find.text('mes_persos'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.trash2).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(macros.parId('m')!.variables, isEmpty);
    expect(find.text('mes_persos'), findsNothing);
  });

  testWidgets('monter une boucle ne duplique pas le texte au-dessus', (
    tester,
  ) async {
    // Le champ de texte gardait le contenu de la ligne qu'il etait avant le
    // deplacement, et le rendait a la boucle qui avait pris sa place.
    final macros = await monte(
      tester,
      const Macro(
        id: 'm',
        nom: 'Inviter',
        etapes: [
          EtapeTexte('/invite Kaska'),
          EtapeBoucle(repetitions: 3, etapes: [EtapePause(50)]),
        ],
      ),
    );

    // La fleche du haut de la boucle : celle du texte est desactivee, il est
    // premier.
    final montees = find.byIcon(LucideIcons.chevronUp);
    await tester.tap(montees.at(1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final etapes = macros.parId('m')!.etapes;
    expect(etapes, hasLength(2));
    expect(etapes.first, isA<EtapeBoucle>());
    expect(etapes.last, const EtapeTexte('/invite Kaska'));
  });

  testWidgets('une boucle dit combien de valeurs elle parcourt', (
    tester,
  ) async {
    await monte(
      tester,
      const Macro(
        id: 'm',
        nom: 'Inviter',
        variables: [Variable(nom: 'mes_persos', valeurs: ['A', 'B', 'C'])],
        etapes: [
          EtapeBoucle(liste: 'mes_persos', etapes: [EtapeTexte('{mes_persos}')]),
        ],
      ),
    );

    expect(find.text('pour chaque {mes_persos} (3 valeurs)'), findsOneWidget);
  });

  testWidgets('supprimer un geste n ecrase pas le suivant', (tester) async {
    // Le meme defaut que pour les variables, sur les gestes : la ligne
    // disparue se rendait a son rang, et ecrasait celui qui venait d'y monter.
    final macros = await monte(
      tester,
      const Macro(
        id: 'm',
        nom: 'Inviter',
        etapes: [
          EtapeTexte('premier'),
          EtapeTexte('deuxieme'),
          EtapeTexte('troisieme'),
        ],
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.trash2).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(macros.parId('m')!.etapes, [
      const EtapeTexte('deuxieme'),
      const EtapeTexte('troisieme'),
    ]);
  });
}
