; MCU 8051 IDE - Demostration code
; Interrupt monitor and list of active subprograms

; 1) Press Ctrl+0 to show tab "List of subprograms" on righ panel
; 2) Run interrupt monitor
;	(Main menu: Simulator -> Interrupt monitor)
; 3) Press F2 to start simulator and F6 to run animation mode

; Macro instructions
; ------------------

;; Handle interrupt
intr	macro
	; Set UART interrupt flags
	setb	RI
	setb	TI
	
	; Wait a while and return from interrupt
	acall	wait
	reti
endm


; Interrupt vectors
; -----------------
	org	00h	; Reset
	ajmp	start

	org	03h	; External 0
	intr

	org	0Bh	; Timer 0
	intr

	org	13h	; External 0
	intr

	org	1Bh	; Timer 1
	intr

	org	23h	; UART and SPI
	intr

	org	2Bh	; Timer 2
	intr

	org	33h	; Analog comparator
	intr

; Subprograms
; -----------------
wait:	; Wait for 24 cycles
	mov	R7, #10h
	acall	wait_aux
	ret

wait_aux:
	djnz	R7, $
	ret


; Program start
; -----------------
start:
	; Set some interrupt bits
	setb	TF0
	setb	TF1
	setb	IE0
	setb	IE1

	; Enable all interrupts and set priorities
	mov	IE, #0FFh
	setb	PS

	; Infinite loop
	sjmp	$


; End of code
; -----------------
	end
