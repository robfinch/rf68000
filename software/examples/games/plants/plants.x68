;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;														;
;	Plants and animals demo EASy68K V1.20			2011/05/30			;
;														;
;	This world is inhabited by two types of life. Plants, which are photosyn-	;
;	thetic and will grow until they fill all space, and animals which eat the	;
;	foliage of the plants and will multiply while food is available.			;
;														;
;	The growing tip of the plant is a redish bud, this tip not only grows but	;
;	sprouts new buds as it goes up to a preset maximum number of buds. As a		;
;	bud grows and moves on it leaves behind green foliage. If a bud has no		;
;	space to grow into that bud stops growing and another bud can be spawned	;
;	elsewhere on the plant.										;
;														;
;	The animals eat the plant's green foliage and once they have eaten enough	;
;	they will spawn a new animal which will go its own way eating another share	;
;	of green foliage. If there is no green foliage to eat an animal will starve.	;
;														;
;	Also a bud trying to grow into the space where there is an animal will get	;
;	stepped on and die, and animal trying to eat the bud of a plant will get	;
;	sick and die. Watching over all this is a benevolent deity who, on seeing	;
;	the extinction of growing plants or eating animals will spawn a new proge-	;
;	nitor for the extinct species.								;
;														;
;														;
;	The main loop time is throttled by measuring the time the loop took and		;
;	then waiting the remains of the required time using task #23, delay. This,	;
;	on my laptop, reduces the CPU loading from 100% to 65%.				;
;														;
;	Changes to the way new plants and animals are spawned, the plant or animal	;
;	array is not searched if it is already full, has further reduced the CPU	;
;	loading to 50% on my laptop.									;
;														;
;														;
;	The [F2], [F3] and [F4]	keys can be used to select a screen size of 640 x	;
;	480, 800 x 600 and 1024 x 768 respectively.						;
;														;
;	[ESC] can be used to quit the program.							;
;														;
;	More 68000 and other projects can be found on my website at ..			;
;														;
;	 http://mycorner.no-ip.org/index.html							;
;														;
;	mail : leeedavison@googlemail.com								;
;														;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; some equates

ESC		EQU	$1B				; [ESC] character
;CR		EQU	$0D				; [CR] character
;LF		EQU	$0A				; [LF] character

def_back	EQU	$000000			; the default background colour
def_animal	EQU	$FFFFFF		; the default animal colour
def_plant	EQU	$8080FF			; the default plant colour
def_leaf	EQU	$008000			; the default leaf colour

def_plants	EQU	50				; the default plant count
def_p_spawn	EQU	1				; the default plant spawn level
def_animals	EQU	50				; the default animal count
def_a_spawn	EQU	5				; the default animal spawn level


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;

;	ORG		$20000
	code
	even

start_plants:
	move.b #14,leds
	bsr InitialisePlants	; go setup everything but the world
restart
	move.b #15,leds
	bsr	init_world				; go setup the world

; main loop

plants_main_loop
	MOVEQ		#8,d0				; get the time in 1/100 ths seconds
	TRAP		#15

	MOVE.l	d1,-(sp)			; save the time on the stack

	MOVEQ		#94,d0			; copy buffer screen to main
	TRAP		#15
	move.b #$03,leds

; animate the scene

	BSR		do_plants			; do the plants
	BSR		do_animals			; do the animals

; test the keys used

	BSR		screen_size			; test and handle widow size change keys
	BSR		test_escape			; test if the user wants to quit

; now see if we need to wait for some time

	MOVE.l	(sp)+,d7			; get the main loop start time
	MOVEQ		#8,d0				; get time in 1/100 ths seconds
	TRAP		#15

	move.b #$04,leds

; doing the BGT means that if the clock passed midnight while the code was in the main
; loop then the delay is skipped this go. this means things may run a bit fast for one
; loop which is waaaaay better than waiting for a few 100ths of a second shy of twenty
; four hours by mistake

	SUB.l		d1,d7				; subtract the current time from the start time
	BGT.s		end_main_loop		; if the time crossed midnight just contimue

; moving the wait time into d1 like this menas we can have any wait up to 1.27 seconds
; and still use the MOVEQ form to load it

	MOVEQ		#5,d1				; set the wait time in 100ths of a second
	ADD.l		d7,d1				; add the loop negative time delta
	BLE.s		end_main_loop		; if the time is up just contimue

	move.b #$05,leds
	moveq	#23,d0				; else wait d1 100ths of a second
	trap #15
	move.b #$06,leds

end_main_loop
	TST.w		redraw(a3)			; test the redraw flag
	BNE.s		restart			; if redraw go initialise the world

	TST.w		quit(a3)			; test the quit flag
	BEQ.s		plants_main_loop			; if not quit go get another key

; all done so tidy up and stop

;	MOVE.b	#16,d1			; disable double buffering
;	MOVE.b	#92,d0			; set draw mode
;	TRAP		#15

	LEA		goodbye_message(pc),a1	; set the goodbye message pointer
	MOVEQ		#13,d0			; display a string with [CR][LF]
	TRAP		#15

	jmp Monitor
;	MOVEQ		#9,d0				; halt the simulator
;	TRAP		#15

goodbye_message
	dc.b	$0C,CR,LF
	dc.b	'  Goodbye',0

	ds.w	0					; ensure even


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; test if the user wants to quit
	even
test_escape
	MOVEQ		#7,d0				; read the key status
	TRAP		#15

	TST.b		d1				; test the result
	BEQ.s		exit_test_escape		; if no key just exit

	MOVEQ		#5,d0				; read a key
	TRAP		#15

	CMPI.b	#ESC,d1			; compare with [ESC]
	BNE.s		exit_test_escape		; if not [ESC] just exit

	MOVEQ		#-1,d1			; set the longword
	MOVE.w	d1,quit(a3)			; set the quit flag
exit_test_escape
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; setup the world

init_world:
;	MOVE.w	#$FF00,d1			; clear screen
;	MOVEQ		#11,d0			; position cursor
;	TRAP		#15
	move.l #$70000,d7
	moveq #DEV_CLEAR,d6
	trap #0
	move.b #'E',d1
	jsr OutputChar

	MOVE.l	#def_animal,d0		; set the default animal colour
	MOVE.l	d0,animal_colour(a3)	; save the animal colour
	MOVE.l	#def_back,d0		; set the default background colour
	MOVE.l	d0,animal_fill(a3)	; save the animal fill colour


	MOVE.l	#def_plant,d0		; set the default plant colour
	MOVE.l	d0,plant_colour(a3)	; save the plant colour
	MOVE.l	#def_leaf,d0		; set the default leaf colour
	MOVE.l	d0,plant_fill(a3)		; save the plant fill colour

	MOVEQ		#def_plants,d0		; set the default plant count
	MOVE.w	d0,max_plants(a3)		; save the maximum plants count
	MOVEQ		#def_p_spawn,d0		; set the default plant spawn value
	MOVE.b	d0,plant_spawn(a3)	; save the plant spawn value

	MOVEQ		#def_animals,d0		; set the default animal count
	MOVE.w	d0,max_animals(a3)	; save the maximum animals count
	MOVEQ		#def_a_spawn,d0		; set the default animal spawn value
	MOVE.b	d0,animal_spawn(a3)	; save the animal spawn value

	MOVEQ		#0,d0				; clear the longword
	MOVE.w	d0,redraw(a3)		; clear the redraw flag

; clear all the plants

	LEA		plant_flag(a3),a0		; set the pointer to the plant flags
	MOVE.w	max_plants(a3),d7		; get the maximum plants count
	SUBQ.w	#1,d7				; adjust for the loop type
	move.b #$01,leds
clr_plant_loop
	MOVE.b	d0,(a0)+			; clear the plant flag
	DBF		d7,clr_plant_loop		; loop if more to do

	MOVE.w	d0,num_plants(a3)		; clear the plants count

; clear all the animals

	LEA		animal_flag(a3),a0	; set the pointer to the animal flags
	MOVE.w	max_animals(a3),d7	; get the maximum animals count
	SUBQ.w	#1,d7				; adjust for the loop type
clr_animals_loop
	MOVE.b	d0,(a0)+			; clear the animal flag
	DBF		d7,clr_animals_loop	; loop if more to do

	MOVE.w	d0,num_animals(a3)	; clear the animals count

; get the screen size
	move.b #$02,leds

	moveq #0,d1				; get current window size
	moveq #33,d0			; set/get output window size
	trap #15
	move.b #$03,leds

	lsr.l	#1,d1				; / 2 for 2x2 pixels
	move.l d1,width(a3)		; save the screen x,y size

	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; do the plants

do_plants
	move.b #$07,leds
	LEA		num_plants(a3),a0		; point to the plants count
	MOVE.w	max_plants(a3),a1		; get the plants maximum
	LEA		plant_spawn(a3),a2	; point to the plant spawn level
	LEA		plant_xy(a3),a4		; point to the plant position array
	LEA		plant_flag(a3),a5		; point to the plant flags
	MOVE.l	plant_colour(a3),thing_colour(a3)
							; copy the plant colour
	MOVE.l	plant_fill(a3),fill_colour(a3)
							; copy the plant fill colour
	MOVE.l	animal_fill(a3),food_colour(a3)
							; copy the animal fill colour
	MOVE.l	animal_colour(a3),poison_colour(a3)
							; copy the animal colour
	BRA.s		do_things			; go do the plants


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; do the animals

do_animals
	move.b #$08,leds
	LEA		num_animals(a3),a0	; point to the animals count
	MOVE.w	max_animals(a3),a1	; get the animals maximum
	LEA		animal_spawn(a3),a2	; point to the animal spawn level
	LEA		animal_xy(a3),a4		; point to the animal position array
	LEA		animal_flag(a3),a5	; point to the animal flags
	MOVE.l	animal_colour(a3),thing_colour(a3)
							; copy the animal colour
	MOVE.l	animal_fill(a3),fill_colour(a3)
							; copy the animal fill colour
	MOVE.l	plant_fill(a3),food_colour(a3)
							; copy the plant fill colour
	MOVE.l	plant_colour(a3),poison_colour(a3)
							; copy the plant colour


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; do things

do_things
	move.b #$09,leds
	MOVE.w	(a0),d7			; get the things count
	BNE.s		things_exist		; if things exist go make them eat

; else get a random position for thing zero

	MOVE.w	width(a3),d0		; get the screen width
	BSR		get_prng			; get a random number between 0 and d0.w - 1
	MOVE.w	d0,d3				; copy the x co-ordinate
	MOVE.w	d0,d4				; copy the x co-ordinate again
	SWAP		d4				; swap it to the high word
	MOVE.w	height(a3),d0		; get the screen height
	BSR		get_prng			; get a random number between 0 and d0.w - 1
	MOVE.w	d0,d4				; copy the x co-ordinate
	MOVE.l	d4,(a4)			; set the x,y for thing zero

	MOVEQ		#8,d0				; direction is this position
	BSR		neighbour			; get the neighbouring pixel colour in
							; direction d0
	CMP.l		food_colour(a3),d5	; compare the colour with the food colour
	BNE		exit_do_things		; if it is not food just exit

; else make thing zero active

	ADDQ.w	#1,(a0)			; increment the thing count
	MOVE.b	#1,(a5)			; flag thing zero active

	MOVE.l	thing_colour(a3),-(sp)	; fill the old position with the thing colour
	BRA		fill_old_thing		; go draw thing zero, d7.w = 0 here

; set the direction delta, randomly setting -1 and +1 should remove any bias toward
; sweeping round the screen clockwise or anticlockwise

things_exist
	move.b #10,leds
	MOVEQ		#2,d0				; set for 0 or 1
	BSR		get_prng			; get a random number between 0 and d0.w - 1
	ADD.w		d0,d0				; now 0 or 2
	SUBQ.w	#1,d0				; -1 or + 1
	MOVE.w	d0,a6				; copy the direction delta

; scan through all the possible things
	SUBQ.w	#1,a1				; - 1 for loop type
	MOVE.w	a1,d7				; get the maximum things count
do_things_loop
	TST.b		(a5,d7.w)			; test the thing status
	BEQ		next_thing			; if not active skip this thing

; get this thing's x,y position

thing_zero_only
	move.b #11,leds
	MOVE.w	d7,d4				; copy the index
	ASL.w		#2,d4				; ; 4 bytes per word
	MOVE.l	(a4,d4.w),d4		; get the thing's x,y position
	MOVE.l	d4,d3				; copy the thing's x position
	SWAP		d3				; move the thing's x position to the low word

; fill the thing's current position

	MOVE.l	fill_colour(a3),-(sp)	; set the fill behind colour

; get a random direction

	BSR		get_direction		; get a random direction

; remember the direction we start from

	MOVE.w	d0,d6				; copy the start direction
check_for_food
	move.b #12,leds
	BSR.s		neighbour			; get the neighbouring pixel colour in
							; direction d0
	CMP.l		food_colour(a3),d5	; compare the colour with the food colour
	BEQ.s		is_food			; if it is food go move the thing

	CMP.l		poison_colour(a3),d5	; compare the colour with the poison colour
	BEQ.s		kill_thing			; if it is poison go kill the thing

; no food in the direction looked so try the next direction

	ADD.w		a6,d0				; add the direction delta
	ANDI.w	#7,d0				; mask 0 to 7
	CMP.w		d0,d6				; compare it with the start direction
	BNE.s		check_for_food		; if not back at the start go check for food

; else this thing has starved so kill it

kill_thing
	move.b #13,leds
	SUBQ.w	#1,(a0)			; decrement the thing count
	MOVE.b	#0,(a5,d7.w)		; clear the thing flag
	BRA.s		fill_old_thing		; go fill this thing with the fill behind colour

; found food beside the thing so move it there

is_food
	move.b #14,leds
	MOVE.w	d7,d0				; copy the index
	ASL.w		#2,d0				; ; 4 bytes per word
	MOVE.w	d1,(a4,d0.w)		; save the thing's new x position
	MOVE.w	d2,2(a4,d0.w)		; save the thing's new y position

	ADDQ.b	#1,(a5,d7.w)		; increment the thing flag

; check for spawning a new thing

	MOVE.b	(a5,d7.w),d0		; get the thing flag
	SUB.b		(a2),d0			; compare it with the spawn level
	BLE.s		draw_old_thing		; if not there yet skip the spawn

; else the thing is going to try to spawn

	MOVE.b	d0,(a5,d7.w)		; reset the flag for this thing, d0 = 1

; search for a free thing slot

	MOVE.w	a1,d6				; get the maximum things count
	CMP.w		(a0),d6			; compare it with the things count
	BMI.s		draw_old_thing		; if no space just draw the old thing

new_thing_loop
	move.b #15,leds
	TST.b		(a5,d6.w)			; test this thing flag
	DBEQ		d6,new_thing_loop		; loop if active

; found one of the free thing slots so flag that the new thing is active

	ADDQ.w	#1,(a0)			; increment the thing count
	MOVE.b	d0,(a5,d6.w)		; set the new thing's active flag, d0 = 1

; save the new thing position

	ASL.w		#2,d6				; ; 4 bytes per word
	MOVE.l	d4,(a4,d6.w)		; save the new thing's x,y position

; set the new thing's colour to fill the thing's old position

	MOVE.l	thing_colour(a3),(sp)	; fill the old position with the thing colour

; now draw the current thing in the new position and fill the old position

draw_old_thing
	BSR.s		set_thing_pixel		; set the pixel at d1,d2 to the thing's colour
fill_old_thing
	MOVE.l	(sp)+,d0			; get the d3,d4 pixel's colout
	BSR		set_a_pixel			; set the pixel at d3,d4 to the d0's colour
next_thing
	DBF		d7,do_things_loop		; decrement and loop if more things to do

exit_do_things
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; get the neighbouring 2x2 pixel colour in direction d0.w
;
; x is in d3.w, y is in d4.w
;
; returns the pixel colour or -1 of out of range in d5.l
; returns the new x,y in d1,d2

neighbour
	move.b #16,leds
	MOVEM.l	d0/a0,-(sp)		; save the direction

	MOVEQ		#-1,d5			; flag out of range

	MOVE.w	d3,d1				; copy x
	MOVE.w	d4,d2				; copy y

	add.w	d0,d0					; * 2 bytes per word
	lea delta_x(pc),a0
	add.w	(a0,d0.w),d1			; add the direction delta x to x
	BMI.s		exit_neighbour		; if x < screen x minimum just exit

	CMP.w		width(a3),d1		; compare it with the screen width
	BGE.s		exit_neighbour		; if x > screen x maximum just exit

	lea delta_y(pc),a0
	add.w	(a0,d0.w),d2	; add the direction delta y to y
	BMI.s		exit_neighbour		; if y < screen y minimum just exit

	CMP.w		height(a3),d2		; compare it with the screen height
	BGE.s		exit_neighbour		; if y > screen y maximum just exit

	MOVEM.l	d1-d2,-(sp)			; save the new x,y

	ADD.w		d1,d1				; * 2
	ADD.w		d2,d2				; * 2
	MOVEQ		#83,d0			; read a pixel
	trap #15

	MOVEM.l	(sp)+,d1-d2			; restore the new x,y

	MOVE.l	d0,d5				; copy the pixel colour
exit_neighbour
	MOVEM.l	(sp)+,d0/a0			; restore the direction

	rts

; direction deltas				; the directions are
							;
							; +---+---+---+
							; | 5 | 4 | 3 |
							; +---+---+---+
							; | 6 | 8 | 2 |
							; +---+---+---+
							; | 7 | 0 | 1 |
							; +---+---+---+
delta_x
	dc.w	0					; direction 0 dx,dy =  0, 1
	dc.w	1					; direction 1 dx,dy =  1, 1
	dc.w	1					; direction 2 dx,dy =  1, 0
	dc.w	1					; direction 3 dx,dy =  1,-1
	dc.w	0					; direction 4 dx,dy =  0,-1
	dc.w	-1					; direction 5 dx,dy = -1,-1
	dc.w	-1					; direction 6 dx,dy = -1, 0
	dc.w	-1					; direction 7 dx,dy = -1, 1
	dc.w	0					; direction 8 dx,dy =  0, 0

delta_y
	dc.w	1					; direction 0 dx,dy =  0, 1
	dc.w	1					; direction 1 dx,dy =  1, 1
	dc.w	0					; direction 2 dx,dy =  1, 0
	dc.w	-1					; direction 3 dx,dy =  1,-1
	dc.w	-1					; direction 4 dx,dy =  0,-1
	dc.w	-1					; direction 5 dx,dy = -1,-1
	dc.w	0					; direction 6 dx,dy = -1, 0
	dc.w	1					; direction 7 dx,dy = -1, 1
	dc.w	0					; direction 8 dx,dy =  0, 0


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; set the 2x2 pixel at d1,d2 to the thing's

set_thing_pixel
	move.b #18,leds
	MOVEM.l	d1-d4,-(sp)			; save the registers
	MOVE.w	d1,d3				; copy the thing's new x position
	MOVE.w	d2,d4				; copy the thing's new y position
	MOVE.l	thing_colour(a3),d0	; get the thing colour
	BRA.s		set_this_pixel		; go set this pixel


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; set the 2x2 pixel at d3,d4 to colour d0

set_a_pixel
	move.b #19,leds
	MOVEM.l	d1-d4,-(sp)			; save the registers

set_this_pixel
	move.b #20,leds
	MOVE.l	d0,d1				; copy the colour
	MOVEQ		#80,d0			; set the pen colour
	TRAP		#15

	MOVEQ		#1,d1				; + 1
	MOVEQ		#1,d2				; + 1
	ADD.w		d3,d3				; x*2
	ADD.w		d4,d4				; y*2
	ADD.w		d3,d1				; x*2 + 1
	ADD.w		d4,d2				; y*2 + 1
	MOVEQ		#90,d0			; draw a rectangle in the pen colour
	TRAP		#15

	MOVEM.l	(sp)+,d1-d4			; restore the registers
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; setup stuff

InitialisePlants:
	move.b #'@',d1
	jsr OutputChar
	
;	MOVE.b	#17,d1			; enable double buffering
;	MOVE.b	#92,d0			; set draw mode
;	TRAP		#15

	move.b #'A',d1
	jsr OutputChar
	
	moveq #0,d1					; echo off
	moveq #12,d0				; set keyboard echo
	trap #15
	move.b #'B',d1
	jsr OutputChar

	move.l #$00000888,d1		; 24 bpp
	move.l #$60000,d7							; framebuf device
	moveq #DEV_SET_COLOR_DEPTH,d6
	trap #0
	move.l #$70000,d7							; graphics accelerator device
	trap #0
	move.l #$0F003F4F,d1		; set burst length, max burst number and interval
	jsr rbo
	move.l d1,FRAMEBUF+4
	move.b #'C',d1
	jsr OutputChar

	lea	pvariables(pc),a3		; get the variables base address

	move.w d1,quit(a3)			; clear the quit flag

	moveq #8,d0					; get time in 1/100 ths seconds
	trap #15
	move.l d1,d0
	move.b #'D',d1
	jsr OutputChar
	move.l d0,d1

	eori.l #$DEADBEEF,d1		; EOR with the initial PRNG seed, this must
													; result in any value but zero
	move.l d1,PRNlword(a3)	; save the initial PRNG seed
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; get a random direction

get_direction
	moveq #8,d0				; set for direction 0 to 7


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; get a random number between 0 and d0.w - 1

get_prng
	jsr gen_prng			; call the PRNG code
	mulu.w PRNlword(a3),d0		; random word times scale
	clr.w	d0					; clear the low word
	swap d0						; return the high word as the result
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

;gen_prng
;	MOVEM.l	d0-d2,-(sp)			; save d0, d1 and d2
;	MOVE.l	PRNlword(a3),d0		; get current seed longword
;	MOVEQ		#$AF-$100,d1		; set EOR value
;	MOVEQ		#18,d2			; do this 19 times
;Ninc0
;	ADD.l		d0,d0				; shift left 1 bit
;	BCC.s		Ninc1				; if bit not set skip feedback

;	EOR.b		d1,d0				; do Galois LFSR feedback
;Ninc1
;	DBF		d2,Ninc0			; loop;

;	MOVE.l	d0,PRNlword(a3)		; save back to seed longword
;	MOVEM.l	(sp)+,d0-d2			; restore d0, d1 and d2

;	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; check the [F2], [F3] and [F4] keys. set the screen size to 640 x 480, 800 x 600 or
; 1024 x 768 if the corresponding key has been pressed

screen_size
	rts
	MOVE.l	#$71007273,d1		; [F2], [], [F3] and [F4] keys
	MOVEQ		#19,d0			; check for keypress
	TRAP		#15

	MOVE.l	d1,d2				; copy result
	BEQ.s		pnotscreen			; skip screen size if no F key

	MOVE.l	#$028001E0/2,d1		; set 640 x 480
	TST.l		d2				; test result
	BMI.s		psetscreen			; if F2 go set window size

	MOVE.l	#$03200258/2,d1		; set 800 x 600
	TST.w		d2				; test result
	BMI.s		psetscreen			; if F3 go set window size

							; else was F4 so ..
	MOVE.l	#$04000300/2,d1		; set 1024 x 768
psetscreen
	CMP.l		width(a3),d1		; compare with current screen size
	BEQ.s		.0001			; if already set skip setting it now

	ADD.l		d1,d1				; make it the full size
	MOVEQ 	#33,d0			; get/set window size
	TRAP		#15

	MOVEQ		#-1,d0			; set the longword
	MOVE.w	d0,redraw(a3)		; set the redraw flag
.0001
pnotscreen:
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; variables

pvariables

	OFFSET	0				; going to use relative addressing

;PRNlword
;	ds.l	1					; PRNG seed long word
quit
	ds.w	1					; quit flag
redraw
	ds.w	1					; redraw the world flag

width
	ds.w	1					; screen width
height
	ds.w	1					; screen height

num_plants
	ds.w	1					; the number of plants
max_plants
	ds.w	1					; the maximum number of plants

num_animals
	ds.w	1					; the number of animals
max_animals
	ds.w	1					; the maximum number of animals

plant_colour
	ds.w	1					; plant colour
plant_fill
	ds.w	1					; plant overfill

animal_colour
	ds.l	1					; animal colour
animal_fill
	ds.l	1					; animal overfill

thing_colour
	ds.l	1					; the colour of things
fill_colour
	ds.l	1					; the colour that things leave
food_colour
	ds.l	1					; the colour that things eat
poison_colour
	ds.l	1					; the colour that kills things

plant_xy
	ds.w	def_plants*2			; plant x,y positions
plant_flag
	ds.b	def_plants				; plant active flags

animal_xy
	ds.w	def_animals*2			; animal x,y positions
animal_flag
	ds.b	def_animals				; animal active and state

plant_spawn
	ds.b	1					; the space count at which a plant reproduces
animal_spawn
	ds.b	1					; the leaf count at which a animal reproduces

	ds.w	0					; ensure even


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	END		start_plants

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
