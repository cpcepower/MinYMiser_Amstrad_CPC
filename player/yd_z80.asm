; ---------------------------------------------------------------------------------
; - Amstrad CPC Z80 version of MinYMiser
; - $VER 1.0 - (c) 08/2025 Megachur
; ---------------------------
; 680x0 -> Z80 code conversion
; $VER 1.0 - no optimisation
; for Frosty / Benediction Team and all the Amstrad CPC fans ;-) !
; -----------------------------------------------------------------------
;	YD (DELTA-PACK) PLAYER CODE
; -----------------------------------------------------------------------
rsreset
;;yd_curr		rs.l	1
;;yd_frame_count	rs.l	1
;;yd_start	rs.l	1
;;yd_frames	rs.w	1
;;yd_size		rs.b	1

yd_curr			equ 0
yd_frame_count	equ 2+yd_curr
yd_start		equ 4+yd_frame_count
yd_frames		equ 2+yd_start
yd_size			equ 4+yd_frames
; -----------------------------------------------------------------------
; a0 = player state (ds.b yd_size)
; a1 = start of packed ym data
; -----------------------------------------------------------------------
yd_player_init
; ---------------------------
LET a0_psa = player_state

;;	addq.l	#2,a1				; skip header
	inc hl
	inc hl
;;	move.l	(a1)+,d0			; frame count
	ld b,(hl)
	inc hl
	ld c,(hl)
	inc hl

	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl

	push de

;;	move.l	a1,(a0)+			; curr
	ex de,hl		; hl = xx - de = a1

	ld hl,a0_psa

	ld (hl),e
	inc hl
	ld (hl),d
	inc hl

;;	move.l	d0,(a0)+			; frames left

	pop de

	ld (hl),e
	inc hl
	ld (hl),d
	inc hl

	ld (hl),c
	inc hl
	ld (hl),b
	inc hl

;;	move.l	a1,(a0)+			; start
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl

;;	move.l	d0,(a0)+			; frames
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl

	ld (hl),c
	inc hl
	ld (hl),b
	inc hl

;;	rts
	ret
; -----------------------------------------------------------------------
; a0 = player state structure
; -----------------------------------------------------------------------
yd_player_update
; ---------------------------
;;	move.l	yd_curr(a0),a1
	ld hl,(a0_psa+yd_curr)

;;	lea	$ffff8800.w,a2
;;	lea	$ffff8802.w,a3
;;	subq.l	#1,yd_frame_count(a0)
;;	bne.s	.no_loop
	ld bc,(a0_psa+yd_frame_count)

	ld a,c
	or b
	jr z,yd_frame_count_32bits

	dec bc
	ld (a0_psa+yd_frame_count),bc

	ld a,c
	or b
	jr nz,yd_no_loop

yd_frame_count_32bits
	ld bc,(a0_psa+yd_frame_count+2)

	ld a,c
	or b
	jr z,yd_loop

	dec bc
	ld (a0_psa+yd_frame_count+2),bc

	ld de,#ffff
	ld (a0_psa+yd_frame_count),de

	ld a,c
	or b
	jr nz,yd_no_loop

yd_loop
;;	move.l	yd_frames(a0),yd_frame_count(a0)
	ld hl,(a0_psa+yd_frames)
	ld (a0_psa+yd_frame_count),hl
	ld hl,(a0_psa+yd_frames+2)
	ld (a0_psa+yd_frame_count+2),hl

;;	move.l	yd_start(a0),a1
	ld hl,(a0_psa+yd_start)

yd_no_loop		;; .no_loop
;;r	set	0

	ld d,#00
	
;;	rept	2
REPEAT 2
;;	move.b	(a1)+,d0
	ld e,(hl)
	inc hl

;;	rept	7
REPEAT 7
;;	add.b	d0,d0
;;	bcc.s	*+(2+4+2)

	sla e
	jr nc,@yd1

;;	move.b	#r,(a2)
;;	move.b	(a1)+,(a3)

	ld b,#f4	; PPI port A data
	out (c),d	; send register number

	ld b,#f6	; PPI port C
	in a,(c)	; read value
	or #c0		; select PSG register
	out (c),a
	and #3f		; set inactive
	out (c),a
	ld c,a

	ld b,#f4	; PPI port A data
	ld a,(hl)
	inc hl
	out (c),a	; send register data value

	; dec b
	; outi
	; ld c,a

	ld b,#f6	; PPI port C
	ld a,c
	or #80		; write to selected PSG register
	out (c),a	; send
	out (c),c	; set inactive

; bcc jumps to here
@yd1
;;r	set	r+1
	inc d

;;	endr
REND

;;	endr
REND

;;	move.l	a1,yd_curr(a0)
;;	rts
	ld (a0_psa+yd_curr),hl
	ret
