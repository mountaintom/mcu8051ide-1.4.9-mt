; MCU 8051 IDE - Demonstration code
; Very simple code

; Press F2 and F6 to run the program (start simulator and animate)

	org	0h

main:	inc	R0
	inc	@R0
	cjne	R0, #07Fh, main
	mov	R0, #0d
	sjmp	main

	end

; <-- Bookmark (try Alt+PgUp/Alt+PgDown)
; <-- Breakpoint

; -----------------------------------------
; NOTICE:
; Simulator limitations:
;	* SPI
;	* Access to external code memory
;	* Power down modes
; -----------------------------------------

; IF YOU HAVE FOUND SOME BUG IN THIS IDE , PLEASE LET ME KNOW
