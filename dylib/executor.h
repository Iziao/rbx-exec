#pragma once
#include <string>
#include <functional>

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <luacode.h>
}

namespace executor {
    void Initialize();
    void Shutdown();
    lua_State* State();
    int EnvRef();

    std::string RunScriptInternal(const std::string& source);
    void RunScriptAsync(const std::string& source,
                        void (^completion)(std::string));
}

namespace api   { void Register(lua_State* L); }
namespace hooks { void Install(); void Uninstall(); }
