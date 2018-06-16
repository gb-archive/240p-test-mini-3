#ifndef GLOBAL_H
#define GLOBAL_H
#include <stdint.h>
#include <sys/types.h>
#include <gba_sprites.h>
#include <gba_systemcalls.h>

// Size of a statically sized array
#define count(array) (sizeof((array)) / sizeof((array)[0]))

// help.c
#define HELP_LINE_LEN 48
extern char help_line_buffer[HELP_LINE_LEN];
extern unsigned char help_bg_loaded, help_wanted_page, help_cursor_y;
extern signed char help_wnd_progress;
unsigned int helpscreen(unsigned int doc_num, unsigned int keymask);
unsigned int read_pad_help_check(const void *doc_num_as_ptr);

// stills.c
void activity_linearity(void);

// pads.c
extern unsigned short cur_keys, new_keys, das_keys, das_timer;
unsigned int read_pad(void);
unsigned int autorepeat(unsigned int allowed_keys);

// placeholder.c
void lame_boy_demo(void);

// ppuclear.c
typedef unsigned short VBTILE[16];
extern unsigned char oam_used;
extern OBJATTR SOAM[128];
void ppu_clear_oam(size_t start);
void ppu_copy_oam(void);
void dma_memset16(void *s, unsigned int c, size_t n);

// vwfdraw.c
void loadMapRowMajor(unsigned short *dst, unsigned int tilenum,
                     unsigned int width, unsigned int height);
void vwf8PutTile(uint32_t *dst, unsigned int glyphnum,
                 unsigned int x, unsigned int color);
const char *vwf8Puts(uint32_t *restrict dst, const char *restrict s,
                     unsigned int x, unsigned int color);
unsigned int vwf8StrWidth(const char *s);

#endif