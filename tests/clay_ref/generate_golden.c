#define CLAY_IMPLEMENTATION
#include "../../clay/clay.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Simple measure text function - matches Lua mock
static Clay_Dimensions measure_text(Clay_StringSlice text, Clay_TextElementConfig *config, void *userData) {
    return (Clay_Dimensions){
        .width = (float)text.length * 10,
        .height = 20
    };
}

void golden_simple_row() {
    FILE *f = fopen("golden_simple_row.txt", "w");
    if (!f) return;
    
    Clay_BeginLayout();
    
    // Root container
    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
    root.layout.padding.left = 0;
    root.layout.padding.right = 0;
    root.layout.padding.top = 0;
    root.layout.padding.bottom = 0;
    root.layout.childGap = 0;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};
    
    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);
    
        // Child 1: 100x50, red
        Clay_ElementDeclaration child1 = CLAY__DEFAULT_STRUCT;
        child1.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child1.layout.sizing.width.size.minMax.min = 100;
        child1.layout.sizing.width.size.minMax.max = 100;
        child1.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child1.layout.sizing.height.size.minMax.min = 50;
        child1.layout.sizing.height.size.minMax.max = 50;
        child1.backgroundColor = (Clay_Color){255, 0, 0, 255};
        
        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child1);
        Clay__CloseElement();
        
        // Child 2: 200x50, green
        Clay_ElementDeclaration child2 = CLAY__DEFAULT_STRUCT;
        child2.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child2.layout.sizing.width.size.minMax.min = 200;
        child2.layout.sizing.width.size.minMax.max = 200;
        child2.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child2.layout.sizing.height.size.minMax.min = 50;
        child2.layout.sizing.height.size.minMax.max = 50;
        child2.backgroundColor = (Clay_Color){0, 255, 0, 255};
        
        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child2);
        Clay__CloseElement();
    
    Clay__CloseElement();
    
    Clay_RenderCommandArray commands = Clay_EndLayout();
    
    fprintf(f, "commands_count=%d\n", commands.length);
    for (int i = 0; i < commands.length; i++) {
        Clay_RenderCommand cmd = commands.internalArray[i];
        fprintf(f, "cmd[%d]: id=%u type=%d bbox={x=%f,y=%f,w=%f,h=%f}\n",
            i, cmd.id, cmd.commandType,
            cmd.boundingBox.x, cmd.boundingBox.y,
            cmd.boundingBox.width, cmd.boundingBox.height);
    }
    
    fclose(f);
    printf("Created golden_simple_row.txt\n");
}

void golden_nested_containers() {
    FILE *f = fopen("golden_nested_containers.txt", "w");
    if (!f) return;
    
    Clay_BeginLayout();
    
    // Root
    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_TOP_TO_BOTTOM;
    root.layout.padding.left = 0;
    root.layout.padding.right = 0;
    root.layout.padding.top = 0;
    root.layout.padding.bottom = 0;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};
    
    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);
    
        // Child with padding
        Clay_ElementDeclaration child = CLAY__DEFAULT_STRUCT;
        child.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child.layout.sizing.width.size.minMax.min = 100;
        child.layout.sizing.width.size.minMax.max = 100;
        child.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child.layout.sizing.height.size.minMax.min = 100;
        child.layout.sizing.height.size.minMax.max = 100;
        child.layout.padding.left = 10;
        child.layout.padding.right = 10;
        child.layout.padding.top = 10;
        child.layout.padding.bottom = 10;
        child.backgroundColor = (Clay_Color){255, 0, 0, 255};
        
        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child);
        
            // Grandchild
            Clay_ElementDeclaration grandchild = CLAY__DEFAULT_STRUCT;
            grandchild.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
            grandchild.layout.sizing.width.size.minMax.min = 50;
            grandchild.layout.sizing.width.size.minMax.max = 50;
            grandchild.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
            grandchild.layout.sizing.height.size.minMax.min = 50;
            grandchild.layout.sizing.height.size.minMax.max = 50;
            grandchild.backgroundColor = (Clay_Color){0, 255, 0, 255};
            
            Clay__OpenElement();
            Clay__ConfigureOpenElementPtr(&grandchild);
            Clay__CloseElement();
        
        Clay__CloseElement();
    
    Clay__CloseElement();
    
    Clay_RenderCommandArray commands = Clay_EndLayout();
    
    fprintf(f, "commands_count=%d\n", commands.length);
    for (int i = 0; i < commands.length; i++) {
        Clay_RenderCommand cmd = commands.internalArray[i];
        fprintf(f, "cmd[%d]: id=%u type=%d bbox={x=%f,y=%f,w=%f,h=%f}\n",
            i, cmd.id, cmd.commandType,
            cmd.boundingBox.x, cmd.boundingBox.y,
            cmd.boundingBox.width, cmd.boundingBox.height);
    }
    
    fclose(f);
    printf("Created golden_nested_containers.txt\n");
}

void golden_alignment_center() {
    FILE *f = fopen("golden_alignment_center.txt", "w");
    if (!f) return;
    
    Clay_BeginLayout();
    
    // Root with centered child
    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
    root.layout.childAlignment.x = CLAY_ALIGN_X_CENTER;
    root.layout.childAlignment.y = CLAY_ALIGN_Y_CENTER;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};
    
    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);
    
        // Child: 100x100, blue
        Clay_ElementDeclaration child = CLAY__DEFAULT_STRUCT;
        child.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child.layout.sizing.width.size.minMax.min = 100;
        child.layout.sizing.width.size.minMax.max = 100;
        child.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child.layout.sizing.height.size.minMax.min = 100;
        child.layout.sizing.height.size.minMax.max = 100;
        child.backgroundColor = (Clay_Color){0, 0, 255, 255};
        
        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child);
        Clay__CloseElement();
    
    Clay__CloseElement();
    
    Clay_RenderCommandArray commands = Clay_EndLayout();
    
    fprintf(f, "commands_count=%d\n", commands.length);
    for (int i = 0; i < commands.length; i++) {
        Clay_RenderCommand cmd = commands.internalArray[i];
        fprintf(f, "cmd[%d]: id=%u type=%d bbox={x=%f,y=%f,w=%f,h=%f}\n",
            i, cmd.id, cmd.commandType,
            cmd.boundingBox.x, cmd.boundingBox.y,
            cmd.boundingBox.width, cmd.boundingBox.height);
    }
    
    fclose(f);
    printf("Created golden_alignment_center.txt\n");
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
    
    // Set measure text
    Clay_SetMeasureTextFunction(measure_text, NULL);
    
    printf("Generating golden output files...\n");
    
    // Reset arena between tests
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_simple_row();
    
    // Reset for next test
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_nested_containers();
    
    // Reset for next test
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_alignment_center();
    
    printf("All golden files generated successfully!\n");
    
    free(arenaMemory);
    return 0;
}
