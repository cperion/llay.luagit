local ffi = require("ffi")

-- Define types only once (handle multiple requires)
local clay_ffi_defined = package.loaded["clay_ffi_loaded"]
if not clay_ffi_defined then
    pcall(function()
        ffi.cdef([[
    // =========================================================================
    // PRIMITIVES & FORWARD DECLARATIONS
    // =========================================================================
    typedef struct Clay_String {
        int32_t length;
        const char *chars;
        bool isStaticallyAllocated;
    } Clay_String;

    typedef struct Clay_StringSlice {
        int32_t length;
        const char *chars;
        const char *baseChars;
    } Clay_StringSlice;

    typedef struct Clay_Arena {
        uintptr_t nextAllocation;
        size_t capacity;
        char *memory;
    } Clay_Arena;

    typedef struct Clay_Dimensions { float width, height; } Clay_Dimensions;
    typedef struct Clay_Vector2 { float x, y; } Clay_Vector2;
    typedef struct Clay_Color { float r, g, b, a; } Clay_Color;
    typedef struct Clay_BoundingBox { float x, y, width, height; } Clay_BoundingBox;
    typedef struct Clay_CornerRadius { float topLeft, topRight, bottomLeft, bottomRight; } Clay_CornerRadius;

    typedef struct Clay_ElementId {
        uint32_t id;
        uint32_t offset;
        uint32_t baseId;
        Clay_String stringId;
    } Clay_ElementId;

    // =========================================================================
    // ENUMS
    // =========================================================================
    typedef enum {
        CLAY_LEFT_TO_RIGHT,
        CLAY_TOP_TO_BOTTOM
    } Clay_LayoutDirection;

    typedef enum {
        CLAY_ALIGN_X_LEFT,
        CLAY_ALIGN_X_RIGHT,
        CLAY_ALIGN_X_CENTER
    } Clay_LayoutAlignmentX;

    typedef enum {
        CLAY_ALIGN_Y_TOP,
        CLAY_ALIGN_Y_BOTTOM,
        CLAY_ALIGN_Y_CENTER
    } Clay_LayoutAlignmentY;

    typedef enum {
        CLAY__SIZING_TYPE_FIT,
        CLAY__SIZING_TYPE_GROW,
        CLAY__SIZING_TYPE_PERCENT,
        CLAY__SIZING_TYPE_FIXED
    } Clay__SizingType;

    typedef enum {
        CLAY_TEXT_WRAP_WORDS,
        CLAY_TEXT_WRAP_NEWLINES,
        CLAY_TEXT_WRAP_NONE
    } Clay_TextElementConfigWrapMode;

    typedef enum {
        CLAY_TEXT_ALIGN_LEFT,
        CLAY_TEXT_ALIGN_CENTER,
        CLAY_TEXT_ALIGN_RIGHT
    } Clay_TextAlignment;

    typedef enum {
        CLAY_ATTACH_POINT_LEFT_TOP,
        CLAY_ATTACH_POINT_LEFT_CENTER,
        CLAY_ATTACH_POINT_LEFT_BOTTOM,
        CLAY_ATTACH_POINT_CENTER_TOP,
        CLAY_ATTACH_POINT_CENTER_CENTER,
        CLAY_ATTACH_POINT_CENTER_BOTTOM,
        CLAY_ATTACH_POINT_RIGHT_TOP,
        CLAY_ATTACH_POINT_RIGHT_CENTER,
        CLAY_ATTACH_POINT_RIGHT_BOTTOM
    } Clay_FloatingAttachPointType;

    typedef enum {
        CLAY_POINTER_CAPTURE_MODE_CAPTURE,
        CLAY_POINTER_CAPTURE_MODE_PASSTHROUGH
    } Clay_PointerCaptureMode;

    typedef enum {
        CLAY_ATTACH_TO_NONE,
        CLAY_ATTACH_TO_PARENT,
        CLAY_ATTACH_TO_ELEMENT_WITH_ID,
        CLAY_ATTACH_TO_ROOT
    } Clay_FloatingAttachToElement;

    typedef enum {
        CLAY_CLIP_TO_NONE,
        CLAY_CLIP_TO_ATTACHED_PARENT
    } Clay_FloatingClipToElement;

    typedef enum {
        CLAY_RENDER_COMMAND_TYPE_NONE,
        CLAY_RENDER_COMMAND_TYPE_RECTANGLE,
        CLAY_RENDER_COMMAND_TYPE_BORDER,
        CLAY_RENDER_COMMAND_TYPE_TEXT,
        CLAY_RENDER_COMMAND_TYPE_IMAGE,
        CLAY_RENDER_COMMAND_TYPE_SCISSOR_START,
        CLAY_RENDER_COMMAND_TYPE_SCISSOR_END,
        CLAY_RENDER_COMMAND_TYPE_CUSTOM
    } Clay_RenderCommandType;

    typedef enum {
        CLAY_POINTER_DATA_PRESSED_THIS_FRAME,
        CLAY_POINTER_DATA_PRESSED,
        CLAY_POINTER_DATA_RELEASED_THIS_FRAME,
        CLAY_POINTER_DATA_RELEASED
    } Clay_PointerDataInteractionState;

    typedef enum {
        CLAY_ERROR_TYPE_TEXT_MEASUREMENT_FUNCTION_NOT_PROVIDED,
        CLAY_ERROR_TYPE_ARENA_CAPACITY_EXCEEDED,
        CLAY_ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED,
        CLAY_ERROR_TYPE_TEXT_MEASUREMENT_CAPACITY_EXCEEDED,
        CLAY_ERROR_TYPE_DUPLICATE_ID,
        CLAY_ERROR_TYPE_FLOATING_CONTAINER_PARENT_NOT_FOUND,
        CLAY_ERROR_TYPE_PERCENTAGE_OVER_1,
        CLAY_ERROR_TYPE_INTERNAL_ERROR,
        CLAY_ERROR_TYPE_UNBALANCED_OPEN_CLOSE
    } Clay_ErrorType;

    // Internal Enums required for structs
    typedef enum {
        CLAY__ELEMENT_CONFIG_TYPE_NONE,
        CLAY__ELEMENT_CONFIG_TYPE_BORDER,
        CLAY__ELEMENT_CONFIG_TYPE_FLOATING,
        CLAY__ELEMENT_CONFIG_TYPE_CLIP,
        CLAY__ELEMENT_CONFIG_TYPE_ASPECT,
        CLAY__ELEMENT_CONFIG_TYPE_IMAGE,
        CLAY__ELEMENT_CONFIG_TYPE_TEXT,
        CLAY__ELEMENT_CONFIG_TYPE_CUSTOM,
        CLAY__ELEMENT_CONFIG_TYPE_SHARED
    } Clay__ElementConfigType;

    // =========================================================================
    // CONFIG STRUCTS
    // =========================================================================
    typedef struct Clay_SizingMinMax { float min, max; } Clay_SizingMinMax;

    typedef struct Clay_SizingAxis {
        union {
            Clay_SizingMinMax minMax;
            float percent;
        } size;
        Clay__SizingType type;
    } Clay_SizingAxis;

    typedef struct Clay_Sizing {
        Clay_SizingAxis width;
        Clay_SizingAxis height;
    } Clay_Sizing;

    typedef struct Clay_Padding {
        uint16_t left, right, top, bottom;
    } Clay_Padding;

    typedef struct Clay_ChildAlignment {
        Clay_LayoutAlignmentX x;
        Clay_LayoutAlignmentY y;
    } Clay_ChildAlignment;

    typedef struct Clay_LayoutConfig {
        Clay_Sizing sizing;
        Clay_Padding padding;
        uint16_t childGap;
        Clay_ChildAlignment childAlignment;
        Clay_LayoutDirection layoutDirection;
    } Clay_LayoutConfig;

    typedef struct Clay_TextElementConfig {
        void *userData;
        Clay_Color textColor;
        uint16_t fontId;
        uint16_t fontSize;
        uint16_t letterSpacing;
        uint16_t lineHeight;
        Clay_TextElementConfigWrapMode wrapMode;
        Clay_TextAlignment textAlignment;
    } Clay_TextElementConfig;

    typedef struct Clay_AspectRatioElementConfig { float aspectRatio; } Clay_AspectRatioElementConfig;
    typedef struct Clay_ImageElementConfig { void* imageData; } Clay_ImageElementConfig;
    typedef struct Clay_CustomElementConfig { void* customData; } Clay_CustomElementConfig;

    typedef struct Clay_FloatingAttachPoints {
        Clay_FloatingAttachPointType element;
        Clay_FloatingAttachPointType parent;
    } Clay_FloatingAttachPoints;

    typedef struct Clay_FloatingElementConfig {
        Clay_Vector2 offset;
        Clay_Dimensions expand;
        uint32_t parentId;
        int16_t zIndex;
        Clay_FloatingAttachPoints attachPoints;
        Clay_PointerCaptureMode pointerCaptureMode;
        Clay_FloatingAttachToElement attachTo;
        Clay_FloatingClipToElement clipTo;
    } Clay_FloatingElementConfig;

    typedef struct Clay_ClipElementConfig {
        bool horizontal;
        bool vertical;
        Clay_Vector2 childOffset;
    } Clay_ClipElementConfig;

    typedef struct Clay_BorderWidth {
        uint16_t left, right, top, bottom, betweenChildren;
    } Clay_BorderWidth;

    typedef struct Clay_BorderElementConfig {
        Clay_Color color;
        Clay_BorderWidth width;
    } Clay_BorderElementConfig;

    typedef struct Clay_SharedElementConfig {
        Clay_Color backgroundColor;
        Clay_CornerRadius cornerRadius;
        void* userData;
    } Clay_SharedElementConfig;

    typedef struct Clay_ElementDeclaration {
        Clay_LayoutConfig layout;
        Clay_Color backgroundColor;
        Clay_CornerRadius cornerRadius;
        Clay_AspectRatioElementConfig aspectRatio;
        Clay_ImageElementConfig image;
        Clay_FloatingElementConfig floating;
        Clay_CustomElementConfig custom;
        Clay_ClipElementConfig clip;
        Clay_BorderElementConfig border;
        void *userData;
    } Clay_ElementDeclaration;

    // =========================================================================
    // INTERNAL ELEMENT DATA STRUCTURES
    // =========================================================================

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

    typedef struct Clay_ElementConfig {
        Clay__ElementConfigType type;
        Clay_ElementConfigUnion config;
    } Clay_ElementConfig;

    typedef struct Clay__WrappedTextLine {
        Clay_Dimensions dimensions;
        Clay_String line;
    } Clay__WrappedTextLine;

    // Forward declarations of array types needed for LayoutElement
    typedef struct { int32_t length; Clay_ElementConfig *internalArray; } Clay__ElementConfigArraySlice;
    typedef struct { int32_t length; Clay__WrappedTextLine *internalArray; } Clay__WrappedTextLineArraySlice;

    typedef struct Clay__TextElementData {
        Clay_String text;
        Clay_Dimensions preferredDimensions;
        int32_t elementIndex;
        Clay__WrappedTextLineArraySlice wrappedLines;
    } Clay__TextElementData;

    typedef struct {
        int32_t *elements;
        uint16_t length;
    } Clay__LayoutElementChildren;

    // The Main Internal Element
    typedef struct Clay_LayoutElement {
        union {
            Clay__LayoutElementChildren children;
            Clay__TextElementData *textElementData;
        } childrenOrTextContent;
        Clay_Dimensions dimensions;
        Clay_Dimensions minDimensions;
        Clay_LayoutConfig *layoutConfig;
        Clay__ElementConfigArraySlice elementConfigs;
        uint32_t id;
        uint16_t floatingChildrenCount;
    } Clay_LayoutElement;

    // =========================================================================
    // RENDER COMMANDS & DATA
    // =========================================================================

    typedef struct Clay_TextRenderData {
        Clay_StringSlice stringContents;
        Clay_Color textColor;
        uint16_t fontId;
        uint16_t fontSize;
        uint16_t letterSpacing;
        uint16_t lineHeight;
    } Clay_TextRenderData;

    typedef struct Clay_RectangleRenderData {
        Clay_Color backgroundColor;
        Clay_CornerRadius cornerRadius;
    } Clay_RectangleRenderData;

    typedef struct Clay_ImageRenderData {
        Clay_Color backgroundColor;
        Clay_CornerRadius cornerRadius;
        void* imageData;
    } Clay_ImageRenderData;

    typedef struct Clay_CustomRenderData {
        Clay_Color backgroundColor;
        Clay_CornerRadius cornerRadius;
        void* customData;
    } Clay_CustomRenderData;

    typedef struct Clay_ClipRenderData {
        bool horizontal;
        bool vertical;
    } Clay_ClipRenderData;

    typedef struct Clay_BorderRenderData {
        Clay_Color color;
        Clay_CornerRadius cornerRadius;
        Clay_BorderWidth width;
    } Clay_BorderRenderData;

    typedef union Clay_RenderData {
        Clay_RectangleRenderData rectangle;
        Clay_TextRenderData text;
        Clay_ImageRenderData image;
        Clay_CustomRenderData custom;
        Clay_BorderRenderData border;
        Clay_ClipRenderData clip;
    } Clay_RenderData;

    typedef struct Clay_RenderCommand {
        Clay_BoundingBox boundingBox;
        Clay_RenderData renderData;
        void *userData;
        uint32_t id;
        int16_t zIndex;
        Clay_RenderCommandType commandType;
    } Clay_RenderCommand;

    // =========================================================================
    // INTERNAL DATA STRUCTURES (Maps, Caches, Trees)
    // =========================================================================

    typedef struct Clay__ScrollContainerDataInternal {
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

    typedef struct Clay__DebugElementData {
        bool collision;
        bool collapsed;
    } Clay__DebugElementData;

    typedef struct Clay_PointerData {
        Clay_Vector2 position;
        Clay_PointerDataInteractionState state;
    } Clay_PointerData;

    // Callback signatures
    typedef void (*Clay_OnHoverFunction)(Clay_ElementId elementId, Clay_PointerData pointerInfo, void *userData);
    typedef void (*Clay_ErrorHandlerFunction)(void* errorData);

    typedef struct Clay_LayoutElementHashMapItem {
        Clay_BoundingBox boundingBox;
        Clay_ElementId elementId;
        Clay_LayoutElement* layoutElement;
        Clay_OnHoverFunction onHoverFunction;
        void *hoverFunctionUserData;
        int32_t nextIndex;
        uint32_t generation;
        Clay__DebugElementData *debugData;
    } Clay_LayoutElementHashMapItem;

    typedef struct Clay__MeasuredWord {
        int32_t startOffset;
        int32_t length;
        float width;
        int32_t next;
    } Clay__MeasuredWord;

    typedef struct Clay__MeasureTextCacheItem {
        Clay_Dimensions unwrappedDimensions;
        int32_t measuredWordsStartIndex;
        float minWidth;
        bool containsNewlines;
        uint32_t id;
        int32_t nextIndex;
        uint32_t generation;
    } Clay__MeasureTextCacheItem;

    typedef struct Clay__LayoutElementTreeNode {
        Clay_LayoutElement *layoutElement;
        Clay_Vector2 position;
        Clay_Vector2 nextChildOffset;
    } Clay__LayoutElementTreeNode;

    typedef struct Clay__LayoutElementTreeRoot {
        int32_t layoutElementIndex;
        uint32_t parentId;
        uint32_t clipElementId;
        int16_t zIndex;
        Clay_Vector2 pointerOffset;
    } Clay__LayoutElementTreeRoot;

    // Error Handling
    typedef struct Clay_ErrorData {
        Clay_ErrorType errorType;
        Clay_String errorText;
        void *userData;
    } Clay_ErrorData;

    typedef struct Clay_ErrorHandler {
        void (*errorHandlerFunction)(Clay_ErrorData errorText);
        void *userData;
    } Clay_ErrorHandler;

    typedef struct Clay_BooleanWarnings {
        bool maxElementsExceeded;
        bool maxRenderCommandsExceeded;
        bool maxTextMeasureCacheExceeded;
        bool textMeasurementFunctionNotSet;
    } Clay_BooleanWarnings;

    typedef struct Clay__Warning {
        Clay_String baseMessage;
        Clay_String dynamicMessage;
    } Clay__Warning;

    // =========================================================================
    // PUBLIC API RETURN STRUCTS
    // =========================================================================
    // Return structs for public API functions

    typedef struct Clay_ScrollContainerData {
        Clay_Vector2 *scrollPosition;
        Clay_Dimensions scrollContainerDimensions;
        Clay_Dimensions contentDimensions;
        Clay_ClipElementConfig config;
        bool found;
    } Clay_ScrollContainerData;

    typedef struct Clay_ElementData {
        Clay_BoundingBox boundingBox;
        bool found;
    } Clay_ElementData;

    // =========================================================================
    // ARRAY TYPE DEFINITIONS
    // =========================================================================
    // Clay defines these via macros. In Lua FFI we must write them out.

    typedef struct { int32_t capacity; int32_t length; bool *internalArray; } Clay__boolArray;
    typedef struct { int32_t capacity; int32_t length; int32_t *internalArray; } Clay__int32_tArray;
    typedef struct { int32_t capacity; int32_t length; char *internalArray; } Clay__charArray;
    
    typedef struct { int32_t capacity; int32_t length; Clay_ElementId *internalArray; } Clay_ElementIdArray;
    
    typedef struct { int32_t capacity; int32_t length; Clay_LayoutConfig *internalArray; } Clay__LayoutConfigArray;
    typedef struct { int32_t capacity; int32_t length; Clay_ElementConfig *internalArray; } Clay__ElementConfigArray;
    
    typedef struct { int32_t capacity; int32_t length; Clay_AspectRatioElementConfig *internalArray; } Clay__AspectRatioElementConfigArray;
    typedef struct { int32_t capacity; int32_t length; Clay_TextElementConfig *internalArray; } Clay__TextElementConfigArray;
    typedef struct { int32_t capacity; int32_t length; Clay_ImageElementConfig *internalArray; } Clay__ImageElementConfigArray;
    typedef struct { int32_t capacity; int32_t length; Clay_FloatingElementConfig *internalArray; } Clay__FloatingElementConfigArray;
    typedef struct { int32_t capacity; int32_t length; Clay_CustomElementConfig *internalArray; } Clay__CustomElementConfigArray;
    typedef struct { int32_t capacity; int32_t length; Clay_ClipElementConfig *internalArray; } Clay__ClipElementConfigArray;
    typedef struct { int32_t capacity; int32_t length; Clay_BorderElementConfig *internalArray; } Clay__BorderElementConfigArray;
    typedef struct { int32_t capacity; int32_t length; Clay_SharedElementConfig *internalArray; } Clay__SharedElementConfigArray;

    typedef struct { int32_t capacity; int32_t length; Clay_String *internalArray; } Clay__StringArray;
    typedef struct { int32_t capacity; int32_t length; Clay__WrappedTextLine *internalArray; } Clay__WrappedTextLineArray;
    typedef struct { int32_t capacity; int32_t length; Clay__TextElementData *internalArray; } Clay__TextElementDataArray;

    typedef struct { int32_t capacity; int32_t length; Clay_LayoutElement *internalArray; } Clay_LayoutElementArray;
    typedef struct { int32_t capacity; int32_t length; Clay_RenderCommand *internalArray; } Clay_RenderCommandArray;

    typedef struct { int32_t capacity; int32_t length; Clay__ScrollContainerDataInternal *internalArray; } Clay__ScrollContainerDataInternalArray;
    typedef struct { int32_t capacity; int32_t length; Clay__DebugElementData *internalArray; } Clay__DebugElementDataArray;
    typedef struct { int32_t capacity; int32_t length; Clay_LayoutElementHashMapItem *internalArray; } Clay__LayoutElementHashMapItemArray;
    typedef struct { int32_t capacity; int32_t length; Clay__MeasureTextCacheItem *internalArray; } Clay__MeasureTextCacheItemArray;
    typedef struct { int32_t capacity; int32_t length; Clay__MeasuredWord *internalArray; } Clay__MeasuredWordArray;
    typedef struct { int32_t capacity; int32_t length; Clay__LayoutElementTreeNode *internalArray; } Clay__LayoutElementTreeNodeArray;
    typedef struct { int32_t capacity; int32_t length; Clay__LayoutElementTreeRoot *internalArray; } Clay__LayoutElementTreeRootArray;
    typedef struct { int32_t capacity; int32_t length; Clay__Warning *internalArray; } Clay__WarningArray;

    // =========================================================================
    // CONTEXT (The Memory Blob)
    // =========================================================================
    typedef struct Clay_Context {
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

        // Layout Elements / Render Commands
        Clay_LayoutElementArray layoutElements;
        Clay_RenderCommandArray renderCommands;
        Clay__int32_tArray openLayoutElementStack;
        Clay__int32_tArray layoutElementChildren;
        Clay__int32_tArray layoutElementChildrenBuffer;
        Clay__TextElementDataArray textElementData;
        Clay__int32_tArray aspectRatioElementIndexes;
        Clay__int32_tArray reusableElementIndexBuffer;
        Clay__int32_tArray layoutElementClipElementIds;

        // Configs
        Clay__LayoutConfigArray layoutConfigs;
        Clay__ElementConfigArray elementConfigs;
        Clay__TextElementConfigArray textElementConfigs;
        Clay__AspectRatioElementConfigArray aspectRatioElementConfigs;
        Clay__ImageElementConfigArray imageElementConfigs;
        Clay__FloatingElementConfigArray floatingElementConfigs;
        Clay__ClipElementConfigArray clipElementConfigs;
        Clay__CustomElementConfigArray customElementConfigs;
        Clay__BorderElementConfigArray borderElementConfigs;
        Clay__SharedElementConfigArray sharedElementConfigs;

        // Misc Data Structures
        Clay__StringArray layoutElementIdStrings;
        Clay__WrappedTextLineArray wrappedTextLines;
        Clay__LayoutElementTreeNodeArray layoutElementTreeNodeArray1;
        Clay__LayoutElementTreeRootArray layoutElementTreeRoots;

        // Hash Maps & Caches
        Clay__LayoutElementHashMapItemArray layoutElementsHashMapInternal;
        Clay__int32_tArray layoutElementsHashMap;
        Clay__MeasureTextCacheItemArray measureTextHashMapInternal;
        Clay__int32_tArray measureTextHashMapInternalFreeList;
        Clay__int32_tArray measureTextHashMap;
        Clay__MeasuredWordArray measuredWords;
        Clay__int32_tArray measuredWordsFreeList;

        Clay__int32_tArray openClipElementStack;
        Clay_ElementIdArray pointerOverIds;
        Clay__ScrollContainerDataInternalArray scrollContainerDatas;
        Clay__boolArray treeNodeVisited;
        Clay__charArray dynamicStringData;
        Clay__DebugElementDataArray debugElementData;
    } Clay_Context;
]])
    end)
    package.loaded["clay_ffi_loaded"] = true
end

return {}
