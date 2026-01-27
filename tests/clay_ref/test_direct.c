#include "../../clay/clay.h"
#include <stdio.h>

// Simple measure text function
Clay_Dimensions MeasureText(Clay_StringSlice text, Clay_TextElementConfig *config, void *userData) {
    Clay_Dimensions dimensions = {
        .width = (float)text.length * 10,
        .height = 20
    };
    return dimensions;
}

int main() {
    // Create arena
    size_t arenaSize = 1024 * 1024 * 16;
    char *arenaMemory = malloc(arenaSize);
    Clay_Arena arena = {
        .capacity = arenaSize,
        .memory = arenaMemory
    };
    
    // Initialize Clay
    Clay_Dimensions dimensions = {.width = 800, .height = 600};
    Clay_Context *context = Clay_Initialize(arena, dimensions, (Clay_ErrorHandler){0});
    
    if (context == NULL) {
        printf("ERROR: Clay_Initialize returned NULL\n");
        return 1;
    }
    
    printf("Clay initialized successfully\n");
    printf("Context pointer: %p\n", (void*)context);
    
    // Set measure text
    Clay_SetMeasureTextFunction(MeasureText, NULL);
    
    // Begin layout
    Clay_BeginLayout();
    
    // Add a simple element
    Clay_ElementDeclaration declaration = CLAY__DEFAULT_STRUCT;
    
    // Set sizing to GROW
    declaration.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    declaration.layout.sizing.width.size.minMax.min = 0;
    declaration.layout.sizing.width.size.minMax.max = 0;
    declaration.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    declaration.layout.sizing.height.size.minMax.min = 0;
    declaration.layout.sizing.height.size.minMax.max = 0;
    
    // Set background color
    declaration.backgroundColor = (Clay_Color){255, 255, 255, 255};
    
    // Open and configure element
    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&declaration);
    Clay__CloseElement();
    
    // End layout
    Clay_RenderCommandArray commands = Clay_EndLayout();
    
    printf("Render commands: %d\n", commands.length);
    
    for (int i = 0; i < commands.length; i++) {
        Clay_RenderCommand cmd = commands.internalArray[i];
        printf("  [%d] id=%u type=%d bbox={x=%f,y=%f,w=%f,h=%f}\n",
            i, cmd.id, cmd.commandType,
            cmd.boundingBox.x, cmd.boundingBox.y,
            cmd.boundingBox.width, cmd.boundingBox.height);
    }
    
    free(arenaMemory);
    return 0;
}
