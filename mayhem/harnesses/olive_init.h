// Shared one-time init for the olive app harnesses: a headless QApplication plus the
// registries ProjectSerializer/Node::Load need (node factory, serializers, default OCIO config)
// and the non-GUI managers the app creates at startup.
// All of it is read-only after init; every input builds its own Project / documents.
#pragma once
#include <QApplication>
#include <QDir>
#include <cstdlib>

#include "node/factory.h"
#include "node/project/serializer/serializer.h"
#include "node/color/colormanager/colormanager.h"
#include "codec/conformmanager.h"
#include "render/framemanager.h"
#include "render/diskmanager.h"
#include "task/taskmanager.h"

static void OliveFuzzInit(int *argc, char ***argv) {
  static QApplication *app = nullptr;
  if (app) return;
  qputenv("QT_QPA_PLATFORM", "offscreen");
  // SetUpDefaultConfig extracts the OCIO config under the XDG cache dir: keep it writable.
  const char *tmp = getenv("TMPDIR");
  QByteArray base = QByteArray(tmp && *tmp ? tmp : "/tmp") + "/olive-fuzz-home";
  QDir().mkpath(QString::fromUtf8(base));
  qputenv("XDG_CACHE_HOME", base + "/cache");
  qputenv("XDG_CONFIG_HOME", base + "/config");
  qputenv("XDG_DATA_HOME", base + "/data");
  qputenv("XDG_RUNTIME_DIR", base);
  app = new QApplication(*argc, *argv);
  olive::NodeFactory::Initialize();
  olive::ProjectSerializer::Initialize();
  olive::ColorManager::SetUpDefaultConfig();
  // The non-GUI singletons Core::Start creates; loaded nodes and caches look them up.
  olive::TaskManager::CreateInstance();
  olive::ConformManager::CreateInstance();
  olive::FrameManager::CreateInstance();
  olive::DiskManager::CreateInstance();
}
