// Project file (.ove) loader: ProjectSerializer::Load(Project*, QXmlStreamReader*, kProject), the
// public entry ProjectSerializer::Load(Project*, filename, kProject) (File > Open) hands the file
// to. Reaches version detection, all five versioned serializers, Node::Load (inputs, hints,
// keyframes, custom data, connections), markers, project settings and the layout reader.
//
// Not the filename overload: its first step, ProjectSerializer::CheckCompressedID, memcmp()s 4 bytes
// of a file->read(4) that is shorter for files under 4 bytes (heap over-read in serializer.cpp),
// which libFuzzer's empty first input hits before any fuzzing starts. The reader overload is the
// same parser minus that "OVEC" check/qUncompress wrapper.
#include <cstdint>

#include "olive_init.h"
#include "node/project.h"

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
  OliveFuzzInit(argc, argv);
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  // Load(filename) reads the file through a QIODevice; QXmlStreamReader(QByteArray) is the same.
  QByteArray bytes(reinterpret_cast<const char *>(data), int(size));
  QXmlStreamReader reader(bytes);
  olive::Project project;
  olive::ProjectSerializer::Load(&project, &reader, olive::ProjectSerializer::kProject);
  return 0;
}
