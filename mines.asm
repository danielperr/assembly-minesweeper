; MINESWEEPER
; AUTHOR: DANIEL PERETZ
; ID: ***REMOVED***
; 17 MAY 2018

IDEAL
MODEL small
STACK 100h

DATASEG

board db 64 dup(0) ; 0=clear, 1-8=numbers, 9=bomb
; GRAPHICS: 0=clear, 1-8=numbers, 9=bomb, A=bombred, B=bombmistake, C=flag, F=covered
graphics db 64 dup(0Fh)
area db 64 dup(0)
bombs db 10
board_startx dw 96
board_starty dw 36
selector dw 27

msg_intro db "Planting bombs, please wait...$"

CODESEG
; colors
col_cell equ 1Bh
col_cell_dark equ 17h
col_cell_light equ 0Fh
col_cell_red equ 28h
col_1 equ 20h
col_2 equ 78h
col_3 equ 04h
col_4 equ 68h
col_5 equ 70h
col_6 equ 7Ch
col_7 equ 00h
col_8 equ 18h
col_bomb equ 00h
col_bomb_white equ 0Fh
col_flag equ 28h
col_flag_base equ 00h
col_selector equ 2Ch
; controls
control_primary equ 39h ; spacebar
control_secondary equ 2Ch ; z

; terminates the program
proc Terminate
	; wait for key press
	mov ah, 1
	int 21h
	; text mode
	mov ax, 2
	int 10h
	; end program
	mov ax, 4c00h
	int 21h
endp Terminate

; ---------- BOARD PROCEDURES ---------- ;

; spreads bombs across the board
proc SpreadBombs
	push ax
	push bx
	push cx
	push dx
	mov cl, [bombs]
	SPRBOMBS_rndloop:
		mov ah, 2Ch
		push cx ;preserve value of cx
		int 21h ;dl stores milliseconds
		pop cx
		xor ax, ax
		mov al, dl
		mov bl, 64
		div bl ;ah stores the remainder
		mov bx, offset board
		add bl, ah
		cmp [byte ptr bx], 9 ;is there a bomb already?
		je SPRBOMBS_rndloop
		; avoid the 4 center cells
		cmp bl, 27
		je SPRBOMBS_rndloop
		cmp bl, 28
		je SPRBOMBS_rndloop
		cmp bl, 35
		je SPRBOMBS_rndloop
		cmp bl, 36
		je SPRBOMBS_rndloop
		mov [byte ptr bx], 9
		;mov ah, 1
		;int 21h
		loop SPRBOMBS_rndloop
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp SpreadBombs

; an aid procedure for MapNumbers. increases a cell's value at a given position.
proc AddNumber ; NOT BLACK BOX
	add bx, offset board
	add bx, cx
	cmp [byte ptr bx], 9 ;is there a bomb?
	je ADDNUM_continue
	add [byte ptr bx], 1
	ADDNUM_continue:
		ret
endp AddNumber

; an aid procedure for many procedures. checks to see if there is free space to the left.
proc CheckLeft ; NOT BLACK BOX
	mov ax, cx
	mov bl, 8
	div bl
	cmp ah, 0
	ret
endp CheckLeft

; an aid procedure for many procedures. checks to see if there is free space to the right.
proc CheckRight ; NOT BLACK BOX
	mov ax, cx
	mov bl, 8
	div bl
	cmp ah, 7
	ret
endp CheckRight

; assigns a number to each cell according to the bombs on the board.
proc MapNumbers
	push ax
	push bx
	push cx
	push dx
	mov cx, 0
	MAP_loop:
			mov bx, offset board
			add bx, cx
			cmp [byte ptr bx], 9 ;is there a bomb?
			jne MAP_continue
			; check for free space above
			cmp cl, 8
			jl MAP_left
			; check for free space to the left
			call CheckLeft
			je MAP_top
			; add number
			mov bx, -9
			call AddNumber
		MAP_top:
			; add number
			mov bx, -8
			call AddNumber
		MAP_topright:
			; check for free space to the right
			call CheckRight
			je MAP_left
			; add number
			mov bx, -7
			call AddNumber
		MAP_left:
			; check for free space to the left
			call CheckLeft
			je MAP_right
			; add number
			mov bx, -1
			call AddNumber
		MAP_right:
			; check for free space to the right
			call CheckRight
			je MAP_bottomleft
			; add number
			mov bx, 1
			call AddNumber
		MAP_bottomleft:
			; check for free space below
			cmp cl, 55
			jg MAP_continue
			; check for free space to the left
			call CheckLeft
			je MAP_bottom
			; add number
			mov bx, 7
			call AddNumber
		MAP_bottom:
			; add number
			mov bx, 8
			call AddNumber
		MAP_bottomright:
			; check for free space to the right
			call CheckRight
			je MAP_continue
			; add number
			mov bx, 9
			call AddNumber
		MAP_continue:
			inc cx
			cmp cx, 64
			jne MAP_loop
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp MapNumbers

; reveals a cell
proc Reveal ; register args: bx=shift, cx=position
	push ax
	push bx
	push dx
	add bx, cx
	mov di, bx
	mov dx, bx
	add bx, offset graphics
	add di, offset board
	; check for covered cell
	cmp [byte ptr bx], 0Fh
	jne RVL_exit
	; is there a bomb?
	cmp [byte ptr di], 9
	je RVL_bomb
	; reveal
	mov al, [byte ptr di]
	mov [byte ptr bx], al
	; draw
	push dx
	call DrawAtPosition
	jmp RVL_exit
	RVL_bomb:
		call GameOver
	RVL_exit:
		pop dx
		pop bx
		pop ax
		ret
endp Reveal

; reveal around means revealing the 8 surrounding cells around a cell, including itself (9)
proc RevealAround ; stack arg: position in board
	push bp
	mov bp, sp
	push ax ;calculations
	push bx ;address and aid in calculations
	push cx ;position in board
	push dx
	push di
	;
	mov cx, [bp+4] ;position
	; check for free space up
	cmp cx, 8
	jl AROUND_left
	; check for free space left
	call CheckLeft
	je AROUND_top
	; reveal
	mov bx, -9
	call Reveal
	AROUND_top:
		; reveal
		mov bx, -8
		call Reveal
	AROUND_topright:
		; check for free space right
		call CheckRight
		je AROUND_left
		; reveal
		mov bx, -7
		call Reveal
	AROUND_left:
		; check for free space left
		call CheckLeft
		je AROUND_center
		; reveal
		mov bx, -1
		call Reveal
	AROUND_center:
		;reveal
		mov bx, 0
		call Reveal
	AROUND_right:
		; check for free space right
		call CheckRight
		je AROUND_bottomleft
		; reveal
		mov bx, 1
		call Reveal
	AROUND_bottomleft:
		; check for free space down
		cmp cx, 55
		jg AROUND_exit
		; check for free space left
		call CheckLeft
		je AROUND_bottom
		; reveal
		mov bx, 7
		call Reveal
	AROUND_bottom:
		; reveal
		mov bx, 8
		call Reveal
	AROUND_bottomright:
		; check for free space right
		call CheckRight
		je AROUND_exit
		; reveal
		mov bx, 9
		call Reveal
	AROUND_exit:
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		pop bp
		ret 2
endp RevealAround

; returns the number of clear (blank) cells
proc CountClearGraphics ; returns ax: number of clear cells in graphics
	push bx
	push cx
	mov ax, 0
	mov cx, 64
	CNTGR_loop:
		dec cx
		cmp cx, 0
		jl CNTGR_exit
		mov bx, offset graphics
		add bx, cx
		cmp [byte ptr bx], 0 ;check for clear cell
		jne CNTGR_loop
		inc ax
		jmp CNTGR_loop
	CNTGR_exit:
		pop cx
		pop bx
		ret
endp CountClearGraphics

; returns the number of cells that were marked as revealed around
proc CountClearArea ; returns dx: number of clear cells in area
	push bx
	push cx
	mov dx, 0
	mov cx, 0
	CNTAR_loop:
		mov bx, offset area
		add bx, cx
		add dl, [byte ptr bx]
		inc cx
		cmp cx, 64
		jne CNTAR_loop
	pop cx
	pop bx
	ret
endp CountClearArea

; iterates through all cells and reveals cells around clear cells (blank cells)
proc RevealArea
	push ax
	push bx
	push cx
	push dx
	push di
	;
	AREA_while:
		mov cx, 0
		AREA_loop:
			mov bx, offset graphics
			add bx, cx
			cmp [byte ptr bx], 0 ;check for clear cell
			jne AREA_continue
			mov di, offset area
			add di, cx
			cmp [byte ptr di], 1 ;has it revealed around already?
			je AREA_continue
			; reveal around
			mov [byte ptr di], 1
			push cx
			call RevealAround
			AREA_continue:
				inc cx
				cmp cx, 64
				jne AREA_loop
		call CountClearGraphics
		call CountClearArea
		cmp ax, dx
		jne AREA_while
	;
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp RevealArea

; checks if there is a flag and if so increases dx
proc CheckFlag ; register args: bx=shift, cx=position
	push ax
	push bx
	add bx, cx
	add bx, offset graphics
	; check for flag
	cmp [byte ptr bx], 0Ch
	jne CHKFLG_exit
	inc dx
	CHKFLG_exit:
		pop bx
		pop ax
		ret
endp CheckFlag

; count flags around selector
proc CountFlags ; needs a blank value to be pushed before called because it returns a value
	push bp
	mov bp, sp
	push ax ;calculations
	push bx ;address and aid in calculations
	push cx ;position in board
	push dx ;flag counter
	push di
	;
	xor dx, dx
	mov cx, [selector] ;position
	; check for free space up
	cmp cx, 8
	jl CFLAGS_left
	; check for free space left
	call CheckLeft
	je CFLAGS_top
	; check flag
	mov bx, -9
	call CheckFlag
	CFLAGS_top:
		; check flag
		mov bx, -8
		call CheckFlag
	CFLAGS_topright:
		; check for free space right
		call CheckRight
		je CFLAGS_left
		; check flag
		mov bx, -7
		call CheckFlag
	CFLAGS_left:
		; check for free space left
		call CheckLeft
		je CFLAGS_center
		; check flag
		mov bx, -1
		call CheckFlag
	CFLAGS_center:
		;check flag
		mov bx, 0
		call CheckFlag
	CFLAGS_right:
		; check for free space right
		call CheckRight
		je CFLAGS_bottomleft
		; check flag
		mov bx, 1
		call CheckFlag
	CFLAGS_bottomleft:
		; check for free space down
		cmp cx, 55
		jg CFLAGS_exit
		; check for free space left
		call CheckLeft
		je CFLAGS_bottom
		; check flag
		mov bx, 7
		call CheckFlag
	CFLAGS_bottom:
		; check flag
		mov bx, 8
		call CheckFlag
	CFLAGS_bottomright:
		; check for free space right
		call CheckRight
		je CFLAGS_exit
		; check flag
		mov bx, 9
		call CheckFlag
	CFLAGS_exit:
		mov [bp+4], dx
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		pop bp
		ret
endp CountFlags

; reveals around a number. a procedure to be called when a primary action is used on a number
; using selector location
proc RevealAroundNumber
	push ax
	push bx
	push cx
	push dx

	push 0 ; return space
	call CountFlags
	pop ax ; flag count

	mov bx, offset graphics
	add bx, [selector]
	cmp [byte ptr bx], al
	jne RVAN_exit

	push [selector]
	call RevealAround

	RVAN_exit:
		pop dx
		pop cx
		pop bx
		pop ax
		ret
endp RevealAroundNumber

; primary action for revealing cells
proc Primary
	push ax
	push bx ; position in graphics
	push di ; position in board
	; is it a number?
	mov bx, offset graphics
	add bx, [selector]
	cmp [byte ptr bx], 9
	jle PRM_number
	; exit proc if it's not covered
	mov bx, offset graphics
	add bx, [selector]
	cmp [byte ptr bx], 0Fh ;covered
	jne PRM_exit
	; is there a bomb?
	mov di, offset board
	add di, [selector]
	cmp [byte ptr di], 9 ;bomb
	je PRM_bomb
	; reveal
	mov al, [byte ptr di]
	mov [byte ptr bx], al
	call RevealArea
	push [selector]
	call DrawAtPosition
	push [selector]
	call DrawSelector
	jmp PRM_exit
	;
	PRM_bomb:
		call GameOver
		jmp PRM_exit
	PRM_number:
		call RevealAroundNumber
	PRM_exit:
		pop di
		pop bx
		pop ax
		ret
endp Primary

; secondary action for marking flags
proc Secondary
	push ax
	push bx ; position in graphics
	push di ; position in board
	;
	mov bx, offset graphics
	add bx, [selector]
	;
	cmp [byte ptr bx], 0Ch ;flag
	je SCND_flag
	cmp [byte ptr bx], 0Fh ;covered
	jne SCND_exit
	;
	mov [byte ptr bx], 0Ch
	push [selector]
	call DrawAtPosition
	push [selector]
	call DrawSelector
	jmp SCND_exit
	;
	SCND_flag:
		mov [byte ptr bx], 0Fh
		push [selector]
		call DrawAtPosition
		push [selector]
		call DrawSelector
	SCND_exit:
		pop di
		pop bx
		pop ax
		ret
endp Secondary

; is callecd when clicked on a bomb
; reveals all cells in board
proc GameOver
	push bx
	push cx
	push di
	mov cx, 0
	OVER_loop:
		mov di, offset board
		add di, cx
		cmp [byte ptr di], 9 ; check for a bomb
		jne OVER_notabomb
		mov bx, offset graphics
		add bx, cx
		mov [byte ptr bx], 9
		push cx
		call DrawAtPosition
		jmp OVER_continue
	OVER_notabomb:
		; then check graphics maybe we got a flag wrong
		mov bx, offset graphics
		add bx, cx
		cmp [byte ptr bx], 0Ch ; is there a flag?
		jne OVER_continue
		mov [byte ptr bx], 0Bh ; place a mistake cell (bomb with X)
		push cx
		call DrawAtPosition
	OVER_continue:
		inc cx
		cmp cx, 64
		jl OVER_loop
	mov bx, offset graphics
	add bx, [selector]
	mov [byte ptr bx], 0Ah
	push [selector]
	call DrawAtPosition
	push [selector]
	call DrawSelector
	call Terminate
	pop di
	pop cx
	pop bx
endp GameOver

; ---------- DRAWING PROCEDURES ---------- ;

proc DrawRect ; stack args: startx, starty, width, height, color
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	; interesting bit
	mov ax, [bp+6] ;height
	RECT_vloop:
		mov bx, [bp+8] ;width
		RECT_hloop:
			; <pixel> al=col, ah=0ch, bx=0, cx=x, dx=y
			push ax
			push bx
			mov cx, [bp+12] ;startx
			add cx, bx ;hloop iteration
			dec cx ;exclusive
			mov dx, [bp+10] ;starty
			add dx, ax ;vloop iteration
			dec dx ;exclusive
			mov ax, [bp+4] ;color
			mov ah, 0ch
			mov bx, 0
			int 10h
			pop bx
			pop ax
			; </pixel>
			dec bx
			cmp bx, 0
			jne RECT_hloop
		dec ax
		cmp ax, 0
		jne RECT_vloop
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 10
endp DrawRect

proc DrawCellCovered ; stack args: startx, starty
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6] ;x
	push [bp+4] ;y
	push 14 ;w
	push 2 ;h
	push col_cell_light ;col
	call DrawRect ;balance stack
	;
	push [bp+6]
	mov ax, [bp+4]
	add ax, 2
	push ax
	push 2
	push 12
	push col_cell_light
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 2
	push ax
	mov ax, [bp+4]
	add ax, 2
	push ax
	push 12
	push 12
	push col_cell
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 2
	push ax
	mov ax, [bp+4]
	add ax, 14
	push ax
	push 14
	push 2
	push col_cell_dark
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 14
	push ax
	mov ax, [bp+4]
	add ax, 2
	push ax
	push 2
	push 12
	push col_cell_dark
	call DrawRect
	;
	push [bp+6]
	mov ax, [bp+4]
	add ax, 14
	push ax
	push 1
	push 1
	push col_cell_light
	call DrawRect
	;
	mov ax, [bp+6]
	inc ax
	push ax
	mov ax, [bp+4]
	add ax, 14
	push ax
	push 1
	push 1
	push col_cell
	call DrawRect
	;
	push [bp+6]
	mov ax, [bp+4]
	add ax, 15
	push ax
	push 1
	push 1
	push col_cell
	call DrawRect
	;
	mov ax, [bp+6]
	inc ax
	push ax
	mov ax, [bp+4]
	add ax, 15
	push ax
	push 1
	push 1
	push col_cell_dark
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 14
	push ax
	push [bp+4]
	push 1
	push 1
	push col_cell_light
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 14
	push ax
	mov ax, [bp+4]
	inc ax
	push ax
	push 1
	push 1
	push col_cell
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 15
	push ax
	push [bp+4]
	push 1
	push 1
	push col_cell
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 15
	push ax
	mov ax, [bp+4]
	inc ax
	push ax
	push 1
	push 1
	push col_cell_dark
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCellCovered

proc DrawCellUncovered ; stack args: startx, starty
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6] ;x
	push [bp+4] ;y
	push 16 ;w
	push 1 ;h
	push col_cell_dark ;col
	call DrawRect
	;
	push [bp+6]
	mov ax, [bp+4]
	inc ax
	push ax
	push 1
	push 15
	push col_cell_dark
	call DrawRect
	;
	mov ax, [bp+6]
	inc ax
	push ax
	mov ax, [bp+4]
	inc ax
	push ax
	push 15
	push 15
	push col_cell ;col
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCellUncovered

proc DrawCellUncoveredRed ; stack args: startx, starty
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6] ;x
	push [bp+4] ;y
	push 16 ;w
	push 1 ;h
	push col_cell_dark ;col
	call DrawRect
	;
	push [bp+6]
	mov ax, [bp+4]
	inc ax
	push ax
	push 1
	push 15
	push col_cell_dark
	call DrawRect
	;
	mov ax, [bp+6]
	inc ax
	push ax
	mov ax, [bp+4]
	inc ax
	push ax
	push 15
	push 15
	push col_cell_red ;col
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCellUncoveredRed

proc DrawCell1 ; stack args: startx, starty
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	;
	mov ax, [bp+6]
	add ax, 5
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 7
	push 2
	push col_1
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 7
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 3
	push 8
	push col_1
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 7
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 1
	push 1
	push col_cell
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 5
	push ax
	push 1
	push 2
	push col_1
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 5
	push ax
	mov ax, [bp+4]
	add ax, 6
	push ax
	push 1
	push 1
	push col_1
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCell1

proc DrawCell2
	push bp
	mov bp, sp
	push ax
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 10
	push 2
	push col_2
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 10
	push ax
	push 4
	push 1
	push col_2
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 9
	push ax
	push 5
	push 1
	push col_2
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 8
	push ax
	push 5
	push 1
	push col_2
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 8
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 4
	push 1
	push col_2
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 10
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 3
	push 3
	push col_2
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 8
	push 1
	push col_2
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 3
	push 2
	push col_2
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 4
	push 1
	push col_2
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCell2

proc DrawCell3
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	;
	mov ax, [bp+6]
	add ax, 10
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 2
	push 10
	push col_3
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 7
	push 2
	push col_3
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 4
	push 2
	push col_3
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 7
	push 2
	push col_3
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 1
	push 3
	push col_3
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 9
	push ax
	push 1
	push 3
	push col_3
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCell3

proc DrawCell4
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	;
	mov ax, [bp+6]
	add ax, 9
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 3
	push 10
	push col_4
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 6
	push 2
	push col_4
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 5
	push ax
	push 3
	push 2
	push col_4
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 5
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 3
	push 2
	push col_4
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 1
	push 2
	push col_4
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCell4

proc DrawCell5
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 9
	push 2
	push col_5
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 8
	push ax
	push 1
	push 4
	push col_5
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 10
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 2
	push 4
	push col_5
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 7
	push 2
	push col_5
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 3
	push 4
	push col_5
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 7
	push 2
	push col_5
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCell5

proc DrawCell6
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 8
	push 2
	push col_6
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 10
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 2
	push 4
	push col_6
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 8
	push ax
	push 1
	push 4
	push col_6
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 3
	push 7
	push col_6
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 1
	push 1
	push col_6
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 4
	push 2
	push col_6
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 8
	push 1
	push col_6
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 6
	push 1
	push col_6
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCell6

proc DrawCell7
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	;
	mov ax, [bp+6]
	add ax, 7
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 3
	push 2
	push col_7
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 8
	push ax
	mov ax, [bp+4]
	add ax, 9
	push ax
	push 3
	push 2
	push col_7
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 9
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 3
	push 2
	push col_7
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 10
	push ax
	mov ax, [bp+4]
	add ax, 5
	push ax
	push 3
	push 2
	push col_7
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 10
	push 2
	push col_7
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCell7

proc DrawCell8
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 2
	push 10
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 2
	push 10
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 10
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 2
	push 10
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 4
	push 2
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 4
	push 2
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 4
	push 2
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 1
	push 3
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 9
	push ax
	push 1
	push 3
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 1
	push 3
	push col_8
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 9
	push ax
	push 1
	push 3
	push col_8
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCell8

proc DrawBomb
	push bp
	mov bp, sp
	push ax
	;
	mov ax, [bp+6]
	add ax, 8
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 3
	push 9
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 11
	push ax
	mov ax, [bp+4]
	add ax, 5
	push ax
	push 1
	push 7
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 6
	push ax
	push 1
	push 5
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 2
	push 2
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 6
	push ax
	push 2
	push 2
	push col_bomb_white
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 8
	push ax
	push 2
	push 5
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 5
	push ax
	mov ax, [bp+4]
	add ax, 5
	push ax
	push 1
	push 7
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 6
	push ax
	push 1
	push 5
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 2
	push ax
	mov ax, [bp+4]
	add ax, 8
	push ax
	push 2
	push 1
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 13
	push ax
	mov ax, [bp+4]
	add ax, 8
	push ax
	push 2
	push 1
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 8
	push ax
	mov ax, [bp+4]
	add ax, 2
	push ax
	push 1
	push 2
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 8
	push ax
	mov ax, [bp+4]
	add ax, 13
	push ax
	push 1
	push 2
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 1
	push 1
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 1
	push 1
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 12
	push ax
	push 1
	push 1
	push col_bomb
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 12
	push ax
	push 1
	push 1
	push col_bomb
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawBomb

proc DrawCellBomb
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	push [bp+6]
	push [bp+4]
	call DrawBomb
	;
	pop ax
	pop bp
	ret 4
endp DrawCellBomb

proc DrawCellBombRed
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncoveredRed
	push [bp+6]
	push [bp+4]
	call DrawBomb
	;
	pop ax
	pop bp
	ret 4
endp DrawCellBombRed

proc DrawCellBombMistake
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellUncovered
	push [bp+6]
	push [bp+4]
	call DrawBomb
	;
	mov ax, [bp+6]
	add ax, 13
	push ax
	mov ax, [bp+4]
	add ax, 14
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 13
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 11
	push ax
	mov ax, [bp+4]
	add ax, 12
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 10
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 9
	push ax
	mov ax, [bp+4]
	add ax, 10
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 7
	push ax
	mov ax, [bp+4]
	add ax, 8
	push ax
	push 3
	push 2
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 5
	push ax
	mov ax, [bp+4]
	add ax, 6
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 5
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 2
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 2
	push ax
	mov ax, [bp+4]
	add ax, 14
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 3
	push ax
	mov ax, [bp+4]
	add ax, 13
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 12
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 5
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 10
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 9
	push ax
	mov ax, [bp+4]
	add ax, 7
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 10
	push ax
	mov ax, [bp+4]
	add ax, 6
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 11
	push ax
	mov ax, [bp+4]
	add ax, 5
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 12
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 13
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 2
	push 1
	push col_cell_red
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCellBombMistake

proc DrawCellFlag
	push bp
	mov bp, sp
	push ax
	;
	push [bp+6]
	push [bp+4]
	call DrawCellCovered
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 11
	push ax
	push 8
	push 2
	push col_flag_base
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 6
	push ax
	mov ax, [bp+4]
	add ax, 10
	push ax
	push 4
	push 1
	push col_flag_base
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 8
	push ax
	mov ax, [bp+4]
	add ax, 8
	push ax
	push 1
	push 2
	push col_flag_base
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 7
	push ax
	mov ax, [bp+4]
	add ax, 3
	push ax
	push 2
	push 5
	push col_flag
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 5
	push ax
	mov ax, [bp+4]
	add ax, 4
	push ax
	push 2
	push 3
	push col_flag
	call DrawRect
	;
	mov ax, [bp+6]
	add ax, 4
	push ax
	mov ax, [bp+4]
	add ax, 5
	push ax
	push 1
	push 1
	push col_flag
	call DrawRect
	;
	pop ax
	pop bp
	ret 4
endp DrawCellFlag

proc CalcCellPosition
	mov dx, 0
	mov ax, cx
	mov bl, 8
	div bl
	mov dl, ah
	mov ah, 0
	mov bl, 16
	mul bl
	mov bx, ax
	mov ax, dx
	mov dx, bx
	mov bl, 16
	mul bl
	add ax, [board_startx]
	add dx, [board_starty]
	ret
endp CalcCellPosition

proc DrawAllNums ; NOT BLACK BOX
	cmp [byte ptr bx], 0
	jne DRAWALL_num1
	push ax
	push dx
	call DrawCellUncovered
	DRAWALL_num1:
		cmp [byte ptr bx], 1
		jne DRAWALL_num2
		push ax
		push dx
		call DrawCell1
	DRAWALL_num2:
		cmp [byte ptr bx], 2
		jne DRAWALL_num3
		push ax
		push dx
		call DrawCell2
	DRAWALL_num3:
		cmp [byte ptr bx], 3
		jne DRAWALL_num4
		push ax
		push dx
		call DrawCell3
	DRAWALL_num4:
		cmp [byte ptr bx], 4
		jne DRAWALL_num5
		push ax
		push dx
		call DrawCell4
	DRAWALL_num5:
		cmp [byte ptr bx], 5
		jne DRAWALL_num6
		push ax
		push dx
		call DrawCell5
	DRAWALL_num6:
		cmp [byte ptr bx], 6
		jne DRAWALL_num7
		push ax
		push dx
		call DrawCell6
	DRAWALL_num7:
		cmp [byte ptr bx], 7
		jne DRAWALL_num8
		push ax
		push dx
		call DrawCell7
	DRAWALL_num8:
		cmp [byte ptr bx], 8
		jne DRAWALL_nums_continue
		push ax
		push dx
		call DrawCell8
	DRAWALL_nums_continue:
		ret
endp DrawAllNums

proc DrawAll
	push ax
	push bx
	push cx
	push dx
	;
	mov cx, 0
	DRAWALL_loop:
		; calculating ax, dx - x, y position of the current cell
		call CalcCellPosition
		;
		mov bx, offset graphics
		add bx, cx
		call DrawAllNums
		; bomb
		cmp [byte ptr bx], 9
		jne DRAWALL_bombred
		push ax
		push dx
		call DrawCellBomb
	DRAWALL_bombred:
		cmp [byte ptr bx], 0Ah
		jne DRAWALL_bombmistake
		push ax
		push dx
		call DrawCellBombRed
	DRAWALL_bombmistake:
		cmp [byte ptr bx], 0Bh
		jne DRAWALL_flag
		push ax
		push dx
		call DrawCellBombMistake
	DRAWALL_flag:
		cmp [byte ptr bx], 0Ch
		jne DRAWALL_covered
		push ax
		push dx
		call DrawCellFlag
	DRAWALL_covered:
		cmp [byte ptr bx], 0Fh
		jne DRAWALL_continue
		push ax
		push dx
		call DrawCellCovered
	DRAWALL_continue:
		inc bx
		inc cx
		cmp cx, 64
		jne DRAWALL_loop
	;
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp DrawAll

proc DrawAtPosition ; stack arg: position on the board array
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	; calculating ax, dx - x, y position of the current cell
	mov cx, [bp+4]
	call CalcCellPosition
	;
	mov bx, offset graphics
	add bx, cx
	call DrawAllNums
	; bomb
	cmp [byte ptr bx], 9
	jne DRAWPOS_bombred
	push ax
	push dx
	call DrawCellBomb
	DRAWPOS_bombred:
		cmp [byte ptr bx], 0Ah
		jne DRAWPOS_bombmistake
		push ax
		push dx
		call DrawCellBombRed
	DRAWPOS_bombmistake:
		cmp [byte ptr bx], 0Bh
		jne DRAWPOS_flag
		push ax
		push dx
		call DrawCellBombMistake
	DRAWPOS_flag:
		cmp [byte ptr bx], 0Ch
		jne DRAWPOS_covered
		push ax
		push dx
		call DrawCellFlag
	DRAWPOS_covered:
		cmp [byte ptr bx], 0Fh
		jne DRAWPOS_continue
		push ax
		push dx
		call DrawCellCovered
	DRAWPOS_continue:
		pop dx
		pop cx
		pop bx
		pop ax
		pop bp
		ret 2
endp DrawAtPosition

proc DrawSelector ; stack arg: position on the board array
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	; calculate the cell position (returns ax=x, dx=y)
	mov cx, [bp+4]
	call CalcCellPosition
	;
	push ax
	push dx
	push 16
	push 1
	push col_selector
	call DrawRect
	;
	push ax
	push dx
	push 1
	push 16
	push col_selector
	call DrawRect
	;
	add ax, 15
	push ax
	push dx
	push 1
	push 16
	push col_selector
	call DrawRect
	;
	sub ax, 15
	add dx, 15
	push ax
	push dx
	push 16
	push 1
	push col_selector
	call DrawRect
	;
	pop ax
	pop bx
	pop cx
	pop dx
	pop bp
	ret 2
endp DrawSelector

; ---------- KEYBOARD AND SELECTOR PROCEDURES ---------- ;

proc MoveUp
	; check borders
	cmp [selector], 8
	jl MOVEUP_exit
	; move
	push [selector]
	call DrawAtPosition
	sub [selector], 8
	push [selector]
	call DrawSelector
	;
	MOVEUP_exit:
		ret
endp MoveUp

proc MoveLeft
	push ax
	push dx
	; check borders
	mov ax, [selector]
	mov dx, 8
	div dl
	cmp ah, 0
	je MOVELEFT_exit
	; move
	push [selector]
	call DrawAtPosition
	dec [selector]
	push [selector]
	call DrawSelector
	;
	MOVELEFT_exit:
		pop dx
		pop ax
		ret
endp MoveLeft

proc MoveDown
	; check borders
	cmp [selector], 55
	jg MOVEDOWN_exit
	; move
	push [selector]
	call DrawAtPosition
	add [selector], 8
	push [selector]
	call DrawSelector
	;
	MOVEDOWN_exit:
		ret
endp MoveDown

proc MoveRight
	push ax
	push dx
	; check borders
	mov ax, [selector]
	mov dx, 8
	div dl
	cmp ah, 7
	je MOVERIGHT_exit
	; move
	push [selector]
	call DrawAtPosition
	inc [selector]
	push [selector]
	call DrawSelector
	;
	MOVERIGHT_exit:
		pop dx
		pop ax
		ret
endp MoveRight

proc KeyboardEvents
	push ax
	mov ah, 0
	int 16h ;ah=scancode
	cmp ah, 1 ;esc
	je KEYB_terminate
	cmp ah, 48h ;up
	je KEYB_up
	cmp ah, 4Bh ;left
	je KEYB_left
	cmp ah, 50h ;down
	je KEYB_down
	cmp ah, 4Dh ;right
	je KEYB_right
	cmp ah, control_primary
	je KEYB_primary
	cmp ah, control_secondary
	je KEYB_secondary
	jmp KEYB_exit
	KEYB_up:
		call MoveUp
		jmp KEYB_exit
	KEYB_left:
		call MoveLeft
		jmp KEYB_exit
	KEYB_down:
		call MoveDown
		jmp KEYB_exit
	KEYB_right:
		call MoveRight
		jmp KEYB_exit
	KEYB_primary:
		call Primary
		jmp KEYB_exit
	KEYB_secondary:
		call Secondary
		jmp KEYB_exit
	KEYB_exit:
		pop ax
		ret
	KEYB_terminate:
		call Terminate
endp KeyboardEvents

start:
	mov ax, @data
	mov ds, ax
	
	mov dx, offset msg_intro
	mov ah, 9
	int 21h

	call SpreadBombs
	call MapNumbers

	; graphic mode
	mov ax, 13h
	int 10h

	call DrawAll
	push [selector]
	call DrawSelector

	infinity:
		call KeyboardEvents
		jmp infinity

	
	call Terminate

END start