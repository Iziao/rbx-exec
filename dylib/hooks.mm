#include "executor.h"
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <mach-o/getsect.h>
#include <cstring>
#include <vector>

namespace hooks {

struct rebinding {
    const char* name;
    void*       replacement;
    void**      replaced;
};

static std::vector<rebinding> g_rebinds;

void Install() {
    static struct rebinding rb[] = {};
    (void)rb;
    NSLog(@"[cobble] hooks installed (framework stubs)");
}

void Uninstall() {
    g_rebinds.clear();
}

}  // namespace hooks
