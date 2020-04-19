; MCU 8051 IDE - Demonstration code
; Interrupts, hexadecimal editor and code validator
; ------------------------------------------------------
; THIS REQUIRES ANOTHER MCU THAN AT89C2051 BECAUSE
; AT89C2051 HAS NO XDATA MENORY. CLICK ON 
; [Main menu] -> [Project] -> [Edit project] AND SELECT
; FOR INSTANCE AT89C51 AND SET XDATA TO SOME VALUE
; ------------------------------------------------------

; * Click on [Main menu] -> [Simulator] -> [Show XDATA memory]
; * Press F2 and F6 (start simulator and animate)



; Code with syntax errors
	nolist	; Disable code listing
if 0
	mov	A, #55d, B	; too many operands
	inc	0FFh,, 04x4h	; invalid operands
	db	(4 *** 5)	; invalid expression
label?:	mul	B		; invalid label and invalid operand
endif
	list	; Enable code listing

; Constants
; --------------------
		cseg at	0D0h
string:		db	'Welcome in MCU 8051 IDE ! '

string_legth	equ	26d

; Macro instructions
; --------------------
write_to_xdata	macro	str, code_ptr, xdata_ptr
	mov	A, code_ptr
	mov	DPTR, #str
	movc	A, @A+DPTR
	mov	DPL, xdata_ptr
	movx	@DPTR, A
	inc	xdata_ptr
	inc	code_ptr
endm

; Program initialization
; --------------------
	org	0h		; Reset vector
	sjmp	start

	org	0Bh		; Interrupt vector - T0
	sjmp	T0_int

; Sub-programs
; --------------------

;; Handle interrupt from TF0
T0_int:	mov	R7, #string_legth
	mov	R6, #0h
loop:	write_to_xdata	string, R6, R5
	djnz	R7, loop
	reti

; Program start
; --------------------
start:	; Start timer 0 in mode 2
	mov	R5, #0h
	mov	IE, #0FFh
	mov	TL0, #255d
	mov	TMOD, #03h
	setb	TR0
	sjmp	main

; Main loop
; --------------------
main:	sjmp	$	; Infinite loop

; Program end
; --------------------
	end
