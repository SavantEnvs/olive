// Clipboard paste: ProjectSerializer::Paste hands the clipboard text to
// ProjectSerializer::Load(Project*, QXmlStreamReader*, type) with one of the "only" load types
// (nodes, clips, markers, keyframes). The first byte picks the type, the rest is the XML.
#include <cstdint>

#include "olive_init.h"
#include "node/project.h"
#include "timeline/timelinemarker.h"
#include "node/keyframe.h"

using olive::ProjectSerializer;

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
  OliveFuzzInit(argc, argv);
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 1) return -1;
  static const ProjectSerializer::LoadType kTypes[] = {
    ProjectSerializer::kOnlyNodes, ProjectSerializer::kOnlyClips,
    ProjectSerializer::kOnlyMarkers, ProjectSerializer::kOnlyKeyframes};
  ProjectSerializer::LoadType type = kTypes[data[0] % 4];
  // Paste reads the clipboard as a QString; mirror that conversion.
  QString text = QString::fromUtf8(reinterpret_cast<const char *>(data + 1), int(size - 1));
  QXmlStreamReader reader(text);
  olive::Project project;
  ProjectSerializer::Result r = ProjectSerializer::Load(&project, &reader, type);
  const ProjectSerializer::LoadData &ld = r.GetLoadData();
  qDeleteAll(ld.nodes);
  for (auto *m : ld.markers) delete m;
  for (auto it = ld.keyframes.cbegin(); it != ld.keyframes.cend(); ++it) qDeleteAll(it.value());
  return 0;
}
