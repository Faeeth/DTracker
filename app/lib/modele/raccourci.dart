/// Un raccourci global, dit dans le vocabulaire de Win32.
///
/// Partage par l'Organizer et les macros : ce sont les memes touches, prises
/// au meme endroit, et `RegisterHotKey` ne connait qu'une seule table. Ce
/// fichier ne sait rien de ce qu'un raccourci declenche.
library;

import 'package:flutter/foundation.dart';

/// Les indicateurs `MOD_*` que `RegisterHotKey` accepte.
abstract final class Modificateur {
  static const int alt = 0x0001;
  static const int ctrl = 0x0002;
  static const int maj = 0x0004;
  static const int windows = 0x0008;
}

/// Un raccourci global, dit dans le vocabulaire de Win32 pour n'avoir aucune
/// traduction a faire avant `RegisterHotKey`.
@immutable
class Raccourci {
  const Raccourci({required this.touche, this.modificateurs = 0, this.libelle});

  /// Code de touche virtuelle (`VK_*`).
  final int touche;

  /// Masque de [Modificateur].
  final int modificateurs;

  /// Le libelle releve a la capture.
  ///
  /// Le code virtuel des touches de ponctuation depend de la disposition du
  /// clavier : on garde la touche telle que l'utilisateur l'a vue plutot que
  /// de tenter de la redeviner.
  final String? libelle;

  /// Ce qui identifie le raccourci cote natif : tous les personnages qui
  /// partagent ces touches partagent un seul enregistrement.
  String get signature => '$modificateurs:$touche';

  bool get valide => touche != 0;

  String get nom {
    final capture = libelle;
    if (capture != null && capture.isNotEmpty) return capture;
    return nomDeTouche(touche);
  }

  String get affichage => [
    if (modificateurs & Modificateur.ctrl != 0) 'Ctrl',
    if (modificateurs & Modificateur.alt != 0) 'Alt',
    if (modificateurs & Modificateur.maj != 0) 'Maj',
    if (modificateurs & Modificateur.windows != 0) 'Win',
    nom,
  ].join(' + ');

  Map<String, Object?> versJson() => {
    'key_code': touche,
    'modifiers': modificateurs,
    if (libelle != null) 'key_name': libelle,
  };

  static Raccourci? depuisJson(Object? json) {
    if (json is! Map) return null;
    final touche = json['key_code'];
    if (touche is! int || touche == 0) return null;
    final mods = json['modifiers'];
    final nom = json['key_name'];
    return Raccourci(
      touche: touche,
      modificateurs: mods is int ? mods : 0,
      libelle: nom is String && nom.isNotEmpty ? nom : null,
    );
  }

  /// L'egalite ignore le libelle : ce qui identifie un raccourci est ce qui
  /// s'enregistre dans Windows.
  @override
  bool operator ==(Object other) =>
      other is Raccourci &&
      other.touche == touche &&
      other.modificateurs == modificateurs;

  @override
  int get hashCode => Object.hash(touche, modificateurs);

  @override
  String toString() => affichage;
}

/// Le nom lisible d'un code de touche virtuelle.
String nomDeTouche(int touche) {
  if (touche >= 0x70 && touche <= 0x87) return 'F${touche - 0x6F}';
  if (touche >= 0x60 && touche <= 0x69) return 'Num ${touche - 0x60}';
  if ((touche >= 0x41 && touche <= 0x5A) || (touche >= 0x30 && touche <= 0x39)) {
    return String.fromCharCode(touche);
  }
  return _nomsFixes[touche] ?? 'Touche $touche';
}

const Map<int, String> _nomsFixes = {
  0x08: 'Retour',
  0x09: 'Tab',
  0x0D: 'Entrée',
  0x13: 'Pause',
  0x14: 'Verr maj',
  0x1B: 'Échap',
  0x20: 'Espace',
  0x21: 'Page haut',
  0x22: 'Page bas',
  0x23: 'Fin',
  0x24: 'Début',
  0x25: 'Gauche',
  0x26: 'Haut',
  0x27: 'Droite',
  0x28: 'Bas',
  0x2C: 'Impr écran',
  0x2D: 'Inser',
  0x2E: 'Suppr',
  0x5D: 'Menu',
  0x6A: 'Num *',
  0x6B: 'Num +',
  0x6D: 'Num -',
  0x6E: 'Num .',
  0x6F: 'Num /',
  0x90: 'Verr num',
  0x91: 'Arrêt défil',
};

