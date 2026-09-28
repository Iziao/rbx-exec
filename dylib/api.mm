#include "executor.h"
#include <cstring>
#include <string>
#include <mach-o/dyld.h>

namespace api {

struct LuauClosure {
    void*    next;
    uint8_t  tt;
    uint8_t  marked;
    uint8_t  isC;
    uint8_t  nupvalues;
    uint32_t _pad;
    void*    gclist;
    void*    env;
    union {
        struct { void* f; void* cont; void* upvalue[1]; } c;
        struct { void* p; void* upvals[1]; } l;
    } u;
};

static LuauClosure* ToClosure(lua_State* L, int idx) {
    return (LuauClosure*)lua_topointer(L, idx);
}

static int l_getgenv(lua_State* L) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, executor::EnvRef());
    return 1;
}
static int l_getrenv(lua_State* L) {
    lua_getglobal(L, "_G");
    return 1;
}

static int l_loadstring(lua_State* L) {
    size_t len = 0;
    const char* src = luaL_checklstring(L, 1, &len);

    size_t bsz = 0;
    char* bc = luau_compile(src, len, nullptr, &bsz);
    if (!bc) { lua_pushnil(L); lua_pushliteral(L, "compile failed"); return 2; }

    lua_rawgeti(L, LUA_REGISTRYINDEX, executor::EnvRef());
    int envIdx = lua_gettop(L);

    int st = luau_load(L, "=loadstring", bc, bsz, envIdx);
    free(bc);

    if (st != 0) {
        lua_pushnil(L);
        lua_pushvalue(L, -2);
        lua_remove(L, envIdx);
        return 2;
    }
    lua_remove(L, envIdx);
    return 1;
}

static int l_getrawmetatable(lua_State* L) {
    if (!lua_getmetatable(L, 1)) lua_pushnil(L);
    return 1;
}

static int l_setreadonly(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    bool ro = lua_toboolean(L, 2) != 0;

    lua_getfield(L, LUA_REGISTRYINDEX, "__ro_set");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_pushvalue(L, -1);
        lua_setfield(L, LUA_REGISTRYINDEX, "__ro_set");
    }
    lua_pushvalue(L, 1);
    lua_pushboolean(L, ro);
    lua_settable(L, -3);
    lua_pop(L, 1);
    lua_pushboolean(L, 1);
    return 1;
}

static int l_isreadonly(lua_State* L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "__ro_set");
    if (lua_isnil(L, -1)) { lua_pop(L, 1); lua_pushboolean(L, 0); return 1; }
    lua_pushvalue(L, 1);
    lua_gettable(L, -2);
    bool ro = lua_toboolean(L, -1) != 0;
    lua_pop(L, 2);
    lua_pushboolean(L, ro);
    return 1;
}

static int l_hookfunction(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    LuauClosure* oldC = ToClosure(L, 1);
    LuauClosure* newC = ToClosure(L, 2);
    if (!oldC || !newC) { lua_pushnil(L); return 1; }

    lua_newtable(L);
    lua_pushinteger(L, oldC->isC);              lua_setfield(L, -2, "isC");
    lua_pushinteger(L, oldC->nupvalues);        lua_setfield(L, -2, "nupvalues");
    lua_pushlightuserdata(L, oldC->u.c.f);      lua_setfield(L, -2, "f");
    lua_pushlightuserdata(L, oldC->u.c.cont);   lua_setfield(L, -2, "cont");
    lua_pushlightuserdata(L, oldC->u.l.p);      lua_setfield(L, -2, "p");
    lua_pushvalue(L, 1);                        lua_setfield(L, -2, "original");

    oldC->isC       = newC->isC;
    oldC->nupvalues = newC->nupvalues;
    oldC->u         = newC->u;
    return 1;
}

static int l_hookmetamethod(lua_State* L) {
    luaL_checkany(L, 1);
    const char* method = luaL_checkstring(L, 2);
    luaL_checktype(L, 3, LUA_TFUNCTION);

    if (!lua_getmetatable(L, 1)) {
        lua_newtable(L);
        lua_pushvalue(L, -1);
        lua_setmetatable(L, 1);
    }

    lua_pushstring(L, method);
    lua_gettable(L, -2);
    lua_pushvalue(L, 3);
    lua_pushstring(L, method);
    lua_settable(L, -4);
    return 1;
}

static int l_identifyexecutor(lua_State* L) {
    lua_pushstring(L, "cobble");
    lua_pushstring(L, "1.0.0-ios");
    return 2;
}
static int l_getthreadidentity(lua_State* L) {
    lua_pushinteger(L, 8); return 1;
}
static int l_setthreadidentity(lua_State* L) {
    luaL_checkinteger(L, 1); return 0;
}
static int l_request(lua_State* L) {
    luaL_checkany(L, 1); lua_pushnil(L); return 1;
}
static int l_firetouchinterest(lua_State* L) {
    luaL_checkany(L, 1); luaL_checkany(L, 2); luaL_checkany(L, 3);
    return 0;
}
static int l_getnamecallmethod(lua_State* L) {
    lua_pushstring(L, ""); return 1;
}

static const luaL_Reg kFuncs[] = {
    {"getgenv",            l_getgenv},
    {"getrenv",            l_getrenv},
    {"loadstring",         l_loadstring},
    {"getrawmetatable",    l_getrawmetatable},
    {"setreadonly",        l_setreadonly},
    {"isreadonly",         l_isreadonly},
    {"hookfunction",       l_hookfunction},
    {"hookmetamethod",     l_hookmetamethod},
    {"getnamecallmethod",  l_getnamecallmethod},
    {"firetouchinterest",  l_firetouchinterest},
    {"identifyexecutor",   l_identifyexecutor},
    {"getthreadidentity",  l_getthreadidentity},
    {"setthreadidentity",  l_setthreadidentity},
    {"request",            l_request},
    {nullptr, nullptr},
};

void Register(lua_State* L) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, executor::EnvRef());
    luaL_register(L, nullptr, kFuncs);
    lua_pop(L, 1);

    for (const luaL_Reg* r = kFuncs; r->name; ++r) {
        lua_pushcfunction(L, r->func, r->name);
        lua_setglobal(L, r->name);
    }
}

}  // namespace api
