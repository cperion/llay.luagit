-- SDL3_ttf FFI bindings
-- Based on SDL_ttf 3.3.0 API from official repository

local ffi = require("ffi")

-- Load SDL3 types first (SDL_Color, SDL_Surface, etc.)
require("sdl3_ffi")

ffi.cdef([[
    // SDL3_ttf types
    typedef struct TTF_Font TTF_Font;
    typedef struct TTF_Text TTF_Text;
    
    // SDL3_ttf functions
    bool TTF_Init(void);
    void TTF_Quit(void);
    
    // Font loading
    TTF_Font* TTF_OpenFont(const char *file, float ptsize);
    void TTF_CloseFont(TTF_Font *font);
    
    // Font properties
    bool TTF_SetFontSize(TTF_Font *font, float ptsize);
    int TTF_GetFontHeight(TTF_Font *font);
    int TTF_GetFontSize(TTF_Font *font);
    
    // Text rendering (SDL3_ttf API)
    // Note: SDL_Surface and SDL_Color are already defined in sdl3_ffi
    SDL_Surface* TTF_RenderText_Solid(TTF_Font *font, const char *text, size_t length, SDL_Color fg);
    SDL_Surface* TTF_RenderText_Blended(TTF_Font *font, const char *text, size_t length, SDL_Color fg);
    
    // Text measurement (SDL3_ttf API uses TTF_GetStringSize, not TTF_GetTextSize)
    bool TTF_GetStringSize(TTF_Font *font, const char *text, size_t length, int *w, int *h);
]])

local lib = ffi.load("SDL3_ttf")

return {
	init = lib.TTF_Init,
	quit = lib.TTF_Quit,
	openFont = lib.TTF_OpenFont,
	closeFont = lib.TTF_CloseFont,
	setFontSize = lib.TTF_SetFontSize,
	getFontHeight = lib.TTF_GetFontHeight,
	getFontSize = lib.TTF_GetFontSize,
	renderTextSolid = lib.TTF_RenderText_Solid,
	renderTextBlended = lib.TTF_RenderText_Blended,
	getStringSize = lib.TTF_GetStringSize, -- Correct SDL3 function name
}
