; ---------------------------------------------------------------------------------
; - Amstrad CPC Z80 version of MinYMiser
; - $VER 1.0 - (c) 08/2025 Megachur
; ---------------------------
; 680x0 -> Z80 code conversion
; $VER 1.0 - no optimisation
; for Frosty / Benediction Team and all the Amstrad CPC fans ;-) !
; -----------------------------------------------------------------------
;	YMP PLAYER CODE
; -----------------------------------------------------------------------
; The number of packed data streams in the file.
; This is one less than the number of YM registers, since
; the Mixer register is encoded into the "volume" register
; streams.
; Bit 7 of the volume stream value is the noise channel enable/disable.
; Bit 6 of the volume stream value is the square channel enable/disable.
; Bits 4-0 of the volume stream value are the natural "volume/envelope" bits.
; ---------------------------
nolist
; ---------------------------
NUM_STREAMS				equ	13

; KEEP THESE 3 IN ORDER

ymunp_match_read_ptr	equ	0			; X when copying, the src pointer (either in cache or in original stream)
ymunp_stream_read_ptr	equ	4			; position in packed data we are reading from
ymunp_copy_count_w		equ	8			; number of bytes remaining to copy. Decremented at start of update.
ymunp_size				equ	10			; structure size

ymset_cache_base_ptr	equ	0			; bottom location of where to write the data
ymset_cache_offset		equ	4			; added to base_ptr for first write ptr
ymset_size				equ	6

;
rsreset
;ymp_sets_ptr			rs.l	1
;ymp_register_list_ptr	rs.l	1
;ymp_streams_state		rs.b	ymunp_size*NUM_STREAMS
;ymp_sets_state			rs.b	ymset_size*NUM_STREAMS	; max possible number of sets
;ymp_vbl_countdown		rs.l	1			; number of VBLs left to restart
;ymp_tune_ptr			rs.l	1
;ymp_cache_ptr			rs.l	1
;ymp_output_buffer		rs.b	NUM_STREAMS
;						rs.b	NUM_STREAMS&1		; pad to even offset
;ymp_size				rs.w	1

ymp_sets_ptr				equ 0
ymp_register_list_ptr	equ 2+ymp_sets_ptr
ymp_streams_state		equ 2+ymp_register_list_ptr
ymp_sets_state			equ ymunp_size*NUM_STREAMS+ymp_streams_state	; max possible number of sets
ymp_vbl_countdown		equ ymset_size*NUM_STREAMS+ymp_sets_state	; number of VBLs left to restart
ymp_tune_ptr			equ 2+ymp_vbl_countdown
ymp_cache_ptr			equ 2+ymp_tune_ptr
ymp_output_buffer		equ 2+ymp_cache_ptr		; pad to even offset
ymp_size				equ NUM_STREAMS/2*2+NUM_STREAMS+ymp_output_buffer
; rsreset_size			equ 2+ymp_size
; -----------------------------------------------------------------------
; a0 = player state (ds.b ymp_size)
; a1 = start of packed ym data
; a2 = start of player cache (ds.b memory)
; -----------------------------------------------------------------------
; Z80 -> player_state address of a free buffer memory of length = ymp_size
; hl = start of packed ym data
; de = start of player cache (ds.b memory)
; -----------------------------------------------------------------------
; code use af, bc, de, hl, ix, iy register and some memory of stack sp
; -----------------------------------------------------------------------
ymp_player_init
; ---------------------------

; Save addresses of buffers

LET a0_psa = player_state	; player_state address = a0

;; move.l a1,ymp_tune_ptr(a0)
;; move.l a2,ymp_cache_ptr(a0)
	ld (a0_psa+ymp_tune_ptr),hl		; hl = a1
	ld (a0_psa+ymp_cache_ptr),de	; de = a2

ymp_player_restart
; hl = a1 = start of packed ym data

;; lea ymp_streams_state(a0),a3 	; a3 = state data
	ld ix,a0_psa+ymp_streams_state

;; move.l a1,d5				; d5 = copy of packed file start
	ld c,l
	ld b,h			; bc = d5 = ymp_tune_ptr

;; addq.l #4,a1				; skip header (2 bytes ID + 2 bytes cache size)
	ld a,l
	add a,#4
	ld l,a
	adc a,h
	sub a,l
	ld h,a			; 1 nop less than 4 x inc hl

;; move.l (a1)+,ymp_vbl_countdown(a0)
	inc hl
	inc hl
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld (a0_psa+ymp_vbl_countdown),de

;; move.l a1,ymp_register_list_ptr(a0)	
	ld (a0_psa+ymp_register_list_ptr),hl

; skip the register list and padding

;; lea NUM_STREAMS+1(a1),a1
	ld de,NUM_STREAMS+1
	add hl,de

; Prime the read addresses for each reg

;; moveq.l #NUM_STREAMS-1,d0
	ld a,NUM_STREAMS-1

ymp_fill		;; .fill
; a1 = input data (this moves for each channel)

;; move.l d5,d1
; bc = d5 = ymp_tune_ptr

;; add.l (a1)+,d1			; read size offset in header
	inc hl
	inc hl
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl		; de = (a1)+

	ex de,hl	; hl = (a1)+ - de = a1

	add hl,bc

;; move.l d1,ymunp_stream_read_ptr(a3)	; setup ymunp_stream_read_ptr
	ld (ix+ymunp_stream_read_ptr+0),l
	ld (ix+ymunp_stream_read_ptr+1),h

	ex de,hl	; hl = a1 - de = xx

;; clr.l ymunp_match_read_ptr(a3)	; setup ymunp_match_read_ptr
	ld (ix+ymunp_match_read_ptr+0),#00
	ld (ix+ymunp_match_read_ptr+1),#00

;; move.w #1,ymunp_copy_count_w(a3)	; setup ymunp_copy_count_w
	ld (ix+ymunp_copy_count_w+0),#01
	ld (ix+ymunp_copy_count_w+1),#00

;; lea ymunp_size(a3),a3		; next stream state
	ld de,ymunp_size
	add ix,de

;; dbf d0,.fill
	dec a
	jp p,ymp_fill

; Calculate the set data

;; move.l a1,ymp_sets_ptr(a0)
	ld (a0_psa+ymp_sets_ptr),hl
;; lea ymp_sets_state(a0),a3		; a3 = set information
	ld ix,a0_psa+ymp_sets_state
;; move.l ymp_cache_ptr(a0),a2		; a2 = curr cache write point
	ld de,(a0_psa+ymp_cache_ptr)

; hl = a1
; de = a2
; ix = a3

ymp_read_set			;; .read_set
;; move.w (a1)+,d1			; d1 = size of set - 1
	ld b,(hl)
	inc hl
	ld c,(hl)
	inc hl		; bc = d1

;; bpl.s	.sets_done
;; rts
	ld a,c
	and b
	inc a
	ret z

; .sets_done
;; move.l a2,ymset_cache_base_ptr(a3)
	ld (ix+ymset_cache_base_ptr+0),e
	ld (ix+ymset_cache_base_ptr+1),d

;; clr.w	ymset_cache_offset(a3)
	ld (ix+ymset_cache_offset+0),#00
	ld (ix+ymset_cache_offset+1),#00

;; move.w	(a1)+,d2				; d2 = cache size per reg
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl		; de = d2

	push hl		; hl = a1

	ld l,(ix+ymset_cache_base_ptr+0)
	ld h,(ix+ymset_cache_base_ptr+1)	; hl = a2

; Move the cache pointer onwards

ymp_inc_cache_ptr	;; .inc_cache_ptr
;; add.w d2,a2
	add hl,de

;; dbf d1,.inc_cache_ptr
	dec bc
	ld a,c
	and a,b
	inc a			; cp #ff
	jr nz,ymp_inc_cache_ptr
	
;; addq.l #ymset_size,a3			; on to next
	ld bc,ymset_size
	add ix,bc

	ex de,hl	; hl = d2 - de = a2

	pop hl		; hl = a1

;; bra.s .read_set
	jr ymp_read_set
; -----------------------------------------------------------------------
; a0 = input structure
; -----------------------------------------------------------------------
ymp_player_update
; ---------------------------
;; lea ymp_streams_state(a0),a3		; a3 = streams state
	ld ix,a0_psa+ymp_streams_state

LET ymp_a6 = a0_psa+ymp_output_buffer
;; lea ymp_output_buffer(a0),a6		; a6 = YM buffer
	ld hl,ymp_a6
	ld (ypu_save_a6),hl

;; move.w #ymunp_size,d2				; d2 = stream structure size (constant)

; Update single stream here

;; lea	ymp_sets_state(a0),a5			; a5 = set current data
	ld iy,a0_psa+ymp_sets_state

;; move.l ymp_sets_ptr(a0),a4			; a4 = static set info
	ld hl,(a0_psa+ymp_sets_ptr)
; hl = a4
	ld (ymp_sets_ptr_a4),hl

;; moveq #0,d3					; d3 = clear to ensure add.l later works

ymp_set_loop
;; move.w (a4)+,d1				; d1 = registers/loop (dbf size)

ymp_sets_ptr_a4 equ $+1
	ld hl,#0000

	ld b,(hl)
	inc hl
	ld c,(hl)

;; bmi ymp_sets_done			; check end
	bit 7,b
	jp nz,ymp_sets_done

	inc hl
	ld (ymp_register_loop_count_w),bc	; bc = d1

;; move.w (a4)+,d3				; d3 = cache size for set
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl

	ld (ymp_save_d3),de		; de = d3
	ld (ymp_sets_ptr_a4),hl	; hl = a4

; TODO can use (a5)+ here in future?

;; move.l ymset_cache_base_ptr(a5),a2
	ld l,(iy+ymset_cache_base_ptr+0)
	ld h,(iy+ymset_cache_base_ptr+1)
;; move.l a2,d5

	push hl		; hl = a2 = d5

;; add.w ymset_cache_offset(a5),a2		; a2 = register's current cache write ptr
	ld c,(iy+ymset_cache_offset+0)
	ld b,(iy+ymset_cache_offset+1)
	add hl,bc

	ex de,hl	; hl = d3 - de = a2

;; add.l d3,d5				; d5 = register's cache end ptr
	pop bc		; bc = d5
	add hl,bc

	ex de,hl	; hl = a2 - de = d5

ymp_register_loop
	ld (ymp_save_d5),de		; de = d5
	ld (ymp_save_a2),hl		; hl = a2
;; moveq #0,d4					; d4 = temp used for decoding
;; subq.w #1,ymunp_copy_count_w(a3)
;; bne.s .stream_copy_one			; still in copying state

	ld l,(ix+ymunp_copy_count_w+0)
	ld h,(ix+ymunp_copy_count_w+1)
	dec hl
	ld (ix+ymunp_copy_count_w+0),l
	ld (ix+ymunp_copy_count_w+1),h
	ld a,l
	or h
	jr nz,ymp_stream_copy_one

; Set up next ymunp_match_read_ptr and ymunp_copy_count_w here

;; move.l ymunp_stream_read_ptr(a3),a1		; a1 = packed data stream
	ld l,(ix+ymunp_stream_read_ptr+0)
	ld h,(ix+ymunp_stream_read_ptr+1)	
;; moveq #0,d0
	ld b,#00
;; move.b (a1)+,d0
	ld c,(hl)
	inc hl

; Match or reference?

;; bclr	#7,d0
;; bne.s .literals
	bit 7,c
	res 7,c
	jr nz,ymp_literals

; Match code
; a1 is the stream read ptr
; d0 is the pre-read count value

;; bsr.s read_extended_number
	call read_extended_number
;; move.w d0,ymunp_copy_count_w(a3)
	ld (ix+ymunp_copy_count_w+0),c
	ld (ix+ymunp_copy_count_w+1),b
	
; Now read offset

;; moveq #0,d0
	ld bc,#0000

ymp_read_offset_b	;; .read_offset_b
;; move.b (a1)+,d4
;; bne.s .read_offset_done
	ld a,(hl)
	inc hl
	or a
	jr nz,ymp_read_offset_done
;; add.w #255,d0
	ld a,c
	add a,255
	ld c,a
	adc a,b
	sub a,c
	ld b,a
;; bra.s .read_offset_b
	jr ymp_read_offset_b

ymp_read_offset_done	;; .read_offset_done
;; add.w d4,d0					; add final non-zero index
	add a,c
	ld c,a
	adc a,b
	sub a,c
	ld b,a

;; move.l a1,ymunp_stream_read_ptr(a3)		; remember stream ptr now, before trashing a1
	ld (ix+ymunp_stream_read_ptr+0),l
	ld (ix+ymunp_stream_read_ptr+1),h

; Apply offset backwards from where we are writing

;; move.l a2,a1					; current cache write ptr
ymp_save_a2 equ $+1
	ld hl,#0000		; hl = a2 = a1

;; add.w d3,a1					; add cache size
ymp_save_d3 equ $+1
	ld de,#0000		; de = d3 saved before ;-)
	add hl,de

; this value is still modulo "cache offset"

;; sub.l d0,a1					; apply reverse offset
	or a		; reset carry flag
	sbc	hl,bc

;; cmp.l d5,a1					; past cache end?
ymp_save_d5 equ $+1
	ld bc,#0000

	push hl		; hl = a1

	or a		; reset carry flag
	sbc	hl,bc								

	pop hl		; hl = a1

;; blt.s .ptr_ok
	jr c,ymp_ptr_ok

;; sub.w d3,a1				; subtract cache size again
	or a		; reset carry flag
	sbc hl,de

ymp_ptr_ok		;; .ptr_ok
;; move.l a1,ymunp_match_read_ptr(a3)
	ld (ix+ymunp_match_read_ptr+0),l
	ld (ix+ymunp_match_read_ptr+1),h
;; bra.s .stream_copy_one
	jr ymp_stream_copy_one_read_ptr_ok	; ymp_stream_copy_one

ymp_literals	;; .literals

; Literals code -- just a count
; a1 is the stream read ptr
; d0 is the pre-read count value

; hl = a1
; bc = d0

;; bsr.s read_extended_number
	call read_extended_number
;; move.w d0,ymunp_copy_count_w(a3)
	ld (ix+ymunp_copy_count_w+0),c
	ld (ix+ymunp_copy_count_w+1),b

;; move.l a1,ymunp_match_read_ptr(a3)		; use the current packed stream address
	ld (ix+ymunp_match_read_ptr+0),l
	ld (ix+ymunp_match_read_ptr+1),h
;; add.l d0,a1					; skip bytes in input stream
	add hl,bc
;; move.l a1,ymunp_stream_read_ptr(a3)
	ld (ix+ymunp_stream_read_ptr+0),l
	ld (ix+ymunp_stream_read_ptr+1),h

; Falls through to do the copy

ymp_stream_copy_one		;; .stream_copy_one

; Copy byte from either the cache or the literals in the stream

;; move.l ymunp_match_read_ptr(a3),a1		; a1 = match read
	ld l,(ix+ymunp_match_read_ptr+0)
	ld h,(ix+ymunp_match_read_ptr+1)

ymp_stream_copy_one_read_ptr_ok
; a2 = cache write, d5 = loop addr

;; move.b (a1)+,d0				; d0 = output result
;; move.b d0,(a2)				; add to cache. Don't need to increment

	ld c,(hl)
	inc hl

	ld de,(ymp_save_a2)
	ld a,c
	ld (de),a

; Handle the *read* pointer hitting the end of the cache
; The write pointer check is done in one single go since all sizes are the same
; This check is done even if literals are copied, it just won't ever pass the check

;; cmp.l d5,a1					; has match read ptr hit end of cache?
;; bne.s .noloop_cache_read
	ld de,(ymp_save_d5)
	ld a,e
	cp l
	jr nz,ymp_noloop_cache_read
	ld a,d
	cp h
	jr nz,ymp_noloop_cache_read
;; sub.w d3,a1					; move back in cache
	ld de,(ymp_save_d3)
	or a
	sbc hl,de

ymp_noloop_cache_read	;; .noloop_cache_read
;; move.l a1,ymunp_match_read_ptr(a3)
	ld (ix+ymunp_match_read_ptr+0),l
	ld (ix+ymunp_match_read_ptr+1),h

; d0 is "output" here

;; move.b d0,(a6)+				; write to output buffer
ypu_save_a6 equ $+1
	ld hl,#0000
	ld (hl),c
	inc hl
	ld (ypu_save_a6),hl

; Move on to the next register

;;	add.w d3,a2					; next ymp_cache_write_ptr
	ld bc,(ymp_save_d3)
	ld hl,(ymp_save_a2)
	add hl,bc

	ex de,hl		; hl = xx - de = a2

;;	add.l d3,d5					; next cache_end ptr
	ld hl,(ymp_save_d5)
	add hl,bc

	ex de,hl		; hl = a2 - de = d5

;; add.w d2,a3					; next stream structure
	ld bc,ymunp_size
	add ix,bc

;; dbf d1,ymp_register_loop
ymp_register_loop_count_w equ $+1
	ld bc,#0000		; bc = d1
	dec bc
	ld (ymp_register_loop_count_w),bc

	ld a,c
	and a,b
	inc a			; cp #ff
	jp nz,ymp_register_loop

; Update and wrap the set offset

;; move.w ymset_cache_offset(a5),d4
	ld l,(iy+ymset_cache_offset+0)
	ld h,(iy+ymset_cache_offset+1)
;; addq.w #1,d4
	inc hl
;; cmp.w d3,d4					;hit the cache size?
;; bne.s .no_cache_loop
	ld de,(ymp_save_d3)
	ld a,e
	cp l
	jr nz,ymp_no_cache_loop
	ld a,d
	cp h
	jr nz,ymp_no_cache_loop

;; moveq #0,d4
	ld hl,#0000

ymp_no_cache_loop		;; .no_cache_loop
;; move.w d4,ymset_cache_offset(a5)
	ld (iy+ymset_cache_offset+0),l
	ld (iy+ymset_cache_offset+1),h
;; addq.l #ymset_size,a5
	ld de,ymset_size
	add iy,de

;; bra ymp_set_loop
	jp ymp_set_loop

; If the previous byte read was 0, read 2 bytes to generate a 16-bit value

read_extended_number

; bc = d0
; hl = a1

;; tst.b d0
;; bne.s valid_count
	ld a,c
	or a
	ret nz	; jr nz,valid_count

;; move.b (a1)+,d0
;; lsl.w #8,d0
;; move.b (a1)+,d0
	ld b,(hl)
	inc hl
	ld c,(hl)
	inc hl

;; valid_count
;; rts
	ret
; ---------------------------
; some MACROs
; ---------------------------

MACRO GET_YMP_OUTPUT_BUFFER_A6

	ld a,(hl)
	inc hl

	add a,ymp_a6
	ld c,a
	adc a,ymp_a6/#100
	sub a,c
	ld b,a

	ld a,(bc)

ENDM

MACRO SEND_PACK_DATA_AY

	ld b,#f4	; PPI port A data
	out (c),d	; send register number

	ld b,#f6	; PPI port C
	in a,(c)	; read value
	or #c0		; select PSG register
	out (c),a
	and #3f		; set inactive
	out (c),a
	ld e,a

	GET_YMP_OUTPUT_BUFFER_A6

	ld b,#f4	; PPI port A data
	out (c),a	; send register data value

	ld b,#f6	; PPI port C
	ld a,e
	or #80		; write to selected PSG register
	out (c),a	; send
	out (c),e	; set inactive

ENDM
; ---------------------------
ymp_sets_done
; ---------------------------
;; ym_write

; We could write these in reverse order and reuse a6?

;; lea ymp_output_buffer(a0),a6
;; move.l ymp_register_list_ptr(a0),a5
;; moveq #0,d0

	ld hl,(a0_psa+ymp_register_list_ptr)

	ld d,#00

write_reg_06_00
	SEND_PACK_DATA_AY

	inc d
	ld a,d
	cp #07
	jr nz,write_reg_06_00

; Generate the mixer register
; We need channels 8, 9, 10
; These are 7,8,9 in the packed stream.

;;	move.b	7(a5),d0
;;	move.b	(a6,d0.w),d1				; d1 = mixer A
;;	move.b	8(a5),d0
;;	move.b	(a6,d0.w),d2				; d2 = mixer B
;;	move.b	9(a5),d0
;;	move.b	(a6,d0.w),d3				; d3 = mixer C

; Accumulate mixer by muxing each channel volume top bits
; Repeat twice, the first time for noise enable bits,
; the second time for square

;;	moveq	#0,d4
;;	rept	2
;;	add.b	d3,d3
;;	addx.w	d4,d4					; shift in top bit channel C
;;	add.b	d2,d2
;;	addx.w	d4,d4					; shift in top bit channel B
;;	add.b	d1,d1
;;	addx.w	d4,d4					; shift in top bit channel A
;;	endr

	ld a,(hl)				; d1 = mixer A
	inc hl

	add a,ymp_a6
	ld e,a
	adc a,ymp_a6/#100
	sub a,e
	ld d,a

	ld a,(de)
	ld c,a					; c = d1

	ld a,(hl)				; d2 = mixer B
	inc hl

	add a,ymp_a6
	ld e,a
	adc a,ymp_a6/#100
	sub a,e
	ld d,a

	ld a,(de)
	ld b,a					; b = d2

	ld a,(hl)				; d3 = mixer C
;	inc hl

	add a,ymp_a6
	ld e,a
	adc a,ymp_a6/#100
	sub a,e
	ld d,a

	ld a,(de)
	ld e,a					; e = d3

	dec hl
	dec hl

MACRO SHIFT_IN_TOP_BIT_CHAN REGV, REGV7

	ld a,REGV
	add a,a
	ld REGV,a
	ld a,REGV7
	adc a,REGV7
	ld REGV7,a
	
ENDM

	ld d,#00

REPEAT 2

	SHIFT_IN_TOP_BIT_CHAN e,d
	SHIFT_IN_TOP_BIT_CHAN b,d
	SHIFT_IN_TOP_BIT_CHAN c,d

REND

;;	lea	$ffff8800.w,a3
;;	lea	$ffff8802.w,a1

; Write registers 0-6 inclusive

;;r	set	0
;;	rept	7
;;	move.b	(a5)+,d0				; fetch depack stream index for this reg
;;	move.b	#r,(a3)
;;	move.b	(a6,d0.w),(a1)
;;r	set	r+1
;;	endr

; Now mixer

;;	move.b	#7,(a3)
;;	move.b	(a3),d1
;;	and.b	#$c0,d1					; preserve top 2 bits (port A/B direction)
;;	or.b	d1,d4
;;	move.b	d4,(a1)

	ld a,#07

	ld b,#f4	; PPI port A data
	out (c),a	; send register number

	ld b,#f6	; PPI port C
	in a,(c)	; read value
	or #c0		; select PSG register
	out (c),a
	and #3f		; set inactive
	out (c),a
	ld e,a

	ld b,#f4	; PPI port A data
	; in a,(c)	; dummy on cpc ;-)
	; or #c0
	; or d
	; out (c),a
	out (c),d	; send register data value

	ld b,#f6	; PPI port C
	ld a,e
	or #80		; write to selected PSG register
	out (c),a	; send
	out (c),e	; set inactive

; Now 8,9,10,11,12

;;	rept	5
;;	move.b	(a5)+,d0				; fetch depack stream index for this reg
;;	move.b	#r+1,(a3)
;;	move.b	(a6,d0.w),(a1)
;;r	set	r+1
;;	endr

	ld d,#08

write_reg_08_12
	SEND_PACK_DATA_AY

	inc d
	ld a,d
	cp #0d
	jr nz,write_reg_08_12

; Reg 13 - buzzer envelope

;;	move.b	(a5)+,d0				; fetch depack stream index for this reg
;;	move.b	(a6,d0.w),d0				; Buzzer envelope register is special case,
;;	bmi.s	.skip_write

	ld a,(hl)

	add a,ymp_a6
	ld c,a
	adc a,ymp_a6/#100
	sub a,c
	ld b,a

	ld a,(bc)
	or a
	jp m,ymp_skip_write

;;	move.b	#13,(a3)				; only write if value is not -1
;;	move.b	d0,(a1)					; since writing re-starts the envelope

	ld b,#f4	; PPI port A data
	out (c),d	; send register number
	ld d,a

	ld b,#f6	; PPI port C
	in a,(c)	; read value
	or #c0		; select PSG register
	out (c),a
	and #3f		; set inactive
	out (c),a
	ld e,a

	ld b,#f4	; PPI port A data
	out (c),d	; send register data value

	ld b,#f6	; PPI port C
	ld a,e
	or #80		; write to selected PSG register
	out (c),a	; send
	out (c),e	; set inactive

ymp_skip_write		;; .skip_write

; Check for tune restart

;; subq.l #1,ymp_vbl_countdown(a0)
;; bne.s .no_tune_restart
	ld bc,(a0_psa+ymp_vbl_countdown)
	dec bc
	ld (a0_psa+ymp_vbl_countdown),bc
	ld a,c
	or b
	ret nz	; jr nz,ymp_no_tune_restart

;; move.l ymp_tune_ptr(a0),a1
	ld hl,(a0_psa+ymp_tune_ptr)

; This should rewrite the countdown value and
; all internal variables

;; a1 = start of packed ym data

;; bsr ymp_player_restart
	jp ymp_player_restart	; call ymp_player_restart

;;.no_tune_restart
;;	rts
; ymp_no_tune_restart
;	ret
