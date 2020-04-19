; MCU 8051 IDE - Demonstration code
; Compiler directives


$DATE(32/13/1907)  	; Places date in page header
; $EJECT		; Places a form feed in listing
; $INCLUDE(file.asm)	; Inserts file in source program
; $LIST			; Allows listing to be output
; $NOLIST		; Stops outputting the listing
; $NOMOD		; No predefined symbols used
$OBJECT(file.hex)	; Places object output in file
; $NOOBJECT		; No object file is generated
$PAGING			; Break output listing into pages
; $NOPAGING		; Print listing w/o page breaks
$PAGELENGTH(10)		; No. of lines on a listing page
$PAGEWIDTH(20)	  	; No. of columns on a listing page
$PRINT(file.lst)	; Places listing output in file
; $NOPRINT		; Listing will not be output
; $SYMBOLS		; Append symbol table to listing
; $NOSYMBOLS		; Symbol table will not be output
$TITLE('demo - 3')	; Places string in page header


;; Summary of Cross Assembler Directives
;; -------------------------------------

a	EQU	54d	; Define symbol
b0	DATA	a / 2	; Define internal memory symbol
c	IDATA	(b0*2-5)	; Define indirectly addressed internal memory
d	BIT	070Q	; Define internal bit memory symbol
e	CODE	0FFA5h	; Define program memory symbol
var	SET	(A * 44) MOD 9 - 14 ; Variable defined by an expression

	CSEG at 20h	; Select program memory space
x:	DB	'34'	; Store byte values in program memory
y:	DW	3334h	; Store word values in program memory

	DSEG at 5d	; Select internal memory data space
m:	DS	1	; Reserve bytes of data memory

	xseg		; Select external memory data space
n:	DS	1	; Reserve bytes of data memory

	ISEG		; Select indirectly addressed internal memory space
o:	DS	1	; Reserve bytes of data memory

	NOLIST	; Disable code listing
	BSEG		; Select bit addressable memory space 
r:	DBIT	4	; Reserve bits of bit memory
	LIST	; Enable code listing

mc	macro	label	; Define macro instruction
	IF 2 <> 2 OR 1 = 4
		EXITM	; Exit macro
	ENDIF
	sjmp	label
endm			; End of definition

	CSEG	; <-- From now on, ORG refers to the code segment
main:	ORG	0	; Set segment location counter
	IF 0	; Begin conditional assembly block
		USING	2	; Select register bank (define AR0..7)
	ELSE	; Alternative conditional assembly block
		USING	2	; Select register bank (define AR0..7)
	ENDIF	; End conditional assembly block

	mc	main	; Macro instruction

	END	; End of assembly language source file


; This is a very long line, try to avoid them. This is a very long line, try to avoid them. This is a very long line, try to avoid them. This is a very long line, try to avoid them. This is a very long line, try to avoid them. This is a very long line, try to avoid them. This is a very long line, try to avoid them.This is a very long line, try to avoid them. This is a very long line, try to avoid them.This is a very long line, try to avoid them. This is a very long line, try to avoid them. This is a very long line, try to avoid them. This is a very long line, try to avoid them.
