#include "input_service.h"

#include "window_focus.h"

#include <timeapi.h>

#include <cstring>
#include <string>

#include <vector>

namespace dofus {

namespace {

// Les touches que Windows distingue par le bit « etendu ». Sans lui, la
// fleche du haut arrive comme le 8 du pave numerique — le meme code de scan,
// et c'est le bit qui les separe.
bool IsExtended(UINT key_code) {
  switch (key_code) {
    case VK_RMENU:
    case VK_RCONTROL:
    case VK_INSERT:
    case VK_DELETE:
    case VK_HOME:
    case VK_END:
    case VK_PRIOR:
    case VK_NEXT:
    case VK_LEFT:
    case VK_UP:
    case VK_RIGHT:
    case VK_DOWN:
    case VK_NUMLOCK:
    case VK_DIVIDE:
    case VK_SNAPSHOT:
      return true;
    default:
      return false;
  }
}

// Une frappe, montante ou descendante.
//
// Le code de scan accompagne le code de touche virtuelle bien que Windows ne
// l'exige pas : un jeu qui lit l'entree brute plutot que les messages de
// fenetre ne regarde souvent que lui, et une frappe sans scan lui parait
// venir de nulle part.
INPUT KeyEvent(UINT key_code, bool up) {
  INPUT input = {};
  input.type = INPUT_KEYBOARD;
  input.ki.wVk = static_cast<WORD>(key_code);
  input.ki.wScan =
      static_cast<WORD>(MapVirtualKeyW(key_code, MAPVK_VK_TO_VSC));
  input.ki.dwFlags = (up ? KEYEVENTF_KEYUP : 0) |
                     (IsExtended(key_code) ? KEYEVENTF_EXTENDEDKEY : 0);
  return input;
}

bool Send(std::vector<INPUT>& events) {
  if (events.empty()) {
    return true;
  }
  const UINT sent = ::SendInput(static_cast<UINT>(events.size()), events.data(),
                                sizeof(INPUT));
  return sent == events.size();
}

// Les modificateurs `MOD_*` de `RegisterHotKey`, dans l'ordre ou on les
// enfonce. Ce sont ceux que Dart envoie, et les memes que pour un raccourci.
constexpr struct {
  UINT flag;
  UINT key;
} kModifiers[] = {
    {0x0001, VK_MENU},     // MOD_ALT
    {0x0002, VK_CONTROL},  // MOD_CONTROL
    {0x0004, VK_SHIFT},    // MOD_SHIFT
    {0x0008, VK_LWIN},     // MOD_WIN
};

}  // namespace

namespace {

// Le temps au-dela duquel on cesse d'attendre une fenetre qui ne repond plus.
constexpr UINT kPatience = 200;

// Le temps laisse avant la premiere frappe d'un texte.
//
// La touche qui precede vient souvent d'ouvrir quelque chose — le tchat du
// jeu — et la fenetre met quelques images a l'avoir vraiment sous le clavier.
// Sans cette avance, le premier caractere se perdait : le « / » d'une commande,
// c'est-a-dire ce qui en fait une commande.
constexpr DWORD kAvantLaPremiere = 60;


// Attend que le fil d'en face ait vide sa file, puis rend le controle qui a le
// clavier.
//
// Sans cette attente, le focus lu serait celui d'**avant** la touche qui
// precede : une macro qui ouvre le tchat par Entree puis ecrit demandait le
// focus alors que le tchat n'etait pas encore ouvert, et le texte partait dans
// le champ d'avant. Les frappes injectees passent par la file du systeme et
// les messages par celle du fil : deux chemins, deux vitesses, et rien qui
// garantisse l'ordre. Un message synchrone les rejoint — il ne revient que
// lorsque le fil a traite ce qui precede.
HWND ControleFocalise(HWND fenetre) {
  DWORD_PTR reponse = 0;
  ::SendMessageTimeoutW(fenetre, WM_NULL, 0, 0, SMTO_ABORTIFHUNG, kPatience,
                        &reponse);

  const DWORD fil = ::GetWindowThreadProcessId(fenetre, nullptr);
  HWND focalise = fenetre;
  if (::AttachThreadInput(::GetCurrentThreadId(), fil, TRUE)) {
    HWND focus = ::GetFocus();
    ::AttachThreadInput(::GetCurrentThreadId(), fil, FALSE);
    if (focus != nullptr) {
      focalise = focus;
    }
  }
  return focalise;
}

}  // namespace

bool InputService::SendText(const std::wstring& text, DWORD pace) {
  if (text.empty()) {
    return true;
  }

  // Le texte part en messages, non en frappes injectees.
  //
  // `SendInput` avec `KEYEVENTF_UNICODE` fabrique des touches `VK_PACKET`, ou
  // le caractere voyage dans le code de scan. Le destinataire ne le lit qu'au
  // moment ou il traite le message, et s'il a pris du retard il lit le
  // caractere **suivant** : on obtenait « /invite aaandestin » pour
  // « /invite Clandestin », et parfois une lettre perdue. Espacer les frappes
  // reduisait le desordre sans le supprimer, parce que le desordre n'est pas
  // dans l'envoi mais dans la lecture.
  //
  // `WM_CHAR` porte le caractere dans le message lui-meme. Il est mis en file
  // avec les autres, dans l'ordre, et rien ne peut le confondre avec son
  // voisin. C'est ce que fait `ControlSend` d'AutoHotkey, et pour la meme
  // raison.
  HWND premier_plan = ::GetForegroundWindow();
  // Et c'est une fenetre du jeu, sans quoi rien ne part.
  //
  // Une macro qui se declenche alors qu'on a bascule ailleurs ecrirait sa
  // commande dans un navigateur, un editeur, une conversation. C'est arrive.
  // Le refus est ici, au plus pres de l'envoi : ce qui appelle n'a pas a
  // penser a verifier.
  if (!EstFenetreDuJeu(premier_plan)) {
    return false;
  }

  // Le message va au controle qui a le clavier, pas a la fenetre : dans une
  // fenetre a plusieurs champs, c'est lui qui ecrit.
  HWND destinataire = ControleFocalise(premier_plan);

  // `SendMessage` et non `PostMessage` : il ne rend la main que lorsque le
  // destinataire a traite le caractere. Le rythme se cale ainsi sur ce que la
  // fenetre d'en face sait absorber, sans qu'on ait a le deviner — et une
  // fenetre qui se fige ne nous entraine pas avec elle, le delai d'attente y
  // pourvoit.
  const bool horloge = ::timeBeginPeriod(1) == TIMERR_NOERROR;
  // Toujours avant la premiere : c'est celle qui se perdait.
  ::Sleep(kAvantLaPremiere);
  for (size_t i = 0; i < text.size(); ++i) {
    DWORD_PTR reponse = 0;
    if (::SendMessageTimeoutW(destinataire, WM_CHAR,
                              static_cast<WPARAM>(text[i]), 1,
                              SMTO_ABORTIFHUNG, kPatience, &reponse) == 0) {
      if (horloge) {
        ::timeEndPeriod(1);
      }
      return false;
    }
    // La cadence reste : elle ne sert plus a laisser le destinataire respirer
    // — le retour synchrone s'en charge — mais a ressembler a une main, ce que
    // certaines fenetres exigent avant d'accepter la suite.
    if (pace > 0 && i + 1 < text.size()) {
      ::Sleep(pace);
    }
  }
  if (horloge) {
    ::timeEndPeriod(1);
  }
  return true;
}

bool InputService::SendKey(UINT key_code, UINT modifiers) {
  if (key_code == 0) {
    return false;
  }

  // Les quatre evenements en un seul envoi.
  //
  // Les separer laissait le jeu voir la touche sans son modificateur — mais
  // surtout, il echantillonne l'etat du clavier assez souvent pour attraper un
  // Ctrl encore enfonce entre deux envois : le clic suivant devenait un
  // Ctrl+clic. Un bloc unique ne laisse pas cette fenetre-la.
  std::vector<INPUT> events;
  events.reserve(10);
  for (const auto& modifier : kModifiers) {
    if (modifiers & modifier.flag) {
      events.push_back(KeyEvent(modifier.key, false));
    }
  }
  events.push_back(KeyEvent(key_code, false));
  events.push_back(KeyEvent(key_code, true));
  // A rebours : le dernier enfonce est le premier relache, comme le ferait une
  // main.
  for (auto it = std::rbegin(kModifiers); it != std::rend(kModifiers); ++it) {
    if (modifiers & it->flag) {
      events.push_back(KeyEvent(it->key, true));
    }
  }
  const bool frappe = Send(events);

  // Et l'assurance : on relache ce qu'on a pu laisser enfonce. Relacher une
  // touche qui ne l'est pas ne coute rien ; un Ctrl reste colle coute une
  // partie de jeu.
  if (modifiers != 0) {
    std::vector<INPUT> menage;
    for (auto it = std::rbegin(kModifiers); it != std::rend(kModifiers); ++it) {
      if (modifiers & it->flag) {
        menage.push_back(KeyEvent(it->key, true));
      }
    }
    Send(menage);
  }
  return frappe;
}

bool InputService::SendClick(int x, int y, bool right) {
  // Comme pour la frappe : un clic ne part que dans le jeu.
  if (!EstFenetreDuJeu(::GetForegroundWindow())) {
    return false;
  }

  // `SendInput` veut des coordonnees normalisees sur 0..65535, rapportees au
  // bureau entier. Le bureau ne commence pas a l'origine : un ecran a gauche
  // du principal a des abscisses negatives, et c'est `SM_XVIRTUALSCREEN` qui
  // le dit.
  const int gauche = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int haut = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int largeur = ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int hauteur = ::GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if (largeur <= 1 || hauteur <= 1) {
    return false;
  }

  INPUT deplacement = {};
  deplacement.type = INPUT_MOUSE;
  deplacement.mi.dx =
      static_cast<LONG>((x - gauche) * 65535.0 / (largeur - 1) + 0.5);
  deplacement.mi.dy =
      static_cast<LONG>((y - haut) * 65535.0 / (hauteur - 1) + 0.5);
  deplacement.mi.dwFlags =
      MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK;

  INPUT bas = {};
  bas.type = INPUT_MOUSE;
  bas.mi.dwFlags = right ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_LEFTDOWN;

  INPUT haut_bouton = {};
  haut_bouton.type = INPUT_MOUSE;
  haut_bouton.mi.dwFlags = right ? MOUSEEVENTF_RIGHTUP : MOUSEEVENTF_LEFTUP;

  std::vector<INPUT> events = {deplacement, bas, haut_bouton};
  return Send(events);
}

}  // namespace dofus
