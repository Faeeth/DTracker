#include "point_picker.h"

#include <windowsx.h>

#include <string>

namespace dofus {

namespace {

constexpr wchar_t kClassName[] = L"DTrackerPointPicker";

constexpr COLORREF kTrait = RGB(255, 205, 0);
constexpr COLORREF kFondTexte = RGB(20, 20, 24);

// L'epaisseur des bandes redessinees autour de la croix. Trois pixels pour un
// trait d'un : les bords d'un trait efface laissent sinon une trainee.
constexpr int kBande = 3;

struct Etat {
  POINT curseur{0, 0};
  std::optional<POINT> choisi;
  bool termine = false;

  // L'ecran, fige au moment ou la visee s'ouvre.
  HDC memoire = nullptr;
  HBITMAP capture = nullptr;
  HGDIOBJ ancienne = nullptr;
  int largeur = 0;
  int hauteur = 0;

  HFONT police = nullptr;

  // Le cadre du libelle, retenu pour pouvoir l'effacer au mouvement suivant.
  RECT boite{0, 0, 0, 0};
};

Etat* EtatDe(HWND fenetre) {
  return reinterpret_cast<Etat*>(::GetWindowLongPtr(fenetre, GWLP_USERDATA));
}

std::wstring Coordonnees(const Etat& etat) {
  const int gauche = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int haut = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
  return L"  " + std::to_wstring(etat.curseur.x + gauche) + L", " +
         std::to_wstring(etat.curseur.y + haut) + L"  ";
}

// Place le libelle pres du pointeur, du bon cote quand on approche d'un bord.
void PlaceLeLibelle(HWND fenetre, Etat* etat) {
  HDC ecran = ::GetDC(fenetre);
  HGDIOBJ ancienne = ::SelectObject(ecran, etat->police);
  const std::wstring texte = Coordonnees(*etat);
  SIZE mesure{0, 0};
  ::GetTextExtentPoint32W(ecran, texte.c_str(), static_cast<int>(texte.size()),
                          &mesure);
  ::SelectObject(ecran, ancienne);
  ::ReleaseDC(fenetre, ecran);

  RECT boite;
  boite.left = etat->curseur.x + 14;
  boite.top = etat->curseur.y - mesure.cy - 14;
  if (boite.top < 0) {
    boite.top = etat->curseur.y + 14;
  }
  if (boite.left + mesure.cx > etat->largeur) {
    boite.left = etat->curseur.x - mesure.cx - 14;
  }
  boite.right = boite.left + mesure.cx;
  boite.bottom = boite.top + mesure.cy + 4;
  etat->boite = boite;
}

// N'invalide que ce que la croix occupe : deux bandes et le libelle.
//
// Redessiner l'ecran entier a chaque mouvement, c'etait douze millions de
// pixels par pas de souris — d'ou la trainee quand on va vite. Les bandes en
// font vingt-cinq mille.
void InvalideLaCroix(HWND fenetre, const Etat& etat) {
  RECT horizontale{0, etat.curseur.y - kBande, etat.largeur,
                   etat.curseur.y + kBande};
  RECT verticale{etat.curseur.x - kBande, 0, etat.curseur.x + kBande,
                 etat.hauteur};
  RECT libelle = etat.boite;
  ::InflateRect(&libelle, 2, 2);
  ::InvalidateRect(fenetre, &horizontale, FALSE);
  ::InvalidateRect(fenetre, &verticale, FALSE);
  ::InvalidateRect(fenetre, &libelle, FALSE);
}

void Peint(HWND fenetre, Etat* etat) {
  PAINTSTRUCT ps;
  HDC ecran = ::BeginPaint(fenetre, &ps);
  const RECT& zone = ps.rcPaint;

  // L'ecran fige, pour la seule zone a refaire. Le reste n'a pas bouge : il
  // n'y a rien a y repeindre, et c'est ce qui rend la croix immediate.
  ::BitBlt(ecran, zone.left, zone.top, zone.right - zone.left,
           zone.bottom - zone.top, etat->memoire, zone.left, zone.top,
           SRCCOPY);

  HPEN crayon = ::CreatePen(PS_SOLID, 1, kTrait);
  HGDIOBJ ancienCrayon = ::SelectObject(ecran, crayon);
  ::MoveToEx(ecran, 0, etat->curseur.y, nullptr);
  ::LineTo(ecran, etat->largeur, etat->curseur.y);
  ::MoveToEx(ecran, etat->curseur.x, 0, nullptr);
  ::LineTo(ecran, etat->curseur.x, etat->hauteur);
  ::SelectObject(ecran, ancienCrayon);
  ::DeleteObject(crayon);

  const std::wstring texte = Coordonnees(*etat);
  HGDIOBJ anciennePolice = ::SelectObject(ecran, etat->police);
  HBRUSH fond = ::CreateSolidBrush(kFondTexte);
  ::FillRect(ecran, &etat->boite, fond);
  ::DeleteObject(fond);
  ::SetBkMode(ecran, TRANSPARENT);
  ::SetTextColor(ecran, kTrait);
  ::TextOutW(ecran, etat->boite.left, etat->boite.top + 2, texte.c_str(),
             static_cast<int>(texte.size()));
  ::SelectObject(ecran, anciennePolice);

  ::EndPaint(fenetre, &ps);
}

LRESULT CALLBACK Procedure(HWND fenetre, UINT message, WPARAM wparam,
                           LPARAM lparam) {
  Etat* etat = EtatDe(fenetre);
  switch (message) {
    case WM_MOUSEMOVE:
      if (etat != nullptr) {
        const int x = GET_X_LPARAM(lparam);
        const int y = GET_Y_LPARAM(lparam);
        if (x == etat->curseur.x && y == etat->curseur.y) {
          return 0;
        }
        InvalideLaCroix(fenetre, *etat);  // l'ancienne
        etat->curseur.x = x;
        etat->curseur.y = y;
        PlaceLeLibelle(fenetre, etat);
        InvalideLaCroix(fenetre, *etat);  // la nouvelle
        // Repeindre maintenant plutot qu'au prochain tour de boucle : c'est ce
        // qui fait que la croix colle au pointeur.
        ::UpdateWindow(fenetre);
      }
      return 0;
    case WM_SETCURSOR:
      ::SetCursor(::LoadCursor(nullptr, IDC_CROSS));
      return TRUE;
    case WM_LBUTTONDOWN:
      if (etat != nullptr) {
        const int gauche = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
        const int haut = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
        etat->choisi = POINT{GET_X_LPARAM(lparam) + gauche,
                             GET_Y_LPARAM(lparam) + haut};
        etat->termine = true;
      }
      ::DestroyWindow(fenetre);
      return 0;
    case WM_RBUTTONDOWN:
      if (etat != nullptr) {
        etat->termine = true;
      }
      ::DestroyWindow(fenetre);
      return 0;
    case WM_KEYDOWN:
      if (wparam == VK_ESCAPE) {
        if (etat != nullptr) {
          etat->termine = true;
        }
        ::DestroyWindow(fenetre);
      }
      return 0;
    case WM_PAINT:
      if (etat != nullptr) {
        Peint(fenetre, etat);
        return 0;
      }
      break;
    case WM_ERASEBKGND:
      // Tout est peint dans WM_PAINT : effacer ici ferait clignoter.
      return 1;
    case WM_DESTROY:
      // Surtout pas de `PostQuitMessage` : le `WM_QUIT` qu'il depose n'est pas
      // pour nous mais pour le fil, et la boucle principale de l'application
      // le lisait ensuite comme un ordre de fermeture. L'outil se fermait donc
      // au moment ou l'on validait un point.
      if (etat != nullptr) {
        etat->termine = true;
      }
      return 0;
    default:
      break;
  }
  return ::DefWindowProc(fenetre, message, wparam, lparam);
}

// Prend l'ecran en photo, une fois pour toutes.
bool Fige(Etat* etat) {
  HDC bureau = ::GetDC(nullptr);
  if (bureau == nullptr) {
    return false;
  }
  const int gauche = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int haut = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
  etat->memoire = ::CreateCompatibleDC(bureau);
  etat->capture =
      ::CreateCompatibleBitmap(bureau, etat->largeur, etat->hauteur);
  bool pris = false;
  if (etat->memoire != nullptr && etat->capture != nullptr) {
    etat->ancienne = ::SelectObject(etat->memoire, etat->capture);
    pris = ::BitBlt(etat->memoire, 0, 0, etat->largeur, etat->hauteur, bureau,
                    gauche, haut, SRCCOPY) != FALSE;
  }
  ::ReleaseDC(nullptr, bureau);
  return pris;
}

void Libere(Etat* etat) {
  if (etat->memoire != nullptr) {
    if (etat->ancienne != nullptr) {
      ::SelectObject(etat->memoire, etat->ancienne);
    }
    ::DeleteDC(etat->memoire);
    etat->memoire = nullptr;
  }
  if (etat->capture != nullptr) {
    ::DeleteObject(etat->capture);
    etat->capture = nullptr;
  }
  if (etat->police != nullptr) {
    ::DeleteObject(etat->police);
    etat->police = nullptr;
  }
}

}  // namespace

std::optional<POINT> PointPicker::Pick() {
  static bool enregistree = false;
  HINSTANCE instance = ::GetModuleHandle(nullptr);
  if (!enregistree) {
    WNDCLASSEXW classe = {};
    classe.cbSize = sizeof(classe);
    classe.lpfnWndProc = Procedure;
    classe.hInstance = instance;
    classe.hCursor = ::LoadCursor(nullptr, IDC_CROSS);
    classe.lpszClassName = kClassName;
    ::RegisterClassExW(&classe);
    enregistree = true;
  }

  const int gauche = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int haut = ::GetSystemMetrics(SM_YVIRTUALSCREEN);

  Etat etat;
  etat.largeur = ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
  etat.hauteur = ::GetSystemMetrics(SM_CYVIRTUALSCREEN);
  ::GetCursorPos(&etat.curseur);
  etat.curseur.x -= gauche;
  etat.curseur.y -= haut;
  etat.police = ::CreateFontW(-18, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                              DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                              CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                              DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

  // L'ecran est fige avant que la fenetre ne s'ouvre : sinon elle se
  // photographierait elle-meme.
  if (!Fige(&etat)) {
    Libere(&etat);
    return std::nullopt;
  }

  HWND fenetre = ::CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, kClassName, L"",
      WS_POPUP, gauche, haut, etat.largeur, etat.hauteur, nullptr, nullptr,
      instance, nullptr);
  if (fenetre == nullptr) {
    Libere(&etat);
    return std::nullopt;
  }
  ::SetWindowLongPtr(fenetre, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&etat));
  PlaceLeLibelle(fenetre, &etat);
  ::ShowWindow(fenetre, SW_SHOWNOACTIVATE);
  ::UpdateWindow(fenetre);

  // Le clavier n'est pas a nous : la fenetre ne prend pas le premier plan pour
  // ne pas deranger ce qu'on vise. Echap est donc lu a la main.
  ::SetCapture(fenetre);

  MSG message;
  while (!etat.termine) {
    const BOOL recu = ::GetMessage(&message, nullptr, 0, 0);
    if (recu == 0) {
      // L'application se ferme pendant qu'on visait. Le `WM_QUIT` ne nous
      // appartient pas : il est repose pour la boucle principale, qui seule
      // sait ce qu'il y a a faire.
      ::PostQuitMessage(static_cast<int>(message.wParam));
      break;
    }
    if (recu < 0) {
      break;
    }
    if (message.message == WM_KEYDOWN && message.wParam == VK_ESCAPE) {
      etat.termine = true;
      break;
    }
    ::TranslateMessage(&message);
    ::DispatchMessage(&message);
  }
  ::ReleaseCapture();
  if (::IsWindow(fenetre)) {
    ::DestroyWindow(fenetre);
  }
  Libere(&etat);
  return etat.choisi;
}

}  // namespace dofus
