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
if { ! [ info exists _ENGINE_OPCODES_TCL ] } {
set _ENGINE_OPCODES_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# OPCODE PROCEDURES
# --------------------------------------------------------------------------


## ACALL
private method 17	{} {ins_acall 0 [getLastOperand]}	;# 0x11 :: acall 0x0__
private method 49	{} {ins_acall 1 [getLastOperand]}	;# 0x31 :: acall 0x1__
private method 81	{} {ins_acall 2 [getLastOperand]}	;# 0x51 :: acall 0x2__
private method 113	{} {ins_acall 3 [getLastOperand]}	;# 0x71 :: acall 0x3__
private method 145	{} {ins_acall 4 [getLastOperand]}	;# 0x91 :: acall 0x4__
private method 177	{} {ins_acall 5 [getLastOperand]}	;# 0xB1 :: acall 0x5__
private method 209	{} {ins_acall 6 [getLastOperand]}	;# 0xD1 :: acall 0x6__
private method 241	{} {ins_acall 7 [getLastOperand]}	;# 0xF1 :: acall 0x7__

## ADD
private method 36	{} {ins_add [getNextOperand]}		;# 0x24 :: add  A, #imm8
private method 37	{} {ins_add_D [getNextOperand]}		;# 0x25 :: add  A, addr
private method 38	{} {ins_add_ID $ram([R 0])}		;# 0x26 :: add  A, @R0
private method 39	{} {ins_add_ID $ram([R 1])}		;# 0x27 :: add  A, @R1
private method 40	{} {ins_add $ram([R 0])}		;# 0x28 :: add  A, R0
private method 41	{} {ins_add $ram([R 1])}		;# 0x29 :: add  A, R1
private method 42	{} {ins_add $ram([R 2])}		;# 0x2A :: add  A, R2
private method 43	{} {ins_add $ram([R 3])}		;# 0x2B :: add  A, R3
private method 44	{} {ins_add $ram([R 4])}		;# 0x2C :: add  A, R4
private method 45	{} {ins_add $ram([R 5])}		;# 0x2D :: add  A, R5
private method 46	{} {ins_add $ram([R 6])}		;# 0x2E :: add  A, R6
private method 47	{} {ins_add $ram([R 7])}		;# 0x2F :: add  A, R7

## ADDC
private method 52	{} {ins_addc [getNextOperand]}		;# 0x34 :: addc  A, #imm8
private method 53	{} {ins_addc_D [getNextOperand]}	;# 0x35 :: addc  A, addr
private method 54	{} {ins_addc_ID $ram([R 0])}		;# 0x36 :: addc  A, @R0
private method 55	{} {ins_addc_ID $ram([R 1])}		;# 0x37 :: addc  A, @R1
private method 56	{} {ins_addc $ram([R 0])}		;# 0x38 :: addc  A, R0
private method 57	{} {ins_addc $ram([R 1])}		;# 0x39 :: addc  A, R1
private method 58	{} {ins_addc $ram([R 2])}		;# 0x3A :: addc  A, R2
private method 59	{} {ins_addc $ram([R 3])}		;# 0x3B :: addc  A, R3
private method 60	{} {ins_addc $ram([R 4])}		;# 0x3C :: addc  A, R4
private method 61	{} {ins_addc $ram([R 5])}		;# 0x3D :: addc  A, R5
private method 62	{} {ins_addc $ram([R 6])}		;# 0x3E :: addc  A, R6
private method 63	{} {ins_addc $ram([R 7])}		;# 0x3F :: addc  A, R7

## AJMP
private method 1	{} {ins_ajmp 0 [getNextOperand]}	;# 0x01 :: ajmp 0x0__
private method 33	{} {ins_ajmp 1 [getNextOperand]}	;# 0x21 :: ajmp 0x1__
private method 65	{} {ins_ajmp 2 [getNextOperand]}	;# 0x41 :: ajmp 0x2__
private method 97	{} {ins_ajmp 3 [getNextOperand]}	;# 0x61 :: ajmp 0x3__
private method 129	{} {ins_ajmp 4 [getNextOperand]}	;# 0x81 :: ajmp 0x4__
private method 161	{} {ins_ajmp 5 [getNextOperand]}	;# 0xA1 :: ajmp 0x5__
private method 193	{} {ins_ajmp 6 [getNextOperand]}	;# 0xC1 :: ajmp 0x6__
private method 225	{} {ins_ajmp 7 [getNextOperand]}	;# 0xE1 :: ajmp 0x7__

## ANL
private method 82	{} {ins_anl [getLastOperand] $sfr(224); incr time -1}	;# 0x52 :: anl  addr, A
private method 83	{} {ins_anl [getNextOperand] [getLastOperand]}		;# 0x53 :: anl  addr, #imm8
private method 84	{} {ins_anl_A [getNextOperand]}				;# 0x54 :: anl  A, #imm8
private method 85	{} {ins_anl_A_D [getNextOperand]}			;# 0x55 :: anl  A, addr
private method 86	{} {ins_anl_A_ID $ram([R 0])}				;# 0x56 :: anl  A, @R0
private method 87	{} {ins_anl_A_ID $ram([R 1])}				;# 0x57 :: anl  A, @R1
private method 88	{} {ins_anl_A $ram([R 0])}				;# 0x58 :: anl  A, R0
private method 89	{} {ins_anl_A $ram([R 1])}				;# 0x59 :: anl  A, R1
private method 90	{} {ins_anl_A $ram([R 2])}				;# 0x5A :: anl  A, R2
private method 91	{} {ins_anl_A $ram([R 3])}				;# 0x5B :: anl  A, R3
private method 92	{} {ins_anl_A $ram([R 4])}				;# 0x5C :: anl  A, R4
private method 93	{} {ins_anl_A $ram([R 5])}				;# 0x5D :: anl  A, R5
private method 94	{} {ins_anl_A $ram([R 6])}				;# 0x5E :: anl  A, R6
private method 95	{} {ins_anl_A $ram([R 7])}				;# 0x5F :: anl  A, R7
private method 130	{} {ins_anl_C [getLastOperand]}				;# 0x82 :: anl  C, Baddr
private method 176	{} {ins_anl_C_N [getLastOperand]}			;# 0xB0 :: anl  C, /Baddr


## CJNE
private method 180	{} {						;# 0xB4 :: cjne  A, #imm8, Roff
	ins_cjne $sfr(224) [getNextOperand] [getLastOperand]
}
private method 181	{} {						;# 0xB5 :: cjne  A, addr, Roff
	ins_cjne_AD [getNextOperand] [getLastOperand]
}
private method 182	{} {						;# 0xB6 :: cjne  @R0, #imm8, Roff
	ins_cjne_ID $ram([R 0]) [getNextOperand] [getLastOperand]
}
private method 183	{} {						;# 0xB7 :: cjne  @R1, #imm8, Roff
	ins_cjne_ID $ram([R 1]) [getNextOperand] [getLastOperand]
}
private method 184	{} {						;# 0xB8 :: cjne  R0, #imm8, Roff
	ins_cjne $ram([R 0]) [getNextOperand] [getLastOperand]
}
private method 185	{} {						;# 0xB9 :: cjne  R1, #imm8, Roff
	ins_cjne $ram([R 1]) [getNextOperand] [getLastOperand]
}
private method 186	{} {						;# 0xBA :: cjne  R2, #imm8, Roff
	ins_cjne $ram([R 2]) [getNextOperand] [getLastOperand]
}
private method 187	{} {						;# 0xBB :: cjne  R3, #imm8, Roff
	ins_cjne $ram([R 3]) [getNextOperand] [getLastOperand]
}
private method 188	{} {						;# 0xBC :: cjne  R4, #imm8, Roff
	ins_cjne $ram([R 4]) [getNextOperand] [getLastOperand]
}
private method 189	{} {						;# 0xBD :: cjne  R5, #imm8, Roff
	ins_cjne $ram([R 5]) [getNextOperand] [getLastOperand]
}
private method 190	{} {						;# 0xBE :: cjne  R6, #imm8, Roff
	ins_cjne $ram([R 6]) [getNextOperand] [getLastOperand]
}
private method 191	{} {						;# 0xBF :: cjne  R7, #imm8, Roff
	ins_cjne $ram([R 7]) [getNextOperand] [getLastOperand]
}

## CLR
private method 228	{} {ins_clr A}			;# 0xE4 :: clr A
private method 195	{} {ins_clr C}			;# 0xC3 :: clr C
private method 194	{} {ins_clr [getNextOperand]}	;# 0xC2 :: clr Baddr

## CPL
private method 244	{} {ins_cpl A}			;# 0xF4 :: cpl A
private method 179	{} {ins_cpl C}			;# 0xC3 :: cpl C
private method 178	{} {ins_cpl [getNextOperand]}	;# 0xC2 :: cpl Baddr

## DA
private method 212	{} {ins_da}	;# 0xD4 :: da A

## DEC
private method 20	{} {ins_dec 224}			;# 0x14 :: dec A
private method 21	{} {ins_dec [getNextOperand]}		;# 0x15 :: dec addr
private method 22	{} {ins_dec_ID $ram([R 0])}		;# 0x16 :: dec @R0
private method 23	{} {ins_dec_ID $ram([R 1])}		;# 0x17 :: dec @R1
private method 24	{} {ins_dec [R 0]}			;# 0x18 :: dec R0
private method 25	{} {ins_dec [R 1]}			;# 0x19 :: dec R1
private method 26	{} {ins_dec [R 2]}			;# 0x1A :: dec R2
private method 27	{} {ins_dec [R 3]}			;# 0x1B :: dec R3
private method 28	{} {ins_dec [R 4]}			;# 0x1C :: dec R4
private method 29	{} {ins_dec [R 5]}			;# 0x1D :: dec R5
private method 30	{} {ins_dec [R 6]}			;# 0x1E :: dec R6
private method 31	{} {ins_dec [R 7]}			;# 0x1F :: dec R7

## DIV
private method 132	{} {ins_div}	;# 0x84 :: div AB

## DJNZ
private method 213	{} {ins_djnz [getNextOperand] [getLastOperand]}	;# 0xD5 :: djnz  addr, Roff
private method 216	{} {ins_djnz [R 0] [getLastOperand]}		;# 0xD8 :: djnz  R0, Roff
private method 217	{} {ins_djnz [R 1] [getLastOperand]}		;# 0xD9 :: djnz  R1, Roff
private method 218	{} {ins_djnz [R 2] [getLastOperand]}		;# 0xDA :: djnz  R2, Roff
private method 219	{} {ins_djnz [R 3] [getLastOperand]}		;# 0xDB :: djnz  R3, Roff
private method 220	{} {ins_djnz [R 4] [getLastOperand]}		;# 0xDC :: djnz  R4, Roff
private method 221	{} {ins_djnz [R 5] [getLastOperand]}		;# 0xDD :: djnz  R5, Roff
private method 222	{} {ins_djnz [R 6] [getLastOperand]}		;# 0xDE :: djnz  R6, Roff
private method 223	{} {ins_djnz [R 7] [getLastOperand]}		;# 0xDF :: djnz  R7, Roff

## INC
private method 4	{} {ins_inc 224}		;# 0x04 :: inc A
private method 5	{} {ins_inc [getNextOperand]}	;# 0x05 :: inc addr
private method 6	{} {ins_inc_ID $ram([R 0])}	;# 0x06 :: inc @R0
private method 7	{} {ins_inc_ID $ram([R 1])}	;# 0x07 :: inc @R1
private method 8	{} {ins_inc [R 0]}		;# 0x08 :: inc R0
private method 9	{} {ins_inc [R 1]}		;# 0x09 :: inc R1
private method 10	{} {ins_inc [R 2]}		;# 0x0A :: inc R2
private method 11	{} {ins_inc [R 3]}		;# 0x0B :: inc R3
private method 12	{} {ins_inc [R 4]}		;# 0x0C :: inc R4
private method 13	{} {ins_inc [R 5]}		;# 0x0D :: inc R5
private method 14	{} {ins_inc [R 6]}		;# 0x0E :: inc R6
private method 15	{} {ins_inc [R 7]}		;# 0x0F :: inc R7
private method 163	{} {ins_inc_DPTR}		;# 0xA3 :: inc DPTR

## JB
private method 32	{} {ins_jb [getNextOperand] [getLastOperand]}	;# 0x20 :: jb  Baddr, Roff

## JNB
private method 48	{} {ins_jnb [getNextOperand] [getLastOperand]}	;# 0x30 :: jnb  Baddr, Roff

## JBC
private method 16	{} {ins_jbc [getNextOperand] [getLastOperand]}	;# 0x10 :: jbc  Baddr, Roff

## JC
private method 64	{} {ins_jc [getLastOperand]}	;# 0x40 :: jc Roff

## JNC
private method 80	{} {ins_jnc [getLastOperand]}	;# 0x50 :: jnc Roff

## JZ
private method 96	{} {ins_jz [getLastOperand]}	;# 0x60 :: jz Roff

## JNZ
private method 112	{} {ins_jnz [getLastOperand]}	;# 0x70 :: jnz Roof

## JMP
private method 115	{} {ins_jmp}			;# 0x79 :: jmp @A+DPTR

## LCALL
private method 18	{} {ins_lcall [getNextOperand] [getLastOperand]}	;# 0x12 :: lcall Paddr16

## LJMP
private method 2	{} {ins_ljmp [getNextOperand] [getNextOperand]}		;# 0x02 :: ljmp Paddr16

## MOV
private method 116	{} {ins_mov 224 [getNextOperand]}		;# 0x74 :: mov  A, #imm8
private method 229	{} {ins_mov_D [getNextOperand] 224}		;# 0xE5 :: mov  A, addr
private method 230	{} {ins_mov_ID1 224 $ram([R 0])}		;# 0xE6 :: mov  A, @R0
private method 231	{} {ins_mov_ID1 224 $ram([R 1])}		;# 0xE7 :: mov  A, @R1
private method 232	{} {ins_mov 224 $ram([R 0])}			;# 0xE8 :: mov  A, R0
private method 233	{} {ins_mov 224 $ram([R 1])}			;# 0xE9 :: mov  A, R1
private method 234	{} {ins_mov 224 $ram([R 2])}			;# 0xEA :: mov  A, R2
private method 235	{} {ins_mov 224 $ram([R 3])}			;# 0xEB :: mov  A, R3
private method 236	{} {ins_mov 224 $ram([R 4])}			;# 0xEC :: mov  A, R4
private method 237	{} {ins_mov 224 $ram([R 5])}			;# 0xED :: mov  A, R5
private method 238	{} {ins_mov 224 $ram([R 6])}			;# 0xEE :: mov  A, R6
private method 239	{} {ins_mov 224 $ram([R 7])}			;# 0xEF :: mov  A, R7
private method 245	{} {ins_mov [getNextOperand] $sfr(224)}		;# 0xF5 :: mov  addr, A
private method 117	{} {						;# 0x75 :: mov  addr, #imm8
	ins_mov [getNextOperand] [getNextOperand]
	incr time
}
private method 133	{} {						;# 0x85 :: mov  addr, addr
	ins_mov_D [getNextOperand] [getNextOperand]
	incr time
}
private method 134	{} {						;# 0x86 :: mov  addr, @R0
	ins_mov_ID1 [getNextOperand] $ram([R 0])
	incr time
}
private method 135	{} {						;# 0x87 :: mov  addr, @R1
	ins_mov_ID1 [getNextOperand] $ram([R 1])
	incr time
}
private method 136	{} {						;# 0x88 :: mov  addr, R0
	ins_mov [getNextOperand] $ram([R 0])
	incr time
}
private method 137	{} {						;# 0x89 :: mov  addr, R1
	ins_mov [getNextOperand] $ram([R 1])
	incr time
}
private method 138	{} {						;# 0x8A :: mov  addr, R2
	ins_mov [getNextOperand] $ram([R 2])
	incr time
}
private method 139	{} {						;# 0x8B :: mov  addr, R3
	ins_mov [getNextOperand] $ram([R 3])
	incr time
}
private method 140	{} {						;# 0x8C :: mov  addr, R4
	ins_mov [getNextOperand] $ram([R 4])
	incr time
}
private method 141	{} {						;# 0x8D :: mov  addr, R5
	ins_mov [getNextOperand] $ram([R 5])
	incr time
}
private method 142	{} {						;# 0x8E :: mov  addr, R6
	ins_mov [getNextOperand] $ram([R 6])
	incr time
}
private method 143	{} {						;# 0x8F :: mov  addr, R7
	ins_mov [getNextOperand] $ram([R 7])
	incr time
}
private method 246	{} {ins_mov_ID0 $ram([R 0]) $sfr(224)}		;# 0xF6 :: mov  @R0, A
private method 247	{} {ins_mov_ID0 $ram([R 1]) $sfr(224)}		;# 0xF7 :: mov  @R1, A
private method 118	{} {ins_mov_ID0 $ram([R 0]) [getNextOperand]}	;# 0x76 :: mov  @R0, #imm8
private method 119	{} {ins_mov_ID0 $ram([R 1]) [getNextOperand]}	;# 0x77 :: mov  @R1, #imm8
private method 166	{} {ins_mov_ID2 $ram([R 0]) [getNextOperand]}	;# 0xA6 :: mov  @R0, addr
private method 167	{} {ins_mov_ID2 $ram([R 1]) [getNextOperand]}	;# 0xA7 :: mov  @R1, addr
private method 248	{} {ins_mov [R 0] $sfr(224)}			;# 0xF8 :: mov  R0, A
private method 249	{} {ins_mov [R 1] $sfr(224)}			;# 0xF9 :: mov  R1, A
private method 250	{} {ins_mov [R 2] $sfr(224)}			;# 0xFA :: mov  R2, A
private method 251	{} {ins_mov [R 3] $sfr(224)}			;# 0xFB :: mov  R3, A
private method 252	{} {ins_mov [R 4] $sfr(224)}			;# 0xFC :: mov  R4, A
private method 253	{} {ins_mov [R 5] $sfr(224)}			;# 0xFD :: mov  R5, A
private method 254	{} {ins_mov [R 6] $sfr(224)}			;# 0xFE :: mov  R6, A
private method 255	{} {ins_mov [R 7] $sfr(224)}			;# 0xFF :: mov  R7, A
private method 120	{} {ins_mov [R 0] [getNextOperand]}		;# 0x78 :: mov  R0, #imm8
private method 121	{} {ins_mov [R 1] [getNextOperand]}		;# 0x79 :: mov  R1, #imm8
private method 122	{} {ins_mov [R 2] [getNextOperand]}		;# 0x7A :: mov  R2, #imm8
private method 123	{} {ins_mov [R 3] [getNextOperand]}		;# 0x7B :: mov  R3, #imm8
private method 124	{} {ins_mov [R 4] [getNextOperand]}		;# 0x7C :: mov  R4, #imm8
private method 125	{} {ins_mov [R 5] [getNextOperand]}		;# 0x7D :: mov  R5, #imm8
private method 126	{} {ins_mov [R 6] [getNextOperand]}		;# 0x7E :: mov  R6, #imm8
private method 127	{} {ins_mov [R 7] [getNextOperand]}		;# 0x7F :: mov  R7, #imm8
private method 168	{} {ins_mov_Rx_ADDR 0 [getLastOperand]}		;# 0xA8 :: mov  R0, addr
private method 169	{} {ins_mov_Rx_ADDR 1 [getLastOperand]}		;# 0xA9 :: mov  R1, addr
private method 170	{} {ins_mov_Rx_ADDR 2 [getLastOperand]}		;# 0xAA :: mov  R2, addr
private method 171	{} {ins_mov_Rx_ADDR 3 [getLastOperand]}		;# 0xAB :: mov  R3, addr
private method 172	{} {ins_mov_Rx_ADDR 4 [getLastOperand]}		;# 0xAC :: mov  R4, addr
private method 173	{} {ins_mov_Rx_ADDR 5 [getLastOperand]}		;# 0xAD :: mov  R5, addr
private method 174	{} {ins_mov_Rx_ADDR 6 [getLastOperand]}		;# 0xAE :: mov  R6, addr
private method 175	{} {ins_mov_Rx_ADDR 7 [getLastOperand]}		;# 0xAF :: mov  R7, addr
private method 144	{} {ins_mov_DPTR [getNextOperand] [getLastOperand]}	;# 0x90 :: mov  DPTR, #imm16
private method 146	{} {ins_mov_bit [getLastOperand] {C}}		;# 0x92 :: mov  Baddr, C
private method 162	{} {ins_mov_bit {C} [getLastOperand]}		;# 0xA2 :: mov  C, Baddr

## MOVC
private method 147	{} {ins_movc {DPTR}}		;# 0x93 :: movc  A, @A+DPTR
private method 131	{} {ins_movc {PC}}		;# 0x93 :: movc  A, @A+PC

## MOVX
private method 226	{} {ins_movx {A} {R0}	}	;# 0xE2 :: movx  A, @R0
private method 227	{} {ins_movx {A} {R1}	}	;# 0xE3 :: movx  A, @R1
private method 224	{} {ins_movx {A} {DPTR}	}	;# 0xE0 :: movx  A, @DPTR
private method 242	{} {ins_movx {R0} {A}	}	;# 0xF2 :: movx  @R0, A
private method 243	{} {ins_movx {R1} {A}	}	;# 0xF3 :: movx  @R1, A
private method 240	{} {ins_movx {DPTR} {A}	}	;# 0xF0 :: movx  @DPTR, A

# MUL
private method 164	{} {ins_mul}			;# 0xA4 :: mul AB

## NOP
private method 0	{} {ins_nop}			;# 0x00 :: nop

## ORL
private method 66	{} {ins_orl [getNextOperand] $sfr(224)}	;# 0x42 :: orl  addr, A
private method 67	{} {ins_orl [getNextOperand] [getNextOperand]; incr time}	;# 0x43 :: orl  addr, #imm8
private method 68	{} {ins_orl 224 [getNextOperand]}	;# 0x44 :: orl  A, #imm8
private method 69	{} {ins_orl_D 224 [getNextOperand]}	;# 0x45 :: orl  A, addr
private method 70	{} {ins_orl_ID 224 $ram([R 0])}		;# 0x46 :: orl  A, @R0
private method 71	{} {ins_orl_ID 224 $ram([R 1])}		;# 0x47 :: orl  A, @R1
private method 72	{} {ins_orl 224 $ram([R 0])}		;# 0x48 :: orl  A, R0
private method 73	{} {ins_orl 224 $ram([R 1])}		;# 0x49 :: orl  A, R1
private method 74	{} {ins_orl 224 $ram([R 2])}		;# 0x4A :: orl  A, R2
private method 75	{} {ins_orl 224 $ram([R 3])}		;# 0x4B :: orl  A, R3
private method 76	{} {ins_orl 224 $ram([R 4])}		;# 0x4C :: orl  A, R4
private method 77	{} {ins_orl 224 $ram([R 5])}		;# 0x4D :: orl  A, R5
private method 78	{} {ins_orl 224 $ram([R 6])}		;# 0x4E :: orl  A, R6
private method 79	{} {ins_orl 224 $ram([R 7])}		;# 0x4F :: orl  A, R7
private method 114	{} {ins_orl_bit [getLastOperand]}	;# 0x72 :: orl  C, Baddr
private method 160	{} {ins_orl_not_bit [getLastOperand]}	;# 0xA0 :: orl  C, /Baddr

## POP
private method 208	{} {ins_pop [getLastOperand]}	;# 0xD0 :: pop addr

## PUSH
private method 192	{} {ins_push [getLastOperand]}	;# 0xC0 :: push addr

## RET
private method 34	{} {ins_ret}			;# 0x22 :: ret

## RETI
private method 50	{} {ins_reti}			;# 0x32 :: reti

## RL
private method 35	{} {ins_rl}			;# 0x23 :: rl A

## RR
private method 3	{} {ins_rr}			;# 0x03 :: rr A

## RLC
private method 51	{} {ins_rlc}			;# 0x33 :: rlc A

## RRC
private method 19	{} {ins_rrc}			;# 0x13 :: rrc A

## SETB
private method 211	{} {ins_setb {C}}		;# 0xD3 :: setb C
private method 210	{} {ins_setb [getNextOperand]}	;# 0xD2 :: setb Baddr

## SJMP
private method 128	{} {ins_sjmp [getLastOperand]}	;# 0x80 :: sjmp Roff

## SUBB
private method 148	{} {ins_subb [getNextOperand]}		;# 0x94 :: subb  A, #imm8
private method 149	{} {ins_subb_D [getNextOperand]}	;# 0x95 :: subb  A, addr
private method 150	{} {ins_subb_ID $ram([R 0])}		;# 0x96 :: subb  A, @R0
private method 151	{} {ins_subb_ID $ram([R 1])}		;# 0x97 :: subb  A, @R1
private method 152	{} {ins_subb $ram([R 0])}		;# 0x98 :: subb  A, R0
private method 153	{} {ins_subb $ram([R 1])}		;# 0x99 :: subb  A, R1
private method 154	{} {ins_subb $ram([R 2])}		;# 0x9A :: subb  A, R2
private method 155	{} {ins_subb $ram([R 3])}		;# 0x9B :: subb  A, R3
private method 156	{} {ins_subb $ram([R 4])}		;# 0x9C :: subb  A, R4
private method 157	{} {ins_subb $ram([R 5])}		;# 0x9D :: subb  A, R5
private method 158	{} {ins_subb $ram([R 6])}		;# 0x9E :: subb  A, R6
private method 159	{} {ins_subb $ram([R 7])}		;# 0x9F :: subb  A, R7

## SWAP
private method 196	{} {ins_swap}			;# 0xC4 :: swap A

## XCH
private method 197	{} {ins_xch [getNextOperand]}	;# 0xC5 :: xch  A, addr
private method 198	{} {ins_xch_ID $ram([R 0])}	;# 0xC6 :: xch  A, @R0
private method 199	{} {ins_xch_ID $ram([R 1])}	;# 0xC7 :: xch  A, @R1
private method 200	{} {ins_xch [R 0]}		;# 0xC8 :: xch  A, R0
private method 201	{} {ins_xch [R 1]}		;# 0xC9 :: xch  A, R1
private method 202	{} {ins_xch [R 2]}		;# 0xCA :: xch  A, R2
private method 203	{} {ins_xch [R 3]}		;# 0xCB :: xch  A, R3
private method 204	{} {ins_xch [R 4]}		;# 0xCC :: xch  A, R4
private method 205	{} {ins_xch [R 5]}		;# 0xCD :: xch  A, R5
private method 206	{} {ins_xch [R 6]}		;# 0xCE :: xch  A, R6
private method 207	{} {ins_xch [R 7]}		;# 0xCF :: xch  A, R7

## XCHD
private method 214	{} {ins_xchd $ram([R 0])}	;# 0xD6 :: xchd  A, @R0
private method 215	{} {ins_xchd $ram([R 1])}	;# 0xD6 :: xchd  A, @R1

## XRL
private method 98	{} {ins_xrl [getNextOperand] $sfr(224)}		;# 0x62 :: xrl  addr, A
private method 99	{} {ins_xrl [getNextOperand] [getNextOperand];incr time};# 0x63 :: xrl  addr, #imm8
private method 100	{} {ins_xrl 224 [getNextOperand]}		;# 0x64 :: xrl  A, #imm8
private method 101	{} {ins_xrl_D 224 [getNextOperand]}		;# 0x64 :: xrl  A, addr
private method 102	{} {ins_xrl_ID 224 $ram([R 0])}			;# 0x66 :: xrl  A, @R1
private method 103	{} {ins_xrl_ID 224 $ram([R 1])}			;# 0x67 :: xrl  A, @R1
private method 104	{} {ins_xrl 224 $ram([R 0])}			;# 0x68 :: xrl  A, R0
private method 105	{} {ins_xrl 224 $ram([R 1])}			;# 0x69 :: xrl  A, R1
private method 106	{} {ins_xrl 224 $ram([R 2])}			;# 0x6A :: xrl  A, R2
private method 107	{} {ins_xrl 224 $ram([R 3])}			;# 0x6B :: xrl  A, R3
private method 108	{} {ins_xrl 224 $ram([R 4])}			;# 0x6C :: xrl  A, R4
private method 109	{} {ins_xrl 224 $ram([R 5])}			;# 0x6D :: xrl  A, R5
private method 110	{} {ins_xrl 224 $ram([R 6])}			;# 0x6E :: xrl  A, R6
private method 111	{} {ins_xrl 224 $ram([R 7])}			;# 0x6F :: xrl  A, R7

# >>> File inclusion guard
}
# <<< File inclusion guard
