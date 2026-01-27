local ffi = require("ffi")

print("Loading clay_ffi for type definitions...")
require("src.clay_ffi")

print("Loading libclay_ref.so...")
local clay_c = ffi.load("./tests/clay_ref/libclay_ref.so")

ffi.cdef[[
    typedef Clay_Dimensions (*Clay_MeasureTextFunction)(
        Clay_StringSlice text,
        Clay_TextElementConfig *config,
        void *userData
    );

    uint32_t Clay_MinMemorySize(void);
    Clay_Context* Clay_Initialize(Clay_Arena arena, Clay_Dimensions layoutDimensions, Clay_ErrorHandler errorHandler);
    void Clay_SetCurrentContext(Clay_Context* context);
    void Clay_BeginLayout(void);
    Clay_RenderCommandArray Clay_EndLayout(void);
    void Clay_SetLayoutDimensions(Clay_Dimensions dimensions);
    void Clay_SetMeasureTextFunction(Clay_MeasureTextFunction measureTextFunction, void *userData);
    void Clay_SetMaxElementCount(int32_t maxElementCount);
    void Clay_SetMaxMeasureTextCacheWordCount(int32_t maxMeasureTextCacheWordCount);

    void Clay__OpenElement(void);
    void Clay__ConfigureOpenElementPtr(const Clay_ElementDeclaration *config);
    void Clay__CloseElement(void);

    Clay_ElementId Clay_GetElementId(Clay_String idString);
]]

-- Create a measure text function that will become a C callback
local measure_text_callback
measure_text_callback = function(textSlice, config, userData)
    -- Simple mock: 10px per char, 20px height
    return ffi.new("Clay_Dimensions", {
        width = tonumber(textSlice.length) * 10,
        height = 20
    })
end

-- Create the callback once - this is now permanent
local c_measure_callback = ffi.cast("Clay_MeasureTextFunction", measure_text_callback)

return clay_c, c_measure_callback
