-- ffi.lua - FFI cdef declarations auto-extracted from clay.h
-- Generated using grep/sed from clay.h

local ffi = require("ffi")

ffi.cdef[[
// Forward declarations
typedef struct Clay_Context Clay_Context;

// Basic Types
typedef struct {
    float x, y;
} Clay_Vector2;

typedef struct {
    float width, height;
} Clay_Dimensions;

typedef struct {
    float r, g, b, a;
} Clay_Color;

typedef struct {
    float x, y, width, height;
} Clay_BoundingBox;

typedef struct {
    int32_t length;
    const char* chars;
    bool isStaticallyAllocated;
} Clay_String;

typedef struct {
    uintptr_t nextAllocation;
    size_t capacity;
    char *memory;
} Clay_Arena;

typedef struct {
    float min, max;
} Clay_SizingMinMax;

typedef struct {
    uint8_t left;
    uint8_t right; 
    uint8_t top;
    uint8_t bottom;
} Clay_Padding;

typedef struct {
    uint8_t x;
    uint8_t y;
} Clay_ChildAlignment;

typedef uint8_t Clay__SizingType;
typedef uint8_t Clay_LayoutDirection;

typedef struct {
    Clay__SizingType type;
    union {
        Clay_SizingMinMax minMax;
        float percent;
    } size;
} Clay_SizingAxis;

typedef struct {
    Clay_SizingAxis width;
    Clay_SizingAxis height;
} Clay_Sizing;

typedef struct {
    Clay_Sizing sizing;
    Clay_Padding padding;
    uint16_t childGap;
    Clay_ChildAlignment childAlignment;
    Clay_LayoutDirection layoutDirection;
} Clay_LayoutConfig;

typedef struct {
    Clay_Color backgroundColor;
    Clay_Vector2 textDimensions;
    uint32_t configId;
} Clay_ElementConfig;

typedef struct {
    Clay_ElementConfig elementConfig;
    uint16_t fontSize;
    uint16_t lineHeight;
    Clay_Color textColor;
    Clay_Padding padding;
} Clay_TextElementConfig;

typedef struct {
    Clay_BoundingBox boundingBox;
    Clay_Color backgroundColor;
    Clay_String text;
    uint32_t configId;
    uint32_t id;
} Clay_RenderCommand;

typedef struct {
    int32_t length;
    int32_t capacity;
    Clay_RenderCommand* internalArray;
} Clay_RenderCommandArray;

typedef struct {
    void (*errorHandlerFunction)(void* errorText);
    void *userData;
} Clay_ErrorHandler;

// Public API
typedef uint32_t Clay_ElementId;
typedef struct Clay_ErrorData Clay_ErrorData;

uint32_t Clay_MinMemorySize(void);
Clay_Arena Clay_CreateArenaWithCapacityAndMemory(size_t capacity, void *memory);
Clay_Context* Clay_Initialize(Clay_Arena arena, Clay_Dimensions layoutDimensions, Clay_ErrorHandler errorHandler);
Clay_Context* Clay_GetCurrentContext(void);
void Clay_SetCurrentContext(Clay_Context* context);
void Clay_SetLayoutDimensions(Clay_Dimensions dimensions);
void Clay_BeginLayout(void);
Clay_RenderCommandArray Clay_EndLayout(void);
Clay_ElementId Clay_GetElementId(Clay_String idString);
Clay_ElementId Clay_GetElementIdWithIndex(Clay_String idString, uint32_t index);
void Clay_BeginLayout(void);
void Clay__OpenElement(void);
void Clay__OpenElementWithId(Clay_ElementId elementId);
void Clay__ConfigureOpenElement(const void *config);
void Clay__CloseElement(void);
Clay_ElementId Clay__HashString(Clay_String key, uint32_t seed);
]]

return {
    Clay__SizingType = {
        FIT = 0,
        GROW = 1,
        PERCENT = 2,
        FIXED = 3,
    },
    Clay_LayoutDirection = {
        LEFT_TO_RIGHT = 0,
        TOP_TO_BOTTOM = 1,
    },
}
