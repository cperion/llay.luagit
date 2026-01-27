local ffi = require("ffi")

ffi.cdef[[
typedef struct Clay_Context Clay_Context;
typedef uint32_t Clay_ElementId;

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

typedef enum {
    CLAY_TEXT_WRAP_WORDS,
    CLAY_TEXT_WRAP_NEWLINES,
    CLAY_TEXT_WRAP_NONE,
} Clay_TextElementConfigWrapMode;

typedef enum {
    CLAY_TEXT_ALIGN_LEFT,
    CLAY_TEXT_ALIGN_CENTER,
    CLAY_TEXT_ALIGN_RIGHT,
} Clay_TextAlignment;

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
    int32_t *elements;
    uint16_t length;
} Clay__LayoutElementChildren;

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

typedef struct {
    void *userData;
    Clay_Color textColor;
    uint16_t fontId;
    uint16_t fontSize;
    uint16_t letterSpacing;
    uint16_t lineHeight;
    Clay_Padding padding;
    Clay_TextElementConfigWrapMode wrapMode;
    Clay_TextAlignment textAlignment;
} Clay_TextElementConfig;

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
            uint16_t lineHeight;
        } text;
        struct {
            Clay_Color backgroundColor;
            Clay_CornerRadius cornerRadius;
            void* imageData;
        } image;
        struct {
            Clay_Color backgroundColor;
            Clay_CornerRadius cornerRadius;
            void* customData;
        } custom;
        struct {
            Clay_Color backgroundColor;
            Clay_CornerRadius cornerRadius;
        } rectangle;
        struct {
            bool horizontal;
            bool vertical;
        } clip;
    } renderData;
    Clay_String text;
    uint32_t configId;
    uint32_t id;
    int32_t zIndex;
    uint8_t commandType;
    void* userData;
} Clay_RenderCommand;

typedef enum {
    CLAY_RENDER_COMMAND_TYPE_NONE,
    CLAY_RENDER_COMMAND_TYPERectangle,
    CLAY_RENDER_COMMAND_TYPE_BORDER,
    CLAY_RENDER_COMMAND_TYPE_TEXT,
    CLAY_RENDER_COMMAND_TYPE_IMAGE,
    CLAY_RENDER_COMMAND_TYPE_CUSTOM,
    CLAY_RENDER_COMMAND_TYPE_SCISSOR_START,
    CLAY_RENDER_COMMAND_TYPE_SCISSOR_END,
} Clay_RenderCommandType;

typedef struct {
    int32_t length;
    int32_t capacity;
    Clay_RenderCommand* internalArray;
} Clay_RenderCommandArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    int32_t *internalArray;
} Clay__int32_tArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    bool *internalArray;
} Clay__boolArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    char *internalArray;
} Clay__charArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_LayoutConfig *internalArray;
} Clay__LayoutConfigArray;

typedef struct {
    float aspectRatio;
} Clay_AspectRatioElementConfig;

typedef struct {
    void* imageData;
} Clay_ImageElementConfig;

typedef enum {
    CLAY_ATTACH_POINT_LEFT_TOP,
    CLAY_ATTACH_POINT_LEFT_CENTER,
    CLAY_ATTACH_POINT_LEFT_BOTTOM,
    CLAY_ATTACH_POINT_CENTER_TOP,
    CLAY_ATTACH_POINT_CENTER_CENTER,
    CLAY_ATTACH_POINT_CENTER_BOTTOM,
    CLAY_ATTACH_POINT_RIGHT_TOP,
    CLAY_ATTACH_POINT_RIGHT_CENTER,
    CLAY_ATTACH_POINT_RIGHT_BOTTOM,
} Clay_FloatingAttachPointType;

typedef enum {
    CLAY_POINTER_CAPTURE_MODE_CAPTURE,
    CLAY_POINTER_CAPTURE_MODE_PASSTHROUGH,
} Clay_PointerCaptureMode;

typedef enum {
    CLAY_ATTACH_TO_NONE,
    CLAY_ATTACH_TO_PARENT,
    CLAY_ATTACH_TO_ELEMENT_WITH_ID,
    CLAY_ATTACH_TO_ROOT,
} Clay_FloatingAttachToElement;

typedef enum {
    CLAY_CLIP_TO_NONE,
    CLAY_CLIP_TO_ATTACHED_PARENT,
} Clay_FloatingClipToElement;

typedef struct {
    Clay_Vector2 offset;
    Clay_Dimensions expand;
    uint32_t parentId;
    int16_t zIndex;
    struct {
        Clay_FloatingAttachPointType element;
        Clay_FloatingAttachPointType parent;
    } attachPoints;
    Clay_PointerCaptureMode pointerCaptureMode;
    Clay_FloatingAttachToElement attachTo;
    Clay_FloatingClipToElement clipTo;
} Clay_FloatingElementConfig;

typedef struct {
    void* customData;
} Clay_CustomElementConfig;

typedef struct {
    bool horizontal;
    bool vertical;
    Clay_Vector2 childOffset;
} Clay_ClipElementConfig;

typedef struct {
    uint16_t left;
    uint16_t right;
    uint16_t top;
    uint16_t bottom;
    uint16_t betweenChildren;
} Clay_BorderWidth;

typedef struct {
    Clay_Color color;
    Clay_BorderWidth width;
} Clay_BorderElementConfig;

typedef struct {
    Clay_Color backgroundColor;
    Clay_CornerRadius cornerRadius;
    void* userData;
} Clay_SharedElementConfig;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_AspectRatioElementConfig *internalArray;
} Clay__AspectRatioElementConfigArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_ImageElementConfig *internalArray;
} Clay__ImageElementConfigArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_FloatingElementConfig *internalArray;
} Clay__FloatingElementConfigArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_CustomElementConfig *internalArray;
} Clay__CustomElementConfigArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_ClipElementConfig *internalArray;
} Clay__ClipElementConfigArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_BorderElementConfig *internalArray;
} Clay__BorderElementConfigArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_SharedElementConfig *internalArray;
} Clay__SharedElementConfigArray;

typedef enum {
    CLAY__ELEMENT_CONFIG_TYPE_NONE,
    CLAY__ELEMENT_CONFIG_TYPE_BORDER,
    CLAY__ELEMENT_CONFIG_TYPE_FLOATING,
    CLAY__ELEMENT_CONFIG_TYPE_CLIP,
    CLAY__ELEMENT_CONFIG_TYPE_ASPECT,
    CLAY__ELEMENT_CONFIG_TYPE_IMAGE,
    CLAY__ELEMENT_CONFIG_TYPE_TEXT,
    CLAY__ELEMENT_CONFIG_TYPE_CUSTOM,
    CLAY__ELEMENT_CONFIG_TYPE_SHARED,
} Clay__ElementConfigType;

typedef union {
    Clay_TextElementConfig *textElementConfig;
    Clay_AspectRatioElementConfig *aspectRatioElementConfig;
    Clay_ImageElementConfig *imageElementConfig;
    Clay_FloatingElementConfig *floatingElementConfig;
    Clay_CustomElementConfig *customElementConfig;
    Clay_ClipElementConfig *clipElementConfig;
    Clay_BorderElementConfig *borderElementConfig;
    Clay_SharedElementConfig *sharedElementConfig;
} Clay_ElementConfigUnion;

typedef struct {
    Clay__ElementConfigType type;
    Clay_ElementConfigUnion config;
} Clay_ElementConfig;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_ElementConfig *internalArray;
} Clay__ElementConfigArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_TextElementConfig *internalArray;
} Clay__TextElementConfigArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_String *internalArray;
} Clay__StringArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__TextElementData *internalArray;
} Clay__TextElementDataArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__WrappedTextLine *internalArray;
} Clay__WrappedTextLineArray;

typedef struct {
    uint32_t id;
    uint32_t offset;
    uint32_t baseId;
    Clay_String stringId;
} Clay_ElementId;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_ElementId *internalArray;
} Clay_ElementIdArray;

typedef struct {
    bool maxElementsExceeded;
    bool maxRenderCommandsExceeded;
    bool maxTextMeasureCacheExceeded;
    bool textMeasurementFunctionNotSet;
} Clay_BooleanWarnings;

typedef struct {
    Clay_String baseMessage;
    Clay_String dynamicMessage;
} Clay__Warning;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__Warning *internalArray;
} Clay__WarningArray;

typedef struct Clay_ErrorData Clay_ErrorData;

typedef struct {
    void (*errorHandlerFunction)(Clay_ErrorData errorText);
    void *userData;
} Clay_ErrorHandler;

typedef enum {
    CLAY_POINTER_DATA_PRESSED_THIS_FRAME,
    CLAY_POINTER_DATA_PRESSED,
    CLAY_POINTER_DATA_RELEASED_THIS_FRAME,
    CLAY_POINTER_DATA_RELEASED,
} Clay_PointerDataInteractionState;

typedef enum {
    CLAY_ALIGN_X_LEFT,
    CLAY_ALIGN_X_CENTER,
    CLAY_ALIGN_X_RIGHT,
} Clay_AlignX;

typedef enum {
    CLAY_ALIGN_Y_TOP,
    CLAY_ALIGN_Y_CENTER,
    CLAY_ALIGN_Y_BOTTOM,
} Clay_AlignY;

typedef struct {
    Clay_Vector2 position;
    Clay_PointerDataInteractionState state;
} Clay_PointerData;

typedef struct {
    int32_t startOffset;
    int32_t length;
    float width;
    int32_t next;
} Clay__MeasuredWord;

typedef struct {
    Clay_Dimensions unwrappedDimensions;
    int32_t measuredWordsStartIndex;
    float minWidth;
    bool containsNewlines;
    uint32_t id;
    int32_t nextIndex;
    uint32_t generation;
} Clay__MeasureTextCacheItem;

typedef struct {
    Clay_BoundingBox boundingBox;
    Clay_ElementId elementId;
    Clay_LayoutElement* layoutElement;
    void (*onHoverFunction)(Clay_ElementId elementId, Clay_PointerData pointerInfo, void *userData);
    void *hoverFunctionUserData;
    int32_t nextIndex;
    uint32_t generation;
    void *debugData;
} Clay_LayoutElementHashMapItem;

typedef struct {
    Clay_LayoutElement *layoutElement;
    Clay_BoundingBox boundingBox;
    Clay_Dimensions contentSize;
    Clay_Vector2 scrollOrigin;
    Clay_Vector2 pointerOrigin;
    Clay_Vector2 scrollMomentum;
    Clay_Vector2 scrollPosition;
    Clay_Vector2 previousDelta;
    float momentumTime;
    uint32_t elementId;
    bool openThisFrame;
    bool pointerScrollActive;
} Clay__ScrollContainerDataInternal;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__MeasuredWord *internalArray;
} Clay__MeasuredWordArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__MeasureTextCacheItem *internalArray;
} Clay__MeasureTextCacheItemArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_LayoutElementHashMapItem *internalArray;
} Clay__LayoutElementHashMapItemArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_LayoutElementHashMapItem *internalArray;
} Clay_LayoutElementHashMapArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__ScrollContainerDataInternal *internalArray;
} Clay__ScrollContainerDataInternalArray;

typedef struct {
    int32_t *elements;
    uint16_t length;
} Clay__LayoutElementChildren;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__MeasuredWord *internalArray;
} Clay__MeasuredWordArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__MeasureTextCacheItem *internalArray;
} Clay__MeasureTextCacheItemArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_LayoutElementHashMapItem *internalArray;
} Clay__LayoutElementHashMapItemArray;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay_LayoutElementHashMapItem *internalArray;
} Clay_LayoutElementHashMapArray;

typedef struct {
    Clay_Color color;
    Clay_BorderWidth width;
} Clay_BorderElementConfig;

typedef struct {
    Clay_Color backgroundColor;
    Clay_CornerRadius cornerRadius;
    void* userData;
} Clay_SharedElementConfig;

typedef struct {
    int32_t *elements;
    uint16_t length;
} Clay__LayoutElementChildren;

typedef struct {
    Clay_LayoutElement *layoutElement;
    Clay_Vector2 position;
    Clay_Vector2 nextChildOffset;
} Clay__LayoutElementTreeNode;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__LayoutElementTreeNode *internalArray;
} Clay__LayoutElementTreeNodeArray;

typedef struct {
    int32_t layoutElementIndex;
    uint32_t parentId;
    uint32_t clipElementId;
    int16_t zIndex;
    Clay_Vector2 pointerOffset;
} Clay__LayoutElementTreeRoot;

typedef struct {
    int32_t capacity;
    int32_t length;
    Clay__LayoutElementTreeRoot *internalArray;
} Clay__LayoutElementTreeRootArray;

struct Clay_Context {
    int32_t maxElementCount;
    int32_t maxMeasureTextCacheWordCount;
    bool warningsEnabled;
    Clay_ErrorHandler errorHandler;
    Clay_BooleanWarnings booleanWarnings;
    Clay__WarningArray warnings;
    Clay_PointerData pointerInfo;
    Clay_Dimensions layoutDimensions;
    Clay_ElementId dynamicElementIndexBaseHash;
    uint32_t dynamicElementIndex;
    bool debugModeEnabled;
    bool disableCulling;
    bool externalScrollHandlingEnabled;
    uint32_t debugSelectedElementId;
    uint32_t generation;
    uintptr_t arenaResetOffset;
    void *measureTextUserData;
    void *queryScrollOffsetUserData;
    Clay_Arena internalArena;
    Clay_LayoutElementArray layoutElements;
    Clay_RenderCommandArray renderCommands;
    Clay__int32_tArray openLayoutElementStack;
    Clay__int32_tArray layoutElementChildren;
    Clay__int32_tArray layoutElementChildrenBuffer;
    Clay__TextElementDataArray textElementData;
    Clay__int32_tArray aspectRatioElementIndexes;
    Clay__int32_tArray reusableElementIndexBuffer;
    Clay__int32_tArray layoutElementClipElementIds;
    Clay__LayoutConfigArray layoutConfigs;
    Clay__ElementConfigArray elementConfigs;
    Clay__TextElementConfigArray textElementConfigs;
    Clay__StringArray layoutElementIdStrings;
    Clay__WrappedTextLineArray wrappedTextLines;
    Clay__boolArray treeNodeVisited;
    Clay__charArray dynamicStringData;
    Clay__LayoutElementHashMapItemArray layoutElementsHashMapInternal;
    Clay__int32_tArray layoutElementsHashMap;
    Clay__LayoutElementTreeNodeArray layoutElementTreeNodeArray1;
    Clay__LayoutElementTreeRootArray layoutElementTreeRoots;
    Clay__MeasureTextCacheItemArray measureTextHashMapInternal;
    Clay__int32_tArray measureTextHashMapInternalFreeList;
    Clay__int32_tArray measureTextHashMap;
    Clay__MeasuredWordArray measuredWords;
    Clay__int32_tArray measuredWordsFreeList;
    Clay__ScrollContainerDataInternalArray scrollContainerDatas;
    int32_t generation;
    bool disableCulling;
};

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
    Clay_TextElementConfigWrapMode = {
        WORDS = 0,
        NEWLINES = 1,
        NONE = 2,
    },
    Clay_TextAlignment = {
        LEFT = 0,
        CENTER = 1,
        RIGHT = 2,
    },
    Clay_RenderCommandType = {
        NONE = 0,
        RECTANGLE = 1,
        BORDER = 2,
        TEXT = 3,
        IMAGE = 4,
        CUSTOM = 5,
        SCISSOR_START = 6,
        SCISSOR_END = 7,
    },
}
