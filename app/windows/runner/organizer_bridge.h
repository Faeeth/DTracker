#ifndef RUNNER_ORGANIZER_BRIDGE_H_
#define RUNNER_ORGANIZER_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

#include "hotkey_service.h"

namespace dofus {

// Expose le moteur de raccourcis de l'Organizer au cote Dart.
//
// Dart possede la configuration et la pousse ici ; l'activation elle-meme ne
// repasse jamais par lui, si bien qu'un appui de touche coute une resolution
// de fenetre et un appel de premier plan, rien de plus.
class OrganizerBridge {
 public:
  OrganizerBridge();
  ~OrganizerBridge();

  OrganizerBridge(const OrganizerBridge&) = delete;
  OrganizerBridge& operator=(const OrganizerBridge&) = delete;

  // Lie le canal et cree la fenetre message-only qui porte les raccourcis.
  void Initialize(flutter::BinaryMessenger* messenger);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<HotkeyService> hotkeys_;
};

}  // namespace dofus

#endif  // RUNNER_ORGANIZER_BRIDGE_H_
