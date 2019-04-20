;
; Help screen for 240p test suite
; Copyright 2015-2017 Damian Yerrick
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
;

.include "nes.inc"
.include "global.inc"
.include "rectfill.inc"
.importzp helpsect_linearity, helpsect_sharpness, helpsect_ire
.importzp helpsect_smpte_color_bars, helpsect_color_bars_on_gray
.importzp helpsect_pluge, helpsect_grid, helpsect_gradient_color_bars
.importzp helpsect_gray_ramp, helpsect_color_bleed
.importzp helpsect_full_screen_stripes, helpsect_solid_color_screen
.importzp helpsect_chroma_crosstalk

; sb53-based stills ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.rodata
; To allow set-and-forget palette management, sharpness bricks do not
; share color 0 with the main pattern.  This means they use
; colors 5, 6, 7, not 0, 1, 2.
bricks_tile:
  .byte %11000000
  .byte %00110000
  .byte %00001100
  .byte %10000111
  .byte %11100011
  .byte %00110111
  .byte %00001111
  .byte %00000011

  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %01111011
  .byte %11011101
  .byte %11111001
  .byte %11111101
  .byte %11111111

.segment "BSS"
test_state: .res 24

.segment "CODE"

.proc do_sharpness
  lda #VBLANK_NMI
  sta test_state
  sta help_reload
  sta PPUCTRL
  asl a
  sta PPUMASK

  ; Load main nametable, plus main and bricks palettes
  ldx #$20
  lda #$00
  tay
  jsr ppu_clear_nt
  tax
  jsr ppu_clear_nt
  lda #2
  jsr load_iu53_file
  
  ; Load bricks tile
  ldx #$24
  lda #$FF
  ldy #$55
  jsr ppu_clear_nt
  lda #$0F
  sta PPUADDR
  lda #$F0
  sta PPUADDR
  ldx #$00
  brickloop1:
    lda bricks_tile,x
    sta PPUDATA
    inx
    cpx #16
    bcc brickloop1

loop:
  jsr ppu_wait_vblank
  lda test_state
  clc
  jsr ppu_screen_on_xy0

  lda #helpsect_sharpness
  jsr read_pads_helpcheck
  bcs do_sharpness
  lda new_keys
  and #KEY_A
  beq not_toggle_bricks
    lda #1
    eor test_state
    sta test_state
  not_toggle_bricks:
  lda new_keys
  and #KEY_B
  beq loop
  rts
.endproc

.proc do_crosstalk
palette_base = test_state + 0
  lda #VBLANK_NMI
  sta help_reload
  sta PPUCTRL
  asl a
  sta PPUMASK

  ; load bg
  tay
  tax
  jsr ppu_clear_nt
  ldx #$20
  jsr ppu_clear_nt
  lda #4
  jsr load_iu53_file
  lda #$16
  sta palette_base

loop:
  jsr ppu_wait_vblank
  lda #$3F
  sta PPUADDR
  lda #$01
  sta PPUADDR
  lda palette_base
  sta PPUDATA
  ldx #2
  palloop:
    clc
    adc #4
    cmp #$1D
    bcc :+
      sbc #$0C
    :
    sta PPUDATA
    dex
    bne palloop
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0
  
  lda #helpsect_chroma_crosstalk
  jsr read_pads_helpcheck
  bcs do_crosstalk

  lda nmis
  and #$0F
  bne noinccolor
    ldy palette_base
    iny
    cpy #$1D
    bcc :+
      ldy #$11
    :
    sty palette_base
  noinccolor:

  lda new_keys
  and #KEY_B
  beq loop
  rts
.endproc

; IRE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"

ire_rects:
  rf_rect   0,  0,256,240,$00, 0  ; Clear screen to black
  rf_rect  64, 64,192,176,$0C, 0  ; Color 3: inside
  rf_rect 160,192,224,200,$F8, RF_INCR  ; text area
  .byte $00
ire_attrs:
  rf_attr  0,  0,256, 240, 0
  .byte $00
.if 0
ire_texts:
  rf_label 112,112, 0, 3
  .byte "IRE LAND",0
  .byte $00
.endif

ire_msgs2:
  .byte ire_msg00-ire_msgbase,   ire_msg0D-ire_msgbase
  .byte ire_msg10-ire_msgbase,   ire_msg1D-ire_msgbase
  .byte ire_msg20-ire_msgbase,   ire_msg2D-ire_msgbase
  .byte ire_msg30-ire_msgbase,   ire_msg3D-ire_msgbase
  .byte ire_msg00em-ire_msgbase, ire_msg0Dem-ire_msgbase
  .byte ire_msg10em-ire_msgbase, ire_msg1Dem-ire_msgbase
  .byte ire_msg20em-ire_msgbase, ire_msg2Dem-ire_msgbase
  .byte ire_msg30em-ire_msgbase, ire_msg3Dem-ire_msgbase

; Using lidnariq's measurements from
; http://wiki.nesdev.com/w/index.php/NTSC_video#Terminated_measurement
ire_msgbase:
ire_msg00:   .byte "43",0
ire_msg10:   .byte "74",0
ire_msg20:
ire_msg30:   .byte "110",0
ire_msg0D:   .byte "-12",0
ire_msg1D:   .byte "0", 0
ire_msg2D:   .byte "34",0
ire_msg3D:   .byte "80",0
ire_msg00em: .byte "26",0
ire_msg10em: .byte "51",0
ire_msg20em:
ire_msg30em: .byte "82",0
ire_msg0Dem: .byte "-17",0
ire_msg1Dem: .byte "-8",0
ire_msg2Dem: .byte "19",0
ire_msg3Dem: .byte "56",0
ire_sepmsg:  .byte "on",0

irelevel_bg: .byte $0D,$1D,$1D,$1D,$1D, $1D,$1D,$00,$10,$20
irelevel_fg: .byte $1D,$1D,$2D,$00,$10, $3D,$20,$20,$20,$20
NUM_IRE_LEVELS = * - irelevel_fg

.segment "CODE"
ire_emph = test_state+3
.proc do_ire
ire_level = test_state+0
need_reload = test_state+1
disappear_time = test_state+2

  lda #6
  sta ire_level
  lda #0
  sta ire_emph
restart:
  jsr rf_load_tiles
  lda #$20
  sta need_reload
  sta rf_curnametable
  sta rf_tilenum
  lda #$00
  sta rf_curpattable
  ldy #<ire_rects
  lda #>ire_rects
  jsr rf_draw_rects_attrs_ay

loop:
  lda need_reload
  beq not_reloading
    sty $FF
    lda #0
    sta need_reload
    lda #120
    sta disappear_time
    jsr clearLineImg

    ; Draw foreground level
    ldx ire_level
    lda irelevel_fg,x
    jsr ire_get_msgbase
    jsr vwfStrWidth
    sec
    eor #$FF
    adc #24
    tax
    jsr vwfPuts0

    ; Draw background level
    lda #>ire_sepmsg
    ldy #<ire_sepmsg
    ldx #27
    jsr vwfPuts
    ldx ire_level
    lda irelevel_bg,x
    jsr ire_get_msgbase
    ldx #40
    jsr vwfPuts

    ; Prepare for blitting    
    lda #%0111
    jsr rf_color_lineImgBuf
    lda #$0F
    sta vram_copydsthi
    lda #$80
    sta vram_copydstlo
  not_reloading:

  jsr ppu_wait_vblank

  ; Update palette
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx ire_level
  ldy irelevel_bg,x
  sty PPUDATA
  lda disappear_time
  beq :+
    ldy #$02
  :
  sty PPUDATA
  beq :+
    ldy #$38
    dec disappear_time
  :
  sty PPUDATA
  ldy irelevel_fg,x
  sty PPUDATA

  ; Copy tiles if needed
  lda vram_copydsthi
  bmi :+
    jsr rf_copy8tiles
    lda #$80
    sta vram_copydsthi
  :
    
  ; And turn the display on
  ldx #0
  stx PPUSCROLL
  stx PPUSCROLL
  lda #VBLANK_NMI|BG_0000
  sta PPUCTRL
  lda #BG_ON
  ldx ire_emph
  beq :+
    ora #TINT_R|TINT_G|TINT_B
  :
  sta PPUMASK

  lda #helpsect_ire
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:

  lda new_keys+0
  and #KEY_A
  beq not_toggle_emph
    lda ire_emph
    eor #$01
    sta ire_emph
    inc need_reload
  not_toggle_emph:

  lda new_keys+0
  and #KEY_RIGHT|KEY_UP
  beq not_increase
  lda ire_level
  cmp #NUM_IRE_LEVELS - 1
  bcs not_increase
    inc ire_level
    inc need_reload
  not_increase:

  lda new_keys+0
  and #KEY_LEFT|KEY_DOWN
  beq not_decrease
  lda ire_level
  beq not_decrease
    dec ire_level
    inc need_reload
  not_decrease:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop

done:
  rts
.endproc

;;
; Given in A and an emphasis value in X, gets a pointer
; to its IRE value as text in A:Y.
.proc ire_get_msgbase
  lsr a
  lsr a
  lsr a
  ldx ire_emph
  beq :+
    ora #$08
  :
  tax
  clc
  lda ire_msgs2,x
  adc #<ire_msgbase
  tay
  lda #0
  adc #>ire_msgbase
  rts
.endproc

; SMPTE color bars ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.rodata
smpte_rects:
  rf_rect   0,  0, 32,160,$04, 0  ; bar 1
  rf_rect  32,  0, 40,160,$10, 0  ; bar 1-2
  rf_rect  40,  0, 72,160,$08, 0  ; bar 2 (allegedly not so yellow)
  rf_rect  72,  0, 80,160,$11, 0  ; bar 2-3
  rf_rect  80,  0,112,160,$0c, 0  ; bar 3
  rf_rect 112,  0,144,160,$04, 0  ; bar 4
  rf_rect 144,  0,176,160,$04, 0  ; bar 5
  rf_rect 176,  0,184,160,$10, 0  ; bar 5-6
  rf_rect 184,  0,216,160,$08, 0  ; bar 6
  rf_rect 216,  0,224,160,$11, 0  ; bar 6-7
  rf_rect 224,  0,256,160,$0c, 0  ; bar 7
  rf_rect   0,160,256,240,$00, 0  ; black
  rf_rect   0,160, 32,176,$0c, 0  ; bar 7
  rf_rect  32,160, 40,176,$18, 0  ; bar 7-
  rf_rect  72,160, 80,176,$19, 0  ; bar -5
  rf_rect  80,160,112,176,$04, 0  ; bar 5
  rf_rect 144,160,176,176,$0c, 0  ; bar 3
  rf_rect 176,160,184,176,$18, 0  ; bar 3-
  rf_rect 216,160,224,176,$19, 0  ; bar -1
  rf_rect 224,160,256,176,$04, 0  ; bar 1
  rf_rect   0,176, 48,240,$04, 0  ; i
  rf_rect  48,176, 96,240,$08, 0  ; white
  rf_rect  96,176,144,240,$0C, 0  ; q
  rf_rect 184,176,200,240,$08, 0  ; 0d
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr 112,  0,144,160, 3  ; green bar
  rf_attr 144,  0,256,160, 1  ; bars 5-7
  rf_attr   0,160,112,176, 1  ; bars 7-5
  rf_attr   0,176,144,240, 2  ; i, y, q
  rf_attr 160,176,256,240, 3  ; 0d
  .byte $00

cbgray_rects:
  rf_rect   0,  0,256,240,$04, 0  ; bar 1 and bg

  rf_rect  32, 48, 40, 96,$10, 0  ; bar 1-2
  rf_rect  40, 48, 72, 96,$08, 0  ; bar 2 (allegedly not so yellow)
  rf_rect  72, 48, 80, 96,$11, 0  ; bar 2-3
  rf_rect  80, 48,112, 96,$0c, 0  ; bar 3
  rf_rect 112, 48,144, 96,$04, 0  ; bar 4
  rf_rect 144, 48,176, 96,$04, 0  ; bar 5
  rf_rect 176, 48,184, 96,$10, 0  ; bar 5-6
  rf_rect 184, 48,216, 96,$08, 0  ; bar 6
  rf_rect 216, 48,224, 96,$11, 0  ; bar 6-7
  rf_rect 224, 48,256, 96,$0c, 0  ; bar 7
  rf_rect   0,144, 32,192,$0c, 0  ; bar 7
  rf_rect  32,144, 40,192,$12, 0  ; bar 7-6
  rf_rect  40,144, 72,192,$08, 0  ; bar 6
  rf_rect  72,144, 80,192,$13, 0  ; bar 6-5
  rf_rect  80,144,112,192,$04, 0  ; bar 5
  rf_rect 112,144,144,192,$04, 0  ; bar 4
  rf_rect 144,144,176,192,$0c, 0  ; bar 3
  rf_rect 176,144,184,192,$12, 0  ; bar 3-2
  rf_rect 184,144,216,192,$08, 0  ; bar 2
  rf_rect 216,144,224,192,$13, 0  ; bar 2-1
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr 112, 48,144, 96, 3  ; green bar
  rf_attr 144, 48,256, 96, 1  ; bars 5-7
  rf_attr   0,144,112,192, 1  ; bars 7-5
  rf_attr 112,144,144,192, 3  ; green bar
  .byte $00

smpte_types:
  .addr smpte_rects
  .byte helpsect_smpte_color_bars
  .addr cbgray_rects
  .byte helpsect_color_bars_on_gray
smpte_helpscreen = smpte_types+2

.segment "RODATA"

smpte_palettes:
  .byte $0f,$10,$28,$2c, $0f,$14,$16,$02, $0f,$01,$20,$04, $0f,$1a,$0d,$00
  .byte $0f,$20,$38,$2c, $0f,$14,$16,$12, $0f,$01,$20,$04, $0f,$2a,$0d,$00

tvSystemkHz: .byte 55, 51, 55

.segment "CODE"

.proc do_smpte
  ldx #0
  bpl do_bars
.endproc

.proc do_601bars
  ldx #3
  ; fall through
.endproc
.proc do_bars
smpte_level = test_state+0
smpte_type  = test_state+1

  lda #0
  sta smpte_level
  stx smpte_type
restart:
  jsr rf_load_tiles
  lda #$20
  sta rf_curnametable
  lda #$00
  sta rf_curpattable
:
  lda #1
  sta :-+1
  ldx smpte_type
  ldy smpte_types+0,x
  lda smpte_types+1,x
  jsr rf_draw_rects_attrs_ay

loop:
  jsr ppu_wait_vblank

  ; Update palette
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda smpte_level
  and #$10
  tax
  ldy #16
  :
    lda smpte_palettes,x
    sta PPUDATA
    inx
    dey
    bne :-

  ; And turn the display on
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0
  
  ; Update sound
  lda smpte_level
  and #$01
  beq :+
    lda #$88
  :
  sta $4008
  ldx tvSystem
  lda tvSystemkHz,x
  sta $400A
  lda #0
  sta $400B

  ldy smpte_type
  lda smpte_helpscreen,y
  jsr read_pads_helpcheck
  bcs restart

  lda new_keys+0
  and #KEY_A
  beq not_increase
    lda #16
    eor smpte_level
    sta smpte_level
  not_increase:

  lda new_keys+0
  and #KEY_SELECT
  beq not_beep
    lda #1
    eor smpte_level
    sta smpte_level
  not_beep:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop

done:
  lda #$00   ; Turn off triangle
  sta $4008
  sta $400B
  rts
.endproc

; PLUGE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"
pluge_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect  16, 48, 32,192,$0A, 0  ; lowest color above black
  rf_rect 224, 48,240,192,$0A, 0
  rf_rect  48, 48, 64,192,$04, 0  ; below black
  rf_rect 192, 48,208,192,$04, 0
  rf_rect  80, 48,176, 96,$0C, 0  ; gray boxes in center
  rf_rect  80, 96,176,144,$08, 0
  rf_rect  80,144,176,192,$04, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr  80, 48,176,192, 1
  .byte $00
pluge_palettes:
  .byte $0F,$0D,$04,$0A
  .byte $0F,$0D,$2D,$2D
pluge_shark_palettes:
  .byte $0F,$10,$02,$1C
  .byte $0F,$00,$0F,$0C
  .byte $10,$20,$32,$3C
  
.segment "CODE"
.proc do_pluge
palettechoice = test_state+0
emphasis = test_state+1
is_shark = test_state+2
  lda #0
  sta palettechoice
  sta is_shark
  lda #BG_ON
  sta emphasis

restart:
  ; Load initial palette
  lda #$3F
  sta PPUADDR
  ldx #$05
  stx PPUADDR
  lda #$00
  sta PPUDATA
  lda #$10
  sta PPUDATA
  asl a
  sta PPUDATA

  jsr rf_load_tiles
  ldx #$02
  ldy #$00
  lda #10
  jsr unpb53_file

  ; Draw PLUGE map on nametable 0
  lda #$20
  sta rf_curnametable
  lda #$00
  sta rf_curpattable
  ldy #<pluge_rects
  lda #>pluge_rects
  jsr rf_draw_rects_attrs_ay

  ; Draw shark map on nametable 1
  lda #$00
  tay
  ldx #$24
  jsr ppu_clear_nt
  ldx #$24
  stx PPUADDR
  lda #$00
  sta PPUADDR
  lda #$23  ; starting tile number
  ldy #30
  clc
  sharkrowloop:
    ldx #32
    sharktileloop:
      sta PPUDATA
      adc #4
      and #$2F
      dex
      bne sharktileloop
    adc #1
    and #$23
    dey
    bne sharkrowloop

loop:
  lda #helpsect_pluge
  jsr read_pads_helpcheck
  bcs restart

  lda new_keys+0
  and #KEY_DOWN
  beq not_toggle_emphasis
    lda #$E0
    eor emphasis
    sta emphasis
  not_toggle_emphasis:

  lda new_keys+0
  and #KEY_SELECT
  beq not_toggle_shark
    lda #1
    eor is_shark
    sta is_shark
    lda #0
    sta palettechoice
  not_toggle_shark:

  lda new_keys+0
  and #KEY_A
  beq not_next_palette
    inc palettechoice
    lda #2-1
    ldx is_shark
    beq :+
      lda #3-1
    :
    cmp palettechoice
    bcs not_next_palette
      lda #0
      sta palettechoice
  not_next_palette:

  jsr ppu_wait_vblank

  ; Update palette
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda is_shark
  asl a
  adc palettechoice
  asl a
  asl a
  tax
  ldy #4
  palloadloop:
    lda pluge_palettes,x
    sta PPUDATA
    inx
    dey
    bne palloadloop

  ; And turn the display on
  ; ppu_screen_on doesn't support emphasis
  sty PPUSCROLL
  sty PPUSCROLL
  lda #VBLANK_NMI|BG_0000
  ora is_shark
  sta PPUCTRL
  lda emphasis
  sta PPUMASK

  lda new_keys+0
  and #KEY_B
  bne :+
    jmp loop
  :
  rts
.endproc

; GRADIENT COLOR BARS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"

gcbars_grid:
  rf_rect   0,  0,256,240,$16, RF_ROWXOR|RF_COLXOR
gcbars_nogrid:
  rf_rect  80, 32,112, 64,$04, 0  ; red 0
  rf_rect 112, 32,144, 64,$08, 0  ; red 1
  rf_rect 144, 32,176, 64,$0C, 0  ; red 2
  rf_rect  80, 80,112,112,$04, 0  ; green 0
  rf_rect 112, 80,144,112,$08, 0  ; green 1
  rf_rect 144, 80,176,112,$0C, 0  ; green 2
  rf_rect  80,128,112,160,$04, 0  ; blue 0
  rf_rect 112,128,144,160,$08, 0  ; blue 1
  rf_rect 144,128,176,160,$0C, 0  ; blue 2
  rf_rect  80,176,112,208,$04, 0  ; white 0
  rf_rect 112,176,144,208,$08, 0  ; white 1
  rf_rect 144,176,208,208,$0C, 0  ; white 2-3
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr  80, 32,176, 64, 1  ; red
  rf_attr  80, 80,176,112, 2  ; green
  rf_attr  80,128,176,160, 3  ; blue
  .byte $00
  rf_label  80, 24, 3, 0
  .byte "0",0
  rf_label 112, 24, 3, 0
  .byte "1",0
  rf_label 144, 24, 3, 0
  .byte "2",0
  rf_label 176, 24, 3, 0
  .byte "3",0
  rf_label  48, 40, 3, 0
  .byte "Red",0
  rf_label  48, 88, 3, 0
  .byte "Green",0
  rf_label  48,136, 3, 0
  .byte "Blue",0
  rf_label  48,184, 3, 0
  .byte "White",0
  .byte $00

.segment "CODE"

.proc do_gcbars
  lda #VBLANK_NMI|BG_0000|OBJ_8X16
  sta test_state+0
restart:
  jsr rf_load_tiles
  jsr rf_load_yrgb_palette

  ; On $2400, draw a CPS-2 grid and no labels
  ldx #$24
  stx rf_curnametable
  ldy #<gcbars_grid
  lda #>gcbars_grid
  jsr rf_draw_rects_attrs_ay

  ldx #$20
  stx rf_curnametable
  stx rf_tilenum
  lda #$00
  sta rf_curpattable
  tay
  jsr ppu_clear_nt
  ldy #<gcbars_nogrid
  lda #>gcbars_nogrid
  jsr rf_draw_rects_attrs_ay
  inc ciSrc
  bne :+
    inc ciSrc+1
  :
  jsr rf_draw_labels

  ; Set up sprite pattable
  lda #$10
  sta PPUADDR
  ldy #$00
  sty PPUADDR
  dey
  ldx #32
  sprchrloop:
    sty PPUDATA
    dex
    bne sprchrloop
  
  ; The "pale" ($3x) colors are drawn as 24 sprites.

sprite_y = $00
sprite_attr = $02
sprite_x = $03
  lda #31
  sta sprite_y
  ldx #0
  sprboxloop:
    lda #176
    sprcolloop:
      sta sprite_x
      lda sprite_y
      sta OAM+0,x
      clc
      adc #16
      sta OAM+4,x
      lda #$01
      sta OAM+1,x
      sta OAM+5,x
      lda sprite_attr
      sta OAM+2,x
      sta OAM+6,x
      lda sprite_x
      sta OAM+3,x
      sta OAM+7,x
      txa
      clc
      adc #8
      tax
      lda sprite_x
      clc
      adc #8
      cmp #208
      bcc sprcolloop
    inc sprite_attr
    lda sprite_y
    adc #48-1  ; the carry adds an additional 1
    sta sprite_y
    cmp #160
    bcc sprboxloop

  ; And hide the rest of sprites      
  jsr ppu_clear_oam

loop:
  jsr ppu_wait_vblank
  lda test_state+0
  jsr ppu_oam_dma_screen_on_xy0

  lda #helpsect_gradient_color_bars
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:
  lda new_keys+0
  and #KEY_A
  beq not_toggle_screen
    lda #$01
    eor test_state+0
    sta test_state+0
  not_toggle_screen:

  lda new_keys+0
  and #KEY_B
  beq loop
  rts
.endproc

; CPS-2 STYLE GRID ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"
cpsgrid_224p_rects:
  rf_rect   0,  0,256,224,$16, RF_ROWXOR|RF_COLXOR
  rf_rect   0,224,256,240,$00, 0
  .byte $00
  rf_attr   0,  0,256,240, 1
  rf_attr  16, 16,240,208, 0
  .byte $00
cpsgrid_240p_rects:
  rf_rect   0,  0,256,240,$16, RF_ROWXOR|RF_COLXOR
  .byte $00
  rf_attr   0,  0,256,240, 1
  rf_attr  16, 16,240,224, 0
  .byte $00

.segment "CODE"
.proc do_cpsgrid
whichpage = test_state+0
bgcolor = test_state+1
  lda #VBLANK_NMI|BG_0000|OBJ_8X16
  sta whichpage
  lda #$0F
  sta bgcolor
restart:
  jsr rf_load_tiles
  jsr rf_load_yrgb_palette

  ; On $2400, draw a CPS-2 grid and no labels
  ldx #$20
  stx rf_curnametable
  ldy #<cpsgrid_224p_rects
  lda #>cpsgrid_224p_rects
  jsr rf_draw_rects_attrs_ay
  ldx #$24
  stx rf_curnametable
  ldy #<cpsgrid_240p_rects
  lda #>cpsgrid_240p_rects
  jsr rf_draw_rects_attrs_ay
  
loop:
  jsr ppu_wait_vblank
  
  lda #$3F
  ldx #$00
  sta PPUADDR
  stx PPUADDR
  lda bgcolor
  sta PPUDATA

  ldy #0
  lda whichpage
  lsr a
  bcs :+
    ldy #240-8
  :
  rol a  ; restores test_state bit 0 and clears carry
  jsr ppu_screen_on

  lda #helpsect_grid
  jsr read_pads_helpcheck
  bcs restart

  lda new_keys+0
  and #KEY_A
  beq not_toggle_screen
    lda #$01
    eor whichpage
    sta whichpage
  not_toggle_screen:

  lda new_keys+0
  and #KEY_SELECT
  beq not_toggle_gray
    lda #$0F
    eor bgcolor
    sta bgcolor
  not_toggle_gray:

  lda new_keys+0
  and #KEY_B
  beq loop
  rts
.endproc

; GRAY RAMP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"
gray_ramp_rects:
  rf_rect  32, 24, 48,120,$01, 0
  rf_rect  48, 24, 64,120,$02, 0
  rf_rect  64, 24, 80,120,$03, 0
  rf_rect  80, 24, 96,120,$04, 0
  rf_rect  96, 24,112,120,$05, 0
  rf_rect 112, 24,128,120,$06, 0
  rf_rect 128, 24,144,120,$07, 0
  rf_rect 144, 24,160,120,$08, 0
  rf_rect 160, 24,176,120,$09, 0
  rf_rect 176, 24,192,120,$0a, 0
  rf_rect 192, 24,208,120,$0b, 0
  rf_rect 208, 24,224,120,$0c, 0
  rf_rect  32,120, 48,216,$0c, 0
  rf_rect  48,120, 64,216,$0b, 0
  rf_rect  64,120, 80,216,$0a, 0
  rf_rect  80,120, 96,216,$09, 0
  rf_rect  96,120,112,216,$08, 0
  rf_rect 112,120,128,216,$07, 0
  rf_rect 128,120,144,216,$06, 0
  rf_rect 144,120,160,216,$05, 0
  rf_rect 160,120,176,216,$04, 0
  rf_rect 176,120,192,216,$03, 0
  rf_rect 192,120,208,216,$02, 0
  rf_rect 208,120,224,216,$01, 0
  .byte $00

.code

.proc do_gray_ramp
  jsr rf_load_tiles
  jsr rf_load_yrgb_palette
  ldx #$20
  stx rf_curnametable
  lda #$00
  tay
  jsr ppu_clear_nt
  lda #>gray_ramp_rects
  ldy #<gray_ramp_rects
  sta ciSrc+1
  sty ciSrc
  jsr rf_draw_rects

loop:
  jsr ppu_wait_vblank
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0

  lda #helpsect_gray_ramp
  jsr read_pads_helpcheck
  bcs do_gray_ramp
  lda new_keys+0
  and #KEY_B
  beq loop
  rts
.endproc

; COLOR BLEED ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"
bleedtile_top:    .byte $00, $55, $55
bleedtile_bottom: .byte $FF, $55, $AA

bleed_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect  16, 32,240, 64,$01, 0
  rf_rect  16, 80,240,112,$01, 0
  rf_rect  16,128,240,160,$01, 0
  rf_rect  16,176,240,208,$01, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr  16, 32,240, 64, 1
  rf_attr  16, 80,240,112, 2
  rf_attr  16,128,240,160, 3
  .byte $00
fullstripes_rects:
  rf_rect   0,  0,256,240,$01, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  .byte $00
bleed_palette:
  .byte $0F,$0F,$0F,$20, $0F,$0F,$0F,$16, $0F,$0F,$0F,$1A, $0F,$0F,$0F,$12
  .byte $0F,$0F,$0F,$20
frame_label:
  .byte "Frame",0

bleed_types:
  .addr bleed_rects
  .byte helpsect_color_bleed
  .addr fullstripes_rects
  .byte helpsect_full_screen_stripes

bleed_helpscreen = bleed_types+2

tvSystemFPS:  .byte 60, 50, 50
.segment "CODE"
;;
; Sets tile 0 to solid color 0 and tile 1 to the color bleed tile
; in colors 2 and 3.
; @param X Pattern select: 0 horizontal; 1 vertical; 2 checkerboard
; @param A invert: $FF or $00
; @param Y Frame counter
.proc prepare_color_bleed_tiles

  ; Draw the frame counter
  pha
  txa
  pha
  jsr clearLineImg
  tya
  jsr bcd8bit
  ora #'0'
  ldx #56
  jsr vwfPutTile
  lda bcd_highdigits
  ora #'0'
  ldx #51
  jsr vwfPutTile
  lda #>frame_label
  ldy #<frame_label
  ldx #20
  jsr vwfPuts

  pla
  tax
  pla
  sta $00

  ; Draw the tile in question into x=8-15
  ldy #8
  l2:
    lda bleedtile_top,x
    eor $00
    sta lineImgBuf,y
    iny
    lda bleedtile_bottom,x
    eor $00
    sta lineImgBuf,y
    iny
    cpy #16
    bcc l2
  lda #%00000110
  jsr rf_color_lineImgBuf

  ; Finally, blank the first tile to color 0
  lda #$00
  sta vram_copydstlo
  sta vram_copydsthi
  ldy #15
  l3:
    sta lineImgBuf,y
    dey
    bpl l3
  
  rts 
.endproc

.proc do_full_stripes
  ldx #3
  bpl do_generic_color_bleed
.endproc

.proc do_color_bleed
  ldx #0
  ; fall through
.endproc
.proc do_generic_color_bleed
tile_shape  = test_state+0
xor_value   = test_state+1
frame_count = test_state+2
bg_type     = test_state+3
  stx bg_type
  ldx #0
  stx tile_shape
  stx xor_value
  stx frame_count

restart:
  jsr ppu_wait_vblank
  lda #$3F
  sta PPUADDR
  ldy #$00
  sty PPUADDR
  palloop:
    lda bleed_palette,y
    sta PPUDATA
    iny
    cpy #20
    bcc palloop

  ldx #$20
  stx rf_curnametable
  lda #$80
  sta PPUCTRL
  sta help_reload
  asl a
  sta PPUMASK
  lda bg_type
  and #$7F
  tax
  ldy bleed_types+0,x
  lda bleed_types+1,x
  jsr rf_draw_rects_attrs_ay
  
  ; Set up the frame counter sprites
  ldx #0
  ldy #2
  objloop:
    lda #207
    sta OAM+0,x
    tya
    sta OAM+1,x
    asl a
    asl a
    asl a
    sta OAM+3,x
    lda #0
    sta OAM+2,x
    txa
    adc #4
    tax
    iny
    cpy #8
    bcc objloop
  jsr ppu_clear_oam 

loop:
  ldx tile_shape
  lda xor_value
  ldy frame_count
  jsr prepare_color_bleed_tiles
  jsr ppu_wait_vblank
  jsr rf_copy8tiles
  ldx #0
  stx OAMADDR
  lda #>OAM
  sta OAM_DMA
  lda bg_type
  asl a  ; bg_type D7 controls sprite on/off
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  jsr ppu_screen_on_xy0

  lda bg_type
  and #$7F
  tay
  lda bleed_helpscreen,y
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:
  lda das_keys
  and #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
  sta das_keys
  lda das_timer
  cmp #4
  bcs :+
    lda #1
    sta das_timer
  :
  ldx #0
  jsr autorepeat

  inc frame_count
  lda frame_count
  ldx tvSystem
  cmp tvSystemFPS,x
  bcc :+
    lda #0
    sta frame_count
  :

  lda new_keys+0
  and #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
  beq not_flip
    lda #$FF
    eor xor_value
    sta xor_value
  not_flip:

  lda new_keys+0
  and #KEY_SELECT
  beq not_toggle_counter
    lda #$80
    eor bg_type
    sta bg_type
  not_toggle_counter:

  lda new_keys+0
  and #KEY_A
  beq not_switch
    inc tile_shape
    lda tile_shape
    cmp #3
    bcc not_switch
      lda #0
      sta tile_shape
  not_switch:

  lda new_keys
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

; SOLID COLOR SCREEN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.segment "RODATA"

; cur_color=0-2: use one of these
; cur_color=3: use white_color
; cur_color=4: use black_color
solid_color_rgb: .byte $16,$1A,$12

solid_color_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect 160, 32,224, 40,$20, RF_INCR
  .byte $00
  rf_attr   0,  0,256,240, 0
  .byte $00
color_msg:  .byte "Color:",0

.segment "CODE"

.proc do_solid_color
cur_color = test_state+0
color_box_open = test_state+1
white_color = test_state+2
black_color = test_state+3
cur_bg_color = lineImgBuf+128
text_dark_color = lineImgBuf+129
text_light_color = lineImgBuf+130

  lda #3
  sta cur_color
  lda #0
  sta color_box_open
  lda #$20
  sta white_color
  lda #$0F
  sta black_color
restart:
  jsr rf_load_tiles
  ldx #$20
  stx rf_curnametable
  ldy #<solid_color_rects
  lda #>solid_color_rects
  jsr rf_draw_rects_attrs_ay

loop:
  ; Prepare color display
  jsr clearLineImg
  lda white_color
  lsr a
  lsr a
  lsr a
  lsr a
  ldx #44
  jsr vwfPutNibble
  lda white_color
  and #$0F
  ldx #50
  jsr vwfPutNibble
  ldy #<color_msg
  lda #>color_msg
  ldx #8
  jsr vwfPuts

  lda #%1001
  jsr rf_color_lineImgBuf
  lda #$02
  sta vram_copydsthi
  lda #$00
  sta vram_copydstlo
  
  ; Choose palette display
  ; 0-2: RGB, no box
  ; 3: white, optional box
  ; 4: black, no box
  ldx cur_color
  cpx #3
  beq load_palette_white
  bcs load_palette_black
  lda solid_color_rgb,x
  bcc have_bg_color_no_text
load_palette_white:
  lda white_color
  ldx color_box_open
  beq have_bg_color_no_text
  ldx #$02
  stx text_dark_color
  ldx #$38
  stx text_light_color
  bne have_bg_color
load_palette_black:
  lda black_color
have_bg_color_no_text:
  sta text_dark_color
  sta text_light_color
have_bg_color:
  sta cur_bg_color

  jsr ppu_wait_vblank
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda cur_bg_color
  sta PPUDATA 
  sta PPUDATA
  lda text_dark_color
  sta PPUDATA
  lda text_light_color
  sta PPUDATA
  jsr rf_copy8tiles
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0

  lda #helpsect_solid_color_screen
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:
  lda new_keys+0
  and #KEY_RIGHT
  beq not_right
  lda color_box_open
  beq next_color
    lda white_color
    and #$0F
    clc
    adc #1
    cmp #$0D
    bcc :+
      lda #$00
    :
    eor white_color
    and #$0F
    eor white_color
    sta white_color
    jmp not_right
  next_color:
    inc cur_color
    lda cur_color
    cmp #5
    bcc not_right
      lda #0
      sta cur_color
  not_right:

  lda new_keys+0
  and #KEY_LEFT
  beq not_left
  lda color_box_open
  beq prev_color
    lda white_color
    and #$0F
    clc
    adc #<-1
    bpl :+
      lda #$0C
    :
    eor white_color
    and #$0F
    eor white_color
    sta white_color
    jmp not_left
  prev_color:
    dec cur_color
    bpl not_left
      lda #4
      sta cur_color
  not_left:

  lda new_keys+0
  and #KEY_UP
  beq not_up
  lda color_box_open
  beq not_up
    lda white_color
    clc
    adc #16
    cmp #$40
    bcc :+
      lda #$30
    :
    sta white_color
  not_up:

  lda new_keys+0
  and #KEY_DOWN
  beq not_down
  lda color_box_open
  beq not_down
    lda white_color
    sec
    sbc #16
    bcs :+
      lda #$00
    :
    sta white_color
  not_down:

  lda new_keys+0
  and #KEY_A
  beq notA
  lda cur_color
  cmp #3
  bcc notA
  bne A_toggle_black
    lda #$01
    eor color_box_open
    sta color_box_open
    bcs notA
  A_toggle_black:
    lda #$0D ^ $0F
    eor black_color
    sta black_color
  notA:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

.proc vwfPutNibble
  cmp #10
  bcc :+
    adc #'A'-'9'-2
  :
  adc #'0'
  jmp vwfPutTile
.endproc
