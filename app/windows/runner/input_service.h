#ifndef RUNNER_INPUT_SERVICE_H_
#define RUNNER_INPUT_SERVICE_H_

#include <windows.h>

#include <string>

namespace dofus {

// L'envoi de frappes a la fenetre au premier plan.
//
// C'est la seule partie du programme qui **produit** quelque chose plutot que
// de lire : elle sert aux macros, et a rien d'autre. Elle passe par
// `SendInput`, la file d'entree ordinaire de Windows — le meme chemin qu'un
// clavier branche. Aucun processus n'est ouvert, aucune memoire n'est ecrite,
// et rien n'est adresse a une fenetre en particulier : ce qui a le premier
// plan recoit, comme pour une frappe humaine.
class InputService {
 public:
  // Ecrit |text| dans la fenetre qui a le clavier.
  //
  // En messages `WM_CHAR` et non en frappes injectees : le caractere voyage
  // alors dans le message, et arrive donc identique quelle que soit la
  // disposition du clavier — ce qui n'est pas vrai d'un « a » envoye comme
  // touche a qui joue en azerty — sans pouvoir etre confondu avec son voisin.
  //
  // Les frappes injectees, elles, portent le caractere dans un code de scan
  // que le destinataire lit au moment ou il traite le message : en retard,
  // il lisait le caractere suivant.
  //
  // |pace| est le temps, en millisecondes, laisse entre deux
  // caracteres. Zero les envoie a la file. Ce n'est pas une lenteur
  // decorative : une application qui recoit tout d'un bloc n'a pas
  // toujours vide sa file de messages entre-temps, et rend alors
  // plusieurs fois le meme caractere.
  static bool SendText(const std::wstring& text, DWORD pace);

  // Appuie et relache |key_code|, modificateurs `MOD_*` compris.
  //
  // Les modificateurs encadrent la frappe et sont relaches dans l'ordre
  // inverse : sans cela un Ctrl reste enfonce du point de vue de l'application
  // qui recoit, et tout ce qui suit devient un raccourci.
  static bool SendKey(UINT key_code, UINT modifiers);

  // Clique a |x|,|y|, en coordonnees d'ecran.
  //
  // Le pointeur y est deplace : Windows ne sait pas cliquer ailleurs qu'ou il
  // se trouve, et une application qui suit le survol doit voir le mouvement
  // pour reagir comme a une main. Les coordonnees couvrent tous les ecrans, y
  // compris ceux places a gauche ou au-dessus du principal, dont les
  // coordonnees sont negatives.
  static bool SendClick(int x, int y, bool right);
};

}  // namespace dofus

#endif  // RUNNER_INPUT_SERVICE_H_
