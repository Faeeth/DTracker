/// Suivi de session Dofus : surcouche translucide posee au-dessus du jeu.
///
/// La capture et le decodage du protocole restent en Python — c'est la que vit
/// `dofus_stats`, validee par soixante-et-onze verifications sur des captures
/// reelles. Cette application en consomme le flux d'evenements et se charge de
/// l'affichage, ce que Qt rendait laborieux : une fenetre translucide, deux
/// opacites independantes, des animations, et la charte du jeu au pixel.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
// `shadcn_ui` reexporte `flutter_svg`, qui definit lui aussi un `Cache`. On
// masque le sien : le notre est celui des classes et des prix.
import 'package:shadcn_ui/shadcn_ui.dart' hide Cache;
import 'package:window_manager/window_manager.dart';

import 'config.dart';
import 'modele/session.dart';
import 'source/archives.dart';
import 'source/cache.dart';
import 'source/emplacements.dart';
import 'source/flux.dart';
import 'source/ressources.dart';
import 'vue/fenetre.dart';
import 'vue/theme_shad.dart';
import 'i18n/textes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Les reglages, le cache et les sessions vivent chez l'utilisateur ; le
  // programme, la ou il a ete installe. Voir `source/emplacements.dart`.
  final ou = Emplacements.reconnait();
  await ou.prepare(
    // Ce que les versions d'avant laissaient a cote de l'executable, ou dans
    // un dossier voisin : on le reprend une fois, sans jamais ecraser ce qui
    // existe deja ici.
    reprises: [
      Directory(Platform.resolvedExecutable).parent.path,
      '${Directory(ou.donnees).parent.path}/dofus_tracker',
    ],
  );
  final racine = ou.donnees;
  final config = await Config.charge(racine);
  // La langue avant tout affichage : les libelles se lisent au premier build.
  changeLangue(Langue.depuisCode(config.langue));
  final res = Ressources(ou.ressources);
  await res.charge();
  final archives = Archives(ou.sessions);
  // Un lancement ouvre toujours une session neuve. Ce qui restait marque
  // « en cours » vient de l'execution precedente et ne l'est plus.
  await archives.clotLesOrphelines();
  // Chaque lancement ouvre sa session. Elle ne prendra un fichier qu'au
  // premier fait — un demarrage suivi d'une bascule ne doit rien semer.
  final numero = await archives.prochainNumero();
  final cache = Cache(ou.cache);
  // Au premier lancement, on reprend ce que la version precedente savait
  // deja : ses classes et ses prix n'ont pas a etre reappris.
  await cache.charge();

  // On ouvre toujours en vue standard, quelle que soit celle qu'on regardait
  // en fermant. La compacte est un mode de travail — on y bascule quand on se
  // met a jouer — et la retrouver au demarrage donne une fenetre etroite,
  // translucide et sans reglages accessibles pour qui vient d'ouvrir l'outil.
  config.compact = false;

  // Chaque vue a sa geometrie. La compacte se cale sur son contenu et n'est
  // pas redimensionnable ; la standard est une fenetre ordinaire, qu'on
  // redimensionne et dont la taille est conservee.
  final depart = Size(config.largeurStandard, config.hauteurStandard);

  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: depart,
      // Chaque vue a son plancher : la compacte tient dans une bande etroite,
      // la standard non. En dessous, la rangee deborde — une erreur de rendu,
      // pas un defaut d'apparence.
      minimumSize: tailleMiniStandard,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    ),
    () async {
      await windowManager.setAsFrameless();
      await windowManager.setPosition(Offset(config.x, config.y));
      await windowManager.setAlwaysOnTop(config.toujoursDevant);
      await windowManager.setHasShadow(false);
      await windowManager.setResizable(true);
      // La vue standard occupe sa propre fenetre : elle reste pleine. La
      // transparence de la compacte passe par l'opacite de la fenetre — voir
      // `Fenetre._appliqueTransparence`, qui la pose au moment de basculer.
      await windowManager.setOpacity(1);
      await windowManager.show();
    },
  );

  runApp(
    Application(
      numero: numero,
      config: config,
      res: res,
      racine: racine,
      cache: cache,
      archives: archives,
      flux: Flux(ou: ou, interface: config.interface),
    ),
  );
}

class Application extends StatelessWidget {
  const Application({
    super.key,
    required this.numero,
    required this.config,
    required this.res,
    required this.racine,
    required this.cache,
    required this.archives,
    required this.flux,
  });

  /// Numero de la session qui s'ouvre, qui lui donne son nom par defaut.
  final int numero;

  final Config config;
  final Ressources res;
  final String racine;
  final Cache cache;
  final Archives archives;
  final Flux flux;

  @override
  Widget build(BuildContext context) {
    // `ShadApp.custom` et non `ShadApp` : ce dernier construit un `WidgetsApp`,
    // sans ancetre Material. Or l'outil se sert de `Scaffold`, `TextField`,
    // `Tooltip` et `Scrollbar`, qui exigent tous `MaterialLocalizations`. Cette
    // variante pose le `ShadTheme` et laisse l'application Material se
    // construire dessous — c'est la voie que la documentation du paquet
    // reserve a ce cas.
    return ShadApp.custom(
      themeMode: ThemeMode.dark,
      darkTheme: themeSombre(),
      appBuilder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: T.marque,
        theme: themeMaterial(),
        localizationsDelegates: const [
          GlobalShadLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        builder: habille,
        home: Surcouche(
          config: config,
          res: res,
          racine: racine,
          flux: flux,
          cache: cache,
          archives: archives,
          session: Session(config.personnages)
            ..numero = numero
            ..nom = T.sessionNumero(numero)
            ..compteLesSucces = config.succesComptes
            ..definitClasses(cache.classes)
            ..prix.addAll(cache.prix),
        ),
      ),
    );
  }
}
