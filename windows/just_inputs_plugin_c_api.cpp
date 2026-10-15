#include "include/just_inputs/just_inputs_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "pointer_lock_plugin.h"

void JustInputsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  just_inputs::PointerLockPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
