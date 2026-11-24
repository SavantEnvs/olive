// Rich text stored in project files (text nodes) is parsed by Html::HtmlToDoc, olive's own
// XML -> QTextDocument reader (span/p attributes, CSS style parsing); round-trip via DocToHtml.
#include <cstdint>
#include <QTextDocument>

#include "olive_init.h"
#include "common/html.h"

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
  OliveFuzzInit(argc, argv);
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  QTextDocument doc;
  olive::Html::HtmlToDoc(&doc, QString::fromUtf8(reinterpret_cast<const char *>(data), int(size)));
  QString out = olive::Html::DocToHtml(&doc);
  (void)out;
  return 0;
}
