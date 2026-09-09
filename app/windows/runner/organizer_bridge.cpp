#include "organizer_bridge.h"

#include <flutter/standard_method_codec.h>

#include "utils.h"

namespace dofus {

namespace {

constexpr char kChannelName[] = "dtracker/organizer";
constexpr char kMethodApply[] = "hotkeys.apply";
constexpr char kMethodSetSuspended[] = "hotkeys.setSuspended";
constexpr char kMethodFocus[] = "window.focus";
constexpr char kMethodVirtualKey[] = "keys.virtualKeyForCharacter";
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
  return !binding->needles.empty();
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

  result->NotImplemented();
}

}  // namespace dofus
