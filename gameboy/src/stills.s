;
; Still image (or mostly so) tests for 240p test suite
; Copyright 2018 Damian Yerrick
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
include "src/gb.inc"
include "src/global.inc"

  rsset hLocals
tilesleft rb 1

  rsset hTestState
curpalette rb 1
curtileid rb 1
curscry rb 1
curlcdc rb 1
customred   rb 1
customgreen rb 1
customblue  rb 1

section "stillswram", WRAM0
curframe_bcd: ds 1

; Gray ramp ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "grayramp",ROM0,align[2]
grayramp_chr:
  incbin "obj/gb/grayramp.chrgb"
grayramp_chr_gbc:
  db %00111111
  dw `00000111
  db %11111111
  db %00111111
  dw `11222223
  db %11111111
  db %00111111
  dw `33330000
  db %11111111
  db %00111111
  dw `33333333
  db %11111111
  db %11111111
  db %11111111
grayramp_bottomhalfmap:
  db 0,18,19,16,15,20,13,12,21,10,9,22,7,6,23,4,3,24,1,0
grayramp_attrmap_gbc:
  db $00,$00,$00,$21,$21,$02,$02,$02,$23,$23,$04,$04,$04,$25,$25,$06,$06,$06,$27,$27

load_gray_ramp_mono:
  ; Tiles 1-24 are compressed: 2 rows (4 bytes) are written 4 times
  ld de,grayramp_chr
  ld a,25
  .tileloop:
    ld [tilesleft],a
    ld b,4
    .rowpairloop:
      ld c,4
      .byteloop:
        ld a,[de]
        inc e
        ld [hl+],a
        dec c
        jr nz,.byteloop
      ld a,e
      sub 4
      ld e,a
      dec b
      jr nz,.rowpairloop

    ; Did it wrap to the next page?
    add 4
    ld e,a
    jr nc,.enotwrapped
      inc d
    .enotwrapped:
    ld a,[tilesleft]
    dec a
    jr nz,.tileloop

  ; Now the tilemap
  ; Row 0
  ld hl,_SCRN0
  call oneblanktilerow
  ; Rows 1-8
  ld c,8
  .tophalfrowloop:
    xor a
    .tophalfbyteloop:
      ld [hl+],a
      inc a
      cp 19
      jr c,.tophalfbyteloop
    xor a
    ld [hl+],a
    call add_hl_12
    dec c
    jr nz,.tophalfrowloop
  ; Rows 9-16
  ld c,8
  .bottomhalfrowloop:
    ld b,20
    ld de,grayramp_bottomhalfmap
    .bottomhalfbyteloop:
      ld a,[de]
      inc de
      ld [hl+],a
      dec b
      jr nz,.bottomhalfbyteloop
    call add_hl_12
    dec c
    jr nz,.bottomhalfrowloop
  ; Row 19
  call oneblanktilerow
  ld a,%00011011
  jp set_bgp

load_gray_ramp_gbc:

  ; Tiles 1-3 are a cycle of the gray ramp, and tile 4-5 is solid
  ; to fill in half of the color 0 tile
  ld b,7
  ld de,grayramp_chr_gbc
  call pb16_unpack_block

  ; Set gray ramp palette
  ld a,$80
  ldh [rBCPS],a
  ldh [rOCPS],a
  ld b,0
  .palloop:
    ; calculate 01237654
    ld a,b
    bit 2,a
    jr z,.notdesc
      xor $03
    .notdesc:

    ; calculate $401*a
    ld e,a
    ld l,a
    add a
    add a
    ld d,a

    ; add $20*b
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,de

    ; and write to the VCE
    ld a,l
    ld [rBCPD],a
    ld [rOCPD],a
    ld a,h
    ld [rBCPD],a
    ld [rOCPD],a
    inc b
    ld a,b
    cp 32
    jr nz,.palloop

  ; Fill map plane 0
  ld hl,_SCRN0
  call oneblanktilerow
  ld b,16  ; Fill with 12321 pattern
  ld a,1
  .tilerowloop:
    ld c,4
    .tilequarterloop:
      ld [hl+],a
      inc a
      ld [hl+],a
      inc a
      ld [hl+],a
      dec a
      ld [hl+],a
      dec a
      ld [hl+],a
      dec c
      jr nz,.tilequarterloop
    call add_hl_12
    dec b
    jr nz,.tilerowloop
  call oneblanktilerow

  ; Fill map plane 1
  ld a,1
  ldh [rVBK],a
  ld hl,_SCRN0+32
  ld bc,8*256
  .topattrs:
    call onegbcgrayrampattrrow
    dec b
    jr nz,.topattrs
  ld bc,8*256+$07
  .bottomattrs:
    call onegbcgrayrampattrrow
    dec b
    jr nz,.bottomattrs
  xor a
  ldh [rVBK],a

  ; Because each vertical stripe is 5 pixels wide, the change from
  ; e.g. palette 0 to 1 occurs in the middle of a tile.  This would
  ; cause attribute clash.  So fill the gap with sprites using
  ; solid tile $04.
  ; B: x, C: y; D: attr counter; E: attr xor
  ld hl,SOAM
  ld bc,24*256+24
  ld de,$0081
  .filloamloop:
    ld a,b
    ld [hl+],a  ; write Y
    ld a,c
    ld [hl+],a  ; write X
    add 40
    ld c,a
    ld a,$04
    ld [hl+],a  ; write tile number
    ld a,d
    xor e
    ld [hl+],a  ; write attribute
    ld a,d
    add 2
    cp 8
    jr c,.have_new_oam_attr
      ; Prepare for next row
      ld a,16
      add b
      cp 24+128
      jr nc,.filloamdone
      ld b,a
      cp 24+64
      jr nz,.oamnothalfway
        ld e,$A6
      .oamnothalfway:
      ld c,24
      xor a
      
    .have_new_oam_attr:
    ld d,a
    jr .filloamloop
  .filloamdone:
  ret

oneblanktilerow:
  xor a
oneconsttilerow:
  ld c,20
  call memset_tiny
add_hl_12:
  ld de,12
  add hl,de
  ret
onegbcgrayrampattrrow:
  ld de,grayramp_attrmap_gbc
  push bc
  ld b,20
  .loop:
    ld a,[de]
    inc de
    xor c
    ld [hl+],a
    dec b
    jr nz,.loop
  pop bc
  jr add_hl_12

activity_gray_ramp::
.restart:
  call clear_gbc_attr
  ld [oam_used],a
  call lcd_clear_oam
  xor a
  ld hl,CHRRAM0
  ld c,16
  call memset_tiny
  dec a
  ldh [rLYC],a  ; disable lyc irq

  ld a,[initial_a]
  cp $11
  jr z,.load_gbc
    call load_gray_ramp_mono
    jr .load_done
  .load_gbc:
    call load_gray_ramp_gbc
  .load_done:

  ; Turn on rendering
  call run_dma
  ld a,LCDCF_ON|BG_NT0|BG_CHR01|OBJ_8X16
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a

  ; Now just wait for a B press.  Fortunately, we don't have
  ; to deal with half B presses or parallel universes here.
.loop:
  ld b,helpsect_gray_ramp
  call read_pad_help_check
  jr nz,.restart
  call wait_vblank_irq
  ld a,[new_keys]
  bit PADB_B,a
  jr z,.loop
  ret

; Linearity ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "linearity",ROM0
linearity_chr:
  incbin "obj/gb/linearity.u.chrgb.pb16"
linearity_nam:
  incbin "obj/gb/linearity.nam"
sizeof_linearity_chr = 1232

activity_linearity::
  ld a,%00011011
  ldh [curpalette],a
  ld a,LCDCF_ON|BG_NT0|BG_CHR21
  ldh [curlcdc],a

.restart:
  call clear_gbc_attr
  
  ld de,linearity_chr
  ld hl,CHRRAM2
  ld b,sizeof_linearity_chr/16
  call pb16_unpack_block

  ld hl,linearity_nam
  ld de,_SCRN0
  call load_full_nam

  ; Form full grid, copying already loaded tiles from CHRRAM2
  ; (default) to CHRRAM0 (nondefault)
  ld hl,CHRRAM2
  ld de,CHRRAM0
  ld c,sizeof_linearity_chr/16
  ld b,7
  .gridtileloop:
    push bc
    ; Top row: Copy plane 1 to plane 0 and set plane 1 to $FF
    inc hl
    ld a,[hl+]
    ld [de],a
    inc de
    ld a,$FF
    ld [de],a
    inc de
    ld b,7

    .gridsliverloop:
      ; Other rows: Copy plane 1 bit 7 and plane 0 bits 6-0 to
      ; plane 0, and plane 1 OR $80 to plane 1.
      ld a,[hl+]
      ld c,a
      ld a,[hl]
      xor c
      and $80
      xor c
      ld [de],a
      inc de
      ld a,[hl+]
      or $80
      ld [de],a
      inc de
      dec b
      jr nz,.gridsliverloop
  
    pop bc
    dec c
    jr nz,.gridtileloop

  ld a,255
  ldh [rLYC],a  ; disable lyc irq
  call set_bgp
  ldh a,[curlcdc]
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a

.loop:
  ld b,helpsect_linearity
  call read_pad_help_check
  jr nz,.restart
  call wait_vblank_irq
  ldh a,[curpalette]
  call set_bgp

  ; Process input
  ld a,[new_keys]
  ld b,a

  bit PADB_SELECT,b
  jr z,.not_select
    ldh a,[curpalette]
    cpl
    ldh [curpalette],a
  .not_select:

  bit PADB_A,b
  jr z,.not_A
    ldh a,[curlcdc]
    xor BG_CHR21^BG_CHR01
    ld [curlcdc],a
    ldh [vblank_lcdc_value],a
  .not_A:

  bit PADB_B,b
  jr z,.loop
  ret


load_full_nam::
  ld bc,256*20+18
;;
; Copies a B column by C row tilemap from HL to screen at DE.
load_nam::
  push bc
  push de
  .byteloop:
    ld a,[hl+]
    ld [de],a
    inc de
    dec b
    jr nz,.byteloop

  ; Move to next screen row
  pop de
  ld a,32
  add e
  ld e,a
  jr nc,.no_inc_d
    inc d
  .no_inc_d:

  ; Restore width; do more rows remain?
  pop bc
  dec c
  jr nz,load_nam
  ret

; Sharpness ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
section "sharpness",ROM0,align[4]
sharpness_chr:
  incbin "obj/gb/sharpness.u.chrgb.pb16"
sharpness_nam:
  incbin "obj/gb/sharpness.nam"
sizeof_sharpness_chr = 1632

activity_sharpness::
  ld a,%00011011
  ldh [curpalette],a

.restart:
  call clear_gbc_attr

  ld hl,CHRRAM2
  ld de,sharpness_chr
  ld b,sizeof_sharpness_chr/16
  call pb16_unpack_block

  ld hl,sharpness_nam
  ld de,_SCRN0
  call load_full_nam

  ld a,255
  ldh [rLYC],a  ; disable lyc irq
  call set_bgp
  ld a,LCDCF_ON|BG_NT0|BG_CHR21
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a

.loop:
  ld b,helpsect_sharpness
  call read_pad_help_check
  jr nz,.restart
  call wait_vblank_irq
  ldh a,[curpalette]
  call set_bgp

  ; Process input
  ld a,[new_keys]
  ld b,a

  bit PADB_SELECT,b
  jr z,.not_select
    ldh a,[curpalette]
    cpl
    ldh [curpalette],a
  .not_select:

  bit PADB_B,b
  jr z,.loop
  ret

; Solid screen ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "solid_screen",ROM0
solid_screen_constants:
  drgb $000000
  drgb $FF0000
  drgb $00FF00
  drgb $0000FF
activity_solid_screen::
  xor a
  ldh [curpalette],a
  ld a,31
  ldh [customred],a
  ldh [customgreen],a
  ldh [customblue],a
  ld a,$80
  ldh [curscry],a

.restart:
  call clear_gbc_attr
  
  ; Tile 0: Blank screen in color 0
  ; Tiles 1-0
  ld hl,CHRRAM2
  ld c,16
  xor a
  call memset_tiny
  dec a
  ld c,9*16
  call memset_tiny

  ; Clear tilemap, leaving space for (GBC-only) VWF canvas for RGB
  ld de,_SCRN0
  ld bc,32*18
  ld h,0
  call memset

  ; Create VWF canvas at X=160-176
  ld a,1
  ld hl,_SCRN0+32*1+20
  ld c,3  ;  3 rows tall
  ld de,32-3
.canvasinitrowloop:
  ld b,3
.canvasinitcellloop:
  ld [hl+],a
  inc a
  dec b
  jr nz,.canvasinitcellloop
  add hl,de
  dec c
  jr nz,.canvasinitrowloop

  ld a,255
  ldh [rLYC],a  ; disable lyc irq
  ld a,%11000000
  call set_bgp
  ld a,LCDCF_ON|BG_NT0|BG_CHR21
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a
  ld a,32

.loop:
  ld b,helpsect_solid_screen
  call read_pad_help_check
  jr nz,.restart
  call wait_vblank_irq

  ; Write color to both GB and GBC palette ports
  ldh a,[curpalette]
  ldh [rBGP],a
  or a
  jr nz,.set_bcpd_not_custom
    ld h,a     ; H = 0
    ldh a,[customgreen]
	add a,a
	add a,a
	add a,a
	ld l,a
	add hl,hl
	add hl,hl  ; HL = G * 32
    ldh a,[customred]
	ld e,a             ; E = R
	ldh a,[customblue]
	add a
	add a              ; A = B * 4
	ld d,a             ; DE = R+B*1024
	add hl,de
    jr .have_gbc_color_hl
  .set_bcpd_not_custom:
    ld de,solid_screen_constants-2
    call de_index_a
  .have_gbc_color_hl:
  ld a,$80
  ldh [rBCPS],a
  ld a,l
  ldh [rBCPD],a
  ld a,h
  ldh [rBCPD],a

  ; $80: Scroll to x=32 away from RGB control
  ; $00: Scroll to x=0 with RGB control
  ldh a,[curscry]
  and $80
  xor $80
  rra
  rra
  ldh [rSCX],a

  ; Choose among 5 palettes on GBC or 4 on GB
  ld a,[new_keys]
  bit PADB_B,a
  ret nz  ; quit now if exit
  ld b,a
  ld c,4
  ld a,[initial_a]
  cp $11
  jr nz,.not_5_palettes
    ; A on white screen on GBC only: Toggle custom mode
    bit PADB_A,b
    jr z,.not_toggle_custom
    ldh a,[curpalette]
    or a
    jr nz,.not_toggle_custom
      ldh a,[curscry]
      xor $80
      ldh [curscry],a
    .not_toggle_custom:
    ld c,5
  .not_5_palettes:

  ; Process input
  ldh a,[curscry]
  rla
  jr c,.not_custom_control

    ; Autorepeat for left and right keys
	ld b,PADF_LEFT|PADF_RIGHT
	call autorepeat
	ld a,[new_keys]
	ld b,a
    ldh a,[curscry]

    ; At this point: A is which row is selected, and B
    bit PADB_DOWN,b
    jr z,.not_custom_next_row
      inc a
      cp 3
      jr c,.not_custom_next_row
      dec a
    .not_custom_next_row:

    bit PADB_UP,b
    jr z,.not_custom_prev_row
      dec a
      cp 3
      jr c,.not_custom_prev_row
      inc a
    .not_custom_prev_row:
    ldh [curscry],a

    add low(customred)
    ld c,a
    ld a,[$FF00+c]
    bit PADB_RIGHT,b
    jr z,.not_custom_increase
      inc a
      cp 32
      jr c,.not_custom_increase
      dec a
    .not_custom_increase:

    bit PADB_LEFT,b
    jr z,.not_custom_decrease
      dec a
      cp 32
      jr c,.not_custom_decrease
      inc a
    .not_custom_decrease:
    ld [$FF00+c],a

    call solid_update_rgb
    jr .input_done
  .not_custom_control:
    bit PADB_LEFT,b
    jr z,.not_left
      ldh a,[curpalette]
      or a
      jr nz,.notwrapprev
        ld a,c
      .notwrapprev:
      dec a
      jr .have_new_curpalette
    .not_left:

    bit PADB_RIGHT,b
    jr z,.not_right
      ldh a,[curpalette]
      inc a
      cp c
      jr c,.notwrapnext
        xor a
      .notwrapnext:
    .have_new_curpalette:
      ldh [curpalette],a
    .not_right:
  .input_done:

  jp .loop

solid_update_rgb:
  ; Draw labels for Red, Green, and Blue
  call vwfClearBuf
  ld a,"R"
  ld b,6+24*0
  call vwfPutTile
  ld a,"G"
  ld b,6+24*1
  call vwfPutTile
  ld a,"B"
  ld b,6+24*2
  call vwfPutTile

  ; Draw cursor
  ldh a,[curscry]
  ld b,a
  add a  ; A=component*2
  add b  ; A=component*3
  add a  ; A=component*6
  add a  ; A=component*12
  scf
  adc a  ; A=component*24+1
  ld b,a
  ld a,">"
  call vwfPutTile

  ; Draw red, green, and blue values
  ld de,19 * 256 + low(customred)
.componentloop:
  push de
  ld c,e
  ld a,[$FF00+c]
  call bcd8bit  ; A: tens; C: ones
  jr z,.lessthanten
    push bc
    add "0"
    ld l,a
    ld a,d
    sub 5
    ld b,a  ; B:x, L: ascii, stack: ones digit, Y and hramptr
	ld a,l
    call vwfPutTile
    pop bc   ; Restore ones
    pop de   ; Restore Y and hramptr
    push de
  .lessthanten:
  ld a,c
  add "0"
  ld b,d
  call vwfPutTile
  pop de
  inc e
  ld a,24
  add d
  ld d,a
  cp 24*3
  jr c,.componentloop

  ; Push tiles to VRAM during blanking  
  ld hl,CHRRAM2+1*16
  ld c,9
  jp vwfPutBufHBlank

; CPS style grid ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "cps_grid",ROM0,align[4]
cps_grid_chr:
  incbin "obj/gb/cps_grid.chrgb.pb16"
cps_grid_gbc_palette0:
  drgb $FFFFFF
  drgb $FF00FF
  drgb $FF0000
  drgb $000000
cps_grid_gbc_palette1:
  drgb $000000
  drgb $FF00FF
  drgb $FF0000
  drgb $FFFFFF

sizeof_cps_grid_chr = 128

activity_cps_grid::
  ld a,%00011011
  ldh [curpalette],a

.restart:
  call clear_gbc_attr

  ld hl,CHRRAM2
  ld de,cps_grid_chr
  ld b,sizeof_cps_grid_chr/16
  call pb16_unpack_block

  ; Draw grid
  ld hl,_SCRN0
  ld b,0  ; top red row
  call cps_grid_two_rows
  ld bc,$0407
  .rowloop:
    push bc
    call cps_grid_two_rows
    pop bc
    dec c
    jr nz,.rowloop
  ld b,c  ; bottom red row
  call cps_grid_two_rows

  ld a,255
  ldh [rLYC],a  ; disable lyc irq
  call set_bgp
  ld a,LCDCF_ON|BG_NT0|BG_CHR21
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a

.loop:
  ld b,helpsect_grid
  call read_pad_help_check
  jr nz,.restart
  call wait_vblank_irq

  ; Set GB palette
  ldh a,[curpalette]
  ldh [rBGP],a

  ; Set GBC palette
  and %00001000
  ld e,a
  ld d,0
  ld hl,cps_grid_gbc_palette0
  add hl,de
  ld bc,8*256+low(rBCPS)
  ld a,$80
  call set_gbc_palette
  

  ; Process input
  ld a,[new_keys]
  ld b,a

  bit PADB_SELECT,b
  jr z,.not_select
    ldh a,[curpalette]
    cpl
    ldh [curpalette],a
  .not_select:

  bit PADB_B,b
  jr z,.loop
  ret

;;
; Draws one row of the CPS-2 grid.
cps_grid_two_rows:
  call cps_grid_one_row
  ; Move to bottom half
  inc b
  inc b
cps_grid_one_row:
  ; Left column
  ld a,b
  and $02
  ld [hl+],a
  inc a
  ld [hl+],a

  ; Center 8 columns
  ld c,16
  ld a,b
  .colloop:
    ld [hl+],a
    xor a,1
    dec c
    jr nz,.colloop

  ; Right column
  ld a,b
  and $02
  ld [hl+],a
  inc a
  ld [hl+],a
  inc a

  ; Move to next row
  ld de,12
  add hl,de
  ret

; Full screen stripes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "full_stripes",ROM0,align[3]
bleed_types:
  db %00000000  ; horizontal
  db %11111111  ; horizontal xor
  db %01010101  ; vertical
  db %00000000  ; vertical xor
  db %01010101  ; diagonal
  db %11111111  ; vertical xor
word_frame:
  db "Frame ",0

;;
; @param A index into bleed_types
; @param B starting XOR value (alternates $00 and $FF)
; @param DE destination tile address
load_bleed_frame_a:
  ld hl,bleed_types
  add a,a
  add a,l
  ld l,a
  ld a,[hl+]  ; A = starting byte
  xor b       ; A = starting byte this frame
  ld c,[hl]   ; C = xor value by line
  ld h,d
  ld l,e
  ld b,8      ; bytes left in tile
  ld d,0      ; plane 1 value
  .loop:
    ld [hl+],a
    ld [hl],d
    inc l
    xor c
    dec b
    jr nz,.loop
  ret

activity_full_stripes::
  xor a
  ldh [curtileid],a
  ldh [curscry],a
  ldh [curpalette],a
  ld [curframe_bcd],a
.restart:
  call clear_gbc_attr

  ; Blow away the tilemap, including one more row to show and hide
  ; the frame number
  ld de,_SCRN0
  ld bc,32*19
  ld h,16
  call memset

  ; Hide background until ready
  ld hl,CHRRAM0+256
  xor a
  ld c,16
  call memset_tiny

  ; Make VWF window for frame number at X=0
  ld hl,CHRRAM0
  ld c,96
  ; A is still 0
  call memset_tiny
  ld hl,_SCRN0+32*18+14
  ld c,6
  ; A is still 0
  call memset_inc

  ; Turn on LCD
  ld a,255
  ldh [rLYC],a  ; disable lyc irq
  ld a,%00000011
  call set_bgp
  ld a,LCDCF_ON|BG_NT0|BG_CHR01
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a

.loop:
  ld b,helpsect_full_screen_stripes
  call read_pad_help_check
  jr nz,.restart

  ; Autorepeat at 60 Hz
  ld a,[das_timer]
  cp 4
  jr nc,.no_skip_das_frames
    ld a,1
    ld [das_timer],a
  .no_skip_das_frames:
  ld b,PADF_UP|PADF_DOWN|PADF_LEFT|PADF_RIGHT
  call autorepeat

  ; Process input
  ld a,[new_keys]
  ld b,a
  bit PADB_B,b
  ret nz

  ld a,PADF_UP|PADF_DOWN|PADF_LEFT|PADF_RIGHT
  and b
  jr z,.not_toggle
    ldh a,[curpalette]
    cpl
    ldh [curpalette],a
  .not_toggle:

  bit PADB_A,b
  jr z,.not_A
    ldh a,[curtileid]
    inc a
    cp 3
    jr c,.nowrap0
      xor a
    .nowrap0:
    ldh [curtileid],a
  .not_A:

  bit PADB_SELECT,b
  jr z,.not_select
    ldh a,[curscry]
    xor $08
    ldh [curscry],a
  .not_select:

  call wait_vblank_irq
  ldh a,[curpalette]
  ld b,a
  ld a,[curtileid]
  ld de,CHRRAM0+256
  call load_bleed_frame_a
  ld a,[curscry]
  ldh [rSCY],a
  call update_bcd_frame_counter
  jr .loop

;;
; Update the frame counter
; @param HL destination address of frame counter tiles
update_bcd_frame_counter:
  ld hl,CHRRAM0+$000
  push hl

  ; Write "Frame "
  ld hl,help_line_buffer
  ld de,word_frame
  call stpcpy

  ; Increment and write the frame count
  ld a,[curframe_bcd]
  inc a
  daa
  cp $60
  jr c,.nowrap60
    xor a
  .nowrap60:
  ld [curframe_bcd],a
  call puthex

  ; Terminate the string
  xor a
  ld [hl],a

  ; And draw it
  call vwfClearBuf
  ld hl,help_line_buffer
  ld b,4  ; X position
  call vwfPuts
  pop hl
  ld c,6
  jp vwfPutBufHBlank

;;
; Copies a nul-terminated string.
; @param HL destination pointer
; @param DE source string, NUL-terminated
; @return DE and HL both point to the trailing NUL
stpcpy::
  .loop:
    ld a,[de]
    and a
    jr z,.done
    ld [hl+],a
    inc de
    jr .loop
  .done:
  ld [hl],a
  ret
