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

void golden_sizing_modes() {
    FILE *f = fopen("golden_sizing_modes.txt", "w");
    if (!f) return;

    Clay_BeginLayout();

    // Root - LEFT_TO_RIGHT
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

        // Fixed: 100x100
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

        // GROW: grows to fill remaining space
        Clay_ElementDeclaration child2 = CLAY__DEFAULT_STRUCT;
        child2.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
        child2.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
        child2.backgroundColor = (Clay_Color){0, 255, 0, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&child2);
        Clay__CloseElement();

        // PERCENT: 50% width
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
    printf("Created golden_sizing_modes.txt\n");
}

void golden_child_gap() {
    FILE *f = fopen("golden_child_gap.txt", "w");
    if (!f) return;

    Clay_BeginLayout();

    // Root with childGap
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

        // Child 1: 100x100
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

        // Child 2: 150x100
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

        // Child 3: 200x100
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
    printf("Created golden_child_gap.txt\n");
}

void golden_corners_borders() {
    FILE *f = fopen("golden_corners_borders.txt", "w");
    if (!f) return;

    Clay_BeginLayout();

    // Root
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

        // Rectangle with rounded corners
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
    printf("Created golden_corners_borders.txt\n");
}

void golden_text_plain() {
    FILE *f = fopen("golden_text_plain.txt", "w");
    if (!f) return;

    Clay_BeginLayout();

    // Root
    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_TOP_TO_BOTTOM;
    root.layout.padding.left = 10;
    root.layout.padding.right = 10;
    root.layout.padding.top = 10;
    root.layout.padding.bottom = 10;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};

    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);

        // Text element
        Clay_TextElementConfig textConfig = {0};
        textConfig.textColor = (Clay_Color){0, 0, 0, 255};
        textConfig.fontId = 0;
        textConfig.fontSize = 16;
        textConfig.lineHeight = 20;

        Clay_String text = (Clay_String){true, 11, "Hello World"};

        Clay__OpenTextElement(text, &textConfig);
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
    printf("Created golden_text_plain.txt\n");
}

void golden_multiple_children() {
    FILE *f = fopen("golden_multiple_children.txt", "w");
    if (!f) return;

    Clay_BeginLayout();

    // Root with many children
    Clay_ElementDeclaration root = CLAY__DEFAULT_STRUCT;
    root.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
    root.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
    root.layout.layoutDirection = CLAY_TOP_TO_BOTTOM;
    root.layout.padding.left = 0;
    root.layout.padding.right = 0;
    root.layout.padding.top = 0;
    root.layout.padding.bottom = 0;
    root.layout.childGap = 5;
    root.backgroundColor = (Clay_Color){255, 255, 255, 255};

    Clay__OpenElement();
    Clay__ConfigureOpenElementPtr(&root);

        // Row 1: 3 items
        Clay_ElementDeclaration row1 = CLAY__DEFAULT_STRUCT;
        row1.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
        row1.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        row1.layout.sizing.height.size.minMax.min = 50;
        row1.layout.sizing.height.size.minMax.max = 50;
        row1.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
        row1.layout.childGap = 5;
        row1.backgroundColor = (Clay_Color){240, 240, 240, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&row1);

            Clay_ElementDeclaration item1 = CLAY__DEFAULT_STRUCT;
            item1.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
            item1.layout.sizing.width.size.minMax.min = 80;
            item1.layout.sizing.width.size.minMax.max = 80;
            item1.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
            item1.backgroundColor = (Clay_Color){255, 0, 0, 255};
            Clay__OpenElement();
            Clay__ConfigureOpenElementPtr(&item1);
            Clay__CloseElement();

            Clay_ElementDeclaration item2 = CLAY__DEFAULT_STRUCT;
            item2.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
            item2.layout.sizing.width.size.minMax.min = 80;
            item2.layout.sizing.width.size.minMax.max = 80;
            item2.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
            item2.backgroundColor = (Clay_Color){0, 255, 0, 255};
            Clay__OpenElement();
            Clay__ConfigureOpenElementPtr(&item2);
            Clay__CloseElement();

            Clay_ElementDeclaration item3 = CLAY__DEFAULT_STRUCT;
            item3.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
            item3.layout.sizing.width.size.minMax.min = 80;
            item3.layout.sizing.width.size.minMax.max = 80;
            item3.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
            item3.backgroundColor = (Clay_Color){0, 0, 255, 255};
            Clay__OpenElement();
            Clay__ConfigureOpenElementPtr(&item3);
            Clay__CloseElement();

        Clay__CloseElement();

        // Row 2: 2 items
        Clay_ElementDeclaration row2 = CLAY__DEFAULT_STRUCT;
        row2.layout.sizing.width.type = CLAY__SIZING_TYPE_GROW;
        row2.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        row2.layout.sizing.height.size.minMax.min = 50;
        row2.layout.sizing.height.size.minMax.max = 50;
        row2.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
        row2.layout.childGap = 5;
        row2.backgroundColor = (Clay_Color){240, 240, 240, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&row2);

            Clay_ElementDeclaration item4 = CLAY__DEFAULT_STRUCT;
            item4.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
            item4.layout.sizing.width.size.minMax.min = 120;
            item4.layout.sizing.width.size.minMax.max = 120;
            item4.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
            item4.backgroundColor = (Clay_Color){255, 255, 0, 255};
            Clay__OpenElement();
            Clay__ConfigureOpenElementPtr(&item4);
            Clay__CloseElement();

            Clay_ElementDeclaration item5 = CLAY__DEFAULT_STRUCT;
            item5.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
            item5.layout.sizing.width.size.minMax.min = 120;
            item5.layout.sizing.width.size.minMax.max = 120;
            item5.layout.sizing.height.type = CLAY__SIZING_TYPE_GROW;
            item5.backgroundColor = (Clay_Color){255, 0, 255, 255};
            Clay__OpenElement();
            Clay__ConfigureOpenElementPtr(&item5);
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
    printf("Created golden_multiple_children.txt\n");
}

void golden_deep_nesting() {
    FILE *f = fopen("golden_deep_nesting.txt", "w");
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

        // Level 1
        Clay_ElementDeclaration l1 = CLAY__DEFAULT_STRUCT;
        l1.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
        l1.layout.sizing.width.size.minMax.min = 300;
        l1.layout.sizing.width.size.minMax.max = 300;
        l1.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
        l1.layout.sizing.height.size.minMax.min = 300;
        l1.layout.sizing.height.size.minMax.max = 300;
        l1.layout.padding.left = 20;
        l1.layout.padding.right = 20;
        l1.layout.padding.top = 20;
        l1.layout.padding.bottom = 20;
        l1.backgroundColor = (Clay_Color){255, 0, 0, 255};

        Clay__OpenElement();
        Clay__ConfigureOpenElementPtr(&l1);

            // Level 2
            Clay_ElementDeclaration l2 = CLAY__DEFAULT_STRUCT;
            l2.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
            l2.layout.sizing.width.size.minMax.min = 200;
            l2.layout.sizing.width.size.minMax.max = 200;
            l2.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
            l2.layout.sizing.height.size.minMax.min = 200;
            l2.layout.sizing.height.size.minMax.max = 200;
            l2.layout.padding.left = 15;
            l2.layout.padding.right = 15;
            l2.layout.padding.top = 15;
            l2.layout.padding.bottom = 15;
            l2.backgroundColor = (Clay_Color){0, 255, 0, 255};

            Clay__OpenElement();
            Clay__ConfigureOpenElementPtr(&l2);

                // Level 3
                Clay_ElementDeclaration l3 = CLAY__DEFAULT_STRUCT;
                l3.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
                l3.layout.sizing.width.size.minMax.min = 100;
                l3.layout.sizing.width.size.minMax.max = 100;
                l3.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
                l3.layout.sizing.height.size.minMax.min = 100;
                l3.layout.sizing.height.size.minMax.max = 100;
                l3.layout.padding.left = 10;
                l3.layout.padding.right = 10;
                l3.layout.padding.top = 10;
                l3.layout.padding.bottom = 10;
                l3.backgroundColor = (Clay_Color){0, 0, 255, 255};

                Clay__OpenElement();
                Clay__ConfigureOpenElementPtr(&l3);

                    // Level 4 - final
                    Clay_ElementDeclaration l4 = CLAY__DEFAULT_STRUCT;
                    l4.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
                    l4.layout.sizing.width.size.minMax.min = 50;
                    l4.layout.sizing.width.size.minMax.max = 50;
                    l4.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
                    l4.layout.sizing.height.size.minMax.min = 50;
                    l4.layout.sizing.height.size.minMax.max = 50;
                    l4.backgroundColor = (Clay_Color){255, 255, 0, 255};

                    Clay__OpenElement();
                    Clay__ConfigureOpenElementPtr(&l4);
                    Clay__CloseElement();

                Clay__CloseElement();

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
    printf("Created golden_deep_nesting.txt\n");
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

    // Reset for next test
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;

    golden_sizing_modes();

    // Reset for next test
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;

    golden_child_gap();

    // Reset for next test
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;

    golden_corners_borders();

    // Reset for next test
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;

    golden_text_plain();

    // Reset for next test
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;

    golden_multiple_children();

    // Reset for next test
    arena.nextAllocation = sizeof(Clay_Context);
    context->generation++;

    golden_deep_nesting();

    printf("All golden files generated successfully!\n");
    
    free(arenaMemory);
    return 0;
}
