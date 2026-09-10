#include "window_focus.h"

#include <dwmapi.h>

#include <psapi.h>

#include <algorithm>
#include <cwctype>

namespace dofus {

namespace {

// Le debut du nom d'executable du jeu, en minuscules. « Dofus.exe » pour le
// client ordinaire ; le prefixe couvre les variantes sans avoir a les nommer.
constexpr wchar_t kExecutableDuJeu[] = L"dofus";

// Upper bound used when reading a window title. Dofus titles are far below
// this, and a fixed stack buffer keeps the hotkey path allocation free.
constexpr int kMaxTitleLength = 512;

// Le nom de l'executable d'un processus, en minuscules, sans son chemin.
std::wstring NomDExecutable(DWORD processus) {
  HANDLE poignee = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                                 processus);
  if (poignee == nullptr) {
    return std::wstring();
  }
  wchar_t chemin[MAX_PATH];
  DWORD longueur = MAX_PATH;
  std::wstring nom;
  if (::QueryFullProcessImageNameW(poignee, 0, chemin, &longueur)) {
    nom.assign(chemin, longueur);
    const size_t barre = nom.find_last_of(L"\\/");
    if (barre != std::wstring::npos) {
      nom = nom.substr(barre + 1);
    }
    nom = NormalizeTitleNeedle(nom);
  }
  ::CloseHandle(poignee);
  return nom;
}

bool EstDuJeu(HWND window) {
  DWORD processus = 0;
  ::GetWindowThreadProcessId(window, &processus);
  if (processus == 0) {
    return false;
  }
  const std::wstring nom = NomDExecutable(processus);
  return nom.rfind(kExecutableDuJeu, 0) == 0;
}

// A window is a candidate only when it is a visible, titled top level window
// that is not cloaked by DWM (virtual desktops, suspended UWP hosts) and does
// not belong to the organizer itself.
bool IsCandidate(HWND window) {
  if (!::IsWindowVisible(window)) {
    return false;
  }
  DWORD process_id = 0;
  ::GetWindowThreadProcessId(window, &process_id);
  if (process_id == ::GetCurrentProcessId()) {
    return false;
  }
  if (::GetWindowTextLengthW(window) == 0) {
    return false;
  }
  // Seules les fenetres du jeu sont des cibles. Un navigateur ou un editeur
  // ouvert sur le nom d'un personnage porte le meme titre, et une macro qui
  // s'y tromperait ecrirait ailleurs.
  if (!EstDuJeu(window)) {
    return false;
  }
  BOOL cloaked = FALSE;
  if (SUCCEEDED(::DwmGetWindowAttribute(window, DWMWA_CLOAKED, &cloaked,
                                        sizeof(cloaked))) &&
      cloaked) {
    return false;
  }
  return true;
}

// Reads the title of |window| normalized for comparison. Returns false when
// the window has no readable title.
bool ReadNormalizedTitle(HWND window, std::wstring* out) {
  wchar_t buffer[kMaxTitleLength];
  int length = ::GetWindowTextW(window, buffer, kMaxTitleLength);
  if (length <= 0) {
    return false;
  }
  out->assign(buffer, static_cast<size_t>(length));
  *out = NormalizeTitleNeedle(*out);
  return true;
}

bool TitleContains(HWND window, const std::wstring& needle) {
  std::wstring title;
  if (!ReadNormalizedTitle(window, &title)) {
    return false;
  }
  return title.find(needle) != std::wstring::npos;
}

// Brings |window| to the foreground.
//
// The process owning a registered hotkey is allowed to steal the foreground,
// so the direct call succeeds in the nominal case. The thread input attachment
// is the fallback for the cases Windows still refuses (foreground lock timeout
// after another process grabbed the focus).
void Activate(HWND window) {
  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  }
  if (::SetForegroundWindow(window)) {
    ::BringWindowToTop(window);
    return;
  }

  HWND foreground = ::GetForegroundWindow();
  DWORD current_thread = ::GetCurrentThreadId();
  DWORD foreground_thread =
      foreground ? ::GetWindowThreadProcessId(foreground, nullptr) : 0;
  DWORD target_thread = ::GetWindowThreadProcessId(window, nullptr);

  if (foreground_thread && foreground_thread != current_thread) {
    ::AttachThreadInput(current_thread, foreground_thread, TRUE);
  }
  if (target_thread && target_thread != current_thread) {
    ::AttachThreadInput(current_thread, target_thread, TRUE);
  }

  ::BringWindowToTop(window);
  ::SetForegroundWindow(window);
  ::SetActiveWindow(window);

  if (target_thread && target_thread != current_thread) {
    ::AttachThreadInput(current_thread, target_thread, FALSE);
  }
  if (foreground_thread && foreground_thread != current_thread) {
    ::AttachThreadInput(current_thread, foreground_thread, FALSE);
  }
}

struct EnumContext {
  const std::vector<std::wstring>* needles;
  std::vector<HWND>* results;
};

BOOL CALLBACK EnumProc(HWND window, LPARAM lparam) {
  auto* context = reinterpret_cast<EnumContext*>(lparam);
  if (!IsCandidate(window)) {
    return TRUE;
  }
  std::wstring title;
  if (!ReadNormalizedTitle(window, &title)) {
    return TRUE;
  }

  bool pending = false;
  for (size_t i = 0; i < context->needles->size(); ++i) {
    if ((*context->results)[i] != nullptr) {
      continue;
    }
    if (title.find((*context->needles)[i]) != std::wstring::npos) {
      (*context->results)[i] = window;
    } else {
      pending = true;
    }
  }
  // Stop as soon as every target is resolved.
  return pending ? TRUE : FALSE;
}

}  // namespace

bool EstFenetreDuJeu(HWND window) {
  return window != nullptr && EstDuJeu(window);
}

std::wstring NormalizeTitleNeedle(const std::wstring& title) {
  std::wstring normalized = title;
  std::transform(normalized.begin(), normalized.end(), normalized.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(::towlower(c)); });
  return normalized;
}

int WindowFocus::ActivateFirstMatch(const std::vector<std::wstring>& needles) {
  if (needles.empty()) {
    return -1;
  }

  // Fast path: the highest priority target is still valid, no enumeration is
  // needed. Lower priority targets are irrelevant as soon as it matches.
  if (HWND cached = CachedLookup(needles.front())) {
    Activate(cached);
    return 0;
  }

  std::vector<HWND> results(needles.size(), nullptr);
  EnumContext context{&needles, &results};
  ::EnumWindows(EnumProc, reinterpret_cast<LPARAM>(&context));

  int activated = -1;
  for (size_t i = 0; i < results.size(); ++i) {
    if (results[i] == nullptr) {
      continue;
    }
    cache_[needles[i]] = results[i];
    if (activated < 0) {
      activated = static_cast<int>(i);
    }
  }
  if (activated >= 0) {
    Activate(results[static_cast<size_t>(activated)]);
  }
  return activated;
}

void WindowFocus::ClearCache() {
  cache_.clear();
}

HWND WindowFocus::CachedLookup(const std::wstring& needle) {
  auto it = cache_.find(needle);
  if (it == cache_.end()) {
    return nullptr;
  }
  HWND window = it->second;
  // The client may have been closed, or the handle recycled by another window:
  // the title is re-checked, not only the handle validity.
  if (!::IsWindow(window) || !::IsWindowVisible(window) ||
      !TitleContains(window, needle)) {
    cache_.erase(it);
    return nullptr;
  }
  return window;
}

}  // namespace dofus
