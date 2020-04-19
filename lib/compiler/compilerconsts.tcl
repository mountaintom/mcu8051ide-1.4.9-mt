#!/usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2007, 2008, 2009, 2010, 2011, 2012 by Martin Ošmera     #
#    martin.osmera@gmail.com                                               #
#                                                                          #
#    Copyright (C) 2014 by Moravia Microsystems, s.r.o.                    #
#    martin.osmera@moravia-microsystems.com                                #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 2 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

# >>> File inclusion guard
if { ! [ info exists _COMPILERCONSTS_TCL ] } {
set _COMPILERCONSTS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Defines compiler constatnts. This code is part of Compiler
# (see compiler.tcl) and many other sources.
#
# Contains:
#	- Definition of instruction set
#	- Lists of defined instructions and durectives
#	- many other things (see code)
# --------------------------------------------------------------------------

namespace eval CompilerConsts {
	# Directives defining constants
	variable ConstDefinitionDirectives {
		bit set equ code data xdata idata flag
	}
	# Data segment selection directives
	variable ConstDataSegmentSelectionDirectives {
		bseg dseg iseg xseg
	}
	# Data memory reservation directives
	variable ConstDataMemoryReservationDirectives {
		ds dbit
	}
	# Fixed (non-variable) operands
	variable FixedOperands {
		a	c	ab	@dptr	@a+dptr
		@a+pc	r0	r1	r2	r3
		r4	r5	r6	r7	@r0
		@r1	dptr
	}
	# All 8051 instructions
	variable AllInstructions {
		acall	add	addc	ajmp	anl
		anl	cjne	clr	cpl	da
		dec	div	djnz	inc	jb
		jbc	jc	jmp	jnb	jnc
		jnz	jz	lcall	ljmp	mov
		movc	movx	mul	nop	orl
		pop	push	ret	reti	rl
		rr	rlc	rrc	setb	sjmp
		subb	swap	xch	xchd	xrl
		call
	}
	# All compiler directives
	variable AllDirectives {
		endif	endm	end	else	exitm
		list	nolist	dseg	iseg	bseg
		xseg	cseg	skip	name	equ
		bit	set	code	data	idata
		xdata	macro	flag	ds	dw
		db	dbit	include	org	if
		using	byte	name	rept	times
		elseif	ifn	elseifn	ifdef	elseifdef
		ifndef	elseifndef	ifb	elseifb
		ifnb	elseifnb	local
	}

	# Addresses of SFR registers
	variable MapOfSFRArea {
		{P0	80}	{SP	81}	{DPL	82}	{DPH	83}
		{PCON	87}	{TCON	88}	{TMOD	89}	{TL0	8A}
		{TL1	8B}	{TH0	8C}	{TH1	8D}	{P1	90}
		{SCON	98}	{SBUF	99}	{P2	A0}	{IE	A8}
		{P3	B0}	{IP	B8}	{PSW	D0}	{ACC	E0}
		{B	F0}	{P4	C0}	{WDTCON	A7}	{EECON	96}
		{DP0H	83}	{DP0L	82}	{DP1H	85}	{DP1L	84}
		{T2CON	C8}	{T2MOD	C9}	{RCAP2L	CA}	{RCAP2H	CB}
		{TL2	CC}	{TH2	CD}	{AUXR1	A2}	{WDTRST	A6}
		{CLKREG	8F}	{ACSR	97}	{IPH	B7}	{SADDR	A9}
		{SADEN	B9}	{SPCR	D5}	{SPSR	AA}	{SPDR	86}
		{AUXR	8E}	{CKCON	8F}	{WDTPRG	A7}

		{CH	F9}	{CCAP0H	FA}	{CCAP1H	FB}	{CCAP2H	FC}
		{CCAP3H	FD}	{CCAP4H	FE}	{CCAPL2H FC}	{CCAPL3H FD}
		{CCAPL4H FE}	{ADCLK	F2}	{ADCON	F3}	{ADDL	F4}
		{ADDH	F5}	{ADCF	F6}	{P5	E8}	{CL	E9}
		{CCAP0L	EA}	{CCAP1L	EB}	{CCAPL2L EC}	{CCAPL3L ED}
		{CCAPL4L EE}	{CCON	D8}	{CMOD	D9}	{CCAPM0	DA}
		{CCAPM1	DB}	{CCAPM2	DC}	{CCAPM3	DD}	{CCAPM4	DE}
		{P1M2	E2}	{P3M2	E3}	{P4M2	E4}	{P1M1	D4}
		{P3M1	D5}	{P4M1	D6}	{SPCON	C3}	{SPSTA	C4}
		{SPDAT	C5}	{IPL0	B8}	{IPL1	B2}	{IPH1	B3}
		{IPH0	B7}	{BRL	9A}	{BDRCON	9B}	{BDRCON_1 9C}
		{KBLS	9C}	{KBE	9D}	{KBF	9E}	{SADEN_0 B9}
		{SADEN_1 BA}	{SADDR_0 A9}	{SADDR_1 AA}	{CKSEL	85}
		{OSCCON	86}	{CKRL	97}	{CKCON0	8F}
	}

	# Addresses of bits of SFR registers
	variable MapOfSFRBitArea {
		{IT0	88}	{IE0	89}	{IT1	8A}	{IE1	8B}
		{TR0	8C}	{TF0	8D}	{TR1	8E}	{TF1	8F}

		{RI	98}	{TI	99}	{RB8	9A}	{TB8	9B}
		{REN	9C}	{SM2	9D}	{SM1	9E}	{SM0	9F}
		{FE	9F}

		{EX0	A8}	{ET0	A9}	{EX1	AA}	{ET1	AB}
		{ES	AC}	{ET2	AD}	{EC	AE}	{EA	AF}

		{RXD	B0}	{TXD	B1}	{INT0	B2}	{INT1	B3}
		{T0	B4}	{T1	B5}	{WR	B6}	{RD	B7}

		{PX0	B8}	{PT0	B9}	{PX1	BA}	{PT1	BB}
		{PS	BC}	{PT2	BD}	{PC	BE}

				{PPCL	BE}	{PT2L	BD}	{PSL	BC}
		{PT1L	BB}	{PX1L	BA}	{PT0L	B9}	{PX0L	B8}

		{TF2	CF}	{EXF2	CE}	{RCLK	CD}	{TCLK	CC}
		{EXEN2	CB}	{TR2	CA}	{CT2	C9}	{CPRL2	C8}

		{P	D0}			{OV	D2}	{RS0	D3}
		{RS1	D4}	{F0	D5}	{AC	D6}	{CY	D7}

				{CR	DE}			{CCF4	DC}
		{CCF3	DB}	{CCF2	DA}	{CCF1	D9}	{CCF0	D8}
	}

	# Program vectors
	variable progVectors {
		{RESET	00}	{EXTI0	03}	{TIMER0	0B}	{EXTI1	13}
		{TIMER1	1B}	{SINT	23}	{TIMER2	2B}	{CFINT	33}
	}

	## Instruction set definition
	 # ---------------------------------------------------------------------------------------------
	 #
	 # Format:
	 # {
	 #	{Instruction} {Operands_count
	 #		{{Operand_type_0 Operand_type_1 ...} Code_length Opcode Opcode_mask Machine_cycles_per_iteration}
	 #		...
	 #	}
	 #	...
	 # }
	 # Note: Triple dot means "et catera"
	 # ---------------------------------------------------------------------------------------------
	 #
	 # Opreand types:
	 #	code8	-	8 bit offset for relative jump
	 #	code11	-	11 bit program memory address
	 #	code16	-	16 bit program memory address
	 #	imm8	-	8 bit constant data
	 #	imm16	-	16 bit constant data
	 #	data	-	internal data memory or SFR direct address
	 #	bit	-	bit memory direct address
	 #
	 #	DPTR	-	Data PoinTeR register (16 bit)
	 #	A	-	Primary work register (Accumulator)
	 #	AB	-	16bit Accumulator
	 #	R0..R7	-	Register of active bank
	 #	C	-	Carry flag in PSW
	 #	@R0, R1, @DPTR, @A+PC, @A+DPTR	- Indirect addresses
	 # ---------------------------------------------------------------------------------------------
	 # For instance, instruction "acall" takes "1" operand,
	 #	that operand must be an operand of type "code11", acall takes "2" bytes
	 #	in the program memory. Its opcode is 0x11 and opcode mask is 0xE0
	 #	and instruction time is 2 cycles (for 8051 is means 24 clock periods).
	 # ---------------------------------------------------------------------------------------------
	 #
	 # Opcode mask explanation (for acall):
	 #	Bit number:	15 14 13 12 11 10 9  8  7  6  5  4  3  2  1  0		hex
	 #
	 #	Opcode mask:		       -  -  -  1  1  1  0  0  0  0  0		 -- E0
	 #	Operand:		       1  1  1  1  1  1  1  1  1  1  1		 -7 FF
	 #				   -- $processing --
	 #	Final operand:	1  1  1  0  0  0  0  0  1  1  1  1  1  1  1  1		E0 FF
	 #					-- OR --
	 #	Opcode:		0  0  0  1  0  0  0  1  -  -  -  -  -  -  -  -		-- 11
	 #			----------------------------------------------
	 #	Processor code: 1  1  1  1  0  0  0  1  1  1  1  1  1  1  1  1		F1 FF
	 #			^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	 #
	 # Note: $processing == "ones stands for operand code and zeroes are just zeroes"
	 # ---------------------------------------------------------------------------------------------
	 # Note: I know it doesn't make much sence, but I don't know any another way how to explain that.
	 #	 I'm sorry for that, see the list.
	 # ---------------------------------------------------------------------------------------------
	variable InstructionSetDefinition {
		{acall}	{1
			{
				{{code11	}	2	11	E0	2}
			}
		}
		{add}	{2
			{
				{{A	imm8	}	2	24	00	1}
				{{A	data	}	2	25	00	1}

				{{A	@R0	}	1	26	00	1}
				{{A	@R1	}	1	27	00	1}

				{{A	R0	}	1	28	00	1}
				{{A	R1	}	1	29	00	1}
				{{A	R2	}	1	2A	00	1}
				{{A	R3	}	1	2B	00	1}
				{{A	R4	}	1	2C	00	1}
				{{A	R5	}	1	2D	00	1}
				{{A	R6	}	1	2E	00	1}
				{{A	R7	}	1	2F	00	1}
			}
		}
		{addc}	{2
			{
				{{A	imm8	}	2	34	00	1}
				{{A	data	}	2	35	00	1}

				{{A	@R0	}	1	36	00	1}
				{{A	@R1	}	1	37	00	1}

				{{A	R0	}	1	38	00	1}
				{{A	R1	}	1	39	00	1}
				{{A	R2	}	1	3A	00	1}
				{{A	R3	}	1	3B	00	1}
				{{A	R4	}	1	3C	00	1}
				{{A	R5	}	1	3D	00	1}
				{{A	R6	}	1	3E	00	1}
				{{A	R7	}	1	3F	00	1}
			}
		}
		{ajmp}	{1
			{
				{{code11	}	2	01	E0	2}
			}
		}
		{anl}	{2
			{
				{{data	A	}	2	52	00	1}
				{{data	imm8	}	3	53	00	2}

				{{A	imm8	}	2	54	00	1}
				{{A	data	}	2	55	00	1}

				{{A	@R0	}	1	56	00	1}
				{{A	@R1	}	1	57	00	1}

				{{A	R0	}	1	58	00	1}
				{{A	R1	}	1	59	00	1}
				{{A	R2	}	1	5A	00	1}
				{{A	R3	}	1	5B	00	1}
				{{A	R4	}	1	5C	00	1}
				{{A	R5	}	1	5D	00	1}
				{{A	R6	}	1	5E	00	1}
				{{A	R7	}	1	5F	00	1}

				{{C	bit	}	2	82	00	2}
				{{C	/bit	}	2	B0	00	2}
			}
		}
		{call}	{1
			{
				{{code16	}	3	12	00	2}
				{{code11	}	2	11	E0	2}
			}
		}
		{cjne}	{3
			{
				{{A	imm8	code8}	3	B4	00	2}
				{{A	data	code8}	3	B5	00	2}

				{{@R0	imm8	code8}	3	B6	00	2}
				{{@R1	imm8	code8}	3	B7	00	2}

				{{R0	imm8	code8}	3	B8	00	2}
				{{R1	imm8	code8}	3	B9	00	2}
				{{R2	imm8	code8}	3	BA	00	2}
				{{R3	imm8	code8}	3	BB	00	2}
				{{R4	imm8	code8}	3	BC	00	2}
				{{R5	imm8	code8}	3	BD	00	2}
				{{R6	imm8	code8}	3	BE	00	2}
				{{R7	imm8	code8}	3	BF	00	2}
			}
		}
		{clr}	{1
			{
				{{A		}	1	E4	00	1}
				{{bit		}	2	C2	00	1}
				{{C		}	1	C3	00	1}
			}
		}
		{cpl} {1
			{
				{{A		}	1	F4	00	1}
				{{bit		}	2	B2	00	1}
				{{C		}	1	B3	00	1}
			}
		}
		{da}	{1
			{
				{{A		}	1	D4	00	1}
			}
		}
		{dec}	{1
			{
				{{A		}	1	14	00	1}
				{{data		}	2	15	00	1}

				{{@R0		}	1	16	00	1}
				{{@R1		}	1	17	00	1}

				{{R0		}	1	18	00	1}
				{{R1		}	1	19	00	1}
				{{R2		}	1	1A	00	1}
				{{R3		}	1	1B	00	1}
				{{R4		}	1	1C	00	1}
				{{R5		}	1	1D	00	1}
				{{R6		}	1	1E	00	1}
				{{R7		}	1	1F	00	1}
			}
		}
		{div}	{1
			{
				{{AB		}	1	84	00	4}
			}
		}
		{djnz}	{2
			{
				{{data	code8	}	3	D5	00	2}

				{{R0	code8	}	2	D8	00	2}
				{{R1	code8	}	2	D9	00	2}
				{{R2	code8	}	2	DA	00	2}
				{{R3	code8	}	2	DB	00	2}
				{{R4	code8	}	2	DC	00	2}
				{{R5	code8	}	2	DD	00	2}
				{{R6	code8	}	2	DE	00	2}
				{{R7	code8	}	2	DF	00	2}
			}
		}
		{inc}	{1
			{
				{{A		}	1	04	00	1}
				{{data		}	2	05	00	1}

				{{@R0		}	1	06	00	1}
				{{@R1		}	1	07	00	1}

				{{R0		}	1	08	00	1}
				{{R1		}	1	09	00	1}
				{{R2		}	1	0A	00	1}
				{{R3		}	1	0B	00	1}
				{{R4		}	1	0C	00	1}
				{{R5		}	1	0D	00	1}
				{{R6		}	1	0E	00	1}
				{{R7		}	1	0F	00	1}

				{{DPTR		}	1	A3	00	2}
			}
		}
		{jb}	{2
			{
				{{bit	code8	}	3	20	00	2}
			}
		}
		{jbc}	{2
			{
				{{bit	code8	}	3	10	00	2}
			}
		}
		{jc}	{1
			{
				{{code8		}	2	40	00	2}
			}
		}
		{jmp}	{1
			{
				{{@A+DPTR	}	1	73	00	2}
				{{code16	}	3	02	00	2}
				{{code11	}	2	01	E0	2}
				{{code8		}	2	80	00	2}
			}
		}
		{jnb}	{2
			{
				{{bit	code8	}	3	30	00	2}
			}
		}
		{jnc}	{1
			{
				{{code8		}	2	50	00	2}
			}
		}
		{jnz}	{1
			{
				{{code8		}	2	70	00	2}
			}
		}
		{jz}	{1
			{
				{{code8		}	2	60	00	2}
			}
		}
		{lcall}	{1
			{
				{{code16	}	3	12	00	2}
			}
		}
		{ljmp}	{1
			{
				{{code16	}	3	02	00	2}
			}
		}
		{mov}	{2
			{
				{{A	imm8	}	2	74	00	1}
				{{A	data	}	2	E5	00	1}

				{{A	@R0	}	1	E6	00	1}
				{{A	@R1	}	1	E7	00	1}

				{{A	R0	}	1	E8	00	1}
				{{A	R1	}	1	E9	00	1}
				{{A	R2	}	1	EA	00	1}
				{{A	R3	}	1	EB	00	1}
				{{A	R4	}	1	EC	00	1}
				{{A	R5	}	1	ED	00	1}
				{{A	R6	}	1	EE	00	1}
				{{A	R7	}	1	EF	00	1}



				{{data	A	}	2	F5	00	1}

				{{data	imm8	}	3	75	00	2}
				{{data	data	}	3	85	00	2}

				{{data	@R0	}	2	86	00	2}
				{{data	@R1	}	2	87	00	2}

				{{data	R0	}	2	88	00	2}
				{{data	R1	}	2	89	00	2}
				{{data	R2	}	2	8A	00	2}
				{{data	R3	}	2	8B	00	2}
				{{data	R4	}	2	8C	00	2}
				{{data	R5	}	2	8D	00	2}
				{{data	R6	}	2	8E	00	2}
				{{data	R7	}	2	8F	00	2}



				{{@R0	A	}	1	F6	00	1}
				{{@R1	A	}	1	F7	00	1}

				{{@R0	imm8	}	2	76	00	1}
				{{@R1	imm8	}	2	77	00	1}

				{{@R0	data	}	2	A6	00	2}
				{{@R1	data	}	2	A7	00	2}



				{{R0	A	}	1	F8	00	1}
				{{R1	A	}	1	F9	00	1}
				{{R2	A	}	1	FA	00	1}
				{{R3	A	}	1	FB	00	1}
				{{R4	A	}	1	FC	00	1}
				{{R5	A	}	1	FD	00	1}
				{{R6	A	}	1	FE	00	1}
				{{R7	A	}	1	FF	00	1}

				{{R0	imm8	}	2	78	00	1}
				{{R1	imm8	}	2	79	00	1}
				{{R2	imm8	}	2	7A	00	1}
				{{R3	imm8	}	2	7B	00	1}
				{{R4	imm8	}	2	7C	00	1}
				{{R5	imm8	}	2	7D	00	1}
				{{R6	imm8	}	2	7E	00	1}
				{{R7	imm8	}	2	7F	00	1}

				{{R0	data	}	2	A8	00	2}
				{{R1	data	}	2	A9	00	2}
				{{R2	data	}	2	AA	00	2}
				{{R3	data	}	2	AB	00	2}
				{{R4	data	}	2	AC	00	2}
				{{R5	data	}	2	AD	00	2}
				{{R6	data	}	2	AE	00	2}
				{{R7	data	}	2	AF	00	2}



				{{DPTR	imm16	}	3	90	00	2}

				{{bit	C	}	2	92	00	2}

				{{C	bit	}	2	A2	00	1}
			}
		}
		{movc}	{2
			{
				{{A	@A+DPTR	}	1	93	00	2}
				{{A	@A+PC	}	1	83	00	2}
			}
		}
		{movx}	{2
			{
				{{A	@R0	}	1	E2	00	2}
				{{A	@R1	}	1	E3	00	2}
				{{A	@DPTR	}	1	E0	00	2}

				{{@R0	A	}	1	F2	00	2}
				{{@R1	A	}	1	F3	00	2}
				{{@DPTR	A	}	1	F0	00	2}
			}
		}
		{mul}	{1
			{
				{{AB		}	1	A4	00	4}
			}
		}
		{nop}	{0
			{
				{{		}	1	00	00	1}
			}
		}
		{orl}	{2
			{
				{{data	A	}	2	42	00	1}
				{{data	imm8	}	3	43	00	2}

				{{A	imm8	}	2	44	00	1}
				{{A	data	}	2	45	00	1}

				{{A	@R0	}	1	46	00	1}
				{{A	@R1	}	1	47	00	1}

				{{A	R0	}	1	48	00	1}
				{{A	R1	}	1	49	00	1}
				{{A	R2	}	1	4A	00	1}
				{{A	R3	}	1	4B	00	1}
				{{A	R4	}	1	4C	00	1}
				{{A	R5	}	1	4D	00	1}
				{{A	R6	}	1	4E	00	1}
				{{A	R7	}	1	4F	00	1}

				{{C	bit	}	2	72	00	2}
				{{C	/bit	}	2	A0	00	2}
			}
		}
		{pop}	{1
			{
				{{data		}	2	D0	00	2}
			}
		}
		{push}	{1
			{
				{{data		}	2	C0	00	2}
			}
		}
		{ret}	{0
			{
				{{		}	1	22	00	2}
			}
		}
		{reti}	{0
			{
				{{		}	1	32	00	2}
			}
		}
		{rl}	{1
			{
				{{A		}	1	23	00	1}
			}
		}
		{rr}	{1
			{
				{{A		}	1	03	00	1}
			}
		}
		{rlc}	{1
			{
				{{A		}	1	33	00	1}
			}
		}
		{rrc}	{1
			{
				{{A		}	1	13	00	1}
			}
		}
		{setb}	{1
			{
				{{C		}	1	D3	00	1}
				{{bit		}	2	D2	00	1}
			}
		}
		{sjmp}	{1
			{
				{{code8		}	2	80	00	2}
			}
		}
		{subb}	{2
			{
				{{A	imm8	}	2	94	00	1}
				{{A	data	}	2	95	00	1}

				{{A	@R0	}	1	96	00	1}
				{{A	@R1	}	1	97	00	1}

				{{A	R0	}	1	98	00	1}
				{{A	R1	}	1	99	00	1}
				{{A	R2	}	1	9A	00	1}
				{{A	R3	}	1	9B	00	1}
				{{A	R4	}	1	9C	00	1}
				{{A	R5	}	1	9D	00	1}
				{{A	R6	}	1	9E	00	1}
				{{A	R7	}	1	9F	00	1}
			}
		}
		{swap}	{1
			{
				{{A		}	1	C4	00	1}
			}
		}
		{xch}	{2
			{
				{{A	data	}	2	C5	00	1}

				{{A	@R0	}	1	C6	00	1}
				{{A	@R1	}	1	C7	00	1}

				{{A	R0	}	1	C8	00	1}
				{{A	R1	}	1	C9	00	1}
				{{A	R2	}	1	CA	00	1}
				{{A	R3	}	1	CB	00	1}
				{{A	R4	}	1	CC	00	1}
				{{A	R5	}	1	CD	00	1}
				{{A	R6	}	1	CE	00	1}
				{{A	R7	}	1	CF	00	1}
			}
		}
		{xchd}	{2
			{
				{{A	@R0	}	1	D6	00	1}
				{{A	@R1	}	1	D7	00	1}
			}
		}
		{xrl}	{2
			{
				{{data	A	}	2	62	00	1}
				{{data	imm8	}	3	63	00	2}

				{{A	imm8	}	2	64	00	1}
				{{A	data	}	2	65	00	1}

				{{A	@R0	}	1	66	00	1}
				{{A	@R1	}	1	67	00	1}

				{{A	R0	}	1	68	00	1}
				{{A	R1	}	1	69	00	1}
				{{A	R2	}	1	6A	00	1}
				{{A	R3	}	1	6B	00	1}
				{{A	R4	}	1	6C	00	1}
				{{A	R5	}	1	6D	00	1}
				{{A	R6	}	1	6E	00	1}
				{{A	R7	}	1	6F	00	1}
			}
		}
	}

	variable InstructionDefinition			;# Array of instruction efinitions (key: instrcution name)
	variable SimpleOperandDefinitions		;# Array of simple operand definitions (eg. '#', '/')
	variable defined_OPCODE			{}	;# List of defined opcodes
	variable defined_SFR			{}	;# List of defined SFR (lowercase)
	variable defined_SFRBitArea		{}	;# List of defined bit addressable bits in SFR (lowercase)
	variable defined_progVectors		{}	;# List of defined interrupt vectors (lowercase)
	variable Opcode					;# Array of instruction defnitions (key: OP code)

	## Initialize NS variables (must be called to make this NS usable)
	 # @return void
	proc initialize {} {
		variable InstructionDefinition		;# Array of instruction efinitions (key: instrcution name)
		variable InstructionSetDefinition	;# List of instruction definitions
		variable SimpleOperandDefinitions	;# Array of simple operand definitions (eg. '#', '/')
		variable defined_OPCODE			;# List of defined opcodes
		variable defined_SFR			;# List of defined SFR
		variable defined_SFRBitArea		;# List of defined bit addressable bits in SFR
		variable defined_progVectors		;# List of defined interrupt vectors
		variable Opcode				;# Array of instruction defnitions (key: OP code)

		# Remove redutant space from lists
		foreach var {
			ConstDefinitionDirectives
			ConstDataSegmentSelectionDirectives
			ConstDataMemoryReservationDirectives
			FixedOperands
			AllInstructions
			AllDirectives
			MapOfSFRArea
			MapOfSFRBitArea
			progVectors
		} \
		{
			variable $var
			set val [subst -nocommands "\$$var"]
			regsub -all {\s+} $val { } $var
		}

		# Initialize defined_SFR, defined_SFRBitArea and defined_progVectors
		foreach item $MapOfSFRArea {
			lappend defined_SFR [string tolower [lindex $item 0]]
		}
		foreach item $MapOfSFRBitArea {
			lappend defined_SFRBitArea [string tolower [lindex $item 0]]
		}
		foreach item $progVectors {
			lappend defined_progVectors [string tolower [lindex $item 0]]
		}

		# Create new constants from list of instructin definitions
		for {set i 0} {1} {incr i} {
			# Determinate instruction name
			set instruction [lindex $InstructionSetDefinition $i]
			if {$instruction == {}} {break}

			# Determinate instruction definition
			incr i
			set def [lindex $InstructionSetDefinition $i]
			set def [regsub -all {\s+} $def { }]

			# Initialize simple operands definition and instruction definition array
			set SimpleOperandDefinitions($instruction) {}
			set InstructionDefinition($instruction) [string tolower $def]

			# Iterate over oprand set definitions
			set def_idx 0
			foreach code_def [lindex $def 1] {
				incr def_idx

				# Local variables
				set time	[lindex $code_def 4]	;# Time
				set mask	[lindex $code_def 3]	;# OP code mask
				set opcode	[lindex $code_def 2]	;# OP code
				set len		[lindex $code_def 1]	;# Code length
				set operands	[lindex $code_def 0]	;# Operand types
				set new_oprs	{}			;# List of simple operands

				# Create list of simple operands
				foreach opr $operands {
					# Direct addressing
					if {[lsearch {data bit code8 code11 code16} $opr] != -1} {
						lappend new_oprs {D}
					# Immediate addressing
					} elseif {$opr == {imm8} || $opr == {imm16}} {
						lappend new_oprs {#}
					# Inverted bit
					} elseif {$opr == {/bit}} {
						lappend new_oprs {/}
					# Fixed operand
					} else {
						lappend new_oprs $opr
					}
				}
				lappend SimpleOperandDefinitions($instruction) $new_oprs

				## Create array of instruction definitions by OP codes (for disassembler)
				 # No OP code mask
				if {$mask == {00}} {
					# Skip "CALL" and "JMP" (except 1st op. set)
					if {!($instruction == {call} || ($instruction == {jmp} && $def_idx > 1))} {
						if {[lsearch $defined_OPCODE $opcode] != -1} {
							puts "Instruction set parse error 0 -- opcode $opcode"
							continue
						}
						lappend defined_OPCODE $opcode
						set Opcode($opcode) [list $instruction $operands $len {} $time]
					}
				 # Non-zero OP code mask
				} else {
					# Translate OP code and its mask to list of booleans
					set opcode [assembler::hex2binlist $opcode]
					set mask [assembler::hex2binlist $mask]

					# Insure than masked OP code bits are zeroes
					set idx 0
					foreach mask_bit $mask {
						if {$mask_bit} {
							lset opcode $idx 0
						}
						incr idx
					}

					# Determinate number of positive bits in the
					# mask and maximum value under mask
					set max 0
					set val 1
					set bits 0
					foreach bit $mask {
						if {$bit} {
							incr bits
							incr max $val
							set val [expr {$val * 2}]
						}
					}

					# Determinate list of possible high-order values
					# of opreands according to the mask
					set values {}
					set tmp 0
					set tmp_len 0
					for {set val 0} {$val <= $max} {incr val} {
						set tmp [NumSystem::dec2bin $val]
						set tmp_len [string length $tmp]
						if {$tmp_len != $bits} {
							set tmp "[string repeat 0 [expr {$bits - $tmp_len}]]$tmp"
						}
						lappend values $tmp
					}

					# Detereminate list of possible OP codes and
					# corresponding high-order operand values
					set opcodes {}
					set new_values {}
					foreach val $values {
						set tmp {}
						set idx 0
						foreach mask_bit $mask opcode_bit $opcode {
							if {$mask_bit} {
								append tmp [string index $val $idx]
								incr idx
							} else {
								append tmp $opcode_bit
							}
						}
						set tmp [NumSystem::bin2hex $tmp]
						if {[string length $tmp] == 1} {
							set tmp "0$tmp"
						}
						lappend opcodes $tmp
						lappend new_values [NumSystem::bin2hex $val]
					}
					set values $new_values

					# Append results to Array of instruction definitions by OP codes
					foreach opcode $opcodes masked_opr $values {
						# Skip "CALL" and "JMP" (except 1st op. set)
						if {$instruction == {call}} {
							break
						} elseif {$instruction == {jmp} && $def_idx > 1} {
							break
						}

						# Register OP code
						if {[lsearch $defined_OPCODE $opcode] != -1} {
							puts "Instruction set parse error 1 -- opcode $opcode"
							continue
						}
						lappend defined_OPCODE $opcode
						set Opcode($opcode) [list $instruction $operands $len $masked_opr $time]

					}
				}
			}
		}
	}
}

# Initialize NS variables
CompilerConsts::initialize

# >>> File inclusion guard
}
# <<< File inclusion guard
