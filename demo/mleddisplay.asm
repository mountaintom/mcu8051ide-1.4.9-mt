; Demonstration code for MCU 8051 IDE
;
; Load virtual HW from "mleddisplay.vhc"
; and press F2 and F6
;
; It should increment 4 digit number displayed
; on multiplexed LED display


; -----------------------------------------------
; CONSTANTS
; -----------------------------------------------

data_ptr	data	20h	; Number to display
data_len	equ	4h	; Number of digits

;; Codes for 8-segment LED display
 ; They can be easily determinated with
 ; 8-segment editor ( [Main menu] - > 
 ; [Utilities] -> [8-segment editor] )
numbers:db	11000000b ; 0
	db	11111001b ; 1
	db	10100100b ; 2
	db	10110000b ; 3
	db	10011001b ; 4
	db	10010010b ; 5
	db	10000010b ; 6
	db	11111000b ; 7
	db	10000000b ; 8
	db	10010000b ; 9

; -----------------------------------------------
; VECTORS
; -----------------------------------------------
	; Reset vector
	org	0
	jmp	start

; -----------------------------------------------
; SUBPROGRAMS
; -----------------------------------------------

;; Increment the number
 ;
 ; R0 must be set to data_ptr before call
 ;
 ; Affected registers: R0
 ; Interrupts: None
 ; Notes: Recursive sub-program
inrement_number:
	inc	@R0
	cjne	@R0, #0Ah, inc_num_end

	mov	@R0, #0
	inc	R0
	cjne	R0, #data_ptr+data_len, $+4
	ret
	call	inrement_number
inc_num_end:
	ret

;; Display the number on the LED display
 ;
 ; DPTR must point to table numbers
 ; R0 must contain (data_ptr+data_len)
 ;
 ; Affected registers: A, B, R0, P1, P3
 ; Interrupts: None
 ; Notes: Uses DPTR
display_number:
	; Select digit to display
	dec	R0	; In uC
	mov	A, B
	rr	A
	mov	B, A

	; Translate the digit to binary 
	; representation for the LED display
	mov	A, @R0
	movc	A, @A+DPTR

	; Display the digit on the display
	mov	P3, #0ffh
	mov	P1, A
	mov	P3, B

	; Display next digit
	cjne	R0, #data_ptr, display_number
	ret

; -----------------------------------------------
; PROGRAM START
; -----------------------------------------------
start:
	; Data to zeroes
	mov	data_ptr+0, #0h	; left-most
	mov	data_ptr+1, #0h
	mov	data_ptr+2, #0h
	mov	data_ptr+3, #0h	; right-most

	; Address 1st number on the display
	mov	B, #0EEh
	; Initialize DPTR (Data PoinTeR)
	mov	DPTR, #numbers

; -----------------------------------------------
; MAIN LOOP
; -----------------------------------------------

main:
	; Show the number on the LED display
	mov	R0, #data_ptr+data_len
	call	display_number

	; Increment the number
	mov	R0, #data_ptr
	call	inrement_number

	; Close main loop
	jmp	main

; -----------------------------------------------
; PROGRAM END
; -----------------------------------------------
	end
