#define CLAY_IMPLEMENTATION
#include "../../clay/clay.h"
#include <stdio.h>
#include <stdlib.h>

static Clay_Dimensions measure_text(Clay_StringSlice text, Clay_TextElementConfig *config, void *userData) {
    (void)config;
    (void)userData;
    return (Clay_Dimensions){
        .width = (float)text.length * 10,
        .height = 20
    };
}

void golden_simple_row() {
    FILE *f = fopen("golden_simple_row.txt", "w");
    if (!f) return;
    
    Clay_BeginLayout();
    
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
}

void golden_nested_containers() {
    FILE *f = fopen("golden_nested_containers.txt", "w");
    if (!f) return;
    
    Clay_BeginLayout();
    
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
}

void golden_alignment_center() {
    FILE *f = fopen("golden_alignment_center.txt", "w");
    if (!f) return;
    
    Clay_BeginLayout();
    
    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
    root.layout.childAlignment.x = CLAY_ALIGN_X_CENTER;
    root.layout.childAlignment.y = CLAY_ALIGN_Y_CENTER;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};
    
    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);
    
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
}

void golden_sizing_modes() {
    FILE *f = fopen("golden_sizing_modes.txt", "w");
    if (!f) return;

    Clay_BeginLayout();

    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
    root.layout.padding.left = 0;
    root.layout.padding.right = 0;
    root.layout.padding.top = 0;
    root.layout.padding.bottom = 0;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};

    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);

        Clay_ElementDeclaration child1 = CLAY__DEFAULT_STRUCT;
        child1.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child1.layout.sizing.width.size.minMax.min = 100;
        child1.layout.sizing.width.size.minMax.max = 100;
        child1.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child1.layout.sizing.height.size.minMax.min = 100;
        child1.layout.sizing.height.size.minMax.max = 100;
        child1.backgroundColor = (Clay_Color){255, 0, 0, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child1);
        Clay__CloseElement();

        Clay_ElementDeclaration child2 = CLAY__DEFAULT_STRUCT;
        child2.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
        child2.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
        child2.backgroundColor = (Clay_Color){0, 255, 0, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child2);
        Clay__CloseElement();

        Clay_ElementDeclaration child3 = CLAY__DEFAULT_STRUCT;
        child3.layout.sizing.width.type = CLAY__SIZING_TYPE_PERCENT;
        child3.layout.sizing.width.size.percent = 0.5f;
        child3.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child3.layout.sizing.height.size.minMax.min = 100;
        child3.layout.sizing.height.size.minMax.max = 100;
        child3.backgroundColor = (Clay_Color){0, 0, 255, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child3);
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
}

void golden_child_gap() {
    FILE *f = fopen("golden_child_gap.txt", "w");
    if (!f) return;

    Clay_BeginLayout();

    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
    root.layout.padding.left = 0;
    root.layout.padding.right = 0;
    root.layout.padding.top = 0;
    root.layout.padding.bottom = 0;
    root.layout.childGap = 20;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};

    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);

        Clay_ElementDeclaration child1 = CLAY__DEFAULT_STRUCT;
        child1.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child1.layout.sizing.width.size.minMax.min = 100;
        child1.layout.sizing.width.size.minMax.max = 100;
        child1.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child1.layout.sizing.height.size.minMax.min = 100;
        child1.layout.sizing.height.size.minMax.max = 100;
        child1.backgroundColor = (Clay_Color){255, 0, 0, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child1);
        Clay__CloseElement();

        Clay_ElementDeclaration child2 = CLAY__DEFAULT_STRUCT;
        child2.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child2.layout.sizing.width.size.minMax.min = 150;
        child2.layout.sizing.width.size.minMax.max = 150;
        child2.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child2.layout.sizing.height.size.minMax.min = 100;
        child2.layout.sizing.height.size.minMax.max = 100;
        child2.backgroundColor = (Clay_Color){0, 255, 0, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child2);
        Clay__CloseElement();

        Clay_ElementDeclaration child3 = CLAY__DEFAULT_STRUCT;
        child3.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child3.layout.sizing.width.size.minMax.min = 200;
        child3.layout.sizing.width.size.minMax.max = 200;
        child3.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child3.layout.sizing.height.size.minMax.min = 100;
        child3.layout.sizing.height.size.minMax.max = 100;
        child3.backgroundColor = (Clay_Color){0, 0, 255, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child3);
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
}

void golden_corners_borders() {
    FILE *f = fopen("golden_corners_borders.txt", "w");
    if (!f) return;

    Clay_BeginLayout();

    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
    root.layout.padding.left = 50;
    root.layout.padding.right = 50;
    root.layout.padding.top = 50;
    root.layout.padding.bottom = 50;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};

    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);

        Clay_ElementDeclaration child = CLAY__DEFAULT_STRUCT;
        child.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        child.layout.sizing.width.size.minMax.min = 200;
        child.layout.sizing.width.size.minMax.max = 200;
        child.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        child.layout.sizing.height.size.minMax.min = 150;
        child.layout.sizing.height.size.minMax.max = 150;
        child.backgroundColor = (Clay_Color){255, 0, 0, 255};
        child.cornerRadius.topLeft = 20;
        child.cornerRadius.topRight = 20;
        child.cornerRadius.bottomLeft = 20;
        child.cornerRadius.bottomRight = 20;
        child.border.width.left = 5;
        child.border.width.right = 5;
        child.border.width.top = 5;
        child.border.width.bottom = 5;
        child.border.color = (Clay_Color){0, 0, 0, 255};

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
}

int main() {
    size_t arenaSize = 1024 * 1024 * 16;
    char *arenaMemory = malloc(arenaSize);
    Clay_Arena arena = {
        .capacity = arenaSize,
        .memory = arenaMemory
    };
    
    Clay_Dimensions dimensions = {.width = 800, .height = 600};
    Clay_Context *context = Clay_Initialize(arena, dimensions, (Clay_ErrorHandler){0});
    
    if (context == NULL) {
        fprintf(stderr, "ERROR: Clay_Initialize returned NULL\n");
        return 1;
    }
    
    Clay_SetMeasureTextFunction(measure_text, NULL);
    
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_simple_row();
    
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_nested_containers();
    
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_alignment_center();

    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_sizing_modes();

    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_child_gap();

    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;
    
    golden_corners_borders();
    
    free(arenaMemory);
    return 0;
}
