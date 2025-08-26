; ---------------------------------------------------------------------------------
; - Amstrad CPC Z80 version of MinYMiser
; - $VER 1.0 - (c) 08/2025 Megachur
; ---------------------------
; Example of replay program
; ---------------------------
;; fork from https://github.com/tattlemuss/minymiser
; ---------------------------------------------------------------------------------
; Warning - Use a YM file at 1Mhz in input of the packer for replaying at Amtrad CPC AY-8912 rate !
; ---------------------------------------------------------------------------------
nolist
; ---------------------------
;DELTA_PACK equ 1	; uncomment this for DELTA_PACK player
; ---------------------------
	run start

	org #1000
	
start
	di

	ld hl,#c9fb
	ld (#0038),hl	; stop basic system interrupt

IFDEF DELTA_PACK
	ld hl,tune_data
	call yd_player_init
ELSE
	ld hl,tune_data
	ld de,player_cache
	call ymp_player_init
ENDIF

main_loop

	ld b,#f5

wait_vbl_loop
	in a,(c)
	rra
	jr c,wait_vbl_loop

wait_vbl_synchro_loop
	in a,(c)
	rra
	jr nc,wait_vbl_synchro_loop

	ei
	halt
	halt

	ld bc,#7f10		; see how CPU time is used by the player
	ld a,#5c
	out (c),c
	out (c),a

IFDEF DELTA_PACK
	call yd_player_update
ELSE
	call ymp_player_update
ENDIF

	ld bc,#7f10
	ld a,#4c
	out (c),c
	out (c),a

	halt

	ld bc,#7f10
	ld a,#54
	out (c),c
	out (c),a

	jr main_loop
; ---------------------------
; Player code
; ---------------------------
IFDEF DELTA_PACK
yd_player
	read "yd_z80.asm"
yd_player_end equ $
ELSE
ymp_player
	read "ymp_z80.asm"
ymp_player_end equ $
ENDIF
; ---------------------------
; Our packed data file.
; ---------------------------
tune_data
IFDEF DELTA_PACK
;;;;	incbin "example.yd" Warning size is 79ko !!!
ELSE
;;;;	incbin "example.ymp"
;	incbin "Molusks.minys"
	incbin "Molusks.minyq"
ENDIF
tune_data_end equ $
; ---------------------------
; Data space for each copy of playback state
; ---------------------------
player_state
IFDEF DELTA_PACK
	ds yd_size,#00
ELSE
	ds ymp_size,#00
ENDIF
player_state_end equ $
; ---------------------------
; LZ cache for player. Size depends on the compressed file.
; ---------------------------
player_cache
	ds	8192,#00		; (or whatever size you need)
player_cache_end equ $
; ---------------------------
list:example_player_end equ $:nolist
; ---------------------------