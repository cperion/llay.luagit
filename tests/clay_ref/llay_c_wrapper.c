#define CLAY_IMPLEMENTATION
#include "../../clay/clay.h"
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdlib.h>
#include <string.h>

static luaL_Reg clay_lua_lib[] = {
    {NULL, NULL}
};

// Simple C measure text function
static Clay_Dimensions measure_text_wrapper(Clay_StringSlice text, Clay_TextElementConfig *config, void *userData) {
    // Very simple: 10px per character, 20px height
    Clay_Dimensions dimensions = {
        .width = (float)text.length * 10,
        .height = 20
    };
    return dimensions;
}

// Initialize Clay with measure text
static int llay_clay_init(lua_State *L) {
    size_t arenaSize = 1024 * 1024 * 16;
    char *arenaMemory = malloc(arenaSize);
    Clay_Arena arena = {
        .capacity = arenaSize,
        .memory = arenaMemory
    };
    
    float width = (float)luaL_checknumber(L, 1);
    float height = (float)luaL_checknumber(L, 2);
    
    Clay_Dimensions dimensions = {.width = width, .height = height};
    Clay_Context *context = Clay_Initialize(arena, dimensions, (Clay_ErrorHandler){0});
    
    if (context == NULL) {
        lua_pushnil(L);
        return 1;
    }
    
    // Set measure text
    Clay_SetMeasureTextFunction(measure_text_wrapper, NULL);
    
    // Return context as lightuserdata
    lua_pushlightuserdata(L, context);
    return 1;
}

// Wrapper functions
static int llay_begin_layout(lua_State *L) {
    Clay_BeginLayout();
    return 0;
}

static int llay_end_layout(lua_State *L) {
    Clay_RenderCommandArray commands = Clay_EndLayout();
    lua_pushlightuserdata(L, commands.internalArray);
    lua_pushinteger(L, commands.length);
    return 2;
}

static int llay_set_dimensions(lua_State *L) {
    float width = (float)luaL_checknumber(L, 1);
    float height = (float)luaL_checknumber(L, 2);
    Clay_Dimensions dims = {.width = width, .height = height};
    Clay_SetLayoutDimensions(dims);
    return 0;
}

static int llay_open_element(lua_State *L) {
    Clay__OpenElement();
    return 0;
}

static int llay_configure_element(lua_State *L) {
    Clay_ElementDeclaration *decl = (Clay_ElementDeclaration*)lua_touserdata(L, 1);
    if (decl) {
        Clay__ConfigureOpenElementPtr(decl);
    }
    return 0;
}

static int llay_close_element(lua_State *L) {
    Clay__CloseElement();
    return 0;
}

// Create element declaration userdata
static int llay_create_declaration(lua_State *L) {
    Clay_ElementDeclaration *decl = (Clay_ElementDeclaration*)lua_newuserdata(L, sizeof(Clay_ElementDeclaration));
    memset(decl, 0, sizeof(Clay_ElementDeclaration));
    return 1;
}

static int llay_set_sizing(lua_State *L) {
    Clay_ElementDeclaration *decl = (Clay_ElementDeclaration*)lua_touserdata(L, 1);
    if (!decl) return 0;
    
    decl->layout.sizing.width.type = luaL_checkinteger(L, 2);
    decl->layout.sizing.height.type = luaL_checkinteger(L, 3);
    
    return 0;
}

static int llay_set_background_color(lua_State *L) {
    Clay_ElementDeclaration *decl = (Clay_ElementDeclaration*)lua_touserdata(L, 1);
    if (!decl) return 0;
    
    decl->backgroundColor.r = luaL_checknumber(L, 2);
    decl->backgroundColor.g = luaL_checknumber(L, 3);
    decl->backgroundColor.b = luaL_checknumber(L, 4);
    decl->backgroundColor.a = luaL_checknumber(L, 5);
    
    return 0;
}

static const luaL_Reg clay_methods[] = {
    {"init", llay_clay_init},
    {"begin_layout", llay_begin_layout},
    {"end_layout", llay_end_layout},
    {"set_dimensions", llay_set_dimensions},
    {"open_element", llay_open_element},
    {"configure_element", llay_configure_element},
    {"close_element", llay_close_element},
    {"create_declaration", llay_create_declaration},
    {"set_sizing", llay_set_sizing},
    {"set_background_color", llay_set_background_color},
    {NULL, NULL}
};

int luaopen_llay_clay(lua_State *L) {
    luaL_newlib(L, clay_methods);
    return 1;
}
