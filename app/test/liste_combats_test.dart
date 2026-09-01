/// Verrous sur la colonne des challenges dans la liste des combats.
library;

import 'package:dofus_tracker/modele/session.dart';
import 'package:dofus_tracker/source/ressources.dart';
import 'package:dofus_tracker/theme.dart';
import 'package:dofus_tracker/vue/standard/pages/combats.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;

const qui = 'Kaska-yopette';
final res = Ressources('.');

ChallengeFait defi(int id, {required bool reussi}) => ChallengeFait(
  ts: 1,
  challengeId: id,
  bonus: 10,
  origine: 'choisi',
  reussi: reussi,
  combattants: const [qui],
);

Combat combatAvec(double fin, List<ChallengeFait> challenges) => Combat(
  fin: fin,
  duree: 60,
  challenges: challenges,
  participants: [
    ParticipantCombat(
      nom: qui,
      niveau: 60,
      xp: 100,
      xpTotal: 0,
      xpSeuilBas: 0,
      xpSeuilHaut: 0,
      kamas: 10,
      butin: const {},
    ),
  ],
);

Future<void> monte(WidgetTester tester, List<Combat> combats) async {
  await tester.binding.setSurfaceSize(const Size(1000, 600));
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
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: PageCombats(
              combats: combats,
              personnage: qui,
              res: res,
              onCombat: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// La pastille d'un challenge : le carre teinte, vert ou rouge.
Iterable<Color?> pastilles(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.borderRadius == BorderRadius.circular(5))
    .map((d) => d.color);

void main() {
  testWidgets('la colonne se tient entre la duree et l\'experience', (
    tester,
  ) async {
    await monte(tester, [combatAvec(1700000000, [defi(1, reussi: true)])]);
    final duree = tester.getRect(find.text('DURÉE'));
    final challenges = tester.getRect(find.text('CHALLENGES'));
    final experience = tester.getRect(find.text('EXPÉRIENCE'));
    expect(duree.left, lessThan(challenges.left));
    expect(challenges.left, lessThan(experience.left));
  });

  testWidgets('une pastille par challenge, teintee selon l\'issue', (
    tester,
  ) async {
    await monte(tester, [
      combatAvec(1700000000, [defi(1, reussi: true), defi(2, reussi: false)]),
    ]);
    final couleurs = pastilles(tester).toList();
    expect(couleurs.length, 2);
    // Le vert de la palette pour le reussi, le rouge du theme pour l'echoue :
    // c'est la seule chose que la colonne dit, elle doit la dire juste.
    expect(couleurs.first, Palette.vert.withValues(alpha: 0.14));
    expect(couleurs.last, isNot(Palette.vert.withValues(alpha: 0.14)));
  });

  testWidgets('un combat sans challenge le dit', (tester) async {
    await monte(tester, [combatAvec(1700000000, const [])]);
    expect(pastilles(tester), isEmpty);
    // Une case vide se confondrait avec une colonne qui ne marche pas.
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('le tri classe les reussis avant les rates', (tester) async {
    await monte(tester, [
      combatAvec(1700000000, [defi(1, reussi: false)]),
      combatAvec(1700000100, [defi(1, reussi: true), defi(2, reussi: true)]),
      combatAvec(1700000200, const []),
    ]);
    await tester.tap(find.text('CHALLENGES'));
    await tester.pumpAndSettle();

    // Deux reussis en tete, puis l'echec, puis le combat sans challenge.
    final lignes = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.borderRadius == BorderRadius.circular(5))
        .toList();
    expect(lignes.length, 3);
    expect(lignes[0].color, Palette.vert.withValues(alpha: 0.14));
    expect(lignes[1].color, Palette.vert.withValues(alpha: 0.14));
    expect(lignes[2].color, isNot(Palette.vert.withValues(alpha: 0.14)));
  });

  testWidgets('la colonne ignore les objectifs de boss', (tester) async {
    await monte(tester, [
      combatAvec(1700000000, [
        defi(1, reussi: true),
        // Un objectif de boss : pas de pourcentage de bonus, et une origine
        // qui le dit. Le jeu le fait tomber par les memes messages qu'un
        // challenge, et la colonne en montrait deux.
        ChallengeFait(
          ts: 1,
          challengeId: 127,
          bonus: null,
          origine: 'objectif',
          reussi: true,
          combattants: const [qui],
        ),
      ]),
    ]);
    expect(pastilles(tester).length, 1);
  });
}
