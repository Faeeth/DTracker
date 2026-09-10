#include "organizer_bridge.h"

#include <flutter/standard_method_codec.h>

#include "input_service.h"
#include "point_picker.h"
#include "utils.h"

namespace dofus {

namespace {

constexpr char kChannelName[] = "dtracker/organizer";
constexpr char kMethodApply[] = "hotkeys.apply";
constexpr char kMethodSetSuspended[] = "hotkeys.setSuspended";
constexpr char kMethodFocus[] = "window.focus";
constexpr char kMethodVirtualKey[] = "keys.virtualKeyForCharacter";
constexpr char kMethodSendText[] = "input.text";
constexpr char kMethodSendKey[] = "input.key";
constexpr char kMethodForeground[] = "window.foreground";
constexpr char kMethodClick[] = "input.click";
constexpr char kMethodPick[] = "mouse.pick";
constexpr char kMethodIsGame[] = "window.isGame";
constexpr char kEventHotkey[] = "onHotkey";

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// Lit |key| dans |map| quand la valeur y est du type T, sinon rend |fallback|.
template <typename T>
T ValueOr(const EncodableMap& map, const char* key, T fallback) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return fallback;
  }
  const auto* value = std::get_if<T>(&it->second);
  return value ? *value : fallback;
}

// Convertit un descripteur venu de Dart. Rend faux quand la charge utile n'est
// pas exploitable, pour qu'une entree malformee n'enregistre pas en silence un
// raccourci de travers.
bool ParseBinding(const EncodableValue& value, HotkeyBinding* binding) {
  const auto* map = std::get_if<EncodableMap>(&value);
  if (map == nullptr) {
    return false;
  }
  binding->id = ValueOr<std::string>(*map, "id", "");
  binding->modifiers =
      static_cast<UINT>(ValueOr<int32_t>(*map, "modifiers", 0));
  binding->key_code = static_cast<UINT>(ValueOr<int32_t>(*map, "keyCode", 0));
  if (binding->id.empty() || binding->key_code == 0) {
    return false;
  }

  auto targets = map->find(EncodableValue("targets"));
  if (targets == map->end()) {
    return false;
  }
  const auto* list = std::get_if<EncodableList>(&targets->second);
  if (list == nullptr) {
    return false;
  }
  for (const EncodableValue& entry : *list) {
    const auto* title = std::get_if<std::string>(&entry);
    if (title == nullptr || title->empty()) {
      continue;
    }
    binding->needles.push_back(NormalizeTitleNeedle(Utf16FromUtf8(*title)));
  }
  // Une liste vide est licite : c'est la liaison d'une macro, qui n'active
  // aucune fenetre par elle-meme. Le natif se contente alors de signaler
  // l'appui, et Dart decide de la suite.
  return true;
}

}  // namespace

OrganizerBridge::OrganizerBridge() = default;

OrganizerBridge::~OrganizerBridge() = default;

void OrganizerBridge::Initialize(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());

  hotkeys_ = std::make_unique<HotkeyService>(
      [this](const std::string& id, int target_index) {
        if (!channel_) {
          return;
        }
        channel_->InvokeMethod(
            kEventHotkey,
            std::make_unique<EncodableValue>(EncodableMap{
                {EncodableValue("id"), EncodableValue(id)},
                {EncodableValue("targetIndex"), EncodableValue(target_index)},
            }));
      });
  hotkeys_->Start();

  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

void OrganizerBridge::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (!hotkeys_) {
    result->Error("unavailable", "Le moteur de raccourcis n'est pas demarre");
    return;
  }

  if (call.method_name() == kMethodApply) {
    const auto* list = std::get_if<EncodableList>(call.arguments());
    if (list == nullptr) {
      result->Error("bad_arguments", "Une liste de raccourcis est attendue");
      return;
    }
    std::vector<HotkeyBinding> bindings;
    bindings.reserve(list->size());
    for (const EncodableValue& entry : *list) {
      HotkeyBinding binding;
      if (ParseBinding(entry, &binding)) {
        bindings.push_back(std::move(binding));
      }
    }
    EncodableList rejected;
    for (const std::string& id : hotkeys_->Apply(std::move(bindings))) {
      rejected.push_back(EncodableValue(id));
    }
    result->Success(EncodableValue(rejected));
    return;
  }

  if (call.method_name() == kMethodSetSuspended) {
    const auto* suspended = std::get_if<bool>(call.arguments());
    if (suspended == nullptr) {
      result->Error("bad_arguments", "Un booleen est attendu");
      return;
    }
    hotkeys_->SetSuspended(*suspended);
    result->Success();
    return;
  }

  if (call.method_name() == kMethodFocus) {
    const auto* title = std::get_if<std::string>(call.arguments());
    if (title == nullptr) {
      result->Error("bad_arguments", "Un titre de fenetre est attendu");
      return;
    }
    WindowFocus focus;
    int index =
        focus.ActivateFirstMatch({NormalizeTitleNeedle(Utf16FromUtf8(*title))});
    result->Success(EncodableValue(index >= 0));
    return;
  }

  if (call.method_name() == kMethodVirtualKey) {
    const auto* character = std::get_if<std::string>(call.arguments());
    if (character == nullptr) {
      result->Error("bad_arguments", "Un caractere est attendu");
      return;
    }
    const std::wstring wide = Utf16FromUtf8(*character);
    if (wide.empty()) {
      result->Success(EncodableValue(0));
      return;
    }
    result->Success(
        EncodableValue(static_cast<int32_t>(VirtualKeyForCharacter(wide[0]))));
    return;
  }

  // Le titre de la fenetre qui a le clavier.
  //
  // Une macro s'en sert avant de taper : `SetForegroundWindow` echoue en
  // silence quand Windows refuse le changement de premier plan — un jeu en
  // plein ecran, par exemple — et les frappes partiraient alors dans la
  // fenetre qui etait devant.
  if (call.method_name() == kMethodForeground) {
    const HWND fenetre = ::GetForegroundWindow();
    if (fenetre == nullptr) {
      result->Success(EncodableValue(std::string()));
      return;
    }
    const int longueur = ::GetWindowTextLengthW(fenetre);
    std::wstring titre(static_cast<size_t>(longueur) + 1, L'\0');
    const int lu = ::GetWindowTextW(fenetre, titre.data(), longueur + 1);
    titre.resize(static_cast<size_t>(lu < 0 ? 0 : lu));
    result->Success(EncodableValue(Utf8FromUtf16(titre.c_str())));
    return;
  }

  // La fenetre au premier plan appartient-elle au jeu ?
  //
  // Le natif refuse deja de taper ailleurs ; ceci sert a le **dire** — une
  // macro qui s'arrete sans expliquer pourquoi se signale comme une panne.
  if (call.method_name() == kMethodIsGame) {
    result->Success(EncodableValue(EstFenetreDuJeu(::GetForegroundWindow())));
    return;
  }

  if (call.method_name() == kMethodSendText) {
    const auto* map = std::get_if<EncodableMap>(call.arguments());
    if (map == nullptr) {
      result->Error("bad_arguments", "Un texte est attendu");
      return;
    }
    const std::string texte = ValueOr<std::string>(*map, "text", "");
    const DWORD cadence =
        static_cast<DWORD>(ValueOr<int32_t>(*map, "pace", 0));
    result->Success(EncodableValue(
        InputService::SendText(Utf16FromUtf8(texte), cadence)));
    return;
  }

  if (call.method_name() == kMethodSendKey) {
    const auto* map = std::get_if<EncodableMap>(call.arguments());
    if (map == nullptr) {
      result->Error("bad_arguments", "Une touche est attendue");
      return;
    }
    const UINT key = static_cast<UINT>(ValueOr<int32_t>(*map, "keyCode", 0));
    const UINT modifiers =
        static_cast<UINT>(ValueOr<int32_t>(*map, "modifiers", 0));
    result->Success(EncodableValue(InputService::SendKey(key, modifiers)));
    return;
  }

  if (call.method_name() == kMethodClick) {
    const auto* map = std::get_if<EncodableMap>(call.arguments());
    if (map == nullptr) {
      result->Error("bad_arguments", "Des coordonnees sont attendues");
      return;
    }
    const int x = ValueOr<int32_t>(*map, "x", 0);
    const int y = ValueOr<int32_t>(*map, "y", 0);
    const bool droit = ValueOr<bool>(*map, "right", false);
    result->Success(EncodableValue(InputService::SendClick(x, y, droit)));
    return;
  }

  // La visee. Les raccourcis sont relaches par Dart avant l'appel : sans cela
  // une touche de fonction enregistree partirait pendant qu'on vise.
  if (call.method_name() == kMethodPick) {
    const std::optional<POINT> point = PointPicker::Pick();
    if (!point.has_value()) {
      result->Success();
      return;
    }
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("x"), EncodableValue(static_cast<int32_t>(point->x))},
        {EncodableValue("y"), EncodableValue(static_cast<int32_t>(point->y))},
    }));
    return;
  }

  result->NotImplemented();
}

}  // namespace dofus
