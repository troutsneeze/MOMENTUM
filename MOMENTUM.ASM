; Assemble with FASM

org 100h

; Clear the screen and set video mode
mov ah, 0
mov al, 3
int 10h

; Hide cursor
mov ah, 3
int 0x10
mov [CUR_START], ch
mov [CUR_END], cl
mov ah, 1
mov ch, 0x20
int 0x10

new_game:

; Initialize our variables
mov [SCORE], 0
mov [NUKES], 9
mov [SIN], 0
mov [SINA], 0
mov [SINB], 40
mov [SINGLE_ODDS], 24
mov [SINGLE_INC], 1
mov [SHIP_POS], 0x0c0a
mov [FRAME_NUM], 0
mov [IS_DEAD], 0

call cls

; Grab a seed from the RTC
call seed

call draw_all
call draw_ship

call press_enter

go:
	call draw_ship
	call draw_score
	call draw_nukes
	call vsync
	mov al, [FRAME_NUM]
	inc al
	mov [FRAME_NUM], al
	xor ah, ah
	xor dx, dx
	mov cx, 3
	div cx
	cmp dx, 0
	jne handle_input
	call erase_ship
	call scroll_level
	call last_col
handle_input:
	call check_dead
	cmp bx, 1
	je gameover
	mov ax, [SCORE]
	cmp ax, 0xff
	jb no_wrap
	mov ax, 0
	mov bx, [NUKES]
	inc bx
	mov [NUKES], bx
	jmp done_changing_score
no_wrap:
	inc ax
done_changing_score:
	mov [SCORE], ax
	; ping-pong number of extra stars
	xor dx, dx
	mov cx, 64
	div cx
	cmp dx, 0
	jne no_change
	cmp [SINGLE_INC], 1
	je si_positive
	mov al, [SINGLE_ODDS]
	cmp al, [SINGLE_ODDS_MIN]
	je si_neg_min
	dec al
	mov [SINGLE_ODDS], al
	jmp no_change
si_neg_min:
	mov al, [SINGLE_ODDS_MIN]
	mov [SINGLE_ODDS], al
	inc [SINGLE_ODDS]
	mov [SINGLE_INC], 1
	jmp no_change
si_positive:
	mov al, [SINGLE_ODDS]
	cmp al, [SINGLE_ODDS_MAX]
	je si_pos_max
	inc al
	mov [SINGLE_ODDS], al
	jmp no_change
si_pos_max:
	mov al, [SINGLE_ODDS_MAX]
	mov [SINGLE_ODDS], al
	dec [SINGLE_ODDS]
	mov [SINGLE_INC], -1
no_change:
	mov ah, 1
	int 16h
	jnz key_pressed
	jmp go
key_pressed:
	mov ah, 0
	int 16h
	cmp ah, 1 ; escape scancode
	je exit
	cmp ah, 44 ; Z scancode
	jne check_arrows
	cmp [NUKES], 0
	jle check_arrows
	mov bx, [NUKES]
	dec bx
	mov [NUKES], bx
	call cls
check_arrows:
	cmp ah, 72 ; up arrow scancode
	je up_arrow
	cmp ah, 80 ; down arrow scancode
	je down_arrow
	jmp go
up_arrow:
	mov bx, [SHIP_POS]
	dec bh
	cmp bh, 0
	jge up_ok
	jmp go
up_ok:
	call erase_ship
	mov [SHIP_POS], bx
	call check_dead
	cmp bx, 1
	je gameover
	jmp go
down_arrow:
	mov bx, [SHIP_POS]
	inc bh
	cmp bh, 24 
	jl down_ok
	jmp go
down_ok:
	call erase_ship
	mov [SHIP_POS], bx
	call check_dead
	cmp bx, 1
	je gameover
	jmp go

gameover:

call draw_ship
call crash_sound
call press_enter_retry
jmp new_game

exit:

call cls
; bring the cursor back
mov dx, 0
call move_cursor

; Restore cursor
mov ah, 1
mov ch, [CUR_START]
mov cl, [CUR_END]
int 0x10

; Terminate program with 0 result code
mov ah, 0
int 21h

seed:
        ;mov ax, 40h
        ;mov es, ax
        ;mov ax, [es:6ch]
	;we're seeding with 0 so the level's the same time each time
	mov ax, 0
        mov [SEED], ax
        mov [RAND], ax
        ret

speaker_tone:
; This put a random number in dx then shift it lo/hi based on function ptr
        call genrand
        call [TONE]
; This turns the speaker on with tone in dx
        mov al, 182
        out 43h, al
        mov ax, dx
        out 42h, al
        mov al, ah
        out 42h, al
        in al, 61h
        or al, 03h
        out 61h, al
        ret

speaker_off:
        in al, 61h
        and al, 0FCh
        out 61h, al
        ret

; 16 bit lcg
genrand:
        mov ax, 75
        mul [RAND]
        add ax, 74
        mov [RAND], ax
        mov dx, ax
        ret

genrand_terrain:
        mov cx, [SEED]
        call genrand
        cmp cx, dx
        jge not_less
        jmp less
not_less:
        mov [SEED], cx
less:
        ret

vsync:
        mov dx, 3dah
l1:
        in al, dx
        and al, 8
        jnz l1
l2:
        in al, dx
        and al, 8
        jz l2

        ret

lopitch:
        shl dx, 12
        ret

hipitch:
        shr dx, 12
        shl dx, 8
        ret

sound:
        mov bx, [RAND]
        mov [RAND], 0
delay:
        call speaker_tone
        call vsync
        dec cl
        jnz delay
        call speaker_off
        mov [RAND], bx
        ret

nuke_sound:
        mov [TONE], hipitch
        mov cl, 15
        call sound
        ret

crash_sound:
        mov [TONE], lopitch
        mov cl, 30
        call sound
        ret

press_enter:
        mov ah, 24
        mov al, 21
        mov [DRAW_POS], ax
        mov [TEXTBUF_END], PRESS_ENTER+37
        mov [TEXTBUF], PRESS_ENTER
        mov [DRAW_COLOR], 12
        call draw_textbuf
	mov bl, 28 ; scancode for enter
	call wait_for_key
        mov ah, 24
        mov al, 21
        mov [DRAW_POS], ax
        mov [TEXTBUF_END], PRESS_ENTER_SPACES+37
        mov [TEXTBUF], PRESS_ENTER_SPACES
        mov [DRAW_COLOR], 12
        call draw_textbuf
	ret

press_enter_retry:
        mov ah, 24
        mov al, 30
        mov [DRAW_POS], ax
        mov [TEXTBUF_END], PRESS_ENTER_RETRY+19
        mov [TEXTBUF], PRESS_ENTER_RETRY
        mov [DRAW_COLOR], 12
        call draw_textbuf
	mov bl, 28 ; scancode for enter
	call wait_for_key
        mov ah, 24
        mov al, 30
        mov [DRAW_POS], ax
        mov [TEXTBUF_END], PRESS_ENTER_RETRY_SPACES+19
        mov [TEXTBUF], PRESS_ENTER_RETRY_SPACES
        mov [DRAW_COLOR], 12
        call draw_textbuf
	ret

wait_for_key:
        mov ah, 1
        int 16h
	jz wait_for_key
        mov ah, 0
        int 16h
	cmp ah, 1
	je exit
	cmp ah, bl
	jne wait_for_key
        ret

cls:
        mov ax, 700h
        mov bh, 7
        mov cx, 0
        mov dx, 184fh
        int 10h
        ret

move_cursor:
        mov ah, 2
        mov bh, 0
        int 10h
        ret

fill_textbuf:
	push ax
	push bx
	push cx
	push dx
        mov cx, 16
        mov ax, [DRAW_NUMBER]
        mov bx, [TEXTBUF_END]
next_digit:
        xor dx, dx
        div cx
	cmp dl, 10
	jge alphabetic
        add dl, '0'
	jmp done_ascii
alphabetic:
	sub dl, 10
	add dl, 'A'
done_ascii:
        mov [bx], dl
        cmp bx, FILLBUF
        jle done_fill
        dec bx
        jmp next_digit
done_fill:
	pop dx
	pop cx
	pop bx
	pop ax
        ret

draw_textbuf:
	push ax
	push bx
	push cx
	push dx
        mov dx, [TEXTBUF]
draw_next:
        mov cx, dx
        mov dx, [DRAW_POS]
        call move_cursor
        mov dx, cx
        mov bx, cx
        mov ax, [bx]
        mov ah, 9
        mov bh, 0
        mov bl, [DRAW_COLOR]
        mov cx, 1
        int 10h
        cmp dx, [TEXTBUF_END]
        jge done
        inc dx
        mov cx, [DRAW_POS]
        inc cx
        mov [DRAW_POS], cx
        jmp draw_next
done:
	pop dx
	pop cx
	pop bx
	pop ax
        ret

draw_chain:
	push bx
	call start_star_ok
	cmp bl, 0
	je no_draw_star
	jmp draw_star
no_draw_star:
	pop bx
	jmp past_draw
draw_star:
	pop bx
        push bx
        call draw_textbuf
	pop bx
past_draw:
        mov ax, [DRAW_POS]
        inc ah
        mov [DRAW_POS], ax
        inc bh
        cmp bh, bl
        jne draw_chain
        ret

really_draw_col:
; Top
	call genrand_terrain
	push ax
	mov ax, dx
	xor dx, dx
	mov cl, [RAND_H]
	xor ch, ch
	div cx
	inc dl
	pop ax
        mov [BACK], next0_1
	mov cl, [SINA]
	mov [SIN], cl
        jmp add_sin
next0_1:
	mov dl, [SIN]
	mov [SINA], dl
        mov bh, 0
	mov bl, cl
	xor ch, ch
	mov cl, [CUR_COL]
        mov ah, 0
        mov al, cl
        mov [DRAW_POS], ax
        call draw_chain

	cmp [SINGLE_ODDS], 0
	je no_singles

; Some single ones in the middle perhaps
	call genrand_terrain
	mov ax, dx
	xor dx, dx
	xor ch, ch
	mov cl, [SINGLE_ODDS]
	div cx
	cmp dx, 0
	je draw_star_2
	jmp past_draw_2
draw_star_2:
	; Doing it twice for extra randomness LOL
	call genrand_terrain
	mov ax, dx
	xor dx, dx
	mov cx, 12
	div cx
	mov bx, dx
	mov cx, 13
	div cx
	add bx, dx
        mov ax, [DRAW_POS]
        mov ah, bl
        mov [DRAW_POS], ax
	call start_star_ok
	cmp bl, 0
	je past_draw_2
        call draw_textbuf
past_draw_2:

no_singles:

; Bottom
        call genrand_terrain
	push ax
	mov ax, dx
	xor dx, dx
	mov cl, [RAND_H]
	xor ch, ch
	div cx
	inc dl
	pop ax
        mov [BACK], next1_1
	mov cl, [SINB]
	mov [SIN], cl
        jmp add_sin
next1_1:
	mov dl, [SIN]
	mov [SINB], dl
        mov bh, 0
        mov bl, cl
	xor ch, ch
	mov cl, [CUR_COL]
        mov ah, 24
        sub ah, bl
        mov al, cl
        mov [DRAW_POS], ax
        call draw_chain
        ret
add_sin:
        push ax
        push bx
        push dx
        xor cx, cx
        mov ax, dx
        mov bx, SINTAB
        mov cl, [SIN]
        add bx, cx
        mov cx, [bx]
        add al, cl
        inc [SIN]
        cmp [SIN], 80
        jl nope1
        mov [SIN], 0
nope1:
        xor ch, ch
        mov cl, al
        pop dx
        pop bx
        pop ax
        jmp [BACK]

draw_all:
        mov [FILLBUF], '*'
	mov [TEXTBUF], FILLBUF
        mov [TEXTBUF_END], FILLBUF
        mov [DRAW_COLOR], 6
        xor cx, cx
	mov [CUR_COL], cl
draw_col:
	call really_draw_col
	xor ch, ch
	mov cl, [CUR_COL]
        inc cl
	mov [CUR_COL], cl
        cmp cl, 80
	jne draw_col
	mov [CUR_COL], 0
        ret

start_star_ok:
	push ax
	push cx
	mov ax, [DRAW_POS]
	mov cx, 0x0c0a
	sub ah, ch
	sub al, cl
	cmp ah, 0
	jge x_sign
	neg ah
x_sign:
	cmp al, 0
	jge done_sign
	neg al
done_sign:
	add al, ah
	add al, ah
	cmp al, 16
	jge sso_ok
	mov bl, 0
	jmp sso_done
sso_ok:
	mov bl, 1
sso_done:
	pop cx
	pop ax	
	ret

draw_ship:
	push ax
	mov ax, [SHIP_POS]
	mov [DRAW_POS], ax
	call is_dead
	cmp bx, 0
	je not_dead_1
	mov [DRAW_COLOR], 4
	mov [TEXTBUF], SHIP_DEAD
	mov [TEXTBUF_END], SHIP_DEAD
	jmp do_draw_1
not_dead_1:
	mov [DRAW_COLOR], 14
	mov [TEXTBUF], SHIP_BACK
	mov [TEXTBUF_END], SHIP_BACK
do_draw_1:
	call draw_textbuf
	mov ax, [SHIP_POS]
	inc al
	mov [DRAW_POS], ax
	cmp bx, 0
	je not_dead_2
	mov [DRAW_COLOR], 4
	mov [TEXTBUF], SHIP_DEAD
	mov [TEXTBUF_END], SHIP_DEAD
	jmp do_draw_2
not_dead_2:
	mov [DRAW_COLOR], 7
	mov [TEXTBUF], SHIP_FRONT
	mov [TEXTBUF_END], SHIP_FRONT
do_draw_2:
	call draw_textbuf
	pop ax
	ret

erase_ship:
	push ax
	mov ax, [SHIP_POS]
	mov [DRAW_POS], ax
	mov [DRAW_COLOR], 4
	mov [TEXTBUF], SHIP_SPACE
	mov [TEXTBUF_END], SHIP_SPACE
	call draw_textbuf
	mov ax, [SHIP_POS]
	inc al
	mov [DRAW_POS], ax
	mov [DRAW_COLOR], 4
	mov [TEXTBUF], SHIP_SPACE
	mov [TEXTBUF_END], SHIP_SPACE
	call draw_textbuf
	pop ax
	ret

draw_score:
	push ax
	mov ax, [SCORE]
	mov [DRAW_NUMBER], ax
	mov [DRAW_POS], 1800h
	mov [DRAW_COLOR], 15
	mov [TEXTBUF], FILLBUF
	mov [TEXTBUF_END], FILLBUF+1
	call fill_textbuf
	call draw_textbuf
	pop ax
	ret

draw_nukes:
	push ax
	push bx
	push cx
	push dx
	mov ax, [NUKES]
	mov bx, 1
next_digit_2:
	xor dx, dx
	cmp ax, 16
	jl no_more_digits
	mov cx, 16
	div cx
	inc bx
	jmp next_digit_2
no_more_digits:
	mov ax, [NUKES]
	mov [DRAW_NUMBER], ax
	mov ch, 18h
	mov cl, 50h
	sub cl, bl
	mov [DRAW_POS], cx
	mov [DRAW_COLOR], 4
	mov [TEXTBUF], FILLBUF
	mov ax, FILLBUF
	add ax, bx
	dec ax
	mov [TEXTBUF_END], ax
	call fill_textbuf
	call draw_textbuf

	mov ch, 18h
	mov cl, 4eh
	sub cl, bl
	mov [DRAW_POS], cx
	mov [DRAW_COLOR], 4
	mov [TEXTBUF], FILLBUF
	mov [TEXTBUF_END], FILLBUF+1
	mov [FILLBUF], 'N'
	mov [FILLBUF+1], ' '
	call draw_textbuf

	pop dx
	pop cx
	pop bx
	pop ax
	ret

last_col:
        mov [FILLBUF], ' '
	mov [TEXTBUF], FILLBUF
        mov [TEXTBUF_END], FILLBUF
        mov [DRAW_COLOR], 0
        mov ah, 0
        mov al, 79
next_row:
        mov [DRAW_POS], ax
        call draw_textbuf
	inc ah
	cmp ah, 24
	je draw_stars
	jmp next_row
draw_stars:
        mov [FILLBUF], '*'
	mov [TEXTBUF], FILLBUF
        mov [TEXTBUF_END], FILLBUF
        mov [DRAW_COLOR], 6
	mov cx, 79
	mov [CUR_COL], cl
	call really_draw_col
	ret

scroll_level:
	push ds
	mov ax, 0xb800
	mov ds, ax
	mov bx, 0
	mov ax, 24
	mov cx, 0
next_line:
	cmp ax, 0
	je done_scroll
next_col:
	add bx, 2
	mov dx, [bx]
	sub bx, 2
	mov [bx], dx
	add bx, 2
	inc cl
	cmp cl, 79
	jb not_done
	mov cl, 0
	dec ax
	add bx, 2
	jmp next_line
not_done:
	jmp next_col
done_scroll:
	pop ds
	ret

check_dead:
	mov dx, [SHIP_POS]
	call move_cursor
	mov ah, 8
	mov bh, 0
	int 0x10
	cmp al, '*'
	je crash
	inc dx
	call move_cursor
	mov ah, 8
	mov bh, 0
	int 0x10
	cmp al, '*'
	je crash
	mov bx, 0
	jmp done_dead_check
crash:
	mov bx, 1
done_dead_check:
	mov [IS_DEAD], bl
	ret

is_dead:
	xor bh, bh
	mov bl, [IS_DEAD]
	ret

; This port tells us when vsync is happening
PORT=3dah
; This is a seed/stored random number
SEED dw 0
RAND dw 0
; Function pointer for modifying tone to hi/lo pitch
TONE dw 0
; Text definitions
PRESS_ENTER db 'PRESS ENTER TO START. PRESS Z FOR NUKE','$'
PRESS_ENTER_SPACES db '                                      ','$'
PRESS_ENTER_RETRY db 'PRESS ENTER TO RETRY','$'
PRESS_ENTER_RETRY_SPACES db '                    ','$'
; Ship position
SCORE dw 0
; Number of nukes
NUKES dw 9
FILLBUF db '     '
TEXTBUF dw 0
TEXTBUF_END dw 0
; dw 1804h
DRAW_NUMBER dw 0
DRAW_POS dw 0
DRAW_COLOR db 0
SINTAB db 4,4,4,5,5,5,6,6,6,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,7,7,7,7,6,6,6,5,5,4,4,4,4,4,4,3,3,2,2,2,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,2,2,3,3,3,4,4,4
SIN db 0
SINA db 0
SINB db 40
BACK dw 0
RAND_H db 6
SINGLE_ODDS_MAX db 24
SINGLE_ODDS_MIN db 4
SINGLE_ODDS db 24
SINGLE_INC db 1
SHIP_BACK db 'ä'
SHIP_FRONT db '¯'
SHIP_DEAD db 'X'
SHIP_SPACE db ' '
SHIP_POS dw 0x0c0a
CUR_COL db 0
FRAME_NUM db 0
CUR_START db 0
CUR_END db 0
IS_DEAD db 0

; Pad to 2K
PAD db 98 dup ' '
