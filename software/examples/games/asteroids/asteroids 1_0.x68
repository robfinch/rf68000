;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;														;
;	ASTEROIDS type game for the EASy68k simulator	2009/05/17	V1.00			;
;														;
;	The objective of of the game is to score as many points as possible by		;
;	destroying asteroids and flying saucers. You control a triangular ship		;
;	that can rotate, fire shots forward and thrust forward. As the ship moves,	;
;	momentum is not conserved, the ship eventually comes to a stop when not		;
;	thrusting. In moments of extreme danger you can send the ship into		;
;	hyperspace, causing it to disappear and reappear in a random location.		;
;														;
;	Each wave starts with the asteroids drifting in random directions onto the	;
;	screen. Objects wrap around screen edges, an asteroid that drifts off the	;
;	left edge of the screen reappears at the right and continues moving in the	;
;	same direction. As you shoot asteroids they break into smaller asteroids	;
;	that often move faster and are more difficult to hit. The smaller the		;
;	asteroid the higher the points scored.							;
;														;
;	Every so often a flying saucer will appear on one side of the screen and	;
;	move to the other before disappearing again. Large saucers fire in random	;
;	directions, while small saucers aim their fire towards the player's ship.	;
;														;
;	Once all of the asteroids and flying saucers have been cleared a new set of	;
;	large asteroids appears. The number of asteroids increases by two each round	;
;	up to a maximum of eleven. The game continues until all the player lives	;
;	are lost, a bonus life being awarded for each 10,000 points scored up to a	;
;	maximum of 255 lives. A maximum of only 18 lives are shown on screen.		;
;														;
;	Like the original game the maximum possible score in this game is 99,990	;
;	points after which it rolls over back to zero.						;
;														;
;	Also like the original game some game parameters can be set using the		;
;	switches in the hardware window. These can be changed at any time during	;
;	the game.												;
;														;
;	Switch	Function										;
;	------	--------										;
;	7 - 3		Unused										;
;	  2		Starting ship count. On = 4, off = 3					;
;	1 - 0		Language	1	0								;
;					off	off	English						;
;					off	on	German						;
;					on	off	French						;
;					on	on	Spanish						;
;														;
;	Game controls...											;
;														;
;	 [1] or [2] for a one or two player game start						;
;	 [s] to toggle the sound off and on								;
;														;
;	 [q] to rotate the ship widdershins								;
;	 [w] to rotate the ship deocil								;
;	 [l] to fire the ship thruster								;
;	 [p] to fire the ship weapon									;
;	 [SPACE] to jump to hyperspace								;
;														;
;	Other keys are:											;
;														;
;	 The F2, F3 and F4 keys can be used to select a screen size of 640 x 480,	;
;	 800 x 600 and 1024 x 768 respectively.							;
;														;
;	The game saves the high scores in the file asteroids.hi If this file is		;
;	not present it will be created after the first high score is entered. If	;
;	this file is read only new high scores will not be saved. No check is made	;
;	on the validity of this file, editing the file may cause the game to crash.	;
;														;
;	This version for Sim68K 4.6.0 or later							;
;														;
;	More 68000 and other projects can be found on my website at ..			;
;														;
;	 http://mycorner.no-ip.org/index.html							;
;														;
;	mail : leeedavison@googlemail.com								;
;														;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; a0 = system calls and volatile
; a1 = system calls and volatile
; a2 = volatile
; a3 = variables base address
; a4 = vector list pointer
; a5 = player 1 / current player
; a6 = player 2 / other player
; a7 = stack pointer


	ORG	$10000
	code
	even

asteroids_start:
	bsr	Initialise				; go setup everything
	bsr reset_game				; clear the scores and set the ship start count

; main loop. this is executed at most once every 16ms, as it waits for the 16ms counter
; to be incremented from zero since the last loop

main_loop:
	moveq	#94,d0					; copy screen buffer to main (page flip)
	trap #15

	jsr clear_bitmap_screen4
;	move.w #$FF00,d1			; clear screen
;	moveq #11,d0					; position cursor
;	trap #15

;	bsr sound_key					; handle the sound key
	bsr s_controls				; go check the screen controls

	move.l tickcnt,d0
.0001:
	cmp.l tickcnt,d0
	beq.s .0001
	moveq #1,d0
;wait_16ms
;	MOVE.b	sixteen_ms(a3),d0		; get the 16ms counter
;	BEQ.s		wait_16ms			; if not there yet just loop

;	clr.b	sixteen_ms(a3)			; clear the 16ms counter
	add.w d0,game_count(a3)		; increment the game counter
	add.b d0,time_count(a3)		; increment the timeout counter

	lea vector(pc),a4			; reset the vector RAM pointer

	bsr game_message			; do "PLAYER x", "GAME OVER" or credit messages

	bsr check_hiscores		; do the high score checks
	bsr enter_hiscores		; get the player high score entries
	bpl.s no_play					; if the high scores are being entered skip the
												; active play routines

	bsr high_scores				; display the high score table if the game is
												; over
	bcs.s	no_play					; if the high score table was displayed skip
												; active play

	tst.b px_time(a3)			; test the "PLAYER x" timer
	bne.s px_hide					; skip the control checks if the "PLAYER x"
												; timer is not timed out

	tst.b num_players(a3)	; test the number of players in the game
	beq.s skip_player_cont		; if no players skip the player controls

	tst.b p_flag_off(a5)			; test the player flag
	bmi.s skip_player_move		; if the player is exploding skip the player
														; move controls

	bsr	ship_fire					; handle the fire button			##
	bsr	hyperspace				; handle the hyperspace button		##
skip_player_move
	bsr ship_move					; handle ship rotation and thrust		##
skip_player_cont
	bsr do_saucer					; handle the saucer
px_hide
	bsr move_items				; move all the objects and add them to the
												; vector list
	bsr check_hits				; check for player/saucer/shot hits
no_play
	bsr static_messages		; add (c), scores and players ships to the
												; vector list

	bsr fx_sounds					; do the saucer and thump sounds

	move.w #HALT,(a4)+		; add HALT to the vector list

	lea vector(pc),a4			; reset the vector RAM pointer
	bsr do_vector					; go do the vector list, draw them

	move.b new_rocks(a5),d0			; test the generate new rocks flag
	beq.s no_dec_new_rocks			; if counted out skip the decrement

	subq.b #1,new_rocks(a5)			; else decrement the generate new rocks flag
no_dec_new_rocks
	or.b rock_count(a5),d0			; OR the new rocks flag with the rock count
	bne main_loop					; if not counted out or still rocks go do the
												; main loop

	pea main_loop					; return to the main loop
	bra make_rocks				; go generate new rocks


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; do "PLAYER x", "GAME OVER" or credit messages

game_message:
	tst.b num_players(a3)		; test the number of players in the game
	beq.s do_start_mess			; if no players go do the start message

	tst.b px_time(a3)				; test the "PLAYER x" timer
	beq.s game_over					; if timed out go do "GAME OVER" or thump
													; sound count

	subq.b #1,px_time(a3)		; decrement the "PLAYER x" timer
	bra player_x						; add "PLAYER x" to the vector list and return

; do the push start message

do_start_mess:
	moveq #5,d0					; GetKey
	trap #15
	tst.l d1
	bmi.s push_start_mess
	moveq #1,d0
	cmpi.b #'1',d1
	beq.s start_game
	cmpi.b #'2',d1
	bne.s push_start_mess

;	MOVE.l	#'2121',d1			; [2][1][2][1] key
;	MOVEQ		#19,d0			; check for keypress
;	TRAP		#15

;	MOVEQ		#1,d0				; default to one player
;	TST.b		d1				; test the [1] key result
;	BMI.s		start_game			; if pressed go start a one player game

;	TST.w		d1				; test the [2] key result
	;BPL.s		push_start_mess		; if not pressed go do the "PUSH START" message

							; else the two player start was pressed
	lea player_2(a3),a5		; set the pointer to player two's variables
	bsr reset_game				; clear the score and set the ship start count
	bsr player_init				; initialise the player variables
	bsr make_rocks				; generate new rocks
	moveq #2,d0						; set two players in this game

; one or two player game start

start_game:
	move.b d0,num_players(a3)	; save the number of players in the game

	clr.b player_idx(a3)			; clear the player index
	lea	player_1(a3),a5				; set the pointer to player one's variables
	lea player_2(a3),a6				; set the pointer to player two's variables

	bsr reset_game				; clear the scores and set the ship start count
	bsr player_init				; initialise the player variables
	bsr make_rocks				; generate new rocks

	moveq #0,d0						; clear the longword
	move.w d0,score_off(a5)		; clear player 1's score
	move.w d0,score_off(a6)		; clear player 2's score

	move.b #$80,px_time(a3)		; set the "PLAYER x" timer
	move.b #$04,thump_time(a3)	; set the thump sound change timer
	rts

; else do the "PUSH START" message

push_start_mess:
	move.b p1_high(a3),d0			; get the player 1 highscore flag
	and.b p2_high(a3),d0			; and with the player 2 highscore flag
	bpl.s exit_push_start			; if either player is entering their high score
														; skip the "PUSH START" message

	moveq #$06,d1								; message 6 - "PUSH START"
	btst.b #5,game_count+1(a3)	; test a bit in the game counter low byte
	beq add_message							; if set add message d1 to the display list
															; and return
exit_push_start
	rts

; do "GAME OVER" or thump sound count

game_over:
	moveq #$3F,d0							; set the game counter mask
	and.w game_count(a3),d0		; mask the game counter
	bne.s nodec_thmpi					; branch if not zero

							; gets here 1/64th of the time
	cmpi.b #6,thmp_sndi(a5)		; compare the thump sound change timer initial
							; value with the minimum value
	beq.s nodec_thmpi					; if there already don't decrement it

	subq.b #1,thmp_sndi(a5)		; else decrement the thump sound change timer
							; initial value
nodec_thmpi
	tst.b ships_off(a5)			; test the player ship count
	bne.s no_game_over			; if ships left skip game over

							; else this player has no ships left
	move.b p_fire_off(a5),d0		; get player fire 1
	or.b p_fire_off+1(a5),d0		; OR with player fire 2
	or.b p_fire_off+2(a5),d0		; OR with player fire 3
	or.b p_fire_off+3(a5),d0		; OR with player fire 4
	bne.s no_game_over			; if shots still flying skip the game over

	moveq #7,d1							; else message 7 - "GAME OVER"
	bsr add_message					; add message d1 to the display list

	cmpi.b #$02,num_players(a3)	; compare the number of players with two
	bne.s no_game_over			; if not two player skip which game's over

	bsr player_x						; add "PLAYER x" to the vector list
no_game_over
	tst.b p_flag_off(a5)		; test the player flag
	bne.s	exit_game_message		; if alive or exploding just exit

	cmpi.b #$80,hide_p_cnt(a5)	; compare with about to die - 1 with the hide
							; the player count
	bne.s exit_game_message			; if not about to die just exit

	move.b #$10,hide_p_cnt(a5)	; set the hide the player count

	move.b num_players(a3),d1	; get the number of players in the game

	move.b p1_ships(a3),d0		; get player 1's ship count
	or.b p2_ships(a3),d0			; OR with player 2's ship count
	beq.s end_game					; if no ships left go end the game

	bsr clear_saucer				; clear the saucer and restart the saucer timer
	subq.b #1,d1						; decrement the number of players in the game
	beq.s exit_game_message	; if that was the last player go flag no game
							; and exit

	move.b #$80,px_time(a3)		; set the "PLAYER x" timer

	tst.b ships_off(a6)			; test the other player's ship count
	beq.s exit_game_message		; if no ships left go flag no game and exit

														; else change to the other player
	eori.b #1,player_idx(a3)		; toggle the player index
	exg a5,a6									; swap the player pointers
exit_game_message
	rts

; neither player has any ships left so end the game

end_game:
	move.b d1,past_play(a3)		; save the number of players that were in the
							; game
	move.b #$FF,num_players(a3)	; clear the number of players in the game
	lea player_1(a3),a5		; set the pointer to player one's variables
	lea player_2(a3),a6		; set the pointer to player two's variables
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; check for player/saucer/shot hits

check_hits:
	moveq #flag_end-p_flag_off-1,d6
							; set the count/index for player/saucer/shots
pss_check_loop
	tst.b p_flag_off(a5,d6.w)	; test if the player/saucer/shot exists
	bgt.s check_pss			; if the item exists and is not exploding go
							; test it

next_pss
	dbf d6,pss_check_loop	; decrement count/index and loop if more to do

	rts

; the player/saucer/shot exists and is not exploding

check_pss
	moveq #s_flag_off-flags_off,d7
							; set the item index to the saucer
	cmpi.w #p_fire_off-p_flag_off,d6
							; compare the player/saucer/shot index with the
							; first player shot
	bcc.s check_all			; if it is a player shot go test it against all
							; the items

	subq.w #1,d7				; else skip the saucer
	tst.w d6						; test the player/saucer/shot index
	bne.s check_all			; if not the player go test against everything

							; else skip the player
check_next_object
	subq.w #1,d7				; decrement the item index
	bmi.s next_pss			; if all done go do next player/saucer/shot

check_all
	MOVE.b	flags_off(a5,d7.w),d2	; get the item flag indexed by d7
	BLE.s		check_next_object		; if the item doesn't exist or the item is
							; exploding go try the next item

	MOVE.w	d7,d5				; copy the item index
	ADD.w		d5,d5				; ; 2 for the item position index

	MOVE.w	d6,d4				; copy the fire item index
	ADD.w		d4,d4				; ; 2 for the fire item position index

	MOVE.w	x_pos_off(a5,d5.w),d0	; get item x position
	SUB.w		p_xpos_off(a5,d4.w),d0	; subtract the player/saucer/shot x position
	BPL.s		delta_x_pos			; if the delta is positive skip the negate

	NEG.w		d0				; else negate the delta
delta_x_pos
	CMPI.w	#$0151,d0			; compare the range with $0151
	BCC.s		check_next_object		; if it's out of range go try the next item

	MOVE.w	y_pos_off(a5,d5.w),d1	; get item y position
	SUB.w		p_ypos_off(a5,d4.w),d1	; subtract the player/saucer/shot y position
	BPL.s		delta_y_pos			; if the delta is positive skip the negate

	NEG.w		d1				; else negate the delta
delta_y_pos
	CMPI.w	#$0151,d1			; compare the range with $0151
	BCC.s		check_next_object		; if it's out of range go try the next item

	MULU.w	d0,d0				; calculate delta x^2
	MULU.w	d1,d1				; calculate delta y^2
	ADD.l		d1,d0				; calculate delta x^2 + delta y^2
	ASR.l		#2,d0				; / 4 makes it a word value again

	ANDI.w	#$07,d2			; mask the size bits
	SUBQ.b	#1,d2				; make $01 to $04 into $00 to $03
	ADD.b		d2,d2				; ; 2 bytes per size^2

	CMPI.w	#s_flag_off-p_flag_off,d6
							; compare the player/saucer/shot index with the
							; saucer
	BGT.s		no_add_size			; if shot index just go get the collision size

	BMI.s		add_p_size			; if player index only add the player offset

	BTST.b	#1,p_flag_off(a5,d6.w)	; else test the saucer size flag
	BEQ.s		small_s_size		; if not size $02 only add the small saucer size

	ADDQ.w	#col_table_l-col_table_s,d2
							; add the offset to the item + large saucer size
							; table
small_s_size
	ADDQ.w	#col_table_s-col_table_p,d2
							; add the offset to the item + small saucer size
							; table
add_p_size
	ADDQ.w	#col_table_p-col_table,d2
							; add the offset to the item + player size table
no_add_size
	MOVE.w	col_table(pc,d2.w),d2	; get the collision size from the table

	CMP.w		d0,d2				; compare the distance^2 with the collision size
	BCS.s		check_next_object		; if it's out of range go try the next item

	PEA		next_pss(pc)		; now go try the next fire item, this one died
	BRA.s		handle_collision		; else go handle a collision between items

; table of collision distance squares

col_table
	dc.w	$06E4			; $24^2		small rock, small saucer, player
	dc.w	$1440			; $48^2		medium rock, large saucer
	dc.w	$0000			; no size 3 rock
	dc.w	$4410			; $84^2		large rock
col_table_p
	dc.w	$1000			; ($24 + $1C)^2	small rock  + player
	dc.w	$2710			; ($48 + $1C)^2	medium rock + player
	dc.w	$0000			; no size 3 rock
	dc.w	$6400			; ($84 + $1C)^2	large rock  + player
col_table_s
	dc.w	$0B64			; ($24 + $12)^2	small rock  + small saucer
	dc.w	$1FA4			; ($48 + $12)^2	medium rock + small saucer
	dc.w	$0000			; no size 3 rock
	dc.w	$57E4			; ($84 + $12)^2	large rock  + small saucer
col_table_l
	dc.w	$1440			; ($24 + $24)^2	small rock  + large saucer
	dc.w	$2D90			; ($48 + $24)^2	medium rock + large saucer
	dc.w	$0000			; no size 3 rock
	dc.w	$6E40			; ($84 + $24)^2	large rock  + large saucer


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; handle collision between items
;
; d6 = X = player/saucer/shot index
; d7 = Y = object index

handle_collision:
	CMPI.w	#s_flag_off-p_flag_off,d6
							; compare the player/saucer/shot index with the
							; saucer
	BNE.s		not_saucer			; if not the saucer go find out what it was

							; else the saucer hit something
	CMPI.w	#p_flag_off-flags_off,d7
							; compare the object with the player index
	BNE.s		not_player			; if not the player go find out what it was

							; else the saucer hit the player so make it that
							; the player hit the saucer
	MOVEQ		#s_flag_off-flags_off,d7
							; make the object the saucer
	MOVEQ		#p_flag_off-p_flag_off,d6
							; make the player/saucer/shot index the player
not_saucer
	TST.w		d6				; test the player/saucer/shot index
	BNE.s		not_pss_player		; if it's not the player go find out what it was

; the player hit something

	MOVE.b	#$81,hide_p_cnt(a5)	; set the hide the player count
	SUBQ.b	#1,ships_off(a5)		; decrement the player's ship count

; either the player hit the saucer or the player or saucer hit either a rock or a shot

not_player
	MOVE.b	#$A0,p_flag_off(a5,d6.w)
							; set the item is exploding flag
	MOVEQ		#0,d0				; clear the longword
	MOVE.b	d0,p_xvel_off(a5,d6.w)	; clear the player/saucer/shot x velocity
	MOVE.b	d0,p_yvel_off(a5,d6.w)	; clear the player/saucer/shot y velocity
	CMPI.w	#p_flag_off-flags_off,d7
							; compare the object with the player index
	BCS.s		what_hit_rock		; if less go handle something hitting a rock

	BRA.s		what_hit_saucer		; else go handle something hitting the saucer

; else a shot hit something

not_pss_player
	CLR.b		p_flag_off(a5,d6.w)	; clear the shot object
	CMPI.b	#p_flag_off-flags_off,d7
							; compare the item with the player's index
	BEQ.s		player_shot			; if it's the player go handle a shot hitting
							; the player

	BCC.s		what_hit_saucer		; if it's the saucer go handle a shot hitting
							; the saucer

what_hit_rock
	BSR		hit_a_rock			; handle something hitting a rock

; explode the object

explode_object
	MOVEQ		#$03,d1			; set the mask for the two size bits
	AND.b		flags_off(a5,d7.w),d1	; and it with the item flag
	ADDQ.b	#sexpl_snd,d1		; add the small explosion sound to the size
	BSR		play_sample			; go play the sample

	MOVE.b	#$A0,flags_off(a5,d7.w)	; set the item to exploding
	CLR.b		x_vel_off(a5,d7.w)	; clear the item x velocity byte
	CLR.b		y_vel_off(a5,d7.w)	; clear the item y velocity byte
	RTS

; handle a shot hitting the player

player_shot
	SUBQ.b	#1,ships_off(a5)		; decrement the player's ship count
	MOVE.b	#$81,hide_p_cnt(a5)	; set the hide the player count
	BRA.s		explode_object		; go explode the player

; handle something hitting the saucer

what_hit_saucer
	MOVE.b	i_sauc_tim(a5),sauc_cntdn(a5)
							; save the small saucer boundary/initial saucer
							; value to the saucer countdown timer
	TST.b		num_players(a3)		; test the number of players in the game
	BEQ.s		explode_object		; if no players skip adding the score

	MOVEQ		#$99,d1			; default to 990 points for a small saucer
	BTST.b	#0,s_flag_off(a5)		; test the saucer size bit
	BNE.s		keep_small			; if it was a small saucer keep the score value

	MOVEQ		#$20,d1			; else set 200 points for the large saucer
keep_small
	BSR		add_score			; add d1 to the current player's score
	BRA.s		explode_object		; go explode the saucer


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; handle the saucer

do_saucer
	MOVEQ		#-4,d0			; set the timeout counter mask
	AND.b		time_count(a3),d0		; mask the timeout counter
	BEQ		exit_do_saucer		; 3/4 of the time just exit

	EOR.b		d0,time_count(a3)		; reset the timeout counter

	TST.b		s_flag_off(a5)		; test the saucer flag
	BMI		exit_do_saucer		; if the saucer is exploding just exit

	BNE		existing_saucer		; if a saucer exists go handle it

; no saucer exists so possibly generate a new one

	TST.b		num_players(a3)		; test the number of players in the game
	BEQ.s		attract_saucer		; if no players go do the attract mode saucer

	TST.b		p_flag_off(a5)		; test the player flag
	BEQ		exit_do_saucer		; if this player doesn't exist just exit

	BMI		exit_do_saucer		; if this player is exploding just exit

attract_saucer
	TST.b		r_hit_tim(a5)		; test the rock hit timer
	BEQ.s		rock_hit_out		; if counted out skip the decrement

	SUBQ.b	#1,r_hit_tim(a5)		; else decrement the rock hit timer
rock_hit_out
	SUBQ.b	#1,sauc_cntdn(a5)		; decrement the saucer countdown timer
	BNE		exit_do_saucer		; if not there yet just exit

	MOVE.b	#$12,sauc_cntdn(a5)	; set the first saucer fire count

	TST.b		r_hit_tim(a5)		; test the rock hit timer
	BEQ.s		dec_isaucer_time		; if timed out go decrement the initial saucer
							; timer

	MOVE.b	rock_count(a5),d0		; get the rock count
	BEQ.s		exit_do_saucer		; if no rocks just exit

	CMP.b		min_rocks(a5),d0		; compare the rock count with the minimum rock
							; count before the saucer initial timer starts
							; to decrement
	BLS.s		exit_do_saucer		; if the minimum rock count is >= the rock count
							; just exit

dec_isaucer_time
	MOVEQ		#-6,d0			; set to subtract 6
	ADD.b		i_sauc_tim(a5),d0		; subtract it from the small saucer
							; boundary/initial saucer timer
	CMPI.b	#$20,d0			; compare it with the minimum value
	BCS.s		no_save_ist			; if less skip the save

	MOVE.b	d0,i_sauc_tim(a5)		; save the small saucer boundary/initial saucer
							; timer
no_save_ist
	BSR		gen_prng			; generate the next pseudo random number
	MOVE.w	PRNlword(a3),d0		; get a pseudo random word
	CMPI.w	#$1800,d0			; compare with $1800
	BCS.s		saucer_yok			; if less than $1800 just use it

	ANDI.w	#$17FF,d0			; else mask to $17xx
saucer_yok
	MOVE.w	d0,s_ypos_off(a5)		; save the saucer y position

	MOVEQ		#0,d0				; clear the saucer x position
	MOVEQ		#$10,d1			; set the saucer x velocity to + $10
	TST.w		PRNlword+2(a3)		; test a pseudo random word
	BMI.s		start_left			; if bit set start on the left

							; else start at the right side and move left
	MOVE.w	#$1FFF,d0			; set the saucer x position
	MOVEQ		#$F0,d1			; set the saucer x velocity to - $10
start_left
	MOVE.b	d1,s_xvel_off(a5)		; save the saucer x velocity byte
	MOVE.w	d0,s_xpos_off(a5)		; save the saucer x position

	MOVEQ		#$02,d1			; default to a large saucer
	TST.b		i_sauc_tim(a5)		; test the small saucer boundary/initial saucer
							; timer
	BMI.s		save_saucer			; if > $80 always make a big saucer

	CMPI.b	#$30,score_off(a5)	; compare the player's score with 30000 points
	BCC.s		small_saucer		; if >= 30000 points go make a small saucer

	BSR		gen_prng			; generate the next pseudo random number
	MOVE.b	i_sauc_tim(a5),d2		; get the small saucer boundary/initial saucer
							; timer
	LSR.b		#1,d2				; / 2
	CMP.b		PRNlword+2(a3),d2		; compare it with the random byte
	BCC.s		save_saucer			; if the small saucer boundary is > the random
							; byte go save the large saucer

small_saucer
	MOVEQ		#$01,d1			; else make it a small saucer
save_saucer
	MOVE.b	d1,s_flag_off(a5)		; save the saucer flag
exit_do_saucer
	RTS

; there is an existing saucer

existing_saucer
	MOVEQ		#$7E,d0			; set saucer change mask
	AND.w		game_count(a3),d0		; mask the game counter
	BNE.s		keep_saucer_dir		; if it was not x000 000x skip the saucer
							; direction change

	BSR		gen_prng			; generate the next pseudo random number
	MOVEQ		#3,d0				; set the direction mask
	AND.b		PRNlword(a3),d0		; mask a pseudo random byte
	MOVE.b	saucer_yvel(pc,d0.w),s_yvel_off(a5)
							; save the saucer y velocity byte
keep_saucer_dir
	TST.b		num_players(a3)		; test the number of players in the game
	BEQ.s		attract_fire		; if no players just go do the fire countdown

	TST.b		hide_p_cnt(a5)		; test the hide the player count
	BNE.s		exit_existing_saucer	; if the player is hidden just exit

attract_fire
	SUBQ.b	#1,sauc_cntdn(a5)		; decrement the saucer countdown timer
	BEQ.s		fire_saucer			; if counted out go fire

exit_existing_saucer
	RTS

; saucer y velocity byte

saucer_yvel
	dc.b	$F0			; down
	dc.b	$00			; horizontal
	dc.b	$00			; horizontal
	dc.b	$10			; up


; handle the saucer fire

fire_saucer
	MOVE.b	#$0A,sauc_cntdn(a5)	; set the time between saucer shots, save the
							; countdown timer
	MOVEQ		#1,d0				; set the mask for a small saucer
	AND.b		s_flag_off(a5),d0		; mask the saucer flag
	BNE.s		aim_shot			; if it's a small saucer go aim at the player

	BSR		gen_prng			; generate the next pseudo random number
	MOVE.b	PRNlword(a3),d0		; get a pseudo random byte
	BRA.s		no_aim_shot			; and go fire wildly in any direction

; aim the shot at the player

aim_shot
	MOVE.b	s_xvel_off(a5),-(sp)	; copy the saucer x velocity byte
	MOVE.w	(sp)+,d0			; get the byte as a word
	CLR.b		d0				; clear the low byte
	ASR.w		#1,d0				; / 2

	MOVE.w	p_xpos_off(a5),d1		; get the player x position
	SUB.w		s_xpos_off(a5),d1		; subtract the saucer x position
	ASL.w		#2,d1				; ; 4 delta x

	SUB.w		d0,d1				; subtract the half saucer x velocity word

	MOVE.b	s_yvel_off(a5),-(sp)	; copy the saucer y velocity byte
	MOVE.w	(sp)+,d0			; get the byte as a word
	CLR.b		d0				; clear the low byte
	ASR.w		#1,d0				; / 2

	MOVE.w	p_ypos_off(a5),d2		; get the player y position
	SUB.w		s_ypos_off(a5),d2		; subtract the saucer y position
	ASL.w		#2,d2				; ; 4 delta x low byte

	SUB.w		d0,d2				; subtract the half saucer y velocity word

	BSR		get_atn			; calculate the angle given the delta x,y in
							; d1.w,d2.w
	MOVE.b	d0,s_orient(a3)		; save the saucer shot direction

	BSR		gen_prng			; generate the next pseudo random number
	MOVEQ		#0,d1				; set index to +/- $0F degree units perturbation
	MOVE.b	PRNlword(a3),d0		; get a pseudo random byte
	CMPI.b	#$35,score_off(a5)	; compare the player's score with 35000
	BCS.s		wide_shot			; if less than 35000 skip the index change

	MOVEQ		#1,d1				; set index to +/- $07 degree units perturbation
wide_shot
	AND.b		shot_mask(pc,d1.w),d0	; mask with the shot AND mask
	BPL.s		no_shot_or			; if the result is positive skip the bit set

	OR.b		shot_or(pc,d1.w),d0	; else set the correct bits for a negative
							; perturbation
no_shot_or
	ADD.b		s_orient(a3),d0		; add the saucer shot direction to the
							; perturbation
no_aim_shot
	MOVE.b	d0,s_orient(a3)		; save the saucer shot direction

	MOVEQ		#1,d4				; set the index to the saucer velocity
	MOVEQ		#2,d5				; set the index to the saucer position
	MOVEQ		#-1,d6			; set the minimum shot index - 1
	MOVEQ		#1,d7				; set the shot start index

	MOVE.b	last_fire(a3),d1		; get the fire last state
	BRA.s		test_fire_loop		; go fire the shot


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; these two byte pairs together effect the accuracy of the small saucer's shooting
; by limiting the range of the random perturbation to the saucer's aim

; shot AND mask, masks the perturbation to either +/- $0F or +/- $07 degree units

shot_mask
	dc.b	$8F			; AND mask to +/- $0F degree units
	dc.b	$87			; AND mask to +/- $07 degree units

; shot OR byte, sets the needed bits for a negative perturbation result

shot_or
	dc.b	$70			; OR to set bits after - $0F mask result
	dc.b	$78			; OR to set bits after - $07 mask result


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; handle the fire button

ship_fire:
;##	TST.b		num_players(a3)		; test the number of players in the game
;##	BEQ.s		exit_ship_fire		; if no players just exit

;##	TST.b		hide_p_cnt(a5)		; test the hide the player count
;##	BNE.s		exit_ship_fire		; if the player is hidden just exit

;	MOVEQ		#'P',d1			; [P] key
;	MOVEQ		#19,d0			; check for keypress
;	TRAP		#15

	moveq #5,d0					; getkey
	trap #15
	cmpi.b #'P',d1
	bne.s save_ship_fire

;	TST.b		d1				; test the result
;	BEQ.s		save_ship_fire		; if fire not pressed go clear the fire state
							; and exit

	tst.b last_fire(a3)		; test the fire last state
	bne.s exit_ship_fire	; if the fire button is held just exit

	moveq #0,d4					; set the index to the player velocity
	moveq #0,d5					; set the index to the player position
	moveq #1,d6					; set the minimum shot index - 1
	moveq #5,d7					; set the shot start index

	move.b p_orient(a3),s_orient(a3)
							; copy the player orientation

; fire the shot, player or saucer

test_fire_loop
	tst.b s_fire_off(a5,d7.w)	; test this fire object
	beq.s fire_shot			; if this shot is free go use it

	subq.w #1,d7				; decrement the shot index
	cmp.w d7,d6					; compare with minimum - 1 index
	bne.s test_fire_loop		; loop if more to do

save_ship_fire
	move.b d1,last_fire(a3)		; save the fire last state
exit_ship_fire
	rts

; player/saucer fired and a shot, indexed by d7, is free

fire_shot:
	move.w d7,d6				; copy the item index
	add.w d6,d6					; 2 for position index

	MOVE.b	#$12,s_fire_off(a5,d7.w)
							; set the fire item flag

	MOVE.b	s_orient(a3),d0		; get the player/saucer orientation
	BSR		cos_d0			; do COS(d0)

	MOVE.b	p_xvel_off(a5,d4.w),d3	; get the player/saucer x velocity byte
	BSR.s		calc_fire_byte		; test the fire velocity and make 3/4 sin/cos
	MOVE.b	d3,f_xvel_off(a5,d7.w)	; save the shot x velocity byte

	ADD.w		p_xpos_off(a5,d5.w),d0	; add the player/saucer x position
	MOVE.w	d0,f_xpos_off(a5,d6.w)	; save the shot x position

	MOVE.b	s_orient(a3),d0		; get the player/saucer orientation
	BSR		sin_d0			; do SIN(d0)

	MOVE.b	p_yvel_off(a5,d4.w),d3	; get the player/saucer y velocity byte
	BSR		calc_fire_byte		; test the fire velocity and make 3/4 sin/cos
	MOVE.b	d3,f_yvel_off(a5,d7.w)	; save the shot y velocity byte

	ADD.w		p_ypos_off(a5,d5.w),d0	; add the player/saucer y position
	MOVE.w	d0,f_ypos_off(a5,d6.w)	; save the shot y position

	MOVE.b	d1,last_fire(a3)		; save the fire last state

	MOVEQ		#pfire_snd,d1		; default to the player fire sound
	CMPI.w	#2,d7				; compare the index with the lowest player fire
	BCC		play_sample			; if it was the player go play the sample and
							; return

							; else it must be the saucer that fired so
	MOVEQ		#sfire_snd,d1		; set the saucer fire sound
	BRA		play_sample			; play the sample and return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; test the fire velocity and make 3/4 sin/cos

calc_fire_byte
	ASR.w		#1,d0				; / 2

	MOVE.w	d0,-(sp)			; push the word value
	MOVE.b	(sp)+,d0			; pop it as a byte value

	ADD.b		d0,d3				; add it to the COS / 2 value
	BMI.s		test_neg_fire		; if negative go test the negative limit

	CMPI.b	#$70,d3			; else compare it with the positive limit
	BCS.s		fire_ok			; if < the positive limit skip the adjust

	MOVEQ		#$6F,d3			; else set the value to the positive limit
	BRA.s		fire_ok			; go save the shot x velocity

test_neg_fire
	CMPI.b	#$91,d3			; compare it with the negative limit
	BCC.s		fire_ok			; if < the negative limit skip the adjust

	MOVEQ		#$91,d3			; else set the value to the negative limit
fire_ok
	EXT.w		d0				; make the byte value into a word

	MOVE.w	d0,d2				; get the COS / 2 back
	ASR.w		#1,d2				; / 4
	ADDX.w	d2,d0				; make 3 / 4 COS and round up

	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; get the player high score entries

enter_hiscores
	MOVE.b	high_off(a5),d0		; get the player 1 highscore flag
	AND.b		high_off(a6),d0		; and with the player 2 highscore flag
	BMI		exit_enter_hiscores	; if neither player is entering their high
							; score just exit

	MOVE.b	high_off(a5),d0		; get the player highscore flag
	BMI		next_p_high			; if this player isn't entering their high
							; score go try the other player

							; get a player high score entry
	CMPI.b	#1,past_play(a3)		; compare 1 with the number of players that
							; were in the game
	BEQ.s		no_playerx			; if it was only 1 player skip the "PLAYER x"
							; message

	MOVEQ		#1,d1				; message 1 - "PLAYER "
	BSR		add_message			; add message d1 to the display list

	MOVEQ		#$10,d0			; set game counter mask
	AND.w		game_count(a3),d0		; mask the game counter
	BNE.s		no_playerx			; if bit set skip the player number write

	BSR		player_n			; add the player number to the vector list
no_playerx
	MOVEQ		#2,d1				; message 2 - "YOUR SCORE IS ONE OF THE TE..."
	BSR		add_message			; add message d1 to the display list
	MOVEQ		#3,d1				; message 3 - "PLEASE ENTER YOUR INITIALS"
	BSR		add_message			; add message d1 to the display list
	MOVEQ		#4,d1				; message 4 - "PUSH ROTATE TO SELECT LETTER"
	BSR		add_message			; add message d1 to the display list
	MOVEQ		#5,d1				; message 5 - "PUSH HYPERSPACE WHEN LETTER..."
	BSR		add_message			; add message d1 to the display list

	MOVE.w	#$2000,glob_scale(a3)	; set the global scale

	MOVEQ		#$64,d1			; set the x co-ordinate
	MOVEQ		#$39,d2			; set the y co-ordinate
	BSR		add_coords			; add co-ordinate pair in d1,d2 to the list as
							; a draw command

	MOVE.w	#REL7,d1			; make a $7000,$0000 command
	BSR		add_single			; add (d1)00,0000 to the vector list

	MOVEQ		#0,d0				; clear the longword
	MOVE.b	high_off(a5),d0		; get the player highscore flag
	LEA		hinames(a3,d0.w),a0	; point to the high score names

	BSR		write_initial		; write a high score initial to the vector list
	BSR		write_initial		; write a high score initial to the vector list
	BSR		write_initial		; write a high score initial to the vector list

;	MOVEQ		#' ',d1			; [SPACE] key
;	MOVEQ		#19,d0			; check for keypress
;	TRAP		#15
	moveq #5,d0
	trap #15
	tst.l d1
	bmi.s save_hbutton
	cmpi.b #' ',d1
	bne.s save_hbutton

;	TST.b		d1				; test the result
;	BEQ.s		save_hbutton		; if hyperspace not pressed go save the state

	TST.b		last_hype(a3)		; test the hyperspace last state
	BNE.s		save_hbutton		; if hyperspace is held go save the state

; the hyperspace button has just been pressed

	ADDQ.b	#1,hi_char(a3)		; increment the input character index
	CMPI.b	#3,hi_char(a3)		; compare with end + 1
	BCS.s		next_hi_char		; if not there yet go and increment to the next
							; character

							; else that was the last character
	MOVE.b	d1,last_hype(a3)		; save the hyperspace last state
	MOVE.b	#$FF,high_off(a5)		; clear the player highscore flag
next_p_high
	MOVEQ		#0,d0				; clear the longword
	MOVE.b	d0,hi_char(a3)		; clear the input character index

	LEA		filename(pc),a1		; point to the highscore filename
	MOVEQ		#52,d0			; open new file
	TRAP		#15

	TST.w		d0				; check for errors
	BNE.s		close_all			; if error go close all files

	LEA		hiscores(a3),a1		; point to the highscore tables
	MOVEQ		#50,d2			; set the table length
	MOVEQ		#54,d0			; write file
	TRAP		#15

close_all
	MOVEQ		#50,d0			; close all files
	TRAP		#15

	MOVE.b	d0,player_idx(a3)		; clear the player index
	LEA		player_1(a3),a5		; get the pointer to player one's variables
	LEA		player_2(a3),a6		; get the pointer to player two's variables

	MOVE.b	#$F0,game_count(a3)	; set the game counter high byte, high score
							; entry timeout
	RTS

; hyperspace button press accepted and not at initials end

next_hi_char
	MOVE.b	#$F4,game_count(a3)	; set the game counter high byte, high score
							; entry timeout

	MOVEQ		#0,d0				; clear the longword
	MOVE.b	high_off(a5),d0		; get the player highscore flag
	ADD.b		hi_char(a3),d0		; add the input character index
	LEA		hinames(a3,d0.w),a0	; point to the high score names
	MOVE.b	#$0B,(a0)			; set the next character to "A"
save_hbutton
	MOVE.b	d1,last_hype(a3)		; save the hyperspace button last state

	TST.b		game_count(a3)		; test the game counter high byte
	BNE.s		not_timed_out		; if not timed out just continue

	MOVEQ		#-1,d0			; flag high score done
	MOVE.b	d0,high_off(a5)		; clear the player 1 highscore flag
	MOVE.b	d0,high_off(a6)		; clear the player 2 highscore flag
	BRA.s		next_p_high			; go save the entry end exit, branch always

not_timed_out
	MOVEQ		#-8,d0			; set the timeout counter mask
	AND.b		time_count(a3),d0		; mask the timeout counter
	BEQ.s		exit_not_done		; just exit 7/8ths of the time

	EOR.b		d0,time_count(a3)		; reset the timeout counter

	MOVEQ		#0,d2				; assume no rotate
;	MOVE.w	#'WQ',d1			; [WQ] keys
;	MOVEQ		#19,d0			; check for keypress
;	TRAP		#15
	moveq #5,d0
	trap #15
	cmpi.b #'Q',d1
	bne.s not_rot_left
	moveq #1,d2
	bra.s was_rot_left
not_rot_left:
	cmpi.b #'W',d1
	bne.s not_rot_right2
	subq.b #1,d2	

;	TST.b		d1				; test the result
;	BPL.s		rot_not_left		; if not pressed go test rotate right
;
;	MOVEQ		#1,d2				; if pressed set the offset to + 1
rot_not_left
;	TST.w		d1				; test the result
;	BPL.s		rot_not_right		; if not pressed go add the rotation

;	SUBQ.b	#1,d2				; if pressed set the offset to - 1
not_rot_right2
was_rot_left:
	MOVEQ		#0,d0				; clear the longword
	MOVE.b	high_off(a5),d0		; get the player highscore flag
	ADD.b		hi_char(a3),d0		; add the input character index
	ADD.b		hinames(a3,d0.w),d2	; add the character to the offset
	BMI.s		wrap_to_z			; if negative go set "Z"

	CMPI.b	#$0B,d2			; compare with "A"
	BCC.s		check_alpha			; if >= "A" go test for <= "Z"

	CMPI.b	#$01,d2			; compare with "0"
	BEQ.s		wrap_to_a			; if "0" go set to "A"

							; gets here if it was "2" to "9"
	MOVEQ		#0,d2				; else set to " "
	BRA.s		save_char			; go save the new character

wrap_to_a
	MOVEQ		#$0B,d2			; set to "A"
	BRA.s		save_char			; go save the new character

wrap_to_z
	MOVEQ		#$24,d2			; set to "Z"
check_alpha
	CMPI.b	#$25,d2			; compare with "Z" + 1
	BCS.s		save_char			; if less skip the reset

	MOVEQ		#0,d2				; else reset it to " "
save_char
	MOVE.b	d2,hinames(a3,d0.w)	; save the new character
exit_not_done
	MOVEQ		#0,d0				; flag high score not complete
exit_enter_hiscores
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; handle the hyperspace button

hyperspace
;##	TST.b		num_players(a3)		; test the number of players in the game
;##	BEQ		exit_hyperspace		; if no players just exit

;##	TST.b		hide_p_cnt(a5)		; test the hide the player count
;##	BNE		exit_hyperspace		; if the player is hidden just exit

	tst.b p_flag_off(a5)		; test the player flag
	ble exit_hyperspace			; if no player or player exploding just exit

;	MOVEQ		#' ',d1			; [SPACE] key, read the hyperspace button
;	MOVEQ		#19,d0			; check for keypress
;	TRAP		#15
	moveq #5,d0
	trap #15
	cmpi.b #' ',d1
	bne.s exit_hyperspace

;	TST.b		d1				; test the result
;	BEQ.s		exit_hyperspace		; if the key is not pressed just exit

	MOVEQ		#0,d0				; clear the longword
	MOVE.b	d0,p_flag_off(a5)		; clear the player flag
	MOVE.b	d0,p_xvel_off(a5)		; clear the player x velocity
	MOVE.b	d0,p_yvel_off(a5)		; clear the player y velocity

	MOVE.b	#$30,hide_p_cnt(a5)	; set the hide the player count

	BSR		gen_prng			; generate the next pseudo random number
	MOVE.w	PRNlword(a3),d0		; get a pseudo random word
	ANDI.w	#$1FFF,d0			; mask to $1Fxx
	CMPI.w	#$1E00,d0			; compare with $1E00
	BCS.s		hype_xok1			; if less than $1E00 just use it

	ANDI.w	#$1CFF,d0			; else restrict it to $1Cxx
hype_xok1
	CMPI.w	#$0400,d0			; compare it with $0400
	BCC.s		hype_xok2			; if >= $0400 go use it

	ORI.w		#$0300,d0			; else make it $03xx
hype_xok2
	MOVE.w	d0,p_xpos_off(a5)		; save the player x position

	BSR		gen_prng			; generate the next pseudo random number
	MOVE.w	PRNlword(a3),d0		; get a pseudo random word
	ANDI.w	#$1FFF,d0			; mask to $1Fxx

	MOVE.w	d0,-(sp)			; push the word
	MOVE.b	(sp)+,d2			; pull the byte for later success/fail check

	CMPI.w	#$1600,d0			; compare with $1600
	BCS.s		hype_yok1			; if less than $1600 just use it

	ANDI.w	#$14FF,d0			; else restrict it to $14xx
hype_yok1
	CMPI.w	#$0400,d0			; compare it with $0400
	BCC.s		hype_yok2			; if >= $0400 go use it

	ORI.w		#$0300,d0			; else make it $03xx
hype_yok2
	MOVE.w	d0,p_ypos_off(a5)		; save the player y position

	MOVEQ		#1,d1				; default to a successful hyperspace jump

	CMPI.b	#$18,d2			; compare with $18xx
	BCS.s		save_hyperspace		; if less than $18xx go save the hyperspace flag

	ANDI.b	#$07,d2			; else mask it
	ADD.b		d2,d2				; ; 2
	ADDI.b	#$04,d2			; + 4
	CMP.b		rock_count(a5),d2		; compare this with the rock count
	BCS.s		save_hyperspace		; if < the rock count allow the jump

	MOVEQ		#$80,d1			; else flag an unsuccessful hyperspace jump
save_hyperspace
	MOVE.b	d1,hyper(a3)		; save the hyperspace flag
exit_hyperspace
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; clear the items and set the ship start count

reset_game:
	MOVEQ		#3,d0				; default to a 3 ship game
	MOVEA.l	switch_addr(a3),a0	; point to the switch
	BTST		#2,(a0)			; test the ship start switch
	BEQ.s		three_ship_start		; if 0 go start with three ships

	MOVEQ		#4,d0				; else make it a 4 ship game
three_ship_start
	MOVE.b	d0,ss_count(a3)		; save the starting ship count

	MOVE.b	#2,i_rk_count(a5)		; set the previous initial rock count

	MOVEQ		#0,d0				; clear the longword
	MOVEQ		#flag_end-flags_off-1,d7
							; set the count for the number of items
clear_items_loop
	MOVE.b	d0,flags_off(a5,d7.w)	; clear an item
	DBF		d7,clear_items_loop	; loop if more to do

	MOVE.b	d0,rock_count(a5)		; clear the rock count

	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; write a high score initial to the vector list

write_initial:
	MOVEQ		#0,d1				; clear the longword
	MOVE.b	(a0)+,d1			; get a high score initial
	BNE.s		add_character		; if not [SPACE] just go add it

	MOVE.b	p1_high(a3),d0		; get the player 1 highscore flag
	AND.b		p2_high(a3),d0		; and with the player 2 highscore flag
	BMI.s		add_character		; if neither is entering their initials just
							; go add the character

							; else add a "_" instead of a [SPACE]
	MOVE.w	#$F872,(a4)+		; add the underline vector word to the vector
							; list
	MOVE.w	#$F801,(a4)+		; add the step to next character vector word
							; to the vector list
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add character (d1) to the vector list

add_character:
	MOVE.l	a0,-(sp)			; save a0
	ADD.w		d1,d1				; ; 2 bytes per character (d1) JSRL
	LEA		char_set(pc),a0		; point to the character JSRL table
	MOVE.w	(a0,d1.w),(a4)+		; add the JSRL word to the vector list
	MOVE.l	(sp)+,a0			; restore a0
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add d7 ships to the vector list. this is limited to a maximum of eighteen ships for
; speed and clarity

add_ships:
	BEQ.s		exit_add_ships		; if no ships left just exit

	MOVEQ		#18,d0			; set the maximum ship count
	CMP.w		d7,d0				; compare the ship count with the max count
	BCC.s		show_ships			; if <= to max go show the ships

	MOVE.w	d0,d7				; else set the ship count to the maximum
show_ships
	SUB.w		d7,d1				; subtract the ship count twice to move the ..
	SUB.w		d7,d1				; .. ships further right the more there are

	MOVE.w	#$E000,glob_scale(a3)	; set the global scale
	MOVE.w	#$D1,d2			; set the ships y co-ordinate
	BSR		add_coords			; add co-ordinate pair in d1,d2 to the list as
							; a draw command
	SUBQ.w	#1,d7				; adjust for loop type
add_ships_loop
	LEA		play_liv(pc),a1		; set the pointer to ships left
	BSR		add_address			; convert the a1 address and add it to the
							; vector list as a vector subroutine call
	DBF		d7,add_ships_loop		; decrement the ship count and loop if more
							; to do
exit_add_ships
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; move all the items and add them to the vector list

; d6 = object index
; d7 = position index

move_items:
	MOVEQ		#x_pos_end-x_pos_off-2,d7
							; set the index to the last object position
	MOVEQ		#flag_end-flags_off-1,d6
							; set the count to the last object
move_next_item
	MOVE.b	flags_off(a5,d6.w),d0	; get an object flag
	BEQ		move_next_object		; if no item go do the next one

; have an active item

	BPL.s		move_item			; if the item is not exploding go move the item

							; else the item is exploding
	NEG.b		d0				; do twos complement [$A0 becones $60]
	LSR.b		#4,d0				; shift the high nibble to the low nibble
							; [$60 becomes $06]
	ADDQ.b	#1,d0				; + 1
	CMPI.b	#p_flag_off-flags_off,d6
							; compare the index with the player index
	BNE.s		skip_play_inc		; if not the player skip setting the player
							; increment

; set the player explosion increment to 1/2 by only setting it to 1 on alternate loops

	MOVEQ		#1,d0				; set game counter mask
	AND.w		game_count(a3),d0		; mask the game counter
skip_play_inc
	ADD.b		flags_off(a5,d6.w),d0	; add the item flag
	BMI.s		item_exploding		; go handle the item still exploding

	CMPI.w	#p_flag_off-flags_off,d6
							; compare the index with the player index
	BEQ.s		go_reset_play		; if the player go reset the player and do next

	BCC.s		go_reset_sauc		; if the saucer go reset the saucer and do next

							; else it was a rock so clear it
	SUBQ.b	#1,rock_count(a5)		; decrement the rock count
	BNE.s		no_new_rocks		; skip flag set if rocks still left

	MOVE.b	#$7F,new_rocks(a5)	; else set the generate new rocks flag
no_new_rocks
	CLR.b		flags_off(a5,d6.w)	; clear the item flag
	BRA		move_next_object		; go check next item

go_reset_play
	BSR		player_reset		; reset the player velocity and position
	BRA		no_new_rocks		; go clear the player and do the next item

; reset the saucer timer

go_reset_sauc
	MOVE.b	i_sauc_tim(a5),sauc_cntdn(a5)
							; get the small saucer boundary/initial saucer
							; timer and reset the saucer countdown timer
	BRA.s		no_new_rocks		; go clear the saucer and do the next item

; the item is still exploding

item_exploding
	MOVE.b	d0,flags_off(a5,d6.w)	; save the incremented item flag
	MOVE.b	d0,-(sp)			; save the byte
	MOVE.w	(sp)+,d1			; pull the word
	AND.w		#$F000,d1			; mask the top nibble as the scale
	ADD.w		#$1000,d1			; + $10
	CMPI.b	#p_flag_off-flags_off,d6
							; compare the index with the player index
	BNE.s		no_reset_scale		; if not the player ship skip the scale reset

	MOVEQ		#$0000,d1			; else it was the player so reset the scale
no_reset_scale
	BRA.s		keep_scale			; go add the object to the vector list and do
							; the next item

; the item is not exploding so move the item

move_item:
	MOVE.b	x_vel_off(a5,d6.w),d0	; get the x velocity byte
	EXT.w		d0				; extend it to a word value
	ADD.w		x_pos_off(a5,d7.w),d0	; add the x position
	BMI.s		x_pos_neg			; if negative go mask to $2000

	CMP.w		#$2000,d0			; compare the object x position with $2000
	BCS.s		not_x_max			; if less go do y position

x_pos_neg
	ANDI.w	#$1FFF,d0			; else wrap round the x position

	CMPI.b	#s_flag_off-flags_off,d6
							; compare the index with the saucer index
	BNE.s		not_x_max			; if not saucer continue

							; else the saucer has passed the screen end
	PEA		move_next_object(pc)	; on RTS go check the next item
	BRA.s		clear_saucer		; clear the saucer and restart the saucer timer

not_x_max
	MOVE.w	d0,x_pos_off(a5,d7.w)	; save the new x position

	MOVE.b	y_vel_off(a5,d6.w),d0	; get the y velocity byte
	EXT.w		d0				; extend it to a word value
	ADD.w		y_pos_off(a5,d7.w),d0	; add the y position
	BPL.s		y_not_neg			; skip add if not < 0

	ADD.w		#$1800,d0			; else wrap round the y position
	BRA.s		not_y_max			; and skip the max check

y_not_neg
	CMP.w		#$1800,d0			; compare the object y position with $1800
	BCS.s		not_y_max			; if less just continue

	SUB.w		#$1800,d0			; else wrap round the y position
not_y_max
	MOVE.w	d0,y_pos_off(a5,d7.w)	; save the new y position

	MOVE.w	#$E000,d1			; set the scale to $E000
	CMPI.w	#s_fire_off-flags_off,d6
							; compare the index with the fire objects
	BCC.s		keep_scale			; if fire object keep this scale and go add the
							; item and do next

	MOVE.b	flags_off(a5,d6.w),d0	; get the object flag
	BTST.l	#0,d0				; test bit 0
	BNE.s		keep_scale			; if %xx1 keep this scale and go add the item
							; and do next

	MOVE.w	#$F000,d1			; set the scale to $F000
	BTST.l	#1,d0				; test bit 0
	BNE.s		keep_scale			; if %x10 keep this scale and go add the item
							; and do next

	MOVEQ		#0,d1				; set the scale to $0000

; add the item to the vector list and go do the next item

keep_scale
	MOVE.w	d1,glob_scale(a3)		; save the global scale
	BSR		add_to_list			; add an object to the vector list
move_next_object
	SUBQ.w	#2,d7				; decrement the position index
	DBF		d6,move_next_item		; decrement the count and loop if more to do

	RTS



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; clear the saucer and restart the saucer timer

clear_saucer:
	move.b i_sauc_tim(a5),sauc_cntdn(a5)	
							; copy the small saucer boundary/initial saucer
							; timer to the saucer countdown timer
	clr.b s_flag_off(a5)		; clear the saucer flag
	clr.b s_xvel_off(a5)		; clear the saucer x velocity byte
	clr.b s_yvel_off(a5)		; clear the saucer y velocity byte
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; handle ship rotation and thrust

ship_move:
;##	TST.b		num_players(a3)		; test the number of players in the game
;##	BEQ.s		exit_ship_move		; if no players just exit

	TST.b		p_flag_off(a5)		; test the player flag
	BMI.s		exit_ship_move		; if the player is exploding just exit

	TST.b		hide_p_cnt(a5)		; test the hide the player count
	BEQ.s		rot_and_thrust		; if the player is visible go handle the ship
							; rotate and thrust

	SUBQ.b	#1,hide_p_cnt(a5)		; else decrement the hide the player count
	BNE.s		exit_ship_move		; if not timed out just exit

	TST.b		hyper(a3)			; test the hyperspace flag
	BMI.s		kill_the_player		; if negative go handle an unsuccessful
							; hyperspace jump

	BNE.s		reveal_player		; else if non zero go handle a successful
							; hyperspace jump

							; else the player has just become visible
	BSR		check_clear			; check items within $0400 range of the player
	BNE.s		clear_hyper			; if there are items within range go clear the
							; hyperspace flag and exit

	TST.b		s_flag_off(a5)		; test the saucer flag
	BEQ.s		reveal_player		; if there's no saucer go reveal the player

	MOVE.b	#$02,hide_p_cnt(a5)	; else set the hide the player count
	RTS

; handle a successful hyperspace jump

reveal_player
	MOVE.b	#$01,p_flag_off(a5)	; set the player flag
	BRA.s		clear_hyper			; go clear the hyperspace flag and return

; handle an unsuccessful hyperspace jump

kill_the_player:
	MOVE.b	#$A0,p_flag_off(a5)	; flag that the player's ship is exploding
	SUBQ.b	#1,ships_off(a5)		; decrement the player's ship count
	MOVE.b	#$81,hide_p_cnt(a5)	; set the hide the player count

	MOVEQ		#mexpl_snd,d1		; set the medium explosion sound
	BSR		play_sample			; go play the sample
clear_hyper
	CLR.b		hyper(a3)			; clear the hyperspace flag
exit_ship_move
	RTS

; handle the ship rotate and thrust

rot_and_thrust
;	MOVEQ		#0,d2				; assume no rotate
;	MOVE.l	#'L WQ',d1			; [L WQ] keys
;	MOVEQ		#19,d0			; check for keypress
;	TRAP		#15
	moveq #5,d0
	trap #15
	cmpi.b #'Q',d1
	bne.s not_rot_left1
	moveq #3,d2
not_rot_left1:
	cmpi.b #'W',d1
	bne.s not_rot_right1
	subq.b #3,d2
not_rot_right1:

;	TST.b		d1				; test the [Q] result
;	BPL.s		not_rot_left		; if not pressed go test rotate right

;	MOVEQ		#3,d2				; if pressed set the rotation angle to + 3
;not_rot_left
;	TST.w		d1				; test the [W] result
;	BPL.s		not_rot_right		; if not pressed go add the rotation

;	SUBQ.b	#3,d2				; if pressed set the rotation angle to - 3
;not_rot_right
	add.b d2,p_orient(a3)		; add the roataion to the player orientation

	moveq #1,d0				; set game counter mask
	and.w game_count(a3),d0		; mask the game counter
	bne.s exit_ship_move		; just exit half the time

	cmpi.b #'L',d1
	bne.s not_thrust
;	TST.l		d1				; test the [L] result
;	BPL.s		not_thrust			; if not pressed then go slow the ship

; thrust button is pressed so increase the ship velocity

	MOVEQ		#thrst_snd,d1		; set the thrust sound
	BSR		play_sample			; play the sample and return

	MOVE.b	p_orient(a3),d0		; get the player orientation
	BSR		cos_d0			; do COS(d0)
	ASR.w		#7,d0				; scale to 1/128th

	MOVE.b	p_xvel_off(a5),-(sp)	; get the x velocity high byte
	MOVE.w	(sp)+,d1			; copy it to d1 high byte
	MOVE.b	p_xvlo_off(a5),d1		; get the x velocity low byte
	ADD.w		d0,d1				; add the thrust x component
	BSR.s		check_velocity		; limit check the velocity in d1
	MOVE.b	d1,p_xvlo_off(a5)		; save the x velocity low byte
	MOVE.w	d1,-(sp)			; save the word
	MOVE.b	(sp)+,p_xvel_off(a5)	; save the x velocity high byte

	MOVE.b	p_orient(a3),d0		; get the player orientation
	BSR		sin_d0			; do SIN(d0)
	ASR.w		#7,d0				; scale to 1/128th

	MOVE.b	p_yvel_off(a5),-(sp)	; get the y velocity high byte
	MOVE.w	(sp)+,d1			; copy it to d1 high byte
	MOVE.b	p_yvlo_off(a5),d1		; get the y velocity low byte
	ADD.w		d0,d1				; add the thrust y component
	BSR.s		check_velocity		; limit check the velocity in d1
	MOVE.b	d1,p_yvlo_off(a5)		; save the y velocity low byte
	MOVE.w	d1,-(sp)			; save the word
	MOVE.b	(sp)+,p_yvel_off(a5)	; save the y velocity high byte

	RTS

; thrust button is not pressed so slow the ship by adding - 128 ; velocity

not_thrust
	MOVE.b	p_xvel_off(a5),-(sp)	; get the x velocity high byte
	MOVE.w	(sp)+,d1			; copy it to d1 high byte
	MOVE.b	p_xvlo_off(a5),d1		; get the x velocity low byte
	MOVE.w	d1,d0				; copy the x velocity
	ASR.w		#7,d0				; scale to 1/128th
	SUB.w		d0,d1				; subtract the x drag component
	MOVE.b	d1,p_xvlo_off(a5)		; save the x velocity low byte
	MOVE.w	d1,-(sp)			; save the word
	MOVE.b	(sp)+,p_xvel_off(a5)	; save the x velocity high byte

; done the x velocity now do the y

	MOVE.b	p_yvel_off(a5),-(sp)	; get the y velocity high byte
	MOVE.w	(sp)+,d1			; copy it to d1 high byte
	MOVE.b	p_yvlo_off(a5),d1		; get the y velocity low byte
	MOVE.w	d1,d0				; copy the y velocity
	ASR.w		#7,d0				; scale to 1/128th
	SUB.w		d0,d1				; subtract the y drag component
	MOVE.b	d1,p_yvlo_off(a5)		; save the y velocity low byte
	MOVE.w	d1,-(sp)			; save the word
	MOVE.b	(sp)+,p_yvel_off(a5)	; save the y velocity high byte

	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; limit check the velocity in XA

check_velocity:
	BMI.s		check_neg_velocity	; if negative go check negative limit

	CMPI.w	#$4000,d1			; compare velocity with positive limit
	BCS.s		exit_check_velocity	; if less just exit

	MOVE.w	#$3FFF,d1			; else set the velocity
	rts

; velocity is negative so check against the negative limit

check_neg_velocity
	CMPI.w	#$C002,d1			; compare velocity with negative limit
	BCC.s		exit_check_velocity	; if greater or equal just exit

	MOVE.w	#$C001,d1			; else set the velocity
exit_check_velocity
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; check items within $0400 range of the player

check_clear:
	moveq #s_flag_off-flags_off,d6
							; set the count/index to the saucer
	moveq #s_xpos_off-x_pos_off,d7
							; set the index to the saucer position
check_clear_loop
	tst.b flags_off(a5,d6.w)	; test the item flag
	BLE.s		not_closer			; if no item or exploding go do the next item

	MOVE.w	x_pos_off(a5,d7.w),d0	; get the item x position
	SUB.w		p_xpos_off(a5),d0		; subtract the player x position
	CMPI.w	#$0400,d0			; compare the result with $0400
	BCS.s		check_clear_y		; if closer go check the y distance

	CMPI.w	#$FC00,d0			; compare the result with -$0400
	BCS.s		not_closer			; if not closer go do the next item

check_clear_y
	MOVE.w	y_pos_off(a5,d7.w),d0	; get the item y position
	SUB.w		p_ypos_off(a5),d0		; subtract the player y position
	CMPI.w	#$0400,d0			; compare the result with $0400
	BCS.s		is_closer			; if closer go flag within distance and
							; increment the hide the player count

	CMPI.w	#$FC00,d0			; compare the result with -$0400
	BCC.s		is_closer			; if closer go flag within distance and
							; increment the hide the player count

not_closer
	SUBQ.w	#2,d7				; decrement the position index
	DBF		d6,check_clear_loop	; decrement the count and loop if more to do

	MOVEQ		#0,d0				; return Zb = 1
	rts

is_closer
	ADDQ.b	#1,hide_p_cnt(a5)		; increment the hide the player count
							; return Zb = 0
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; generate new rocks

make_rocks:
	TST.b		s_flag_off(a5)		; test the saucer flag
	BNE		exit_make_rocks		; if existing saucer just exit

	MOVEQ		#p_xpos_off-x_pos_off-2,d6
							; set the index to the last rock position
	MOVEQ		#p_flag_off-flags_off-1,d5
							; set the count/index to the last rock flag
	TST.b		new_rocks(a5)		; test the generate new rocks flag
	BNE		clear_rocks			; if not counted out go clear all the rocks

; these are used as the new rock initial velocity

	MOVEQ		#0,d0				; clear the longword
	MOVE.b	d0,s_xvel_off(a5)		; clear the saucer x velocity byte
	MOVE.b	d0,s_yvel_off(a5)		; clear the saucer y velocity byte

	MOVEQ		#$0A,d0			; set the max value
	CMP.b		min_rocks(a5),d0		; compare minimum rock count with $0A
	BCS.s		no_inc_min			; if > skip the increment

	ADDQ.b	#1,min_rocks(a5)		; else decrement the minimum rock count before
							; the saucer initial timer starts to decrement
no_inc_min
	MOVEQ		#0,d4				; clear the longword
	MOVE.b	i_rk_count(a5),d4		; get the initial rock count
	ADDQ.b	#2,d4				; + 2
	CMPI.b	#11,d4			; compare the new rock count with 11 rocks
	BLS.s		no_set_max			; if less or equal just use it

	MOVEQ		#11,d4			; else set the new rock count to 11
no_set_max
	MOVE.b	d4,rock_count(a5)		; save the rock count
	MOVE.b	d4,i_rk_count(a5)		; save the initial rock count

	MOVEQ		#s_xvel_off-x_vel_off,d7
							; set the index to the saucer for a zero initial
							; velocity

	SUBQ.w	#1,d4				; adjust for the loop type
gen_rock_loop
	BSR		gen_prng			; generate the next pseudo random number
	MOVEQ		#$18,d0			; set the rock type mask
	AND.b		PRNlword(a3),d0		; mask a pseudo random byte
	ORI.b		#$04,d0			; set the rock size to the largest
	MOVE.b	d0,flags_off(a5,d5.w)	; save the rock flag
	BSR		copy_velocity		; copy the saucer velocity, (d7), plus a random
							; delta x,y velocity to the new rock, (d5),
							; velocity

	BSR		gen_prng			; generate the next pseudo random number
	MOVEQ		#0,d1				; clear the other axis position
	MOVE.w	#$3FFF,d0			; set the starting position mask
	AND.w		PRNlword(a3),d0		; mask a pseudo random word
	LSR.w		#1,d0				; shift a random bit into Cb
	BCC.s		rock_on_x			; if Cb = 0 go set the rock at a point along
							; the x axis

; set the rock at a point along the y axis

	CMPI.w	#$1800,d0			; compare the position with the y axis maximum
	BCS.s		rock_y_ok			; if less just use it

	ANDI.w	#$17FF,d0			; mask the position to the y axis maximum
rock_y_ok
	EXG		d1,d0				; swap y value to d1, zero to d0

; set the rock at a point along the x axis

rock_on_x
	MOVE.w	d0,x_pos_off(a5,d6.w)	; save the rock x position
	MOVE.w	d1,y_pos_off(a5,d6.w)	; save the rock y position
	SUBQ.w	#2,d6				; decrement the rock position index
	SUBQ.w	#1,d5				; decrement the rock count/index
	DBF		d4,gen_rock_loop		; decrement the new rock count and loop if more
							; to do

	MOVE.b	#$7F,sauc_cntdn(a5)	; set the saucer countdown timer
	MOVE.b	#$34,thmp_sndi(a5)	; reset the thump sound change timer initial
							; value
	MOVE.b	#beat1_snd,thump_snd(a3)
							; reset the thump sound value

; now clear all the other rocks

clear_rocks
	MOVEQ		#0,d0				; clear the longword
clear_rocks_loop
	MOVE.b	d0,flags_off(a5,d5.w)	; clear the rock flag
	DBF		d5,clear_rocks_loop	; decrement the count and loop if more to do

exit_make_rocks
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; initialise the player variables

player_init:
	move.b ss_count(a3),ships_off(a5)
							; set the player's starting ship count
	move.b #$92,i_sauc_tim(a5)	; set the small saucer boundary/initial saucer
							; timer
	move.b #$92,sauc_cntdn(a5)	; set the saucer countdown timer
	move.b #$7F,new_rocks(a5)	; set the generate new rocks flag

	move.b #$05,min_rocks(a5)	; set the minimum rock count before the saucer
							; initial timer starts to decrement
	move.b #$34,thmp_sndi(a5)	; reset the thump sound change timer initial
							; value
	move.b #beat1_snd,thump_snd(a3)	; reset the thump sound value
	move.b #$FF,high_off(a5)		; clear the player highscore flag
	move.b #$01,hide_p_cnt(a5)	; set the hide the player count


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; reset the player velocity and position

player_reset:
	move.w #$1000,p_xpos_off(a5)	; set the player x position
	move.w #$0C00,p_ypos_off(a5)	; set the player y position
	clr.b p_xvel_off(a5)					; clear the player x velocity
	clr.b p_yvel_off(a5)					; clear the player y velocity
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; copy the item parameters from the old rock, (d7), to the new rock, (d5)

copy_rock:
	MOVE.w	d7,d4				; copy the old rock index
	ADD.w		d4,d4				; ; 2 for the old rock position index

copy_rock_2
	MOVE.w	d5,d3				; copy the new rock index
	ADD.w		d3,d3				; ; 2 for the new rock position index

	MOVEQ		#$07,d1			; set the size mask
	AND.b		flags_off(a5,d7.w),d1	; mask the old rock size
	BSR		gen_prng			; generate the next pseudo random number
	MOVEQ		#$18,d0			; set the rock type mask
	AND.b		PRNlword(a3),d0		; mask a pseudo random byte
	OR.b		d1,d0				; OR in the old rock size
	MOVE.b	d0,flags_off(a5,d5.w)	; save the new rock flag

	MOVE.w	x_pos_off(a5,d4.w),x_pos_off(a5,d3.w)
							; copy the old rock x position to the new rock
							; x position
	MOVE.w	y_pos_off(a5,d4.w),y_pos_off(a5,d3.w)
							; copy the old rock y position to the new rock
							; y position


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; copy the old rock, (d7), velocity plus random delta x,y velocity to the new rock,
; (d5), velocity

copy_velocity:
	BSR		gen_prng			; generate the next pseudo random number
	MOVEQ		#$8F,d0			; mask +/- $00 to $0F
	AND.b		PRNlword(a3),d0		; mask a pseudo random byte
	BPL.s		x_off_pos			; skip bits set if positive

	ORI.b		#$70,d0			; else make $Fx
x_off_pos
	ADD.b		x_vel_off(a5,d7.w),d0	; add the item (d7) to the delta x velocity
	BSR.s		limit_velocity		; ensure velocity is within limits
	MOVE.b	d0,x_vel_off(a5,d5.w)	; save the rock x velocity


	BSR		gen_prng			; generate the next pseudo random number
	MOVEQ		#$8F,d0			; mask +/- $00 to $0F
	AND.b		PRNlword(a3),d0		; mask a pseudo random byte
	BPL.s		y_off_pos			; skip bits set if positive

	ORI.b		#$70,d0			; else make $Fx
y_off_pos
	ADD.b		y_vel_off(a5,d7.w),d0	; add the item (d5) to the delta y velocity
	BSR.s		limit_velocity		; ensure velocity is within limits
	MOVE.b	d0,y_vel_off(a5,d5.w)	; save the rock y velocity

	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; ensure velocity is within limits

limit_velocity:
	BPL.s		limit_p_vel			; if positive go test positive limit

	CMPI.b	#$E1,d0			; compare velocity with upper limit
	BCC.s		neg_upper_ok		; if less skip set

	MOVEQ		#$E1,d0			; else set velocity to -$1F
neg_upper_ok
	CMPI.b	#$FB,d0			; compare velocity with lower limit
	BCS.s		exit_limit_velocity	; if greater just exit

	MOVEQ		#$FA,d0			; else set velocity to -$06
	RTS

; test velocity positive limit

limit_p_vel
	CMPI.b	#$06,d0			; compare velocity with lower limit
	BCC.s		pos_lower_ok		; skip set if greater

	MOVEQ		#$06,d0			; else set velocity to $06
pos_lower_ok
	CMPI.b	#$20,d0			; compare velocity with upper limit
	BCS.s		exit_limit_velocity	; if less just exit

	MOVEQ		#$1F,d0			; else set velocity to $1F
exit_limit_velocity
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add (c), scores and players ships to the vector list

static_messages:
	LEA		copy_msg(pc),a1		; set the pointer to the copyright message
	BSR		add_address			; convert the a1 address and add it to the
							; vector list as a vector subroutine call

	MOVE.w	#$1000,glob_scale(a3)	; set the global scale
	MOVEQ		#$19,d1			; set the score x co-ordinate
	MOVE.w	#$D7,d2			; set the score y co-ordinate
	BSR		add_coords			; add co-ordinate pair in d1,d2 to the list as
							; a draw command

	MOVE.w	#REL7,d1			; make a $7000,$0000 command
	BSR		add_single			; add (d1)00,0000 to the vector list

	CMPI.b	#$02,num_players(a3)	; compare the number of players in the game
	BNE.s		skip_play_flash		; if not two players skip flashing the active
							; player

	TST.b		player_idx(a3)		; test the player index
	BNE.s		skip_play_flash		; if player 2 go add the player to the vector
							; list

	MOVE.b	p_flag_off(a5),d0		; get the player flag
	OR.b		hyper(a3),d0		; OR with the hyperspace flag
	BNE.s		skip_play_flash		; if playing go add player 1's score to the
							; vector list

	TST.b		hide_p_cnt(a5)		; test the hide the player count
	BMI.s		skip_play_flash		; if the player is dieing go display the score

	BTST.b	#4,game_count+1(a3)	; test a bit in the game counter low byte
	BEQ.s		do_p1_ships			; skip the score display if the flash is off

; add the active player to the vector list

skip_play_flash
	LEA		p1_score(a3),a1		; point to player 1's score
	MOVEQ		#$02,d7			; set the number byte count
	MOVE.b	d7,suppress_0(a3)		; set the flag to suppress leading zeros
	BSR		output_number		; output the number (a1) as a leading zero
							; suppressed character string
	MOVEQ		#0,d1				; add player 1's score's trailing "0"
	BSR		add_hex_chr			; write a hex character to the vector list

do_p1_ships
	MOVEQ		#$29,d1			; set the x co-ordinate for player 1's ships
	MOVEQ		#0,d7				; clear the longword
	MOVE.b	p1_ships(a3),d7		; get player 1's ship count
	BSR		add_ships			; add d7 ships to the vector list

	MOVE.w	#$0000,glob_scale(a3)	; set the global scale

	MOVEQ		#$78,d1			; set the high score x co-ordinate
	MOVE.w	#$D7,d2			; set the high score y co-ordinate
	BSR		add_coords			; add co-ordinate pair in d1,d2 to the list as
							; a draw command
	MOVE.w	#REL5,d1			; make a $5000,$0000 command
	BSR		add_single			; add (d1)00,0000 to the vector list

	LEA		hiscores(a3),a1		; point to the highest high score
	MOVEQ		#$02,d7			; set the number byte count
	MOVE.b	d7,suppress_0(a3)		; set the flag to suppress leading zeros
	BSR		output_number		; output the number (a1) as a leading zero
							; suppressed character string

	MOVEQ		#0,d1				; add the high score trailing "0"
	BSR		add_hex_chr			; write a hex character to the vector list

	MOVE.w	#$1000,glob_scale(a3)	; set the global scale

	MOVE.w	#$C0,d1			; set the score x co-ordinate
	MOVE.w	#$D7,d2			; set the score y co-ordinate
	BSR		add_coords			; add co-ordinate pair in d1,d2 to the list as
							; a draw command
	MOVE.w	#REL5,d1			; make a $5000,$0000 command
	BSR		add_single			; add (d1)00,0000 to the vector list

	CMPI.b	#$01,num_players(a3)	; compare the number of players in the game
							; with one
	BEQ.s		exit_static			; if just one player skip displaying p2 score

	BCS.s		do_p2_score			; if no players go add player 2's score to
							; the vector list

	TST.b		player_idx(a3)		; test the player index
	BEQ.s		do_p2_score			; if player 1 go add the player to the vector
							; list

	MOVE.b	p_flag_off(a5),d0		; get the player flag
	OR.b		hyper(a3),d0		; OR with the hyperspace flag
	BNE.s		do_p2_score			; if playing go add player 2's score to the
							; vector list

	TST.b		hide_p_cnt(a5)		; test the hide the player count
	BMI.s		do_p2_score			; if the player is dieing go display the score

	BTST.b	#4,game_count+1(a3)	; test a bit in the game counter low byte
	BEQ.s		skip_p2_score		; skip the score display if the flash is off

do_p2_score
	LEA		p2_score(a3),a1		; point to player 2's score
	MOVEQ		#$02,d7			; set the number byte count
	MOVE.b	d7,suppress_0(a3)		; set the flag to suppress leading zeros
	BSR		output_number		; output the number (a1) as a leading zero
							; suppressed character string
	MOVEQ		#0,d1				; add player 2's score's trailing "0"
	BSR		add_hex_chr			; write a hex character to the vector list

skip_p2_score
	MOVE.w	#$D0,d1			; set the x co-ordinate for player 2's ships
	MOVEQ		#0,d7				; clear the longword
	MOVE.b	p2_ships(a3),d7		; get player 2's ship count
	BRA		add_ships			; add d7 ships to the vector list and return

exit_static
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add an item to the vector list
;
; d6 = object flag offset
; d7 = position offset

							; first add the DRAW to the item's origin
add_to_list:
	MOVE.w	y_pos_off(a5,d7.w),d0	; get the y position
	ADD.w		#$0400,d0			; add offset so y is centred around 512
	LSR.w		#3,d0				; / 8
	ORI.w		#DRAW,d0			; OR in the draw command
	MOVE.w	d0,(a4)+			; add it to the vector list

	MOVE.w	x_pos_off(a5,d7.w),d0	; get the x position
	LSR.w		#3,d0				; / 8
	OR.w		d1,d0				; OR in the global scale
	MOVE.w	d0,(a4)+			; add it to the vector list

	MOVEQ		#0,d1				; clear the longword
	MOVE.b	flags_off(a5,d6.w),d1	; get the object flag
	BPL.s		add_item			; if not exploding go add the item to the
							; vector list

							; else add an exploding item
	CMPI.b	#p_flag_off-flags_off,d6
							; compare the index with the player index
	BEQ		add_play_explode		; if it is the player go add ship pieces to the
							; vector list

	ANDI.b	#$0C,d1			; else mask the rock type
	LEA		expl_tab(pc),a1		; point to the explosion JSRL table
	BRA.s		add_explode			; go add the JSRL word to the vector list and
							; return

; add item d6 to the vector list

add_item:
	CMPI.b	#p_flag_off-flags_off,d6
							; compare the index with the player index
	BEQ		add_player			; if = go add the player to the vector list

	CMPI.b	#s_flag_off-flags_off,d6
							; compare the index with the saucer index
	BEQ.s		add_saucer			; if = go add the saucer to the vector list

	BCC.s		add_fire			; if > saucer go add fire to the vector list

							; else add a rock to the vector list
	ANDI.w	#$0018,d1			; mask the rock type
	LSR.w		#2,d1				; >> 3 << 1
	LEA		rock_tab(pc),a1		; point to the rock JSRL table
add_explode
	MOVE.w	(a1,d1.w),(a4)+		; add the JSRL word to the vector list
	RTS

; add the saucer to the vector list

add_saucer:
	MOVE.w	sauc_jsr(pc),(a4)+	; add the saucer JSRL to the vector list
	RTS

; add fire to the vector list

add_fire:
	MOVE.w	shot_jsr(pc),(a4)+	; add the shot JSRL to the vector list

	MOVEQ		#3,d0				; set the game counter mask
	AND.w		game_count(a3),d0		; mask the game counter
	BNE.s		no_shot_dec			; skip the shot decrement 3/4 of the time

	SUBQ.b	#1,flags_off(a5,d6.w)	; decrement fire item (d7) flag
no_shot_dec
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add d1.b to the current player's score

add_score:
	MOVE.w	#4,CCR			; set Zb, clear everything else
	MOVE.b	score_off+1(a5),d2	; get the player's score, tens
	ABCD.b	d1,d2				; add the value to the score
	BCC.s		exit_add_score		; if no carry just exit

	MOVEQ		#0,d1				; clear the add high byte
	MOVE.b	score_off(a5),d0		; get the player's score, thousands
	ABCD.b	d1,d0				; add the value to the score
	MOVE.b	d0,score_off(a5)		; save the player's score, thousands

	ANDI.b	#$0F,d0			; mask the units of thousands
	BNE.s		exit_add_score		; if the score is not x0000 just exit

	MOVEQ		#extra_snd,d1		; set the bonus ship sound
	BSR		play_sample			; go play the sample

	ADDQ.b	#1,ships_off(a5)		; increment the player's ship count
	BNE.s		exit_add_score		; exit if not wrappwd

	SUBQ.b	#1,ships_off(a5)		; decrement the player's ship count
exit_add_score
	MOVE.b	d2,score_off+1(a5)	; save the player's score, tens
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; display the high score table if the game is over

high_scores:
	TST.b		num_players(a3)		; test the number of players in the game
	BNE		exit_no_scores		; if playing skip the high scores

	BTST.b	#2,game_count(a3)		; test a bit in the game counter high byte
	BNE		exit_no_scores		; if not high score time just exit

	LEA		hiscores(a3),a2		; point to the high score table

	TST.w		(a2)				; test the highest high score
	BEQ		exit_no_scores		; if the high score table is empty just exit

	MOVEQ		#0,d1				; message 0 - "HIGH SCORES"
	BSR		add_message			; add message d1 to the display list

	MOVE.w	#$1000,glob_scale(a3)	; set the global scale

	LEA		hinames(a3),a0		; point to the high score names
	MOVEQ		#0,d6				; clear the high score index
	MOVE.w	#$00A7,hiscore_y(a3)	; set the score's y co-ordinate
high_scores_loop
	TST.w		(a2)				; test the high score entry
	BEQ.s		exit_high_scores		; if this score is zero just exit

	MOVEQ		#$5F,d1			; set the score's x co-ordinate
	MOVE.w	hiscore_y(a3),d2		; get the score's y co-ordinate
	BSR		add_coords			; add co-ordinate pair in d1,d2 to the list as
							; a draw command

	MOVE.w	#REL4,d1			; make a $4000,$0000 command
	BSR		add_single			; add (d1)00,0000 to the vector list

	LEA		high_idx(a3),a1		; point to the high score index
	MOVEQ		#$01,d7			; set the number byte count and the increment
	MOVE.w	#4,CCR			; set Zb, clear everything else
	ABCD.b	d7,d6				; add to the high score index
	MOVE.b	d6,(a1)			; save the high score decimal index
	MOVE.b	d7,suppress_0(a3)		; set the flag to suppress leading zeros
	BSR		output_number		; output a number as a leading zero suppressed
							; string

							; set the point after the high score number
	MOVE.w	#REL4,d1			; make a $4000,$xx00 command
	MOVE.w	d1,d2				; make a $4000,$4000 command, point after entry
							; number
	BSR		add_pair			; add (d1)00,(d2)00 to the vector list

	MOVEQ		#0,d1				; set [SPACE] character
	BSR		add_character		; add character (d1) to the vector list

	MOVEA.l	a2,a1				; point to the high score entry
	MOVEQ		#$02,d7			; set the number byte count
	MOVE.b	#-1,suppress_0(a3)	; set the flag to suppress leading zeros
	BSR		output_number		; output a number as a leading zero suppressed
							; string

	MOVEQ		#0,d1				; add the final "0"
	BSR		add_hex_chr			; write a hex character to the vector list

	MOVEQ		#0,d1				; set [SPACE] character
	BSR		add_character		; add character (d1) to the vector list

	BSR		write_initial		; write a high score initial to the vector list
	BSR		write_initial		; write a high score initial to the vector list
	BSR		write_initial		; write a high score initial to the vector list

	SUBQ.w	#8,hiscore_y(a3)		; subtract 8 from the score's y co-ordinate
	ADDQ.w	#2,a2				; increment the high score pointer

	CMPI.b	#$10,d6			; compare the high score index with 10
	BCS.s		high_scores_loop		; loop if more to do

exit_high_scores
	ORI.b		#$01,CCR			; set the carry, flag scores displayed
	RTS

exit_no_scores
	ANDI.b	#$FE,CCR			; clear the carry, flag scores not displayed
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; find a free rock item, the index is returned in d5

find_rock:
	MOVEQ		#p_flag_off-flags_off-1,d5
							; set the count/index to the last rock flag

; find a free rock item from d5

find_next_rock
	TST.b		flags_off(a5,d5.w)	; test the rock flag
	BEQ.s		exit_find_rock		; if free return this index

	DBF		d5,find_next_rock		; else loop if more to do

exit_find_rock
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; wrecked ship piece x,y velocities

ship_wrk_x
	dc.w	$FFD8					; x
	dc.w	$0032					; x
	dc.w	$0000					; x
	dc.w	$003C					; x
	dc.w	$000A					; x
	dc.w	$FFD8					; x

ship_wrk_y
	dc.w	$001E					; y
	dc.w	$FFEC					; y
	dc.w	$FFC4					; y
	dc.w	$0014					; y
	dc.w	$0046					; y
	dc.w	$FFD8					; y


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add the player explosion to the vector list

add_play_explode:
	MOVEM.l	d6-d7,-(sp)			; save the registers
	MOVEQ		#0,d1				; clear the longword
	MOVE.b	p_flag_off(a5),d1		; get the player flag
	CMPI.b	#$A2,d1			; compare the player flag with $A2
	BCC.s		no_reset_xy			; if >= $A2 skip resetting the explosion
							; start point

							; else reset the explosion start point
	MOVEQ		#$0A,d7			; set the index to the last piece x,y pair
reset_xy_loop
	MOVE.w	ship_wrk_x(pc,d7.w),d0	; get the x velocity word
	LSL.w		#4,d0				; ; 16
	MOVE.w	d0,expl_x_pos(a3,d7.w)	; save the x position word

	MOVE.w	ship_wrk_y(pc,d7.w),d0	; get the y velocity word
	LSL.w		#4,d0				; ; 16
	MOVE.w	d0,expl_y_pos(a3,d7.w)	; save the y position word

	SUBQ.w	#2,d7				; decrement the index
	BPL.s		reset_xy_loop		; loop if more to do

; now use the player flag as the start index to the ship pieces. this means there will
; be less pieces as the explosion progresses

no_reset_xy
	MOVEQ		#$70,d0			; set the mask
	EOR.b		d0,d1				; toggle the player flag
	AND.b		d0,d1				; mask the player flag
	LSR.b		#3,d1				; / 16 ; 2 gives the piece start index
	MOVE.w	d1,d7				; copy the index

							; the piece draw loop	
piece_draw_loop
	MOVE.w	ship_wrk_x(pc,d7.w),d0	; get the x velocity word
	ADD.w		expl_x_pos(a3,d7.w),d0	; add the x position word
	MOVE.w	d0,expl_x_pos(a3,d7.w)	; save the x position word

	MOVE.w	ship_wrk_y(pc,d7.w),d1	; get the y velocity word
	ADD.w		expl_y_pos(a3,d7.w),d1	; add the y position word
	MOVE.w	d1,expl_y_pos(a3,d7.w)	; save the y position word

	MOVEA.l	a4,a2				; copy the vector pointer

	MOVEQ		#0,d2				; clear the x sign bit
	TST.w		d0				; test the x position word
	BPL.s		vec_x_pos			; if positive skip the negate

	NEG.w		d0				; else negate the x position, make it positive
	MOVE.w	#$0400,d2			; and set the x sign bit
vec_x_pos

	MOVEQ		#0,d3				; clear the y sign bit
	TST.w		d1				; test the y position word
	BPL.s		vec_y_pos			; if positive skip the negate

	NEG.w		d1				; else negate the y position, make it positive
	MOVE.w	#$0400,d3			; and set the y sign bit
vec_y_pos
	LSR.w		#4,d0				; shift the x position
	LSR.w		#4,d1				; shift the y position

	OR.w		d2,d0				; OR in the x sign bit
	ORI.w		#$6000,d1			; fix the scale
	OR.w		d3,d1				; OR in the y sign bit

	MOVE.w	d1,(a4)+			; add y position to the vector list
	MOVE.w	d0,(a4)+			; add x position to the vector list

							; add the piece vector to the list

	MOVE.w	ship_parts(pc,d7.w),d0	; get wrecked ship piece vector word
	MOVE.w	d0,(a4)+			; add the wrecked ship piece vector word to the
							; vector list

	EORI.w	#$0404,d0			; toggle the sign bits
	ANDI.w	#$FF0F,d0			; clear the intensity bits
	MOVE.w	d0,(a4)+			; add the inverse wrecked ship piece vector word
							; to the vector list

							; now copy an inverse relative long vector to
							; the list
	MOVE.l	(a2),d0			; get the vector to the piece
	EORI.l	#$04000400,d0		; toggle the sign bits
	MOVE.l	d0,(a4)+			; save the inverse vector to the list

	SUBQ.w	#2,d7				; decrement the index
	BPL		piece_draw_loop		; loop if more to do

	MOVEM.l	(sp)+,d6-d7			; restore the registers
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; pieces of wrecked ship

ship_parts
	dc.w	$FFC6				; x = -2, Y = -3
	dc.w	$FEC1				; x =  1, Y = -2
	dc.w	$F1C3				; x =  3, Y =  1
	dc.w	$F1CD				; x = -1, Y =  1
	dc.w	$F1C7				; x = -3, Y =  1
	dc.w	$FDC1				; x =  1, Y = -1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add the player ship to the vector list

add_player:
	MOVEQ		#0,d3				; clear the x_sign
	MOVEQ		#0,d2				; clear the y_sign
	MOVEQ		#0,d4				; yx_sign

	MOVE.b	p_orient(a3),d1		; get the player orientation
	BPL.s		no_pos_reflect		; if positive skip reflection

	MOVE.w	#$0400,d2			; set the y_sign
	MOVE.w	d2,d4				; set the yx_sign
	NEG.b		d1				; make ABS orientation
	BMI.s		third_quad			; if still negative go do the third quad

no_pos_reflect
	BTST.l	#6,d1				; test the quadrant
	BEQ.s		first_quad			; skip reflect if in first quadrant

third_quad
	MOVE.w	#$0400,d3			; set the x_sign
	MOVE.b	#$04,d4			; set the yx_sign

	NEG.b		d1				; negate the byte
	ADD.b		#$80,d1			; reflect the quadrant
first_quad
	LSR.b		#1,d1				; do quadrant value / 2
	AND.b		#$3E,d1			; mask to word boundary, value is $00 to $20

	LEA		play_tab(pc),a1		; point to the player ship table
	MOVE.w	(a1,d1.w),d1		; get the offset to the player ship
	LEA		(a1,d1.w),a1		; get the pointer to the player ship
	BSR.s		copy_vectors		; copy the vectors from (a1) to the vector list

;	MOVEQ		#'L',d1			; set for the thrust button
;	MOVEQ		#19,d0			; check for keypress
;	TRAP		#15
	moveq #5,d0
	trap #15
	cmpi.b #'L',d1
	bne.s no_thrust

;	TST.b		d1				; test the result
;	BEQ.s		no_thrust			; if not pressed then skip the thrust copy

	MOVEQ		#3,d0				; set the game counter mask
	AND.w		game_count(a3),d0		; mask the game counter
	BNE.s		copy_vectors		; 3/4 of the time go copy the vectors from (a1)
							; to the vector list and return
no_thrust
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; copy the vectors from (a1) to the vector list

copy_short:
	EOR.w		d4,d0				; possibly toggle the x and y signs
	MOVE.w	d0,(a4)+			; copy the word to the vector list

copy_vectors
	MOVE.w	(a1)+,d0			; get a vector word
	CMP.w		#SHRT,d0			; compare with short form vector
	BCC.s		copy_short			; if short vector go copy it

	CMP.w		#DRAW,d0			; compare with the DRAW command
	BCC.s		exit_copy_vectors		; if DRAW or greater exit the vector copy

; else it is a long vector

	EOR.w		d2,d0				; possibly toggle the y sign
	MOVE.w	d0,(a4)+			; copy the word to the vector list
	MOVE.w	(a1)+,d0			; get the second vector word
	EOR.w		d3,d0				; possibly toggle the x sign
	MOVE.w	d0,(a4)+			; copy the word to the vector list
	BRA.s		copy_vectors		; go do the next word

; it's a short form vector

exit_copy_vectors
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; do the game sounds

fx_sounds:
	MOVEQ		#0,d1				; clear the longword
	MOVE.b	s_flag_off(a5),d1		; get the saucer flag
	BLE.s		no_saucer_sound		; if no saucer or the saucer is exploding skip
							; the saucer sound

	ADDQ.b	#smsau_snd-1,d1		; add the small saucer sound to the size
	BSR		play_sample			; go play the sample
no_saucer_sound
	TST.b		rock_count(a5)		; test the rock count
	BEQ.s		no_thump_sound		; if no rocks skip the thump sound

	TST.b		p_flag_off(a5)		; test the player flag
	BLE.s		no_thump_sound		; if no player or the player is exploding skip
							; the thump sound

	TST.b		hyper(a3)			; test the hyperspace flag
	BNE.s		no_thump_sound		; if in hyperspace skip the thump sound

	SUBQ.b	#1,thump_time(a3)		; decrement the thump sound change timer
	BNE.s		no_thump_sound		; skip changing the sound if not timed out

	MOVEQ		#4,d0				; add the sound on time
	ADD.b		thmp_sndi(a5),d0		; add the thump sound change timer initial
	MOVE.b	d0,thump_time(a3)		; save the thump sound change timer

	MOVEQ		#1,d0				; set the bitmap change mask
	MOVE.b	thump_snd(a3),d1		; get the thump sound value
	EOR.b		d0,d1				; change the thump sound value
	MOVE.b	d1,thump_snd(a3)		; save the thump sound value
	BRA		play_sample			; go play the sample and return

no_thump_sound
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; handle something hitting a rock

; d6 = player/saucer/shot object index
; d7 = object index

hit_a_rock:
	MOVE.b	#$50,r_hit_tim(a5)	; set the rock hit timer
	MOVE.b	flags_off(a5,d7.w),d0	; get the rock flag
	MOVEQ		#$78,d1			; set the mask for the rock type
	AND.b		d0,d1				; mask the rock type

	ANDI.w	#$07,d0			; mask the rock size
	LSR.w		#1,d0				; / 2
	MOVE.w	d0,d2				; copy the size
	BEQ.s		clear_rock			; if the size is zero then the rock is destroyed
							; so go clear the rock flag

	OR.b		d1,d0				; else OR back the rock type
clear_rock
	MOVE.b	d0,flags_off(a5,d7.w)	; save the rock flag

	TST.b		num_players(a3)		; test the number of players in the game
	BEQ.s		skip_add			; if no players skip the score add

	TST.w		d6				; test the player/saucer/shot index
	BEQ.s		add_to_score		; if the player hit the rock go add it to the
							; player's score

	CMPI.w	#p_fire_off-p_flag_off,d6
							; compare the player/saucer/shot index with the
							; first of the player's fire
	BCS.s		skip_add			; if < the player's fire skip adding to the
							; player's score

add_to_score
	MOVE.b	rock_score(pc,d2.w),d1	; get the score per rock size
	BSR		add_score			; add d1.b to the current player's score
skip_add
	TST.b		flags_off(a5,d7.w)	; test the rock flag
	BEQ.s		exit_hit_a_rock		; if the rock was destroyed just exit

; else break the rock into none, one, or two smaller rocks

	BSR		find_rock			; find a free rock, the index is returned in d5
	BNE.s		exit_hit_a_rock		; if there are no free rocks just exit

	ADDQ.b	#1,rock_count(a5)		; else increment the rock count

	BSR		copy_rock			; copy the item parameters from the old rock,
							; (d7), to the new rock, (d5)

	MOVEQ		#$1F,d0			; set the mask for the low 5 bits
	AND.b		x_vel_off(a5,d5.w),d0	; get the new rock x velocity byte
	ADD.b		d0,d0				; ; 2
	EOR.b		d0,x_pos_off+1(a5,d3.w)	; purturb the new rock x position low byte

	BSR		find_next_rock		; find a free rock from d5, the index is
							; returned in d5
	BNE.s		exit_hit_a_rock		; if there are no free rocks just exit

	ADDQ.b	#1,rock_count(a5)		; else increment the rock count

	BSR		copy_rock_2			; copy the item parameters from the old rock,
							; (d7), to the new rock, (d5)

	MOVEQ		#$1F,d0			; set the mask for the low 5 bits
	AND.b		y_vel_off(a5,d5.w),d0	; get the new rock y velocity byte
	ADD.b		d0,d0				; ; 2
	EOR.b		d0,y_pos_off+1(a5,d3.w)	; purturb the new rock y position low byte
exit_hit_a_rock
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; score per rock size

rock_score
	dc.b	$10					; 100 points, small rock
	dc.b	$05					;  50 points, medium rock
	dc.b	$02					;  20 points, large rock
	dc.b	$00					;   0 points, null pad byte


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; do the high score checks

check_hiscores:
	MOVE.b	num_players(a3),d0	; get the number of players in the game
	BPL.s		exit_check_hiscores	; if still players just exit

	MOVE.b	d0,high_off(a5)		; clear the player 2 highscore flag
	MOVE.b	d0,high_off(a6)		; clear the player 1 highscore flag

	MOVE.b	#$01,player_idx(a3)	; set the player index for player two
	LEA		player_2(a3),a5		; set the pointer to player two's variables
	LEA		player_1(a3),a6		; set the pointer to player one's variables
check_hi_player
	MOVEQ		#0,d2				; clear the high score index
	MOVE.w	score_off(a5),d0		; get the player score
	BEQ.s		check_hi_next		; if zero go try the other player

check_hi_loop
	CMP.w		hiscores(a3,d2.w),d0	; compare the high score with the player score
	BHI.s		insert_hiscore		; if the player score was more go insert the
							; score

	ADDQ.w	#2,d2				; increment the high score index
	CMPI.w	#20,d2			; compare with max + 2
	BCS.s		check_hi_loop		; loop if more high scores to do

							; else change to the other player
check_hi_next
	EXG		a5,a6				; swap the players
	EORI.b	#1,player_idx(a3)		; toggle the player index
	BEQ.s		check_hi_player		; loop if more players to do

	MOVE.b	high_off(a5),d0		; get player 2's highscore flag
	BMI.s		exit_hi_chk			; if not entering a high score go clear the
							; player count and exit

	CMP.b		high_off(a6),d0		; compare with the player 1 highscore flag
	BCS.s		exit_hi_chk			; if player 2's position < player 1's position
							; just exit

	ADDQ.b	#3,d0				; else increment player 2's position to the
							; next entry
	CMPI.b	#$1E,d0			; compare the result with max + 1
	BCS.s		save_hi_index		; if less go save the new player 1 index

	MOVEQ		#-1,d0			; else reset player 2's highscore flag
save_hi_index
	MOVE.b	d0,high_off(a5)		; save player 2's highscore flag
exit_hi_chk
	MOVEQ		#0,d0				; clear the longword
	MOVE.b	d0,num_players(a3)	; clear the number of players in the game
	MOVE.b	d0,hi_char(a3)		; clear the input character index
exit_check_hiscores
	RTS

; insert a new high score into the high score table. the index is in d2.w

insert_hiscore:
	MOVEQ		#18,d3			; index to the last high score
	MOVEQ		#27,d4			; index to the last high score initials
insert_loop
	CMP.w		d3,d2				; compare the current high score with the insert
							; point
	BEQ.s		exit_insert_loop		; if there exit the loop

	MOVE.w	hiscores-2(a3,d3.w),hiscores(a3,d3.w)
							; copy the (n-1)th high score to this one
	MOVE.b	hinames-3(a3,d4.w),hinames(a3,d4.w)
							; copy the (n-1)th high score name first byte
	MOVE.b	hinames-2(a3,d4.w),hinames+1(a3,d4.w)
							; copy the (n-1)th high score name second byte
	MOVE.b	hinames-1(a3,d4.w),hinames+2(a3,d4.w)
							; copy the (n-1)th high score name third byte

	SUBQ.w	#2,d3				; decrement the index to the previous score
	SUBQ.w	#3,d4				; decrement the index to the previous initials
	BNE.s		insert_loop			; loop for the next high score

exit_insert_loop
	MOVE.b	d4,high_off(a5)		; save the player highscore flag
	MOVE.w	d0,hiscores(a3,d3.w)	; copy the player score to this one
	MOVE.b	#$0B,hinames(a3,d4.w)	; make the high score name first byte "A"
	CLR.b		hinames+1(a3,d4.w)	; make the high score name second byte " "
	CLR.b		hinames+2(a3,d4.w)	; make the high score name third byte " "

	MOVE.b	#$F0,game_count(a3)	; set the game counter high byte, high score
							; entry timeout

	BRA.s		check_hi_next		; loop for the other player


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; calculate the angle given the delta x,y. the delta is calculated by subtracting the
; source x,y co-ordinates from the target x,y co-ordinates. the angle is returned in
; d0.b with $00 being 3 o'clock
;
; d1.w = delta x = target x - source x
; d2.w = delta y = target y - source y

get_atn:
	TST.w		d2				; test the delta y
	BPL.s		atn_semi			; if +ve skip the delta y negate

	NEG.w		d2				; else make delta y positive
	BSR.s		atn_semi			; get arctan(y/x) for the semicircle
	NEG.b		d0				; negate the result
	RTS

; get arctan(y/x) for the semicircle

atn_semi:
	TST.w		d1				; test the delta x
	BPL.s		atn_quad			; if +ve skip the delta x negate

	NEG.w		d1				; else make delta x positive
	BSR.s		atn_quad			; get arctan(y/x) or arctan(x/y)
	EORI.b	#$80,d0			; reflect 180 degrees
	NEG.b		d0				; negate the result
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; get arctan(y/x) or arctan(x/y) for one quadrant.

atn_quad:
	CMP.w		d1,d2				; compare y with x
	BCS.s		atn_eight			; if x > y get arctan(y/x) from the table
							; and return

	EXG		d1,d2				; else swap x,y
	BSR.s		atn_eight			; get arctan(x/y) from the table
	SUBI.b	#$40,d0			; reflect the quadrant
	NEG.b		d0				; and negate the result
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; divide d2.w by d1.w, the six bit result in d0.w is then used to index the ATN()
; table to get the result for this octant. (is that the right word for one eighth
; of a circle?)

atn_eight:
	MOVEQ		#0,d0				; clear the result
	MOVEQ		#6-1,d7			; set the bit count
loop_atn
	ADD.w		d2,d2				; shift the dividend
	MOVE.w	d2,d3				; copy the dividend
	SUB.w		d1,d3				; compare it with the divisor
	BCS.s		skip_sub			; if the dividend < the divisor skip the
							; subtract

	SUB.w		d1,d2				; else subtract the divisor
skip_sub
	ADDX.b	d0,d0				; shift a bit into the result
	DBF		d7,loop_atn			; loop if more to do

	ANDI.b	#$3F,d0			; mask the result to $0000 to $003F
	MOVE.b	atn_tab(pc,d0.w),d0	; get the arctan from the table
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; arctangent table. returns the effective angle of the dx/dy ratio for scaled values
; of dx/dy of up to 0.984375 or 63/64ths. this is only 1/8th of a full circle but it
; is easy to rotate and reflect these values to cover the other 7/8ths.

atn_tab
	dc.b	$20,$20,$1F,$1F,$1F,$1E,$1E,$1E,$1D,$1D,$1C,$1C,$1C,$1B,$1B,$1A
	dc.b	$1A,$1A,$19,$19,$18,$18,$17,$17,$17,$16,$16,$15,$15,$14,$14,$13
	dc.b	$13,$12,$12,$11,$11,$10,$0F,$0F,$0E,$0E,$0D,$0D,$0C,$0B,$0B,$0A
	dc.b	$0A,$09,$08,$08,$07,$07,$06,$05,$05,$04,$03,$03,$02,$02,$01,$00


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; output a number as a leading zero suppressed character string
;
; a1 = number address
; d7 = number byte count

output_number:
	SUBQ.w	#1,d7				; adjust for the loop type
output_number_loop
	MOVE.b	(a1),d1			; get a byte
	LSR.b		#4,d1				; shift the high nibble to the low nibble
	BSR		add_sup_hex_chr		; add a leading zero suppressed character
	TST.w		d7				; test the byte count
	BNE.s		zero_suppress		; if this isn't the last byte skip the zero
							; suppress clear

	CLR.b		suppress_0(a3)		; clear the zero suppress for the last digit
zero_suppress
	MOVE.b	(a1)+,d1			; get a byte and increment the pointer
	BSR		add_sup_hex_chr		; add a leading zero suppressed character
	DBF		d7,output_number_loop	; decrement count and loop if more to do

	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; get COS(d0) in d0. d0 is an eight bit value representing a full circle with the
; value increasing as you turn widdershins

cos_d0
	ADDI.b	#$40,d0			; add 1/4 rotation

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; get SIN(d0) in d0. d0 is an eight bit value representing a full circle with the
; value increasing as you turn widdershins

sin_d0
	ANDI.w	#$00FF,d0			; mask one full circle
	TST.b		d0				; test angle sign
	BPL.s		cossin_d0			; if +ve just get SIN/COS and return

	BSR.s		cossin_d0			; else get SIN/COS
	NEG.w		d0				; now do twos complement
	RTS

; get d0 from SIN/COS table

cossin_d0
	ADD.b		d0,d0				; ; 2 bytes per word value
	BPL.s		a_was_less			; branch if the angle < 1/4 circle

	NEG.b		d0				; wrap $82 to $FE to $7E to $02
a_was_less
	MOVE.w	sin_cos(pc,d0.w),d0	; get the SIN/COS value
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; SIN/COS table, returns values between $0000 and $7FFF. the last value should be
; $8000 but that can cause an overflow in the word length calculations and it's
; easier to fudge the table a bit. no one will ever notice.

sin_cos
	dc.w	$0000,$0324,$0648,$096B,$0C8C,$0FAB,$12C8,$15E2
	dc.w	$18F9,$1C0C,$1F1A,$2224,$2528,$2827,$2B1F,$2E11
	dc.w	$30FC,$33DF,$36BA,$398D,$3C57,$3F17,$41CE,$447B
	dc.w	$471D,$49B4,$4C40,$4EC0,$5134,$539B,$55F6,$5843
	dc.w	$5A82,$5CB4,$5ED7,$60EC,$62F2,$64E9,$66CF,$68A7
	dc.w	$6A6E,$6C24,$6DCA,$6F5F,$70E3,$7255,$73B6,$7505
	dc.w	$7642,$776C,$7885,$798A,$7A7D,$7B5D,$7C2A,$7CE4
	dc.w	$7D8A,$7E1E,$7E9D,$7F0A,$7F62,$7FA7,$7FD9,$7FF6
	dc.w	$7FFF


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add message d1 to the display list

add_message:
	MOVE.w	#$1000,glob_scale(a3)	; set the global scale

	ADD.w		d1,d1				; make into a word index
	MOVE.w	d1,-(sp)			; save the index

	ADD.w		d1,d1				; make into a word pair index
	LEA		mess_origin(pc),a0	; point to the mesage co-ordinate table
	MOVE.w	2(a0,d1.w),d2		; get the message y co-ordinate
	MOVE.w	(a0,d1.w),d1		; get the message x co-ordinate
	BSR		add_coords			; add co-ordinate pair in d1,d2 to the list as
							; a draw command

	MOVE.w	#REL7,d1			; make a $7000,$0000 command
	BSR		add_single			; add (d1)00,0000 to the vector list

	MOVEQ		#$03,d0			; set the mask for the language bits
	MOVEA.l	switch_addr(a3),a0	; point to the switch
	AND.b		(a0),d0			; get and mask the switch bits
	ADD.w		d0,d0				; make into a word pointer

	LEA		mess_table(pc),a0		; point to the mesage language table
	MOVE.w	(a0,d0.w),d0		; get the offset to the messages
	LEA		(a0,d0.w),a0		; get the pointer to the messages

	MOVE.w	(sp)+,d1			; restore the message index

	MOVE.w	(a0,d1.w),d1		; get the offset to the message
	LEA		(a0,d1.w),a0		; get the pointer to the message
	LEA		char_set(pc),a1		; get the pointer to the character JSRL table
	MOVEQ		#0,d0				; clear the longword
add_char_loop
	MOVE.b	(a0)+,d0			; get the next character
	BEQ.s		exit_add_message		; if null just exit

; convert the character and add it to the vector list

	SUB.b		#' ',d0			; subtract [SPACE]
	BEQ.s		add_the_char		; if it was [SPACE] go add it

	SUB.b		#15,d0			; convert a number
	CMPI.b	#11,d0			; compare with converted "9"+1
	BCS.s		add_the_char		; if it was <="9" go add it

	SUBQ.b	#7,d0				; else convert "A" to "Z"
add_the_char
	ADD.b		d0,d0				; ; 2
	MOVE.w	(a1,d0.w),(a4)+		; copy the JSRL to the vector list
	BRA.s		add_char_loop		; loop for next

exit_add_message
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; timer interrupt. the timer interrupt should be triggered every 16ms

timer_interrupt
	ADDQ.b	#1,sixteen_ms(a3)		; increment the 16ms counter
	RTE


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add "PLAYER x" to the vector list

player_x:
	MOVEQ		#1,d1				; message 1 - "PLAYER "
	BSR		add_message			; add message d1 to the display list
player_n
	MOVEQ		#1,d1				; make 0,1 into 1,2
	ADD.b		player_idx(a3),d1		; add the player index
	BRA.s		add_hex_chr			; write a hex character to the vector list
							; and return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; if suppress_0 <> 0 write a leading zero suppressed hex character to the vector list

add_sup_hex_chr
	TST.b		suppress_0(a3)		; test the leading zero suppressed flag
	BEQ.s		add_hex_chr			; if not suppressed go write a hex character
							; to the vector list

; if supressed write a [SPACE] instead of a "0"

	MOVEQ		#$0F,d0			; set the nibble mask
	AND.w		d0,d1				; mask the low nibble
	BEQ.s		add_sup_zero		; if it is zero go write a space

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; write a hex character d1 to the vector list

add_hex_chr
	AND.w		#$0F,d1			; mask the low nibble
	ADDQ.w	#1,d1				; add 1 to pass the [SPACE] character
	CLR.b		suppress_0(a3)		; clear the leading zero suppressed flag
add_sup_zero
	ADD.w		d1,d1				; ; 2, bytes per character
	MOVE.l	a0,-(sp)			; save a0
	LEA		char_set(pc),a0		; point to the character JSRL table
	MOVE.w	(a0,d1.w),(a4)+		; copy the character JSRL to the vector list
	MOVE.l	(sp)+,a0			; restore a0

	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; convert the a1 address and add it to the vector list as a vector subroutine call

add_address:
	LEA		vector(pc),a0		; point to the vector memory
	SUBA.l	a0,a1				; convert the pointer to an offset
	MOVE.l	a1,d1				; copy the result
	LSR.w		#1,d1				; / 2
	AND.w		#$0FFF,d1			; mask the address bits
	ORI.w		#JSRL,d1			; OR with vector subroutine call
	MOVE.w	d1,(a4)+			; copy to the vector list
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add 4 ; the co-ordinate pair in d1,d2 to the list as a draw command

add_coords:
	MOVEQ		#2,d0				; set shift count
	ASL.w		d0,d1				; x co-ordinate ; 4
	ASL.w		d0,d2				; y co-ordinate ; 4

	MOVE.w	#$0FFC,d0			; set the co-ordinate mask
	AND.w		d0,d1				; mask the x co-ordinate
	AND.w		d0,d2				; mask the y co-ordinate

	ORI.w		#DRAW,d2			; OR in the draw command
	OR.w		glob_scale(a3),d1		; OR in the global scale

	MOVE.w	d2,(a4)+			; save the command/y co-ordinate to the list
	MOVE.w	d1,(a4)+			; save the scale/x co-ordinate to the list
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add (d1)00,0000 to the vector list

add_single
	MOVEQ		#0,d2				; clear the second word


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; add (A)00,(X)00 to the vector list

add_pair
	MOVE.w	d1,(a4)+			; save the first word to the vector list
	MOVE.w	d2,(a4)+			; save the second word to the vector list
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; check the [F2], [F3] and [F4] keys. set the screen size to 640 x 480, 800 x 600 or
; 1024 x 768 if the corresponding key has been pressed

s_controls
;	MOVE.l	#$71007273,d1		; [F2], [], [F3] and [F4] keys
;	MOVEQ		#19,d0			; check for keypress
;	TRAP		#15

;	MOVEQ		#33,d0			; set/get output window size

;	MOVE.l	d1,d2				; copy result
;	BEQ.s		notscreen			; skip screen size if no F key

;	MOVE.l	#$028001E0,d1		; set 640 x 480
;	TST.l		d2				; test result
;	BMI.s		setscreen			; if F2 go set window size

;	MOVE.l	#$03200258,d1		; set 800 x 600
;	TST.w		d2				; test result
;	BMI.s		setscreen			; if F3 go set window size

							; else was F4 so ..
;	MOVE.l	#$04000300,d1		; set 1024 x 768
setscreen
;	CMP.l		scr_x(a3),d1		; compare with current screen size
;	BEQ.s		notscreen			; if already set skip setting it now

;	TRAP		#15

notscreen
;	MOVEQ		#0,d1				; get the current window size
;	TRAP		#15

	move.l #$03200258,d1		; always 800x600
	move.l d1,scr_x(a3)			; save the screen x and y size
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; setup stuff.

Initialise:
	moveq	#0,d1					; turn off echo
	moveq	#12,d0				; keyboard echo
	trap #15

	move.w #$FF00,d1		; clear screen
	moveq #11,d0				; position cursor
	trap #15

	moveq #17,d1				; enable double buffering
	moveq	#92,d0				; set draw mode
	trap #15

	moveq #10,d1				; OR mode drawing, this helps on two ways.
							; first it emulates a vector display where
							; the vectors that cross can bright up the
							; intersection and second it means we can
							; forget depth sorting of objects
	moveq #92,d0				; set draw mode
	trap #15

	lea	variables(pc),a3	; get the pointer to the variables base
	lea player_1(a3),a5		; get the pointer to player one's variables
	lea player_2(a3),a6		; get the pointer to player two's variables

										; clear all the variable space
	moveq #0,d0				; clear the longword
	lea hiscore_y(a3),a0		; get the start address
	lea p_2_end(a3),a1			; get the end address
clear_loop
	move.w d0,(a0)+			; clear the word
	cmpa.l a1,a0				; compare the addresses
	bne.s clear_loop		; if not at end loop

	moveq #8,d0					; get the time in 1/100 ths seconds
	trap #15

	eori.l	#$DEADBEEF,d1		; EOR with the initial PRNG seed, this must
													; result in any value but zero
	jsr InitRand
;	move.l	d1,PRNlword(a3)		; save the initial PRNG seed

	moveq #3,d1					; get the switches address
	moveq #32,d0				; simulator hardware
	trap #15

	move.l d1,switch_addr(a3)	; save the switches address

	;LEA		timer_interrupt(pc),a0	; get the timer interrupt routine address
	;MOVE.l	a0,$64.w			; save the timer interrupt as interrupt 1

	;MOVEQ		#6,d1				; set auto IRQ
	;MOVEQ		#$81,d2			; enable IRQ 1
	;MOVEQ		#16,d3			; set the time in ms
	;MOVEQ		#32,d0			; set simulator hardware
	;TRAP		#15

	;MOVEQ		#5,d1				; enable exceptions
	;MOVEQ		#32,d0			; set simulator hardware
	;TRAP		#15

	lea vector(pc),a4			; get the pointer to the vector list RAM
	move.w #HALT,(a4)			; add HALT to the vector list

	bsr sound_init				; initialise the sounds

	moveq #-1,d0					; flag high score done
	move.b d0,p1_high(a3)	; save the player 1 highscore flag
	move.b d0,p2_high(a3)	; save the player 2 highscore flag

	lea filename(pc),a1		; point to the highscore filename
	moveq	#51,d0					; open existing file
	trap #15

	tst.w d0							; check for errors
	beq.s read_hi					; if no error go read the file

	cmpi.w #3,d0					; compare with read only
	bne.s	close_all_2			; if not read only go close all files

read_hi
	lea hiscores(a3),a1		; point to the highscore tables
	moveq	#50,d2					; set the table length
	moveq	#53,d0					; read file
	trap #15

close_all_2
	moveq #50,d0					; close all files
	trap #15

	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This is the code that generates the pseudo random sequence. A seed word located in
; PRNlword(a3) is loaded into a register before being operated on to generate the
; next number in the sequence. This number is then saved as the seed for the next
; time it's called.
;
; This code is adapted from the 32 bit version of RND(n) used in EhBASIC68. Taking
; the 19th next number is slower but helps to hide the shift and add nature of this
; generator as can be seen from analysing the output.

gen_prng:
	jmp RandGetNum

;	MOVEM.l	d0-d2,-(sp)			; save d0, d1 and d2
;	MOVE.l	PRNlword(a3),d0		; get current seed longword
;	MOVEQ		#$AF-$100,d1		; set the EOR value
;	MOVEQ		#18,d2			; do this 19 times
Ninc0
;	ADD.l		d0,d0				; shift left 1 bit
;	BCC.s		Ninc1				; if bit not set skip feedback

;	EOR.b		d1,d0				; do Galois LFSR feedback
Ninc1
;	DBF		d2,Ninc0			; loop

;	MOVE.l	d0,PRNlword(a3)		; save back to seed longword
;	MOVEM.l	(sp)+,d0-d2			; restore d0, d1 and d2

;	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; vector generator subroutines. this code emulates the atari digital vector generator
; and truns the vector draw list into lines on the screen

; vector subroutine return code. if a vector subroutine is called the address for this
; code is pushed on the stack

op_rtsvec:
	MOVE.l	(sp)+,a4			; restore the vector pointer

; evaluate the next vector command. the command is pointed to by (a4) and execution
; will continue until an RTSL or HALT command is encountered. this is a subset of the
; battlezone DVG command set

do_vector:
	MOVE.w	(a4)+,d4			; get the vector opcode
	MOVE.w	d4,d0				; copy it
	ROL.w		#6,d0				; shift opcode bits to b5-b2
	ANDI.w	#$003C,d0			; mask the opcode bits
	JMP		vector_base(pc,d0.w)	; go do the vector opcode

; call vector subroutine, push the vector pointer and then the vector subroutine
; address as the return address then do jump to vector address

op_call
	MOVE.l	a4,-(sp)			; save the vector pointer
	PEA		op_rtsvec(pc)		; push vector return code as return address

; jump to vector, the address is a thirteen bit address

op_jump
	AND.w		#$0FFF,d4			; mask the address
	ADD.w		d4,d4				; make it a word address
	LEA		vector(pc),a4		; reset the vector RAM pointer
	LEA		(a4,d4.w),a4		; calculate the new address
	BRA.s		do_vector			; go do the next vector

; relative vector routine. co-ordinates are ten bit with sign numbers

op_vctr
	MOVE.w	#$07FF,d7			; set the co-ordinate and sign bits mask
	MOVEQ		#10,d1			; set the sign bit number

	AND.w		d7,d4				; mask the y co-ordinate and sign
	BCLR.l	d1,d4				; test and clear the sign bit
	BEQ.s		no_neg_y11			; if positive skip the negate

	NEG.w		d4				; else negate the y co-ordinate
no_neg_y11

	MOVE.w	(a4)+,d3			; get the second word
	MOVE.w	d3,d2				; copy the intensity

	AND.w		d7,d3				; mask the x co-ordinate and sign
	BCLR.l	d1,d3				; test and clear the sign bit
	BEQ.s		no_neg_x11			; if positive skip the negate

	NEG.w		d3				; else negate the x co-ordinate
no_neg_x11

	ASR.w		#2,d0				; make the scale count from the masked JMP
	NEG.w		d0				; make negative
	ADD.w		#9,d0				; make 9 - scale

	ASR.w		d0,d3				; scale the x co-ordinate
	ASR.w		d0,d4				; scale the y co-ordinate

	BRA		end_vector			; go do the end of the vector draw

; set scale and position the beam

op_abs
	MOVE.w	#$07FF,d7			; set the co-ordinate and sign bits mask
	MOVEQ		#10,d1			; set the sign bit number

	AND.w		d7,d4				; mask the y co-ordinate and sign
	BCLR.l	d1,d4				; test and clear the sign bit
	BEQ.s		no_neg_y10			; if positive skip the negate

	NEG.w		d4				; else negate the y co-ordinate
no_neg_y10

	MOVE.w	(a4)+,d3			; get the second word
	MOVE.w	d3,d2				; copy the scale

	AND.w		d7,d3				; mask the x co-ordinate and sign
	BCLR.l	d1,d3				; test and clear the sign bit
	BEQ.s		no_neg_x10			; if positive skip the negate

	NEG.w		d3				; else negate the x co-ordinate
no_neg_x10

; now convert the scale so it is b15 = direction flag and the rest is the shift count

	ROL.w		#4,d2				; move the scale bits to bits 3 to 0
	ANDI.w	#$000F,d2			; mask the scale bits
	BCLR.l	#3,d2				; clear the top bit
	BEQ.s		not_right			; ship right shift adjust

	NEG.w		d2				; make negative
	ADD.w		#$8008,d2			; add offset and flag right shift
not_right
	MOVE.w	d2,(a3)			; save the global scal, offset is zero	##
;##	MOVE.w	d2,vector_s(a3)		; save the global scale

	MOVEQ		#86,d0			; set move to x,y
	BRA		vector_move			; go do the move

vector_base
	RTS						; treat $0xxx as HALT, quit processing vectors
	NOP						; filler
	BRA.w		op_vctr			; scale 1 relative long vector
	BRA.w		op_vctr			; scale 2 relative long vector
	BRA.w		op_vctr			; scale 3 relative long vector
	BRA.w		op_vctr			; scale 4 relative long vector
	BRA.w		op_vctr			; scale 5 relative long vector
	BRA.w		op_vctr			; scale 6 relative long vector
	BRA.w		op_vctr			; scale 7 relative long vector
	BRA.w		op_vctr			; scale 8 relative long vector
	BRA.w		op_vctr			; scale 9 relative long vector
	BRA.w		op_abs			; set scale and position beam
	RTS						; do HALT, quit processing vectors
	NOP						; filler
	BRA.w		op_call			; call vector subroutine
	RTS						; return from vector subroutine
	NOP						; filler
	BRA.w		op_jump			; do vector jump
;##	BRA.w		op_short			; draw relative short vector

; do relative short vector

op_short
	MOVE.w	d4,d7				; copy the opcode
	ANDI.w	#$0808,d7			; mask the scale bits	0000 x000 0000 y000
	LSL.w		#4,d7				; shift bits to b8,b0	x000 0000 y000 0000
	ROL.b		#1,d7				; shift bits together	x000 0000 0000 000y
	ROL.w		#1,d7				; shift bits to b1,b0	0000 0000 0000 00yx
	ADDQ.w	#1,d7				; make 1 to 4

	MOVE.b	d4,-(sp)			; push the intensity byte
	MOVE.w	(sp)+,d2			; pull the word, intensity now in high byte

	MOVEQ		#7,d0				; set the co-ordinate and sign bits mask
	MOVEQ		#2,d1				; set the sign bit number

	MOVE.w	d4,d3				; copy the opcode for the x co-ordinate

	MOVE.w	d4,-(sp)			; push the opcode
	MOVE.b	(sp)+,d4			; pull the y co-ordinate byte

	AND.w		d0,d4				; mask the y co-ordinate and sign bits
	BCLR.l	d1,d4				; test and clear the sign bit
	BEQ.s		no_neg_y2			; if positive just exit

	NEG.w		d4				; else negate the y co-ordinate
no_neg_y2

	AND.w		d0,d3				; mask the x co-ordinate and sign bits
	BCLR.l	d1,d3				; test and clear the sign bit
	BEQ.s		no_neg_x2			; if positive just exit

	NEG.w		d3				; else negate the x co-ordinate
no_neg_x2

	ASL.w		d7,d3				; scale the x magnitude
	ASL.w		d7,d4				; scale the y magnitude

end_vector
	MOVE.w	(a3),d7			; get the global scale, offset is zero	##
;##	MOVE.w	vector_s(a3),d7		; get the global scale
	BPL.s		shift_left			; if positive go shift left

							; else shift right
	ASR.w		d7,d3				; scale the x co-ordinate
	ASR.w		d7,d4				; scale the y co-ordinate
	BRA.s		last_vector			; continue

shift_left
	ASL.w		d7,d3				; scale the x co-ordinate
	ASL.w		d7,d4				; scale the y co-ordinate
last_vector
	ADD.w		local_x(a3),d3		; add x the co-ordinate to vector x
	ADD.w		local_y(a3),d4		; add y the co-ordinate to vector y

	MOVEQ		#86,d0			; set move to x,y

	AND.w		#$F000,d2			; d2 is intensity
	BEQ.s		vector_move			; if zero intensity just do move

	MOVEQ		#0,d1				; clear the longword
	MOVE.w	d2,-(sp)			; copy the intensity
	MOVE.b	(sp)+,d2			; to the low byte byte
	MOVE.b	d2,d1				; copy the intensity byte
	SWAP		d1				; move to the high word
	MOVE.w	d2,d1				; get the other word

	MOVEQ		#80,d0			; set pen colour
	TRAP		#15

	MOVEQ		#85,d0			; set draw to x,y
vector_move
	MOVE.w	d4,d2				; copy the y co-ordinate
	MOVE.w	d3,d1				; copy the x co-ordinate
;##	BRA.s		display_vector		; display the vector


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; display vector and do next. takes the vector, scales the x and y to the current
; screen size - does axis inversion if needed - and then displays it. set up the
; graphics function in d0, x co-ordinate in d1.w and y co-ordinate in d2.w

;##display_vector
	MOVE.w	d1,local_x(a3)		; save as new local x co-ordinate
	MOVE.w	d2,local_y(a3)		; save as new local y co-ordinate

	MOVEQ		#10,d3			; set the shift count for / 1024

	MULS.w	scr_x(a3),d1		; x ; screen x
	ASR.l		d3,d1				; / 1024

	SUB.w		#128,d2			; subtract offset to centre vertically
	MULS.w	scr_x(a3),d2		; y ; screen x
	ASR.l		d3,d2				; / 1024
	NEG.w		d2				; y = 0 is top of screen remember
	ADD.w		scr_y(a3),d2		; + screen y
	SUBQ.w	#1,d2				; - 1

	TRAP		#15				; do move or draw

	BRA		do_vector			; go do the next vector opcode


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; vector commands

REL1		EQU $1000				; draw relative
REL2		EQU $2000				; draw relative
REL3		EQU $3000				; draw relative
REL4		EQU $4000				; draw relative
REL5		EQU $5000				; draw relative
REL6		EQU $6000				; draw relative
REL7		EQU $7000				; draw relative
REL8		EQU $8000				; draw relative
REL9		EQU $9000				; draw relative
DRAW		EQU $A000				; draw absolute
HALT		EQU $B000				; halt
JSRL		EQU $C000				; vector subroutine call
RTSL		EQU $D000				; return from vector subroutine
JMPL		EQU $E000				; vector jump
SHRT		EQU $F000				; relative short vector


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; vector list RAM

vector
	ds.b	$1000					; 4k of space


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; vector ROM

; copyright symbol followed by JSR's to write "2009 LEE DAVISO", followed by a JMP to
; char_n, which is the routine for "N"

copy_msg
	dc.w	$A088,$019A,$7000,$0000,$F573,$F173,$F178,$F177
	dc.w	$F577,$F578,$3180,$0200,$F875,$FD70,$F871,$FD02
	dc.w	JSRL+(char_2-vector)>>1		; 2
	dc.w	JSRL+(char_o0-vector)>>1	; 0
	dc.w	JSRL+(char_o0-vector)>>1	; 0
	dc.w	JSRL+(char_9-vector)>>1		; 9
	dc.w	JSRL+(char_spc-vector)>>1	; [SPACE]
	dc.w	JSRL+(char_l-vector)>>1		; L
	dc.w	JSRL+(char_e-vector)>>1		; E
	dc.w	JSRL+(char_e-vector)>>1		; E
	dc.w	JSRL+(char_spc-vector)>>1	; [SPACE]
	dc.w	JSRL+(char_d-vector)>>1		; D
	dc.w	JSRL+(char_a-vector)>>1		; A
	dc.w	JSRL+(char_v-vector)>>1		; V
	dc.w	JSRL+(char_i-vector)>>1		; I
	dc.w	JSRL+(char_s-vector)>>1		; S
	dc.w	JSRL+(char_o0-vector)>>1	; O
	dc.w	JMPL+(char_n-vector)>>1		; N

; table for the various saucer and rock explosions

expl_tab
	dc.w	JSRL+(expl_0-vector)>>1		; explosion 0
	dc.w	JSRL+(expl_1-vector)>>1		; explosion 1
	dc.w	JSRL+(expl_2-vector)>>1		; explosion 2
	dc.w	JSRL+(expl_3-vector)>>1		; explosion 3

; explosion 3

expl_3
	dc.w	$F80D,$F8F8,$FD0D,$F8F8,$FD09,$F8F8,$F10B,$F8F8
	dc.w	$F50A,$F8F8,$F908,$F8F8,$F309,$F8F8,$F30D,$F8F8
	dc.w	$5480,$0600,$F8F8,$F10F,$F8F8,RTSL

; explosion 2

expl_2
	dc.w	$3000,$0780,$F8F8,$3780,$0780,$F8F8,$3780,$0380
	dc.w	$F8F8,$40E0,$02A0,$F8F8,$35C0,$0380,$F8F8,$3380
	dc.w	$0000,$F8F8,$42A0,$00E0,$F8F8,$42A0,$04E0,$F8F8
	dc.w	$44E0,$0780,$F8F8,$40E0,$06A0,$F8F8,RTSL

; explosion 1

expl_1
	dc.w	$F807,$F8F8,$FF07,$F8F8,$FF03,$F8F8,$40C0,$0240
	dc.w	$F8F8,$3580,$0300,$F8F8,$FB00,$F8F8,$4240,$00C0
	dc.w	$F8F8,$4240,$04C0,$F8F8,$44C0,$0700,$F8F8,$40C0
	dc.w	$0640,$F8F8,RTSL

; explosion 0

expl_0
	dc.w	$3000,$0680,$F8F8,$3680,$0680,$F8F8,$3680,$0280
	dc.w	$F8F8,$3140,$03C0,$F8F8,$3540,$0280,$F8F8,$3280
	dc.w	$0000,$F8F8,$33C0,$0140,$F8F8,$33C0,$0540,$F8F8
	dc.w	$44A0,$0680,$F8F8,$3140,$07C0,$F8F8,RTSL

; table for rocks

rock_tab
	dc.w	JSRL+(rock_0-vector)>>1		; top notch rock
	dc.w	JSRL+(rock_1-vector)>>1		; "X" rock
	dc.w	JSRL+(rock_2-vector)>>1		; bottom and left notch rock
	dc.w	JSRL+(rock_3-vector)>>1		; left and right notch rock

; top notch rock

rock_0
	dc.w	$F908,$F979,$FD79,$F67D,$F679,$F68F,$F08F,$F97D
	dc.w	$FA78,$F979,$FD79,RTSL

; "X" rock

rock_1
	dc.w	$F10A,$F17A,$F97D,$F57E,$F17E,$FD7D,$F679,$F67D
	dc.w	$FD79,$F179,$F58B,$F38A,$F97D,RTSL

; bottom and left notch rock

rock_2
	dc.w	$F80D,$F57E,$F77A,$F37A,$F778,$F879,$F37A,$F978
	dc.w	$F37E,$F07F,$F77F,$F57A,RTSL

; left and right notch rock

rock_3
	dc.w	$F009,$F17B,$F168,$F27F,$F07F,$F669,$F07F,$F778
	dc.w	$F77A,$F17B,$F569,$F969,$F27F,RTSL

; indirect saucer table

sauc_jsr
	dc.w	JSRL+(sauc_vec-vector)>>1	; saucer

; saucer

sauc_vec
	dc.w	$F10E,$F8CA,$F60B,$6000,$D680,$F6DB,$F8CA,$F2DB
	dc.w	$F2DF,$F2CD,$F8CD,$F6CD,$F6DF,RTSL

; player ship address table

play_tab
	dc.w	play_00-play_tab
	dc.w	play_01-play_tab
	dc.w	play_02-play_tab
	dc.w	play_03-play_tab
	dc.w	play_04-play_tab
	dc.w	play_05-play_tab
	dc.w	play_06-play_tab
	dc.w	play_07-play_tab
	dc.w	play_08-play_tab
	dc.w	play_09-play_tab
	dc.w	play_0A-play_tab
	dc.w	play_0B-play_tab
	dc.w	play_0C-play_tab
	dc.w	play_0D-play_tab
	dc.w	play_0E-play_tab
	dc.w	play_0F-play_tab
	dc.w	play_10-play_tab

; ship and thrust outlines. each ship outline is followed by its thrust outline which
; is only copied if the thrust button is pressed

play_00
	dc.w	$F60F,$FAC8,$F9BD,$6500,$C300,$6500,$C700,$F9B9
	dc.w	RTSL
	dc.w	$F9CE,$F9CA,RTSL
play_01
	dc.w	$4640,$06C0,$5200,$C430,$41C0,$C620,$64B0,$C318
	dc.w	$6548,$C6E0,$4220,$C1C0,RTSL
	dc.w	$50D0,$C610,$4260,$C3C0,RTSL
play_02
	dc.w	$4680,$0680,$43E0,$C4C0,$41A0,$C660,$6468,$C320
	dc.w	$6590,$C6C0,$4260,$C1A0,RTSL
	dc.w	$5090,$C630,$42C0,$C380,RTSL
play_03
	dc.w	$46C0,$0640,$43E0,$C520,$4160,$C680,$6418,$C328
	dc.w	$65D0,$C698,$4280,$C160,RTSL
	dc.w	$5060,$C630,$4320,$C340,RTSL
play_04
	dc.w	$F70E,$43C0,$C580,$4120,$C6A0,$6038,$C328,$6610
	dc.w	$C660,$42A0,$C120,RTSL
	dc.w	$5030,$C640,$4360,$C2E0,RTSL
play_05
	dc.w	$4720,$05C0,$4380,$C5E0,$40E0,$C6C0,$6088,$C320
	dc.w	$6648,$C630,$42C0,$C0E0,RTSL
	dc.w	$5410,$C640,$43A0,$C2A0,RTSL
play_06
	dc.w	$4760,$0560,$4360,$C640,$4080,$C6C0,$60D8,$C310
	dc.w	$6680,$C5F0,$42C0,$C080,RTSL
	dc.w	$5440,$C630,$43E0,$C240,RTSL
play_07
	dc.w	$4780,$0500,$4320,$C680,$4040,$C6E0,$6120,$C2F8
	dc.w	$66B0,$C5B0,$42E0,$C040,RTSL
	dc.w	$5480,$C630,$5210,$C0F0,RTSL
play_08
	dc.w	$4780,$04C0,$42E0,$C6E0,$4000,$C6E0,$6168,$C2D8
	dc.w	$66D8,$C568,$42E0,$C000,RTSL
	dc.w	$54B0,$C620,$5220,$C0B0,RTSL
play_09
	dc.w	$47A0,$0460,$4280,$C720,$4440,$C6E0,$61B0,$C2B0
	dc.w	$66F8,$C520,$42E0,$C440,RTSL
	dc.w	$54F0,$C610,$5230,$C080,RTSL
play_0A
	dc.w	$47A0,$0000,$4240,$C760,$4480,$C6C0,$61F0,$C280
	dc.w	$6710,$C4D8,$42C0,$C480,RTSL
	dc.w	$4640,$C7E0,$5230,$C040,RTSL
play_0B
	dc.w	$47A0,$0060,$41E0,$C780,$44E0,$C6C0,$6230,$C248
	dc.w	$6720,$C488,$42C0,$C4E0,RTSL
	dc.w	$46A0,$C7A0,$5240,$C010,RTSL
play_0C
	dc.w	$4780,$00C0,$4180,$C7C0,$4520,$C6A0,$6260,$C210
	dc.w	$6728,$C438,$42A0,$C520,RTSL
	dc.w	$46E0,$C760,$5240,$C430,RTSL
play_0D
	dc.w	$4780,$0100,$4120,$C7E0,$4560,$C680,$6298,$C1D0
	dc.w	$6728,$C018,$4280,$C560,RTSL
	dc.w	$4740,$C720,$5230,$C460,RTSL
play_0E
	dc.w	$4760,$0160,$40C0,$C7E0,$45A0,$C660,$62C0,$C190
	dc.w	$6720,$C068,$4260,$C5A0,RTSL
	dc.w	$4780,$C6C0,$5230,$C490,RTSL
play_0F
	dc.w	$4720,$01C0,$5030,$C600,$45C0,$C620,$62E0,$C148
	dc.w	$6718,$C0B0,$4220,$C5C0,RTSL
	dc.w	$47C0,$C660,$5210,$C4D0,RTSL
play_10
	dc.w	$F70A,$F8CE,$FDCD,$6300,$C100,$6700,$C100,$F9CD
	dc.w	RTSL
	dc.w	$FECD,$FACD,RTSL

; ship outline for player lives

play_liv
	dc.w	$F70E,$F87A,$FD79,$6300,$7500,$6700,$7500,$F979
	dc.w	$60C0,$0280,$D09F

; character set

char_a						; A
	dc.w	$FA70,$F272,$F672,$FE70
	dc.w	$F906,$F872,$F602,RTSL
char_b						; B
	dc.w	$FB70,$F073,$F571,$F570
	dc.w	$F575,$F077,$F003,$F571
	dc.w	$F570,$F575,$F077,$F803,RTSL
char_c						; C
	dc.w	$FB70,$F872,$FF06,$F872
	dc.w	$F002,RTSL
char_d						; D
	dc.w	$FB70,$F072,$F672,$F670
	dc.w	$F676,$F076,$F803,RTSL
char_e						; E
	dc.w	$FB70,$F872,$F705,$F077
	dc.w	$F700,$F872,$F002,RTSL
char_f						; F
	dc.w	$FB70,$F872,$F705,$F077
	dc.w	$F700,$F803,RTSL
char_g						; G
	dc.w	$FB70,$F872,$F670,$F606
	dc.w	$F072,$F670,$F876,$F803
	dc.w	RTSL
char_h						; H
	dc.w	$FB70,$F700,$F872,$F300
	dc.w	$FF70,$F002,RTSL
char_i						; I
	dc.w	$F872,$F006,$FB70,$F002
	dc.w	$F876,$FF03,RTSL
char_j						; J
	dc.w	$F200,$F672,$F072,$FB70
	dc.w	$FF01,RTSL
char_k						; K
	dc.w	$FB70,$F003,$F777,$F773
	dc.w	$F003,RTSL
char_l						; L
	dc.w	$FB00,$FF70,$F872,$F002,RTSL
char_m						; M
	dc.w	$FB70,$F672,$F272,$FF70
	dc.w	$F002,RTSL
char_n						; N
	dc.w	$FB70,$FF72,$FB70,$FF01,RTSL
char_o0						; O,0
	dc.w	$FB70,$F872,$FF70,$F876
	dc.w	$F803,RTSL
char_p						; P
	dc.w	$FB70,$F872,$F770,$F876
	dc.w	$F703,$F003,RTSL
char_q						; Q
	dc.w	$FB70,$F872,$FE70,$F676
	dc.w	$F076,$F202,$F672,$F002
	dc.w	RTSL
char_r						; R
	dc.w	$FB70,$F872,$F770,$F876
	dc.w	$F001,$F773,$F002,RTSL
char_s						; S
	dc.w	$F872,$F370,$F876,$F370
	dc.w	$F872,$FF01,RTSL
char_t						; T
	dc.w	$F002,$FB70,$F006,$F872
	dc.w	$FF01,RTSL
char_u						; U
	dc.w	$FB00,$FF70,$F872,$FB70
	dc.w	$FF01,RTSL
char_v						; V
	dc.w	$FB00,$FF71,$FB71,$FF01,RTSL
char_w						; W
	dc.w	$FB00,$FF70,$F272,$F672
	dc.w	$FB70,$FF01,RTSL
char_x						; X
	dc.w	$FB72,$F806,$FF72,$F002,RTSL
char_y						; Y
	dc.w	$F002,$FA70,$F276,$F802
	dc.w	$F676,$FE02,RTSL
char_z						; Z
	dc.w	$FB00,$F872,$FF76,$F872
	dc.w	$F002,RTSL
char_spc						; [SPACE]
	dc.w	$F803,RTSL
char_1						; 1
	dc.w	$F002,$FB70,$FF02,RTSL
char_2						; 2
	dc.w	$FB00,$F872,$F770,$F876
	dc.w	$F770,$F872,$F002,RTSL
char_3						; 3
	dc.w	$F872,$FB70,$F876,$F700
	dc.w	$F872,$F702,RTSL
char_4						; 4
	dc.w	$FB00,$F770,$F872,$F300
	dc.w	$FF70,$F002,RTSL
char_5						; 6
	dc.w	$F872,$F370,$F876,$F370
	dc.w	$F872,$FF01,RTSL
char_6						; 6
	dc.w	$F300,$F872,$F770,$F876
	dc.w	$FB70,$FF03,RTSL
char_7						; 7
	dc.w	$FB00,$F872,$FF70,$F002,RTSL
char_8						; 8
	dc.w	$F872,$FB70,$F876,$FF70
	dc.w	$F300,$F872,$F702,RTSL
char_9						; 9
	dc.w	$F802,$FB70,$F876,$F770
	dc.w	$F872,$F702,RTSL

; indirect table for character set

char_set
	dc.w	JSRL+(char_spc-vector)>>1	; [SPACE]
	dc.w	JSRL+(char_o0-vector)>>1	; 0 also O
	dc.w	JSRL+(char_1-vector)>>1		; 1
	dc.w	JSRL+(char_2-vector)>>1		; 2
	dc.w	JSRL+(char_3-vector)>>1		; 3
	dc.w	JSRL+(char_4-vector)>>1		; 4
	dc.w	JSRL+(char_5-vector)>>1		; 5
	dc.w	JSRL+(char_6-vector)>>1		; 6
	dc.w	JSRL+(char_7-vector)>>1		; 7
	dc.w	JSRL+(char_8-vector)>>1		; 8
	dc.w	JSRL+(char_9-vector)>>1		; 9
	dc.w	JSRL+(char_a-vector)>>1		; A
	dc.w	JSRL+(char_b-vector)>>1		; B
	dc.w	JSRL+(char_c-vector)>>1		; C
	dc.w	JSRL+(char_d-vector)>>1		; D
	dc.w	JSRL+(char_e-vector)>>1		; E
	dc.w	JSRL+(char_f-vector)>>1		; F
	dc.w	JSRL+(char_g-vector)>>1		; G
	dc.w	JSRL+(char_h-vector)>>1		; H
	dc.w	JSRL+(char_i-vector)>>1		; I
	dc.w	JSRL+(char_j-vector)>>1		; J
	dc.w	JSRL+(char_k-vector)>>1		; K
	dc.w	JSRL+(char_l-vector)>>1		; L
	dc.w	JSRL+(char_m-vector)>>1		; M
	dc.w	JSRL+(char_n-vector)>>1		; N
	dc.w	JSRL+(char_o0-vector)>>1	; O also 0
	dc.w	JSRL+(char_p-vector)>>1		; P
	dc.w	JSRL+(char_q-vector)>>1		; Q
	dc.w	JSRL+(char_r-vector)>>1		; R
	dc.w	JSRL+(char_s-vector)>>1		; S
	dc.w	JSRL+(char_t-vector)>>1		; T
	dc.w	JSRL+(char_u-vector)>>1		; U
	dc.w	JSRL+(char_v-vector)>>1		; V
	dc.w	JSRL+(char_w-vector)>>1		; W
	dc.w	JSRL+(char_x-vector)>>1		; X
	dc.w	JSRL+(char_y-vector)>>1		; Y
	dc.w	JSRL+(char_z-vector)>>1		; Z

; indirect shot table

shot_jsr
	dc.w	JSRL+(shot_vec-vector)>>1	; shot

; shot vector object, a small cross of intensity $F

shot_vec
	dc.w	$7420,$0000
	dc.w	$7040,$F000
	dc.w	$7420,$0420
	dc.w	$7000,$F040
	dc.w	RTSL


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; canned messages

; x,y co-ordinates for the message origins

mess_origin
	dc.w	$0064,$00B6				; message 0 x,y
	dc.w	$0064,$00B6				; message 1 x,y
	dc.w	$000C,$00AA				; message 2 x,y
	dc.w	$000C,$00A2				; message 3 x,y
	dc.w	$000C,$009A				; message 4 x,y
	dc.w	$000C,$0092				; message 5 x,y
	dc.w	$0064,$00C6				; message 6 x,y
	dc.w	$0064,$009D				; message 7 x,y

; message tables

mess_table
	dc.w	e_messages-mess_table		; english
	dc.w	d_messages-mess_table		; german
	dc.w	f_messages-mess_table		; french
	dc.w	s_messages-mess_table		; spanish

; message offset table

e_messages
	dc.w	e_mess_0-e_messages		; message 0
	dc.w	e_mess_1-e_messages		; message 1
	dc.w	e_mess_2-e_messages		; message 2
	dc.w	e_mess_3-e_messages		; message 3
	dc.w	e_mess_4-e_messages		; message 4
	dc.w	e_mess_5-e_messages		; message 5
	dc.w	e_mess_6-e_messages		; message 6
	dc.w	e_mess_7-e_messages		; message 7

e_mess_0
	dc.b	'HIGH SCORES',$00
e_mess_1
	dc.b	'PLAYER ',$00
e_mess_2
	dc.b	'YOUR SCORE IS ONE OF THE TEN BEST',$00
e_mess_3
	dc.b	'PLEASE ENTER YOUR INITIALS',$00
e_mess_4
	dc.b	'PUSH ROTATE TO SELECT LETTER',$00
e_mess_5
	dc.b	'PUSH HYPERSPACE WHEN LETTER IS CORRECT',$00
e_mess_6
	dc.b	'PUSH START',$00
e_mess_7
	dc.b	'GAME OVER',$00

	ds.w	0					; ensure even

; german message offset table

d_messages
	dc.w	d_mess_0-d_messages		; message 0
	dc.w	d_mess_1-d_messages		; message 1
	dc.w	d_mess_2-d_messages		; message 2
	dc.w	d_mess_3-d_messages		; message 3
	dc.w	d_mess_4-d_messages		; message 4
	dc.w	d_mess_5-d_messages		; message 5
	dc.w	d_mess_6-d_messages		; message 6
	dc.w	d_mess_7-d_messages		; message 7

d_mess_0
	dc.b	'HOECHSTERGEBNIS',$00
d_mess_1
	dc.b	'SPIELER ',$00
d_mess_2
	dc.b	'IHR ERGEBNIS IST EINES DER ZEHN BESTEN',$00
d_mess_3
	dc.b	'BITTE GEBEN SIE IHRE INITIALEN EIN',$00
d_mess_4
	dc.b	'ZUR BUCHSTABENWAHL ROTATE DRUECKEN',$00
d_mess_5
	dc.b	'WENN BUCHSTABE OK HYPERSPACE DRUECKEN',$00
d_mess_6
	dc.b	'STARTKNOEPFE DRUECKEN',$00
d_mess_7
	dc.b	'SPIELENDE',$00

	ds.w	0					; ensure even

; french message offset table

f_messages
	dc.w	f_mess_0-f_messages		; message 0
	dc.w	f_mess_1-f_messages		; message 1
	dc.w	f_mess_2-f_messages		; message 2
	dc.w	f_mess_3-f_messages		; message 3
	dc.w	f_mess_4-f_messages		; message 4
	dc.w	f_mess_5-f_messages		; message 5
	dc.w	f_mess_6-f_messages		; message 6
	dc.w	f_mess_7-f_messages		; message 7

f_mess_0
	dc.b	'MEILLEUR SCORE',$00
f_mess_1
	dc.b	'JOUER ',$00
f_mess_2
	dc.b	'VOTRE SCORE EST UN DES 10 MEILLEURS',$00
f_mess_3
	dc.b	'SVP ENTREZ VOS INITIALES',$00
f_mess_4
	dc.b	'POUSSEZ ROTATE POUR VOS INITIALES',$00
f_mess_5
	dc.b	'POUSSEZ HYPERSPACE QUAND LETTRE CORRECTE',$00
f_mess_6
	dc.b	'APPUYER SUR START',$00
f_mess_7
	dc.b	'FIN DE PARTIE',$00

	ds.w	0					; ensure even

; spanish message offset table

s_messages
	dc.w	s_mess_0-s_messages		; message 0
	dc.w	s_mess_1-s_messages		; message 1
	dc.w	s_mess_2-s_messages		; message 2
	dc.w	s_mess_3-s_messages		; message 3
	dc.w	s_mess_4-s_messages		; message 4
	dc.w	s_mess_5-s_messages		; message 5
	dc.w	s_mess_6-s_messages		; message 6
	dc.w	s_mess_7-s_messages		; message 7

s_mess_0
	dc.b	'RECORDS',$00
s_mess_1
	dc.b	'JUGADOR ',$00
s_mess_2
	dc.b	'SU PUNTAJE ESTA ENTRE LOS DIEZ MEJORES',$00
s_mess_3
	dc.b	'POR FAVOR ENTRE SUS INICIALES',$00
s_mess_4
	dc.b	'OPRIMA ROTATE PARA SELECCIONAR LA LETRA',$00
s_mess_5
	dc.b	'OPRIMA HYPERSPACE',$00
s_mess_6
	dc.b	'PULSAR START',$00
s_mess_7
	dc.b	'JUEGO TERMINADO',$00

	ds.w	0					; ensure even


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; include files

	INCLUDE	"games/asteroids/sounds.x68"
							; sound routines


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; high score table filename

filename
	dc.b		'asteroids.hi',0		; highscore filename
	ds.w		0				; ensure even


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; variables

variables

	OFFSET	0				; going to use relative addressing

vector_s
;##	ds.w	1				; vector scale
glob_scale	ds.w	1				; global scale


local_x	ds.w	1				; local screen x co-ordinate offset
local_y	ds.w	1				; local screen y co-ordinate offset

scr_x		ds.w	1				; screen x size
scr_y		ds.w	1				; screen y size

PRNlword	ds.l	1				; PRNG seed long word

switch_addr	ds.l	1				; hardware switch address

hiscore_y	ds.w	1				; high score y co-ordinate


s_key		ds.b	1				; last [s] key status
play_sound	ds.b	1				; sound flag

suppress_0	ds.b	1				; leading zero suppress flag
							; 0 = don't suppress

high_idx	ds.b	1				; high score index, single byte, 1 to 10 in BCD

player_idx	ds.b	1				; player index
							; 0 = player 1
							; 1 = player 2

past_play	ds.b	1				; number of players that were in the game

num_players	ds.b	1				; number of players in the game
							; $00 - game over
							; $01 - 1 player game
							; $02 - 2 player game
							; $FF - game over, high score not checked

ss_count	ds.b	1				; starting ship count

px_time	ds.b	1				; "PLAYER x" timer. while this is non zero
							; "PLAYER x" will be displayed. this is used at
							; the beginning of any game and at the beginning
							; of each turn in a two player game

sixteen_ms	ds.b	1				; 16ms counter, incremented every 16ms by the
							; timer interrupt and cleared by the main
							; program loop

p_orient	ds.b	1				; player orientation, this is shared by both
							; players as it is in the arcade machine
							;
							; $00 = right
							; $40 = up
							; $80 = left
							; $C0 = down
							;
							; this is $00 = right then anticlockwise each
							; positive step being 1.40625 degrees so that
							; by the time you get back to $00 one full
							; rotation has been done

s_orient	ds.b	1				; shot direction, see above

hi_char	ds.b	1				; high score input character index

last_fire	ds.b	1				; fire key last state register
last_hype	ds.b	1				; hyperspace key last state register

thump_snd	ds.b	1				; thump sound value
thump_time	ds.b	1				; thump sound change timer
time_count	ds.b	1				; game counter byte

hyper		ds.b	1				; hyperspace flag
							; $00 = no jump
							; $01 = jump successful
							; $80 = jump unsuccessful
							; $xx = 

		ds.w	0

hiscores	ds.w	10				; high score table, each score is a BCD word
hinames	ds.b	3*10				; high score initials table

game_count	ds.w	1				; game counter word

expl_x_pos	ds.w	6				; player ship explosion pieces x positions

expl_y_pos	ds.w	6				; player ship explosion pieces y positions


; player 1 variables

player_1	EQU	*+$80				; player one variables base

x_pos_off	EQU	*-player_1			; offset to the x position base
		ds.w	$1B				; item x position base address

p_xpos_off	EQU	*-player_1			; offset to the player x position
		ds.w	1				; player x position

s_xpos_off	EQU	*-player_1			; offset to the saucer x position
		ds.w	1				; saucer x position

f_xpos_off	EQU	*-player_1			; offset to the player x position
		ds.w	6				; fire objects x position
x_pos_end	EQU	*-player_1			; offset to the flags end

y_pos_off	EQU	*-player_1			; offset to the y position base
		ds.w	$1B				; item y position base address

p_ypos_off	EQU	*-player_1			; offset to the player y position
		ds.w	1				; player y position
s_ypos_off	EQU	*-player_1			; offset to the saucer y position
		ds.w	1				; saucer y position

f_ypos_off	EQU	*-player_1			; offset to the player y position
		ds.w	6				; fire objects y position

							; items $xx00 to $xx1A are rocks
							; $00 = no item
							; $0x = item exists
							; $Ax = item exploding

flags_off	EQU	*-player_1			; offset to the flags base
		ds.b	$1B				; space for the rock flags

p_flag_off	EQU	*-player_1			; offset to the player flag
		ds.b	1				; player flag

s_flag_off	EQU	*-player_1			; offset to the saucer flag
		ds.b	1				; saucer flag
							; $00 = no saucer
							; $01 = small saucer
							; $02 = large saucer
							; $8x = saucer exploding

s_fire_off	EQU	*-player_1			; offset to the saucer fire flags
		ds.b	2				; saucer fire objects

p_fire_off	EQU	*-player_1			; offset to the player fire flags
		ds.b	4				; player fire objects
flag_end	EQU	*-player_1			; offset to the flags end

x_vel_off	EQU	*-player_1			; offset to the x velocity base
		ds.b	$1B				; item x velocity base address

p_xvel_off	EQU	*-player_1			; offset to the player x velocity
		ds.b	1				; player x velocity

s_xvel_off	EQU	*-player_1			; offset to the saucer x velocity
		ds.b	1				; saucer x velocity

f_xvel_off	EQU	*-player_1			; offset to the fire objects x velocity
		ds.b	6				; fire objects x velocity

y_vel_off	EQU	*-player_1			; offset to the x velocity base
		ds.b	$1B				; item y velocity base address

p_yvel_off	EQU	*-player_1			; offset to the player y velocity
		ds.b	1				; player y velocity

s_yvel_off	EQU	*-player_1			; offset to the saucer y velocity
		ds.b	1				; saucer y velocity

f_yvel_off	EQU	*-player_1			; offset to the fire objects y velocity
		ds.b	6				; fire objects y velocity


i_rk_count	EQU	*-player_1			; offset to the initial rock count
		ds.b	1				; initial rock count
rock_count	EQU	*-player_1			; offset to the rock count
		ds.b	1				; rock count

sauc_cntdn	EQU	*-player_1			; offset to the saucer countdown timer
		ds.b	1				; saucer countdown timer

i_sauc_tim	EQU	*-player_1			; offset to the initial saucer timer
		ds.b	1				; small saucer boundary/initial saucer timer

r_hit_tim	EQU	*-player_1			; offset to the rock hit timer
		ds.b	1				; rock hit timer. if this times out because the
							; player hasn't shot a rock for a while then
							; the saucer timer initial value is decremented
							; so that the saucers come faster if the player
							; is just ignoring the last rock

hide_p_cnt	EQU	*-player_1			; offset to the hide the player count
		ds.b	1				; hide the player count. when this count is non
							; zero the player is not displayed and the
							; thump sound does not sound. this count is set
							; to various lengths after certain events have
							; occured
							;
							; $0x player hidden, will appear
							; $8x player hidden, gonna die

new_rocks	EQU	*-player_1			; offset to the new rocks flag
		ds.b	1				; generate new rocks flag
							; 0 = generate new rocks
thmp_sndi	EQU	*-player_1			; offset to the thump sound change initial value
		ds.b	1				; thump sound change timer initial value

min_rocks	EQU	*-player_1			; offset to the minimum rock count
		ds.b	1				; minimum rock count before the saucer initial
							; timer starts to decrement

p_xvlo_off	EQU	*-player_1			; offset to the player y velocity low byte
		ds.b	1				; player x velocity low byte
p_yvlo_off	EQU	*-player_1			; offset to the player y velocity low byte
		ds.b	1				; player y velocity low byte

		ds.w	0				; ensure even

score_off	EQU	*-player_1			; offset to the score word
p1_score	ds.w	1				; player score

ships_off	EQU	*-player_1			; offset to the ship count
p1_ships	ds.b	1				; player 1 ship count

high_off	EQU	*-player_1			; offset to the player entering hiscore flag
p1_high	ds.b	1				; player 1 highscore flag
							; $0x - entering high score, also index
							; $8x - done


		ds.w	0				; ensure even

; player 2 variables


player_2	EQU	*+$80				; player two variables base
		ds.b	score_off+$80		; space for the player two variables

p2_score	ds.w	1				; player 2 score

p2_ships	ds.b	1				; player 2 ship count

p2_high	ds.b	1				; player 2 highscore flag
							; $0x - entering high score, also index
							; $8x - done

		ds.w	0				; ensure even

p_2_end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;	END	asteroids_start


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
