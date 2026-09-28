#include "executor.h"
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

namespace executor {

static lua_State*      g_L      = nullptr;
static int             g_envRef = LUA_NOREF;
static dispatch_queue_t g_queue = nil;

lua_State* State()  { return g_L; }
int        EnvRef() { return g_envRef; }

// Shared environment table. getgenv() hands this out so scripts can
// stash values that persist across runs.
static int CreateSharedEnv(lua_State* L) {
    lua_newtable(L);
    lua_newtable(L);
    lua_getglobal(L, "_G");
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    return luaL_ref(L, LUA_REGISTRYINDEX);
}

void Initialize() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        g_queue = dispatch_queue_create("cobble.lua", DISPATCH_QUEUE_SERIAL);
    });

    dispatch_sync(g_queue, ^{
        if (g_L) return;
        g_L = luaL_newstate();
        if (!g_L) return;
        luaL_openlibs(g_L);
        g_envRef = CreateSharedEnv(g_L);
        api::Register(g_L);
        hooks::Install();
        NSLog(@"[cobble] executor ready");
    });
}

void Shutdown() {
    hooks::Uninstall();
    if (g_L) { lua_close(g_L); g_L = nullptr; }
}

std::string RunScriptInternal(const std::string& source) {
    lua_State* L = g_L;
    if (!L) return "[!] no lua state";

    size_t bytecodeSize = 0;
    char* bytecode = luau_compile(source.c_str(), source.size(),
                                  nullptr, &bytecodeSize);
    if (!bytecode) return "[!] compile failed";

    lua_rawgeti(L, LUA_REGISTRYINDEX, g_envRef);
    int envIdx = lua_gettop(L);

    int status = luau_load(L, "=executor", bytecode, bytecodeSize, envIdx);
    free(bytecode);

    if (status != 0) {
        const char* err = lua_tostring(L, -1);
        std::string msg = err ? err : "load error";
        lua_pop(L, 2);
        return "[!] " + msg;
    }
    lua_remove(L, envIdx);

    status = lua_pcall(L, 0, LUA_MULTRET, 0);
    if (status != 0) {
        const char* err = lua_tostring(L, -1);
        std::string msg = err ? err : "runtime error";
        lua_pop(L, 1);
        return "[!] " + msg;
    }

    int nret = lua_gettop(L);
    std::string out;
    for (int i = 1; i <= nret; ++i) {
        size_t len = 0;
        const char* s = luaL_tolstring(L, i, &len);
        if (s) { if (!out.empty()) out += "\t"; out.append(s, len); }
        lua_pop(L, 1);
    }
    lua_settop(L, 0);
    return out.empty() ? "[ok]" : out;
}

void RunScriptAsync(const std::string& source,
                    void (^completion)(std::string)) {
    dispatch_async(g_queue, ^{
        std::string r = RunScriptInternal(source);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(r); });
    });
}

}  // namespace executor
