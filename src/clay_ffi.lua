-- clay_ffi.lua - FFI cdef declarations from clay.h
-- This file contains the FFI type definitions for Clay types

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
} Clay_String;

typedef struct {
    int32_t length;
    const char *chars;
    const char *baseChars;
} Clay_StringSlice;

typedef struct {
    uintptr_t nextAllocation;
    size_t capacity;
    char *memory;
} Clay_Arena;

typedef struct {
    float min, max;
} Clay_SizingMinMax;

typedef struct {
    uint16_t left;
    uint16_t right; 
    uint16_t top;
    uint16_t bottom;
} Clay_Padding;

typedef struct {
    uint8_t x;
    uint8_t y;
} Clay_ChildAlignment;

typedef struct {
    float topLeft;
    float topRight;
    float bottomLeft;
    float bottomRight;
} Clay_CornerRadius;

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

// Layout Element Types
typedef struct {
    int32_t *elements;
    uint16_t length;
} Clay__LayoutElementChildren;

typedef struct {
    Clay_Dimensions dimensions;
    Clay_String line;
} Clay__WrappedTextLine;

typedef struct {
    Clay_String text;
    Clay_Dimensions preferredDimensions;
    int32_t elementIndex;
    struct {
        int32_t length;
        Clay__WrappedTextLine *internalArray;
    } wrappedLines;
} Clay__TextElementData;

typedef struct {
    union {
        Clay__LayoutElementChildren children;
        Clay__TextElementData *textElementData;
    } childrenOrTextContent;
    Clay_Dimensions dimensions;
    Clay_Dimensions minDimensions;
    Clay_LayoutConfig *layoutConfig;
    struct {
        int32_t length;
        struct {
            uint8_t type;
            struct {
                void *textElementConfig;
                void *aspectRatioElementConfig;
                void *imageElementConfig;
                void *floatingElementConfig;
                void *customElementConfig;
                void *clipElementConfig;
                void *borderElementConfig;
                void *sharedElementConfig;
            } config;
        } *internalArray;
    } elementConfigs;
    uint32_t id;
    uint16_t floatingChildrenCount;
} Clay_LayoutElement;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_LayoutElement *internalArray;
} Clay_LayoutElementArray;

// Config Types
typedef struct {
    void *userData;
    Clay_Color textColor;
    uint16_t fontId;
    uint16_t fontSize;
    uint16_t letterSpacing;
    uint16_t lineHeight;
    Clay_Padding padding;
} Clay_TextElementConfig;

// Render Command Types
typedef struct {
    Clay_BoundingBox boundingBox;
    struct {
        Clay_Color backgroundColor;
        struct {
            Clay_StringSlice stringContents;
            Clay_Color textColor;
            uint16_t fontId;
            uint16_t fontSize;
            uint16_t letterSpacing;
        } textData;
    } renderData;
    Clay_String text;
    uint32_t configId;
    uint32_t id;
} Clay_RenderCommand;

typedef struct {
    int32_t length;
    int32_t capacity;
    Clay_RenderCommand* internalArray;
} Clay_RenderCommandArray;

// Context
typedef struct Clay_ErrorData Clay_ErrorData;

typedef struct {
    void (*errorHandlerFunction)( Clay_ErrorData errorText);
    void *userData;
} Clay_ErrorHandler;

// Public API
typedef uint32_t Clay_ElementId;

Clay_Arena Clay_CreateArenaWithCapacityAndMemory(size_t capacity, void *memory);
Clay_Context* Clay_Initialize(Clay_Arena arena, Clay_Dimensions layoutDimensions, Clay_ErrorHandler errorHandler);
void Clay_SetLayoutDimensions(Clay_Dimensions dimensions);
void Clay_BeginLayout(void);
Clay_RenderCommandArray Clay_EndLayout(void);
void Clay__OpenElement(void);
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
