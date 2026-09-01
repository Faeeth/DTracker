/// Verrous sur la mesure des colonnes.
///
/// `RemainingTableSpanExtent` rend `viewportExtent - precedingExtent`, ou
/// `precedingExtent` ne compte que les colonnes **qui precedent**. Place
/// ailleurs qu'en dernier, il avale la place des suivantes, qui sortent du
/// champ — sans erreur, sans debordement signale : la colonne est construite,
/// trouvable par un test, et simplement invisible.
///
/// C'est ainsi qu'une colonne entiere a disparu de cinq tableaux sans que rien
/// ne le dise. Ces cas mesurent donc les **largeurs**, pas la presence.
library;

import 'package:dofus_tracker/vue/standard/briques.dart';
import 'package:dofus_tracker/vue/theme_shad.dart';
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la colonne souple prend exactement ce qui reste', () {
    const colonnes = [
      Colonne('A', 200),
      Colonne('B', 100),
      Colonne('SOUPLE', 0),
      Colonne('C', 150, Alignment.centerRight),
    ];
    final mesures = largeursDe(colonnes, 1000);
    expect(mesures, [200, 100, 550, 150]);
    // La somme fait la largeur : aucune colonne ne sort du champ.
    expect(mesures.reduce((a, b) => a + b), 1000);
  });

  test('la souple garde un plancher plutot que de disparaitre', () {
    const colonnes = [Colonne('A', 400), Colonne('SOUPLE', 0)];
    // Il ne reste que 50 pixels : mieux vaut un tableau qui defile qu'une
    // colonne ecrasee a rien.
    expect(largeursDe(colonnes, 450), [400, 120]);
  });

  test('sans colonne souple, les largeurs sont rendues telles quelles', () {
    const colonnes = [Colonne('A', 200), Colonne('B', 100)];
    expect(largeursDe(colonnes, 1000), [200, 100]);
  });

  test('deux colonnes souples se partagent le reste', () {
    const colonnes = [Colonne('A', 200), Colonne('X', 0), Colonne('Y', 0)];
    expect(largeursDe(colonnes, 1000), [200, 400, 400]);
  });

  testWidgets('l\'en-tete reste en place quand on defile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 240));
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
            body: Tableau(
              colonnes: const [Colonne('RANG', 0)],
              lignes: [
                for (var i = 0; i < 40; i++) [Text('ligne $i')],
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final avant = tester.getRect(find.text('RANG'));
    expect(find.text('ligne 0'), findsOneWidget);

    await tester.drag(find.text('ligne 1'), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Le corps a defile...
    expect(find.text('ligne 0'), findsNothing);
    // ...mais l'en-tete est reste : sans lui, on ne sait plus a la troisieme
    // page quelle colonne on regarde, ni ou cliquer pour trier.
    expect(find.text('RANG'), findsOneWidget);
    expect(tester.getRect(find.text('RANG')), avant);
  });
}
