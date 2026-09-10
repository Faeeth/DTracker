#ifndef RUNNER_POINT_PICKER_H_
#define RUNNER_POINT_PICKER_H_

#include <windows.h>

#include <optional>

namespace dofus {

// Le pointeur de visee : une croix sur tout l'ecran, et un clic qui rend des
// coordonnees.
//
// Une fenetre a nous, posee par-dessus tout le bureau. C'est ce qui permet au
// clic de **ne pas** atteindre ce qu'il y a dessous : il tombe sur cette
// fenetre-la, qui le lit et se retire. Une simple lecture de la position du
// pointeur ne l'aurait pas permis — il aurait fallu cliquer pour de vrai
// quelque part, donc dans le jeu.
//
// La fenetre est transparente par couleur de fond : ce qui est peint dans la
// couleur choisie disparait entierement, le reste — les deux traits et les
// coordonnees — s'affiche. Une transparence par alpha aurait voile le bureau,
// et on vise mal ce qu'on voit mal.
class PointPicker {
 public:
  // Ouvre la visee et attend. Rend le point choisi, ou rien si l'on a renonce
  // — Echap, ou le bouton droit.
  //
  // Bloque le fil appelant en pompant les messages, comme le ferait une boite
  // de dialogue modale : la fenetre de l'application ne repond plus tant que
  // la visee est ouverte, ce qui est sans consequence puisqu'elle est dessous.
  static std::optional<POINT> Pick();
};

}  // namespace dofus

#endif  // RUNNER_POINT_PICKER_H_
