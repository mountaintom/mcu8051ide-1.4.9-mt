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
if { ! [ info exists _INSTRUCTIONDETAILS_TCL ] } {
set _INSTRUCTIONDETAILS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements tab "Instruction details" on the Right Panel
# --------------------------------------------------------------------------

class InstructionDetails {

	## COMMON
	 # Conter of instances
	public common instd_count		0
	 # Font for instruction details
	public common instruction_font	[font create			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-family $::DEFAULT_FIXED_FONT			\
	]
	 ## Highlighting tags for instruction details
	  # {
	  #	{tag_name foreground_color ?bold_or_italic?}
	  #	...
	  # }
	public common instruction_tags {
		{tag_code8	#00AA00	0}
		{tag_code11	#00AA33	0}
		{tag_code16	#00AA55	0}
		{tag_imm8	#FF0000	0}
		{tag_imm16	#FF0055	0}
		{tag_data	#88DD00	0}
		{tag_bit	#555588	0}
		{tag_DPTR	#0000FF	1}
		{tag_A		#3300DD	1}
		{tag_AB		#8800FF	1}
		{tag_SFR	#0000FF	1}
		{tag_indr	#FF0000	1}
		{tag_1		#00DD00}
		{tag_2		#AAAA00}
		{tag_3		#FF0000}
		{tag_4		#8800FF}
		{tag_5		#0000FF}
	}

	## Detail description of each directive
	 # Format: {
	 # 	{directive} {description}
	 # 	{directive} {description}
	 # 	{directive} {description}
	 # 	    .		 .
	 # 	    .		 .
	 # 	    .		 .
	 # }
	public common HELP_FOR_DIRECTIVES {}
	public common HELP_FOR_DIRECTIVES_RAW {
		elseif		{Conditional assembly\n\nSyntax:\n  ELSEIF <expr>\n\nExample:\n  IF(2 * 4 - CND)\n    MOV  A, #20h\n  ELSEIF SOMETHING_ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		ifn		{IF Not, conditional assembly\n\nSyntax:\n  IFN <expr>\n\nExample:\n  IF(2 * 4 - CND)\n    MOV  A, #20h\n  ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		elseifn		{ELSE IF Not\n\nSyntax:\n  ELSEIFN <expr>\n\nExample:\n  IF(2 * 4 - CND)\n    MOV  A, #20h\n  ELSEIFN SOMETHING_ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		ifdef		{IF DEFined\n\nSyntax:\n  IFDEF <symbol>\n\nExample:\n  IFDEF CND\n    MOV  A, #20h\n  ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		elseifdef	{ELSE IF DEFined\n\nSyntax:\n  ELSEIFDEF <symbol>\n\nExample:\n  IFDEF(2 * 4 - CND)\n    MOV  A, #20h\n  ELSEIFDEF SOMETHING_ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		ifndef		{IF Not DEFined\n\nSyntax:\n  IFNDEF <symbol>\n\nExample:\n  IFNDEF CND\n    MOV  A, #20h\n  ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		elseifndef	{ELSE IF Not DEFined\n\nSyntax:\n  ELSEIFNDEF <symbol>\n\nExample:\n  IFDEF CND\n    MOV  A, #20h\n  ELSEIFNDEF SOMETHING_ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		ifb		{IF Black\n\nSyntax:\n  IFB <literal>\n\nExample:\n  IFB <CND>\n    MOV  A, #20h\n  ELSE\n    MOV  A, #40h\n  ENDIF\n\nNote:\n  Supported by ASEM-51 only}
		elseifb		{ELSE IF Black\n\nSyntax:\n  ELSEIFB <literal>\n\nExample:\n  IFB <CND>\n    MOV  A, #20h\n  ELSEIFB <SOMETHING_ELSE>\n    MOV  A, #40h\n  ENDIF\n\literal:\n  Supported by ASEM-51 only}
		ifnb		{IF Not Black\n\nSyntax:\n  IFNB <literal>\n\nExample:\n  IFNB <CND>\n    MOV  A, #20h\n  ELSE\n    MOV  A, #40h\n  ENDIF\n\nNote:\n  Supported by ASEM-51 only}
		elseifnb	{ELSE IF Not Black\n\nSyntax:\n  ELSEIFNB <literal>\n\nExample:\n  IFB <CND>\n    MOV  A, #20h\n  ELSEIFNB <SOMETHING_ELSE>\n    MOV  A, #40h\n  ENDIF\n\nNote:\n  Supported by ASEM-51 only}
		rept		{REPeaT Macro\n\nSyntax:\n  REPT <expr>\n\nExample:\n  REPT 5\n    NOP\n  ENDM\n\n}
		times		{REPeaT Macro\n\nSyntax:\n  TIMES <expr>\n\nExample:\n  TIMES 5\n    NOP\n  ENDM\n\nNote:\n  Supported by native assembler only}
		name		{define module NAME\n\nSyntax:\n  NAME <name>\n\nExample:\n  NAME my_2nd_program\n\nNote:\n  Supported by ASEM-51 only}
		if	{Conditional assembly\n\nSyntax:\n  IF <expr>\n\nExample:\n  IF(2 * 4 - CND)\n    MOV  A, #20h\n  ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		else	{Conditional assembly\n\nSyntax:\n  ELSE\n\nExample:\n  IF(2 * 4 - CND)\n    MOV  A, #20h\n  ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		endif	{Conditional assembly\n\nSyntax:\n  ENDIF\n\nExample:\n  IF(2 * 4 - CND)\n    MOV  A, #20h\n  ELSE\n    MOV  A, #40h\n  ENDIF\n\n}
		endm	{END of Macro definition\n\nSyntax:\n  ENDM\n\nExample:\n  ABC MACRO\n      MOV B, #12d\n  ENDM\n\n}
		end	{END of the program\n\nSyntax:\n  END\n\nExample:\n  END\n\n}
		exitm	{premature end of macro expansion\n\nSyntax:\n  EXITM\n\nExample:\n  ABC MACRO\n      MOV B, #12d\n  EXITM\n      NOP\n  ENDM\n\n}
		list	{enable code LISTing\n\nSyntax:\n  LIST\n\nExample:\n  NOP\n  NOLIST\n  NOP\n  NOP\n  LIST\n  NOP\n\n}
		nolist	{disabled code listing\n\nSyntax:\n  NOLIST\n\nExample:\n  NOP\n  NOLIST\n  NOP\n  NOP\n  LIST\n  NOP\n\n}
		dseg	{switch to DATA segment \[at address\]\n\nSyntax:\n  DSEG \[AT <expr>\]\n\nExample:\n  DSEG at 20d\n\n}
		iseg	{switch to IDATA segment \[at address\]\n\nSyntax:\n  ISEG \[AT <expr>\]\n\nExample:\n  ISEG at 10d\n\n}
		bseg	{switch to BIT segment \[at address\]\n\nSyntax:\n  BSEG \[AT <expr>\]\n\nExample:\n  BSEG at 5d\n\n}
		xseg	{switch to XDATA segment \[at address\]\n\nSyntax:\n  XSEG \[AT <expr>\]\n\nExample:\n  XSEG at 30d\n\n}
		cseg	{switch to CODE segment \[at address\]\n\nSyntax:\n  CSEG \[AT <expr>\]\n\nExample:\n  CSEG at 40d\n\n}
		local	{define a local label inside a macro\n\nSyntax:\n  LOCAL <symbol>\n\nExample:\n  ABC MACRO\n        LOCAL xyz\n  xyz:  MOV B, #12d\n  EXITM\n        NOP\n  ENDM\n\n}
		flag	{define a FLAG bit\n\nSyntax:\n  <symbol> FLAG  <expr>\n\nExample:\n  F4  FLAG  16h\n\nNote:\n  Deprecated directive. Consider directive BIT instead.}
		skip	{SKIP bytes in the code memory\n\nSyntax:\n  SKIP  <expr>\n\nExample:\n  SKIP 5\n\n}
		equ	{EQUivalent\n\nSyntax:\n  <symbol> EQU <expr>\n\nExample:\n  ABC  EQU  R0\n  XYZ  EQU  4Eh+12\n\n}
		bit	{define BIT address\n\nSyntax:\n  <symbol> BIT <expr>\n\nExample:\n  ABC  BIT  P4.5\n\n}
		set	{SET numeric variable or variable register\n\nSyntax:\n  <symbol> SET <expr>\n  <symbol> SET <register>\n\nExample:\n  ALPHA  SET  R0\n  ALPHA  SET  42*BETA\n\n}
		code	{define address in the CODE memory\n\nSyntax:\n  <symbol> CODE <expr>\n\nExample:\n  TBL  CODE  600h\n\n}
		data	{define address in the DATA memory\n\nSyntax:\n  <symbol> DATA <expr>\n\nExample:\n  UIV  DATA  20h\n\n}
		idata	{define address in the Internal DATA memory\n\nSyntax:\n  <symbol> IDATA <expr>\n\nExample:\n  UIV  IDATA  20h\n\n}
		xdata	{define address in the External DATA memory\n\nSyntax:\n  <symbol> XDATA <expr>\n\nExample:\n  UIV  XDATA  400h\n\n}
		macro	{MACRO definition\n\nSyntax:\n  <macro> MACRO \[<arg0> \[,<arg1> ... \]\n\n\nExample:\n  ABC MACRO X\n      MOV X, #12d\n  ENDM\n\n}
		ds	{Define Space\n\nSyntax:\n  DS <expr>\n\nExample:\n  DS 2+4\n\n}
		dw	{Define Words\n\nSyntax:\n  DW <expr1> \[,<expr2> ... \]\n\nExample:\n  DW 0,02009H,2009,4171\n\n}
		db	{Define Bytes\n\nSyntax:\n  DB <expr1> \[,<expr2> ... \]\n\nExample:\n  DB 24,'August',09,(2*8+24)/8\n\n}
		dbit	{Define BITs\n\nSyntax:\n  DBIT <expr>\n\nExample:\n  DBIT 4+2\n\n}
		include	{INCLUDE an external source code\n\nSyntax:\n  INCLUDE <filename>\n\nExample:\n  INCLUDE 'my file.asm'\n\n}
		org	{ORiGin of code segment location\n\nSyntax:\n  ORG <expr>\n\nExample:\n  ORG 0Bh\n\n}
		using	{USING register banks\n\nSyntax:\n  USING <expr>\n\nExample:\n  USING 2\n\n}
		byte	{define BYTE address in the data memory\n\nSyntax:\n  <symbol> BYTE <expr>\n\nExample:\n  UIV  BYTE  20h\n\nNote:\n  Deprecated directive. Consider directive DATA instead.}

		{$cond}		{List full IFxx .. ENDIF\n\nSyntax:\n  \$COND\n\nExample:\n  \$COND\n\nNote:\n  Supported by ASEM-51 only}
		{$nocond}	{Don't list lines in false branches\n\nSyntax:\n  \$NOCOND\n\nExample:\n  \$NOCOND\n\nNote:\n  Supported by ASEM-51 only}
		{$condonly}	{List assembled lines only\n\nSyntax:\n  \$CONDONLY\n\nExample:\n  \$CONDONLY\n\nNote:\n  Supported by ASEM-51 only}
		{$date}		{Inserts date string into page header\n\nSyntax:\n  \$DATE(string)\n\nExample:\n  \$DATE(1965-12-31)\n\n}
		{$da}		{Inserts date string into page header\n\nSyntax:\n  \$DATE(string)\n\nExample:\n  \$DATE(1965-12-31)\n\n}
		{$debug}	{Include debug information\n\nSyntax:\n  \$DEBUG\n\nExample:\n  \$DEBUG\n\nNote:\n  Supported by ASEM-51 only}
		{$db}		{Include debug information\n\nSyntax:\n  \$DB\n\nExample:\n  \$DB\n\nNote:\n  Supported by ASEM-51 only}
		{$nodebug}	{Don't include debug information\n\nSyntax:\n  \$NODEBUG\n\nExample:\n  \$NODEBUG\n\nNote:\n  Supported by ASEM-51 only}
		{$nodb}		{Don't include debug information\n\nSyntax:\n  \$NODB\n\nExample:\n  \$NODB\n\nNote:\n  Supported by ASEM-51 only}
		{$eject}	{Start a new page in list file\n\nSyntax:\n  \$EJECT\n\nExample:\n  \$EJECT\n\n}
		{$ej}		{Start a new page in list file\n\nSyntax:\n  \$EJ\n\nExample:\n  \$EJ\n\n}
		{$error}	{Force a user-defined error\n\nSyntax:\n  \$ERROR(string)\n\nExample:\n  \$ERROR(Impossible combination ...)\n\nNote:\n  Supported by ASEM-51 only}
		{$warning}	{Force a user-defined warning\n\nSyntax:\n  \$WARNING(string)\n\nExample:\n  \$WARNING(Testing only !)\n\nNote:\n  Supported by ASEM-51 only}
		{$ge}		{List macro calls and expansion lines\n\nSyntax:\n  \$GE\n\nExample:\n  \$GE\n\nNote:\n  Supported by ASEM-51 only}
		{$gen}		{List macro calls and expansion lines\n\nSyntax:\n  \$GEN\n\nExample:\n  \$GEN\n\nNote:\n  Supported by ASEM-51 only}
		{$noge}		{List macro calls only\n\nSyntax:\n  \$NOGE\n\nExample:\n  \$NOGE\n\nNote:\n  Supported by ASEM-51 only}
		{$nogen}	{List macro calls only\n\nSyntax:\n  \$NOGEN\n\nExample:\n  \$NOGEN\n\nNote:\n  Supported by ASEM-51 only}
		{$go}		{List expansion lines only\n\nSyntax:\n  \$GO\n\nExample:\n  \$GO\n\nNote:\n  Supported by ASEM-51 only}
		{$genonly}	{List expansion lines only\n\nSyntax:\n  \$GENONLY\n\nExample:\n  \$GENONLY\n\nNote:\n  Supported by ASEM-51 only}
		{$include}	{Include a source file\n\nSyntax:\n  \$INCLUDE(string)\n\nExample:\n  \$INCLUDE(somefile.asm)\n\n}
		{$inc}		{Include a source file\n\nSyntax:\n  \$INC(string)\n\nExample:\n  \$INC(somefile.asm)\n\n}
		{$list}		{List subsequent source lines\n\nSyntax:\n  \$LIST\n\nExample:\n  \$LIST\n\n}
		{$li}		{List subsequent source lines\n\nSyntax:\n  \$LI\n\nExample:\n  \$LI\n\n}
		{$noli}		{Don't list subsequent source lines\n\nSyntax:\n  \$NOLI\n\nExample:\n  \$NOLI\n\n}
		{$nolist}	{Don't list subsequent source lines\n\nSyntax:\n  \$NOLIST\n\nExample:\n  \$NOLIST\n\n}
		{$macro}	{Reserve n % of free memory for macros\n\nSyntax:\n  \$MACRO(int)\n\nExample:\n  \$MACRO(50)\n\nNote:\n  Supported by ASEM-51 only}
		{$mr}		{Reserve n % of free memory for macros\n\nSyntax:\n  \$MR(int)\n\nExample:\n  \$MR(50)\n\nNote:\n  Supported by ASEM-51 only}
		{$nomr}		{Reserve all for the symbol table\n\nSyntax:\n  \$NOMR\n\nExample:\n  \$NOMR\n\nNote:\n  Supported by ASEM-51 only}
		{$nomacro}	{Reserve all for the symbol table\n\nSyntax:\n  \$NOMACRO\n\nExample:\n  \$NOMACRO\n\nNote:\n  Supported by ASEM-51 only}
		{$mod51}	{Enable predefined SFR symbols\n\nSyntax:\n  \$MOD51\n\nExample:\n  \$MOD51\n\nNote:\n  Supported by ASEM-51 only}
		{$mo}		{Enable predefined SFR symbols\n\nSyntax:\n  \$MO\n\nExample:\n  \$MO\n\nNote:\n  Supported by ASEM-51 only}
		{$nomod}	{Disable predefined SFR symbols\n\nSyntax:\n  \$NOMOD\n\nExample:\n  \$NOMOD\n\n}
		{$nomo}		{Disable predefined SFR symbols\n\nSyntax:\n  \$NOMO\n\nExample:\n  \$NOMO\n\n}
		{$nomod51}	{Disable predefined SFR symbols\n\nSyntax:\n  \$NOMOD51\n\nExample:\n  \$NOMOD51\n\n}
		{$nobuiltin}	{Don't list predefined symbols\n\nSyntax:\n  \$NOBUILTIN\n\nExample:\n  \$NOBUILTIN\n\nNote:\n  Supported by ASEM-51 only}
		{$notabs}	{Don't use tabs in list file\n\nSyntax:\n  \$NOTABS\n\nExample:\n  \$NOTABS\n\nNote:\n  Supported by ASEM-51 only}
		{$paging}	{Enable listing page formatting\n\nSyntax:\n  \$LIST\n\nExample:\n  \$PAGING\n\n}
		{$pi}		{Enable listing page formatting\n\nSyntax:\n  \$PI\n\nExample:\n  \$PI\n\n}
		{$nopi}		{Disable listing page formatting\n\nSyntax:\n  \$NOPI\n\nExample:\n  \$NOPI\n\n}
		{$nopaging}	{Disable listing page formatting\n\nSyntax:\n  \$NOPAGING\n\nExample:\n  \$NOPAGING\n\n}
		{$pagelength}	{Set lines per page for listing\n\nSyntax:\n  \$PAGELENGTH(int)\n\nExample:\n  \$PAGELENGTH(64)\n\n}
		{$pl}		{Set lines per page for listing\n\nSyntax:\n  \$PL(int)\n\nExample:\n  \$PL(64)\n\n}
		{$pagewidth}	{Set columns per line for listing\n\nSyntax:\n  \$PAGEWIDTH(int)\n\nExample:\n  \$PAGEWIDTH(132)\n\n}
		{$pw}		{Set columns per line for listing\n\nSyntax:\n  \$PW(int)\n\nExample:\n  \$PW(132)\n\n}
		{$philips}	{Switch on 83C75x family support\n\nSyntax:\n  \$PHILIPS\n\nExample:\n  \$PHILIPS\n\nNote:\n  Supported by ASEM-51 only}
		{$save}		{Save current \$LIST/\$GEN/\$COND\n\nSyntax:\n  \$SAVE\n\nExample:\n  \$SAVE\n\nNote:\n  Supported by ASEM-51 only}
		{$sa}		{Save current \$LIST/\$GEN/\$COND\n\nSyntax:\n  \$SA\n\nExample:\n  \$SA\n\nNote:\n  Supported by ASEM-51 only}
		{$restore}	{Restore old \$LIST/\$GEN/\$COND\n\nSyntax:\n  \$RESTORE\n\nExample:\n  \$RESTORE\n\nNote:\n  Supported by ASEM-51 only}
		{$rs}		{Restore old \$LIST/\$GEN/\$COND\n\nSyntax:\n  \$RS\n\nExample:\n  \$RS\n\nNote:\n  Supported by ASEM-51 only}
		{$symbols}	{Create symbol table\n\nSyntax:\n  \$SYMBOLS\n\nExample:\n  \$SYMBOLS\n\n}
		{$sb}		{Create symbol table\n\nSyntax:\n  \$SB\n\nExample:\n  \$SB\n\n}
		{$nosymbols}	{Don't create symbol table\n\nSyntax:\n  \$NOSYMBOLS\n\nExample:\n  \$NOSYMBOLS\n\n}
		{$nosb}		{Don't create symbol table\n\nSyntax:\n  \$NOSB\n\nExample:\n  \$NOSB\n\n}
		{$title}	{Inserts title string into page header\n\nSyntax:\n  \$TITLE(string)\n\nExample:\n  \$TITLE(My firts code)\n\n}
		{$tt}		{Inserts title string into page header\n\nSyntax:\n  \$TT(string)\n\nExample:\n  \$TT(My firts code)\n\n}
		{$xref}		{Create cross reference\n\nSyntax:\n  \$XREF\n\nExample:\n  \$XREF\n\nNote:\n  Supported by ASEM-51 only}
		{$xr}		{Create cross reference\n\nSyntax:\n  \$XR\n\nExample:\n  \$XR\n\nNote:\n  Supported by ASEM-51 only}
		{$noxref}	{Don't create cross reference\n\nSyntax:\n  \$NOXREF\n\nExample:\n  \$NOXREF\n\nNote:\n  Supported by ASEM-51 only}
		{$noxr}		{Don't create cross reference\n\nSyntax:\n  \$NOXR\n\nExample:\n  \$NOXR\n\nNote:\n  Supported by ASEM-51 only}
		{$noobject}	{Do not create Intel HEX file\n\nSyntax:\n  \$NOOBJECT\n\nExample:\n  \$NOOBJECT\n\nNote:\n  Supported by native assembler only}
		{$object}	{Specify file name for Intel HEX\n\nSyntax:\n  \$OBJECT(string)\n\nExample:\n  \$OBJECT(my_hex.hex)\n\nNote:\n  Supported by native assembler only}
		{$print}	{Specify file name for list file\n\nSyntax:\n  \$PRINT(string)\n\nExample:\n  \$PRINT(my_list.lst)\n\nNote:\n  Supported by native assembler only}
		{$noprint}	{Do not create list file at all\n\nSyntax:\n  \$NOPRINT\n\nExample:\n  \$NOPRINT\n\nNote:\n  Supported by native assembler only}
		{$nomacrosfirst} {Define and expand macro instruction after! conditional assembly and definitions of constants\n\nSyntax:\n  \$NOMACROSFIRTS\n\nExample:\n  \$NOMACROSFIRTS\n\nNote:\n  Supported by native assembler only}
	}

	## Detail description of each instruction
	 # Format: {
	 # 	{INSTRUCTION	OPR0, OPR1 ...} {
	 #		{description}
	 #		{class}
	 #		{note}
	 #		{affected flags in order: C OV AC, for instance "{0 X 1}"}
	 #	}
	 # }
	public common INSTRUCTION_DESCRIPTION {
		{ADD	A, Rn} {
			{Add register to Accumulator}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{ADD	A, direct} {
			{Add direct byte to Accumulator}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{ADD	A, @Ri} {
			{Add indirect RAM to Accumulator}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{ADD	A, #data} {
			{Add immediate data to Accumulator}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{ADDC	A, Rn} {
			{Add register to Accumulator with Carry}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{ADDC	A, direct} {
			{Add direct byte to Accumulator with Carry}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{ADDC	A, @Ri} {
			{Add indirect RAM to Accumulator with Carry}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{ADDC	A, #data} {
			{Add immediate data to Acc with Carry}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{SUBB	A, Rn} {
			{Subtract Register from Acc with borrow}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{SUBB	A, direct} {
			{Subtract direct byte from Acc with borrow}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{SUBB	A, @Ri} {
			{Subtract indirect RAM from ACC with borrow}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{SUBB	A, #data} {
			{Subtract immediate data from Acc with borrow}
			{Arithmetic Operations}
			{}
			{X X X}
		}
		{INC	A} {
			{Increment Accumulator}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{INC	Rn} {
			{Increment register}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{INC	direct} {
			{Increment direct byte}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{INC	@Ri} {
			{Increment direct RAM}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{DEC	A} {
			{Decrement Accumulator}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{DEC	Rn} {
			{Decrement Register}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{DEC	direct} {
			{Decrement direct byte}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{DEC	@Ri} {
			{Decrement indirect RAM}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{INC	DPTR} {
			{Increment Data Pointer}
			{Arithmetic Operations}
			{Read-Modify-Write}
			{}
		}
		{MUL	AB} {
			{Multiply A & B}
			{Arithmetic Operations}
			{}
			{0 X {}}
		}
		{DIV	AB} {
			{Divide A by B}
			{Arithmetic Operations}
			{}
			{0 X {}}
		}
		{DA	A} {
			{Decimal Adjust Accumulator}
			{Arithmetic Operations}
			{}
			{X {} {}}
		}


		{ANL	A, Rn} {
			{AND Register to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ANL	A, direct} {
			{AND direct byte to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ANL	A, @Ri} {
			{AND indirect RAM to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ANL	A, #data} {
			{AND immediate data to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ANL	direct, A} {
			{AND Accumulator to direct byte}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ANL	direct, #data} {
			{AND immediate data to direct byte}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ORL	A, Rn} {
			{OR register to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ORL	A, direct} {
			{OR direct byte to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ORL	A, @Ri} {
			{OR indirect RAM to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ORL	A, #data} {
			{OR immediate data to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ORL	direct, A} {
			{OR Accumulator to direct byte}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{ORL	direct, #data} {
			{OR immediate data to direct byte}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{XRL	A, Rn} {
			{Exclusive-OR register to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{XRL	A, direct} {
			{Exclusive-OR direct byte to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{XRL	A, @Ri} {
			{Exclusive-OR indirect RAM to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{XRL	A, #data} {
			{Exclusive-OR immediate data to Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{XRL	direct, A} {
			{Exclusive-OR Accumulator to direct byte}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{XRL	direct, #data} {
			{Exclusive-OR immediate data to direct byte}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{CLR	A} {
			{Clear Accumulator}
			{Logical Operations}
			{}
			{}
		}
		{CPL	A} {
			{Complement Accumulator}
			{Logical Operations}
			{Read-Modify-Write}
			{}
		}
		{RL	A} {
			{Rotate Accumulator Left}
			{Logical Operations}
			{}
			{}
		}
		{RLC	A} {
			{Rotate Accumulator Left through the Carry}
			{Logical Operations}
			{}
			{X {} {}}
		}
		{RR	A} {
			{Rotate Accumulator Right}
			{Logical Operations}
			{}
			{}
		}
		{RRC	A} {
			{Rotate Accumulator Right through the Carry}
			{Logical Operations}
			{}
			{X {} {}}
		}
		{SWAP	A} {
			{Swap nibbles within the Accumulator}
			{Logical Operations}
			{}
			{}
		}



		{MOV	A, Rn} {
			{Move register to Accumulator}
			{Data Transfer}
			{}
			{}
		}
		{MOV	A, direct} {
			{Move direct byte to Accumulator}
			{Data Transfer}
			{}
			{}
		}
		{MOV	A, @Ri} {
			{Move indirect RAM to Accumulator}
			{Data Transfer}
			{}
			{}
		}
		{MOV	A, #data} {
			{Move immediate data to Accumulator}
			{Data Transfer}
			{}
			{}
		}
		{MOV	Rn, A} {
			{Move Accumulator to register}
			{Data Transfer}
			{}
			{}
		}
		{MOV	Rn, direct} {
			{Move direct byte to register}
			{Data Transfer}
			{}
			{}
		}
		{MOV	Rn, #data} {
			{Move immediate data to register}
			{Data Transfer}
			{}
			{}
		}
		{MOV	direct, A} {
			{Move Accumulator to direct byte}
			{Data Transfer}
			{}
			{}
		}
		{MOV	direct, Rn} {
			{Move register to direct byte}
			{Data Transfer}
			{}
			{}
		}
		{MOV	direct, direct} {
			{Move direct byte to direct}
			{Data Transfer}
			{}
			{}
		}
		{MOV	direct, @Ri} {
			{Move indirect RAM to direct byte}
			{Data Transfer}
			{}
			{}
		}
		{MOV	direct, #data} {
			{Move immediate data to direct byte}
			{Data Transfer}
			{}
			{}
		}
		{MOV	@Ri, A} {
			{Move Accumulator to indirect RAM}
			{Data Transfer}
			{}
			{}
		}
		{MOV	@Ri, direct} {
			{Move direct byte to indirect RAM}
			{Data Transfer}
			{}
			{}
		}
		{MOV	@Ri, #data} {
			{Move immediate data to indirect RAM}
			{Data Transfer}
			{}
			{}
		}
		{MOV	DPTR, #data16} {
			{Load Data Pointer with a 16-bit constant}
			{Data Transfer}
			{}
			{}
		}
		{MOVC	A, @A+DPTR} {
			{Move Code byte relative to DPTR to Acc}
			{Data Transfer}
			{}
			{}
		}
		{MOVC	A, @A+PC} {
			{Move Code byte relative to PC to Acc}
			{Data Transfer}
			{}
			{}
		}
		{MOVX	A, @Ri} {
			{Move External RAM (8-bit addr) to Acc}
			{Data Transfer}
			{}
			{}
		}
		{MOVX	A, @DPTR} {
			{Move Exernal RAM (16-bit addr) to Acc}
			{Data Transfer}
			{}
			{}
		}
		{MOVX	@Ri, A} {
			{Move Acc to External RAM (8-bit addr)}
			{Data Transfer}
			{}
			{}
		}
		{MOVX	@DPTR, A} {
			{Move Acc to External RAM (16-bit addr)}
			{Data Transfer}
			{}
			{}
		}
		{PUSH	direct} {
			{Push direct byte onto stack}
			{Data Transfer}
			{}
			{}
		}
		{POP	direct} {
			{Pop direct byte from stack}
			{Data Transfer}
			{}
			{}
		}
		{XCH	A, Rn} {
			{Exchange register with Accumulator}
			{Data Transfer}
			{}
			{}
		}
		{XCH	A, direct} {
			{Exchange direct byte with Accumulator}
			{Data Transfer}
			{}
			{}
		}
		{XCH	A, @Ri} {
			{Exchange indirect RAM with Accumulator}
			{Data Transfer}
			{}
			{}
		}
		{XCHD	A, @Ri} {
			{Exchange low-order Digit indirect RAM with Acc}
			{Data Transfer}
			{}
			{}
		}


		{CLR	C} {
			{Clear Carry}
			{Boolean Variable Manipulation}
			{}
			{0 {} {}}
		}
		{CLR	bit} {
			{Clear direct bit}
			{Boolean Variable Manipulation}
			{Read-Modify-Write}
			{}
		}
		{SETB	C} {
			{Set Carry}
			{Boolean Variable Manipulation}
			{}
			{1 {} {}}
		}
		{SETB	bit} {
			{Set direct bit}
			{Boolean Variable Manipulation}
			{Read-Modify-Write}
			{}
		}
		{CPL	C} {
			{Complement Carry}
			{Boolean Variable Manipulation}
			{Read-Modify-Write}
			{X {} {}}
		}
		{CPL	bit} {
			{Complement direct bit}
			{Boolean Variable Manipulation}
			{Read-Modify-Write}
			{}
		}
		{ANL	C, bit} {
			{AND direct bit to CARRY}
			{Boolean Variable Manipulation}
			{Read-Modify-Write}
			{X {} {}}
		}
		{ANL	C, /bit} {
			{AND complement of direct bit to Carry}
			{Boolean Variable Manipulation}
			{Read-Modify-Write}
			{X {} {}}
		}
		{ORL	C, bit} {
			{OR direct bit to Carry}
			{Boolean Variable Manipulation}
			{}
			{X {} {}}
		}
		{ORL	C, /bit} {
			{OR complement of direct bit to Carry}
			{Boolean Variable Manipulation}
			{}
			{X {} {}}
		}
		{MOV	C, bit} {
			{Move direct bit to Carry}
			{Boolean Variable Manipulation}
			{}
			{X {} {}}
		}
		{MOV	bit, C} {
			{Move Carry to direct bit}
			{Boolean Variable Manipulation}
			{Read-Modify-Write}
			{}
		}
		{JC	rel} {
			{Jump if Carry is set}
			{Boolean Variable Manipulation}
			{}
			{}
		}
		{JNC	rel} {
			{Jump if Carry not set}
			{Boolean Variable Manipulation}
			{}
			{}
		}
		{JB	bit, rel} {
			{Jump if direct Bit is set}
			{Boolean Variable Manipulation}
			{}
			{}
		}
		{JNB	bit, rel} {
			{Jump if direct Bit is Not set}
			{Boolean Variable Manipulation}
			{}
			{}
		}
		{JBC	bit, rel} {
			{Jump if direct Bit is set & clear bit}
			{Boolean Variable Manipulation}
			{Read-Modify-Write}
			{}
		}


		{ACALL	addr11} {
			{Absolute Subroutine Call}
			{Program Branching}
			{}
			{}
		}
		{LCALL	addr16} {
			{Long Subroutine Call}
			{Program Branching}
			{}
			{}
		}
		{RET	} {
			{Return from Subroutine}
			{Program Branching}
			{}
			{}
		}
		{RETI	} {
			{Return from interrupt}
			{Program Branching}
			{}
			{}
		}
		{AJMP	addr11} {
			{Absolute Jump}
			{Program Branching}
			{}
			{}
		}
		{LJMP	addr16} {
			{Long Jump}
			{Program Branching}
			{}
			{}
		}
		{SJMP	rel} {
			{Short Jump (relative addr)}
			{Program Branching}
			{}
			{}
		}
		{JMP	@A+DPTR} {
			{Jump indirect relative to the DPTR}
			{Program Branching}
			{}
			{}
		}
		{JZ	rel} {
			{Jump if Accumulator is Zero}
			{Program Branching}
			{}
			{}
		}
		{JNZ	rel} {
			{Jump if Accumulator is Not Zero}
			{Program Branching}
			{}
			{}
		}
		{CJNE	A, direct, rel} {
			{Compare direct byte to Acc and Jump if Not Equal}
			{Program Branching}
			{}
			{X {} {}}
		}
		{CJNE	A, #data, rel} {
			{Compare immediate to Acc and Jump if Not Equal}
			{Program Branching}
			{}
			{X {} {}}
		}
		{CJNE	Rn, #data, rel} {
			{Compare immediate to register and Jump if Not Equal}
			{Program Branching}
			{}
			{X {} {}}
		}
		{CJNE	@Ri, #data, rel} {
			{Compare immediate to indirect and Jump if Not Equal}
			{Program Branching}
			{}
			{X {} {}}
		}
		{DJNZ	Rn, rel} {
			{Decrement register and Jump if Not Zero}
			{Program Branching}
			{Read-Modify-Write}
			{}
		}
		{DJNZ	direct, rel} {
			{Decrement direct byte and Jump if Not Zero}
			{Program Branching}
			{Read-Modify-Write}
			{}
		}
		{NOP	} {
			{No Operation}
			{Program Branching}
			{}
			{}
		}
	}

	## PRIVATE
	private variable instruction_text	{}	;# Widget: ID of text widget of tab "Instruction details"
	private variable instruction_menu		;# Widget: Popup menu for the text widget
	private variable instruction_label		;# Widget: ID of label above instruction details
	private variable header_text			;# Widget: Text header
	private variable instruction_last	{}	;# String: Last instruction shown in details window
	private variable parent			{}	;# Widget: GUI parent
	private variable instd_gui_initialized	0	;# Bool: GUI initialized
	private variable gui_preparing		0	;# Bool: Prearing panel GUI
	private variable enabled		0	;# Bool: enable procedures which are needless while loading project

	private variable help_win_index		0	;# Int: Index of help window object (just some number)
	private variable ins_help_win_enabled	1	;# Bool: Enable instruction help window
	private variable ins_help_win_created	0	;# Bool: Help window widgets are ready to be mapped by geometry manager
	private variable ins_help_win_visible	0	;# Bool: Flag help window visible
	private variable ins_help_window	{}	;# Widget: Help window itself
	private variable help_win_title			;# Widget: Title label (should contain instruction name and operands)
	 ## Array of Widgets: Labels containing certain information
	  # available keys are: description, length, execution_time, opcode, note and class
	private variable help_win_labels

	constructor {} {
		incr instd_count
	}

	destructor {
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent	- GUI parent widget
	 # @return void
	public method PrepareInstructionDetails {_parent} {
		set parent $_parent
		set instd_gui_initialized 0
	}

	## Create GUI of tab "Instruction details"
	 # @return void
	public method CreateInstructionDetailsGUI {} {
		if {$instd_gui_initialized || $gui_preparing || ${::Editor::editor_to_use}} {return}
		set gui_preparing 1

		# Create frames
		set body_frame [frame $parent.frm_rightPanel_instruction_body]
		set text_frame [frame $body_frame.frm_rightPanel_instruction_txt -bd 1 -relief sunken]
		set header_frame [frame $parent.frm_rightPanel_instruction_header]

		# Button "Show legend"
		set button [ttk::button					\
			$header_frame.but_rightPanel_instruction_legend	\
			-image ::ICONS::16::help			\
			-style Flat.TButton				\
			-command "$this rightPanel_ins_legend"		\
		]
		DynamicHelp::add $header_frame.but_rightPanel_instruction_legend	\
			-text [mc "Show legend"]
		pack $button -side right -fill none -expand 0
		setStatusTip -widget $button -text [mc "Show legend"]

		# Tab header (instruction name)
		set instruction_label [label $header_frame.lbl_rightPanel_instruction_header	\
			-fg {#0000FF}						\
			-anchor w						\
			-padx {20px}						\
			-font [font create					\
				-weight {bold}					\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-family $::DEFAULT_FIXED_FONT			\
			]							\
		]
		pack $instruction_label -side left -fill x -expand 1
		setStatusTip -widget $instruction_label -text [mc "Instruction name"]

		# Create popup menu for instruction text and its header
		set instruction_menu [menu $text_frame.popup_menu -tearoff 0]
		$instruction_menu add command -label "Configure" -compound left	\
			-command {::configDialogues::rightPanel::mkDialog 1}	\
			-underline 0 -image ::ICONS::16::configure

		# Text header
		set header_text [text $text_frame.txt_rightPanel_instruction_hdr	\
			-cursor left_ptr	\
			-font $instruction_font	\
			-bg {#DDDDDD}		\
			-height 1		\
			-bd 0			\
			-exportselection 0	\
			 -wrap none		\
		]
		bind $header_text <ButtonRelease-3>	"tk_popup $instruction_menu %X %Y; break"
		bind $header_text <Key-Menu>		"tk_popup $instruction_menu %X %Y; break"
		bindtags $header_text $header_text

		# Instruction details text
		set instruction_text [text $text_frame.txt_rightPanel_instruction	\
			-yscrollcommand "$body_frame.src_rightPanel_instruction set"	\
			-cursor left_ptr -state disabled -wrap none			\
			-font $instruction_font -bd 0 -exportselection 0		\
		]
		# Create scrollbar
		pack [ttk::scrollbar $body_frame.src_rightPanel_instruction	\
			-orient vertical -command "$instruction_text yview"	\
		] -side right -fill y

		setStatusTip -widget $instruction_text -text [mc "Instruction operands"]
		bind $instruction_text <ButtonRelease-3>	"tk_popup $instruction_menu %X %Y; break"
		bind $instruction_text <Key-Menu>		"tk_popup $instruction_menu %X %Y; break"
		bind $instruction_text <<Selection>>		{false_selection %W}
		bind $instruction_text <Motion>			"$this rightPanel_ins_text_motion %x %y %X %Y"
		bind $instruction_text <Leave>			"+$this rightPanel_ins_hide_ins_help_window"

		$instruction_text delete 1.0 end
		$instruction_text tag configure tag_sel -background #CCCCFF
		$instruction_text tag configure tag_sel0 -background #E0FFE0
		rightPanel_refresh_instruction_highlighting
		$instruction_text tag configure tag_bold -font [font create	\
			-size [expr {int(-12 * $::font_size_factor)}]		\
			-family $::DEFAULT_FIXED_FONT				\
			-weight {bold}						\
		]

		# Pack parts of text frame (Instruction details text, Text header)
		pack $header_text -side top -fill x
		pack $instruction_text -side bottom -fill both -expand 1
		pack $text_frame -side left -fill both -expand 1

		# Pack all remaining frames
		pack $header_frame -side top -fill x
		pack $body_frame -side bottom -fill both -expand 1

		set instd_gui_initialized 1
	}

	## Invoke legend window for "Instruction details"
	 # @return void
	public method rightPanel_ins_legend {} {
		# Destroy legend window
		if {[winfo exists .rightPanel_legend]} {
			grab release .rightPanel_legend
			destroy .rightPanel_legend
			return
		}
		set x [expr {[winfo pointerx .] - 380}]
		set y [winfo pointery .]

		# Create legend window
		set win [toplevel .rightPanel_legend -class {Help} -bg ${::COMMON_BG_COLOR}]
		set frame [frame $win.f -bg {#555555} -bd 0 -padx 1 -pady 1]
		wm overrideredirect $win 1

		# Click to close
		bind $win <Button-1> "grab release $win; destroy $win"

		# Create header "-- click to close --"
		pack [label $frame.lbl_header		\
			-text [mc "-- click to close --"]	\
			-bg {#FFFF55} -font $::smallfont\
			-fg {#000000} -anchor c		\
		] -side top -anchor c -fill x

		# Create text widget
		set text [text $frame.text	\
			-bg {#FFFFCC}		\
			-exportselection 0	\
			-takefocus 0		\
			-cursor left_ptr	\
			-bd 0 -relief flat	\
		]

		pack $frame -fill both -expand 1

		# Create text tags
		$this right_panel_create_highlighting_tags $text $instruction_tags 0
		$text tag configure tag_sel	\
			-relief raised		\
			-borderwidth 1		\
			-background #F8F8F8
		$text tag configure tag_desc

		## Fill text widget
		# "code8"
		set idx [$text index insert]
		$text insert end [mc "code8"]
		$text tag add tag_code8 $idx insert
		set idx [$text index insert]
		$text insert end [mc "\t8 bit offset for relative jump\n"]
		$text tag add tag_desc $idx insert
		# "code11"
		set idx [$text index insert]
		$text insert end [mc "code11"]
		$text tag add tag_code11 $idx insert
		set idx [$text index insert]
		$text insert end [mc "\t11 bit program memory address\n"]
		$text tag add tag_desc $idx insert
		# "code16"
		set idx [$text index insert]
		$text insert end [mc "code16"]
		$text tag add tag_code16 $idx insert
		set idx [$text index insert]
		$text insert end [mc "\t16 bit program memory address\n"]
		$text tag add tag_desc $idx insert
		# "imm8"
		set idx [$text index insert]
		$text insert end [mc "imm8"]
		$text tag add tag_imm8 $idx insert
		set idx [$text index insert]
		$text insert end [mc "\t8 bit constant data\n"]
		$text tag add tag_desc $idx insert
		# "imm16"
		set idx [$text index insert]
		$text insert end [mc "imm16"]
		$text tag add tag_imm16 $idx insert
		set idx [$text index insert]
		$text insert end [mc "\t16 bit constant data\n"]
		$text tag add tag_desc $idx insert
		# "data"
		set idx [$text index insert]
		$text insert end [mc "data"]
		$text tag add tag_data $idx insert
		set idx [$text index insert]
		$text insert end [mc "\tinternal data memory or SFR direct address\n"]
		$text tag add tag_desc $idx insert
		# "bit"
		set idx [$text index insert]
		$text insert end [mc "bit"]
		$text tag add tag_bit $idx insert
		set idx [$text index insert]
		$text insert end [mc "\tbit memory direct address\n"]
		$text tag add tag_desc $idx insert

                $text insert end "\n"
		# "DPTR"
		set idx [$text index insert]
		$text insert end "DPTR"
		$text tag add tag_DPTR $idx insert
		set idx [$text index insert]
		$text insert end [mc "\tData PoinTeR register (16 bit)\n"]
		$text tag add tag_desc $idx insert
		# "A"
		set idx [$text index insert]
		$text insert end "A"
		$text tag add tag_A $idx insert
		set idx [$text index insert]
		$text insert end [mc "\tPrimary work register\n"]
		$text tag add tag_desc $idx insert
		# "AB"
		set idx [$text index insert]
		$text insert end "AB"
		$text tag add tag_AB $idx insert
		set idx [$text index insert]
		$text insert end [mc "\tAccumulator\n"]
		$text tag add tag_desc $idx insert

		$text insert end "\n"
		# "R0..R7"
		set idx [$text index insert]
		$text insert end "R0..R7"
		$text tag add tag_SFR $idx insert
		set idx [$text index insert]
		$text insert end [mc "\tRegisters of active bank\n"]
		$text tag add tag_desc $idx insert
		# "C"
		set idx [$text index insert]
		$text insert end "C"
		$text tag add tag_SFR $idx insert
		set idx [$text index insert]
		$text insert end [mc "\tCarry flag\n"]
		$text tag add tag_desc $idx insert
		# "@R0 ..."
		set idx [$text index insert]
		$text insert end "@R0 ..."
		$text tag add tag_indr $idx insert
		set idx [$text index insert]
		$text insert end [mc "\tIndirect address"]
		$text tag add tag_desc $idx insert

		# Show the text
		$text configure -state disabled
		pack $text -side bottom -fill both -expand 1

		# Show the window
		wm geometry $win "=380x280+$x+$y"
		update
		catch {
			grab -global $win
		}
	}

	## Clear instruction details window
	 # @return void
	public method rightPanel_ins_clear {} {
		if {!$enabled || ${::Editor::editor_to_use}} {return}
		if {!$instd_gui_initialized} {CreateInstructionDetailsGUI}

		$instruction_text configure -state normal
		$instruction_text delete 1.0 end
		$instruction_text configure -state disabled
		$instruction_label configure -text {}

		set instruction_last {}
		rightPanel_ins_hide_ins_help_window
		set help_win_index 0
	}

	## Refresh highlighting tags in "Instruction details"
	 # @return void
	public method rightPanel_refresh_instruction_highlighting {} {
		if {${::Editor::editor_to_use}} {return}
		if {!$instd_gui_initialized && !$gui_preparing} {return}
		$this right_panel_create_highlighting_tags	\
			$instruction_text $instruction_tags 0
	}

	## Unset current selection in "Instruction details" window
	 # @return void
	public method rightPanel_ins_unselect {} {
		if {!$enabled || ${::Editor::editor_to_use}} {return}
		if {!$instd_gui_initialized} {return}

		$instruction_text tag remove tag_sel 1.0 end
		if {$::CONFIG(VALIDATION_LEVEL) == 2} {
			$instruction_label configure -fg {#FF0000}
		} else {
			$instruction_label configure -fg {#0000FF}
		}
	}

	## Change current selection in "Instruction details" window
	 # @parm Bool perfect_match	- Operand matches exactly
	 # @parm List list_of_indexes	- Lines to select (benining from zero) (eg. '0 4 9')
	 # @return void
	public method rightPanel_ins_select {perfect_match list_of_indexes} {
		if {!$enabled || ${::Editor::editor_to_use}} {return}
		if {!$instd_gui_initialized} {return}
		if {[$instruction_label cget -text] == {}} {return}
		$instruction_label configure -fg {#0000FF}
		if {$perfect_match} {
			set tag tag_sel
		} else {
			set tag tag_sel0
		}
		foreach line $list_of_indexes {
			incr line
			$instruction_text tag add $tag $line.0 "$line.0+1l"
		}
		$instruction_text see $line.0
	}

	## Change current directive in "Instruction details" window
	 # @parm Char type		- 'C' == Control; 'D' == Directive
	 # @parm String directive	- directive name
	 # @return void
	public method rightPanel_dir_change {type directive} {
		if {!$enabled || ${::Editor::editor_to_use}} {return}
		if {!$instd_gui_initialized} {return}

		regsub {^\.} $directive {} directive
		set directive [string tolower $directive]
		if {$instruction_last == $directive} {return}
		set instruction_last $directive

		set ins_help_win_enabled 0

		# Change content of tab header
		if {$type == {D}} {
			set clr {#00AADD}
		} else {
			set clr {#00AADD}
		}
		set dir_up [string toupper $directive]
		$instruction_label configure -text $dir_up -fg $clr
		$header_text delete 1.0 end

		# Enable and clear the text widget
		$instruction_text configure -state normal
		$instruction_text delete 1.0 end

		set idx [lsearch -ascii -exact $HELP_FOR_DIRECTIVES $directive]
		if {$idx == -1} {
			$instruction_text insert end [mc "no help available for this directive"]
		} else {
			incr idx
			$instruction_text insert end [lindex $HELP_FOR_DIRECTIVES $idx]
		}

		# Create highlight tags
		$instruction_text tag add tag_DPTR 1.0 {1.0 lineend}
		$instruction_text tag add tag_AB 3.0 {3.0 lineend}
		$instruction_text tag add tag_AB 6.0 {6.0 lineend}
		$instruction_text tag add tag_indr {end-2l linestart} {end-2l lineend}

		# Disable the widget
		$instruction_text configure -state disabled
	}

	## Change current instruction in "Instruction details" window
	 # @parm String instruction - instruction name
	 # @return void
	public method rightPanel_ins_change {instruction} {
		if {!$enabled || ${::Editor::editor_to_use}} {return}
		if {!$instd_gui_initialized} {return}

		set instruction [string tolower $instruction]
		if {$instruction_last == $instruction} {return}
		set instruction_last $instruction

		set ins_help_win_enabled 0

		# Change content of tab header
		$instruction_label configure -text [string toupper $instruction] -fg {#0000FF}
		$header_text delete 1.0 end
		$header_text insert 1.0 "Opr 0\tOpr 1\tOpr 2\tLen Code Time"

		# Find given instruction in compilers instruction set definition
		if {[lsearch -ascii -exact ${::CompilerConsts::AllInstructions} $instruction] == -1} {return}

		# Enable and clear the text widget
		$instruction_text configure -state normal
		$instruction_text delete 1.0 end

		# Display instruction details
		set data {}
		foreach line [lindex $::CompilerConsts::InstructionDefinition($instruction) 1] {
			# Write operands
			for {set i 0} {$i < 3} {incr i} {
				set startIndex [$instruction_text index insert]
				set opr [lindex $line [list 0 $i]]

				# Adjust operand
				if {[lsearch -ascii -exact {code8 code11 code16 imm8 imm16 data bit} $opr] == -1} {
					set opr [string toupper $opr]
				}

				# Insert operand
				$instruction_text insert insert $opr
				$instruction_text insert insert "\t"

				# Highlight operand
				switch -- $opr {
					{code8}		{ ;# 8 bit offset for relative jump
						$instruction_text tag add tag_code8 $startIndex insert-1c
					}
					{code11}	{ ;# 11 bit program memory address
						$instruction_text tag add tag_code11 $startIndex insert-1c
					}
					{code16}	{ ;# 16 bit program memory address
						$instruction_text tag add tag_code16 $startIndex insert-1c
					}
					{imm8}		{ ;# 8 bit constant data
						$instruction_text tag add tag_imm8 $startIndex insert-1c
					}
					{imm16}		{ ;# 16 bit constant data
						$instruction_text tag add tag_imm16 $startIndex insert-1c
					}
					{data}		{ ;# internal data memory or SFR direct address
						$instruction_text tag add tag_data $startIndex insert-1c
					}
					{bit}		{ ;# bit memory direct address
						$instruction_text tag add tag_bit $startIndex insert-1c
					}
					{DPTR}		{ ;# Data PoinTeR register (16 bit)
						$instruction_text tag add tag_DPTR $startIndex insert-1c
					}
					{A}		{ ;# Primary work register (Accumulator)
						$instruction_text tag add tag_A $startIndex insert-1c
					}
					{AB}		{ ;# Accumulator
						$instruction_text tag add tag_AB $startIndex insert-1c
					}
					default		{ ;# SFR or indirect address
						# Indirect address
						if {[string index $opr 0] == {@}} {
							$instruction_text tag add tag_indr $startIndex insert-1c
						# SFR
						} else {
							$instruction_text tag add tag_SFR $startIndex insert-1c
						}
					}
	 			}
			}

			# Write length
			$instruction_text insert insert " "
			set startIndex [$instruction_text index insert]
			set num [lindex $line 1]
			$instruction_text insert insert $num
			if {$num > 0 && $num < 6} {
				$instruction_text tag add "tag_$num" $startIndex insert
			}

			# Write OP code
			$instruction_text insert insert "   "
			$instruction_text insert insert [string toupper [lindex $line 2]]

			# Write time
			$instruction_text insert insert "  "
			set startIndex [$instruction_text index insert]
			set num [lindex $line 4]
			$instruction_text insert insert $num
			if {$num > 0 && $num < 6} {
				$instruction_text tag add "tag_$num" $startIndex insert
			}

			# Set last 9 characters to bold font
			$instruction_text tag add tag_bold {insert-9c} insert
			$instruction_text insert insert "\n"
		}

		# Disable the widget
		$instruction_text configure -state disabled

		# Update help window
		if {$ins_help_win_visible} {
			set idx $help_win_index
			set help_win_index 0
			show_ins_help_window $idx
		}

		set ins_help_win_enabled 1
	}

	## Set flag enabled
	 # @parm Bool bool - New value
	 # @return void
	public method right_panel_instruction_details_set_enabled {bool} {
		set enabled $bool
	}

	## Handles Motion event on the text widget
	 # @param Int x - Relative mouse pointer position
	 # @param Int y - Relative mouse pointer position
	 # @param Int X - Absolute mouse pointer position
	 # @param Int Y - Absolute mouse pointer position
	 # @return void
	public method rightPanel_ins_text_motion {x y X Y} {
		if {!$ins_help_win_enabled} {return}
		set index [$instruction_text index @$x,$y]
		set index [expr {int($index)}]
		if {$help_win_index == $index} {
			move_ins_help_window $X $Y
			return
		}
		set help_win_index $index

		show_ins_help_window $index
	}

	## Move instruction help window
	 # @param Int X - Absolute mouse pointer position
	 # @param Int Y - Absolute mouse pointer position
	 # @return void
	private method move_ins_help_window {X Y} {
		if {!$ins_help_win_visible} {
			return
		}

		# Determinate main window geometry
		set geometry [split [wm geometry .] {+}]
		set limits [split [lindex $geometry 0] {x}]

		# Adjust X and Y
		set x_coord [expr {$X - 5 - [lindex $geometry 1]}]
		set y_coord [expr {$Y - 20 - [lindex $geometry 2]}]

		if {$y_coord > ([lindex $limits 1] - 220)} {incr y_coord -240}

		# Show the window
		catch {
			place $ins_help_window -anchor ne -x $x_coord -y $y_coord -width 300
			raise $ins_help_window
		}
	}

	## Show instruction help window
	 # @param Int index - Line number
	 # @return void
	private method show_ins_help_window {index} {
		# Create help window widget
		if {!$ins_help_win_created} {
			create_ins_help_window
		}
		# Hide window if there is nothing to show
		if {[$instruction_text compare $index.0 == end]} {
			rightPanel_ins_hide_ins_help_window
			return
		}

		# Set help window visibility flag
		set ins_help_win_visible 1

		# Determinate instruction name (and possibly abort the process)
		incr index -1
		set instruction [string tolower [$instruction_label cget -text]]
		if {![string length $instruction]} {
			rightPanel_ins_hide_ins_help_window
			return
		}
		# Check if the instruction is really an instruction
		if {[lsearch -ascii -exact ${::CompilerConsts::AllInstructions} $instruction] == -1} {return}

		# Modify instruction name if nessesary
		switch -- $instruction {
			{jmp} {
				switch -- $index {
					1 {set instruction {ljmp}}
					2 {set instruction {ajmp}}
					3 {set instruction {sjmp}}
				}
				set index 0
			}
		}

		# Obtain detailed informations about the instruction
		set operands_tmp	[list]
		set instruction_def	[lindex $::CompilerConsts::InstructionDefinition($instruction) [list 1 $index]]
		set operands		[lindex $instruction_def 0]
		foreach operand $operands {
			switch -glob -- $operand {
				a	-
				c	-
				ab	-
				@dptr	-
				@a+dptr	-
				@a+pc	-
				dptr	{
					set operand [string toupper $operand]
				}
				r?	{
					set operand {Rn}
				}
				@r?	{
					set operand {@Ri}
				}
				imm8	{
					set operand {#data}
				}
				imm16	{
					set operand {#data16}
				}
				code8	{
					set operand {rel}
				}
				code11	{
					set operand {addr11}
				}
				code16	{
					set operand {addr16}
				}
				bit	{
					set operand {bit}
				}
				/bit	{
					set operand {/bit}
				}
				data	{
					set operand {direct}
				}
			}
			lappend operands_tmp $operand
		}
		set operands [join $operands_tmp {, }]
		set instruction [string toupper $instruction]

		# Modify detailed informations
		set title "$instruction\t$operands"

		set ins_length [lindex $instruction_def 1]
		set opcode [string toupper [lindex $instruction_def 2]]
		if {[string length $ins_length]} {
			append opcode [string repeat {-} [expr {($ins_length - 1) * 2}]]
		}

		set ins_description [lsearch -ascii -exact $INSTRUCTION_DESCRIPTION $title]
		if {$ins_description == -1} {
			rightPanel_ins_hide_ins_help_window
			return
		}
		incr ins_description
		set ins_description [lindex $INSTRUCTION_DESCRIPTION $ins_description]

		# Fill in the help window
		$help_win_title configure -text $title
		$help_win_labels(description)	 configure -text [mc [lindex $ins_description 0]]
		$help_win_labels(length)	 configure -text $ins_length
		$help_win_labels(execution_time) configure -text [lindex $instruction_def 4]
		$help_win_labels(opcode)	 configure -text "0x$opcode"
		$help_win_labels(note)		 configure -text [mc [lindex $ins_description 2]]
		$help_win_labels(class)		 configure -text [mc [lindex $ins_description 1]]
		foreach i_0 {0		1	2	} \
			i_1 {C		OV	AC	} \
			i_2 {C_l	OV_l	AC_l	} \
		{
			set txt [lindex $ins_description [list 3 $i_0]]
			switch -- $txt {
				X	{set clr {#00AAFF}}
				0	{set clr {#DD0000}}
				1	{set clr {#00CC00}}
				default	{set clr {#888888}}
			}
			$help_win_labels($i_1) configure -text $txt -fg $clr
			$help_win_labels($i_2) configure -fg $clr
		}
	}

	## Hide instruction help window
	 # @return void
	public method rightPanel_ins_hide_ins_help_window {} {
		if {!$ins_help_win_visible} {
			return
		}

		set help_win_index 0
		set ins_help_win_visible 0
		catch {
			place forget $ins_help_window
		}
	}

	## Create instruciton help window
	 # @return void
	private method create_ins_help_window {} {
		if {$ins_help_win_created} {
			return
		}
		set ins_help_win_created 1

		# Create main parts of the window
		incr instd_count
		set ins_help_window [frame .ins_help_window${instd_count} -bd 0 -bg {#BBBBFF} -padx 2 -pady 2]
		pack [frame $ins_help_window.top -bg {#BBBBFF}] -fill x -expand 1
		pack [label $ins_help_window.top.img -bg {#BBBBFF} -image ::ICONS::16::info] -side left
		pack [label $ins_help_window.top.tit -bg {#BBBBFF} -justify left -anchor w] -side left -fill x -expand 1
		pack [frame $ins_help_window.msg -bg {#FFFFFF} -padx 10 -pady 5] -fill both -expand 1
		set help_win_title "${ins_help_window}.top.tit"

		## Create other parts of the window
		 # Descripton
		set i 0
		set help_win_labels(description) [	\
			label $ins_help_window.msg.r_$i	\
			-pady 0 -bg {#FFFFFF}		\
			-highlightthickness 0		\
			-wraplength 260 -justify left	\
		]
		grid $help_win_labels(description) -row $i -column 0 -columnspan 2 -sticky w
		incr i
		 # - (separator)
		grid [ttk::separator $ins_help_window.msg.sep	\
			-orient horizontal			\
		] -row $i -column 0 -columnspan 2 -sticky we
		 # Class
		incr i
		grid [label $ins_help_window.msg.l_$i	\
			-pady 0 -fg {#0000AA}		\
			-bg {#FFFFFF}			\
			-highlightthickness 0		\
			-text [mc "Class:"]		\
		] -row $i -column 0 -sticky w
		set help_win_labels(class) [		\
			label $ins_help_window.msg.r_$i	\
			-pady 0 -bg {#FFFFFF}		\
			-highlightthickness 0		\
		]
		grid $help_win_labels(class) -row $i -column 1 -sticky w
		incr i
		 # Flags
		grid [label $ins_help_window.msg.l_$i	\
			-pady 0 -fg {#0000AA}		\
			-highlightthickness 0		\
			-text [mc "Flags:"]		\
			-bg {#FFFFFF}			\
		] -row $i -column 0 -sticky nw

		set flags_frm [frame $ins_help_window.msg.flags_frm	\
			-bg {#888888}	\
		]
		grid $flags_frm -row $i -column 1 -sticky w
		incr i
		 # Length
		grid [label $ins_help_window.msg.l_$i	\
			-pady 0 -fg {#0000AA}		\
			-highlightthickness 0		\
			-text [mc "Length:"]		\
			-bg {#FFFFFF}			\
		] -row $i -column 0 -sticky w
		set help_win_labels(length) [		\
			label $ins_help_window.msg.r_$i	\
			-pady 0 -bg {#FFFFFF}		\
			-highlightthickness 0		\
		]
		grid $help_win_labels(length) -row $i -column 1 -sticky w
		incr i
		 # Time
		grid [label $ins_help_window.msg.l_$i	\
			-pady 0 -fg {#0000AA}		\
			-highlightthickness 0		\
			-text [mc "Time:"]			\
			-bg {#FFFFFF}			\
		] -row $i -column 0 -sticky w
		set help_win_labels(execution_time) [	\
			label $ins_help_window.msg.r_$i	\
			-pady 0 -bg {#FFFFFF}		\
			-highlightthickness 0		\
		]
		grid $help_win_labels(execution_time) -row $i -column 1 -sticky w
		incr i
		 # OPCODE
		grid [label $ins_help_window.msg.l_$i	\
			-pady 0 -fg {#0000AA}		\
			-highlightthickness 0		\
			-text [mc "OPCODE:"]		\
			-bg {#FFFFFF}			\
		] -row $i -column 0 -sticky w
		set help_win_labels(opcode) [		\
			label $ins_help_window.msg.r_$i	\
			-pady 0 -bg {#FFFFFF}		\
			-highlightthickness 0		\
		]
		grid $help_win_labels(opcode) -row $i -column 1 -sticky w
		incr i
		 # Note
		grid [label $ins_help_window.msg.l_$i	\
			-pady 0 -fg {#0000AA}		\
			-highlightthickness 0		\
			-text [mc "Note:"]		\
			-bg {#FFFFFF}			\
		] -row $i -column 0 -sticky w
		set help_win_labels(note) [		\
			label $ins_help_window.msg.r_$i	\
			-pady 0 -bg {#FFFFFF}		\
			-highlightthickness 0		\
		]
		grid $help_win_labels(note) -row $i -column 1 -sticky w
		 ## Table of flags
		  # Flag C
		set help_win_labels(C_l) [	\
			label $flags_frm.ll_C	\
			-bg {#FFFFFF}		\
			-pady 0			\
			-highlightthickness 0	\
			-text "C"		\
		]
		grid $help_win_labels(C_l) -row 0 -column 0 -sticky nswe -padx 1 -pady 1
		set help_win_labels(C) [	\
			label $flags_frm.lr_C	\
			-bg {#FFFFFF}		\
			-pady 0			\
			-highlightthickness 0	\
		]
		grid $help_win_labels(C) -row 1 -column 0 -sticky nswe -padx 1 -pady 1
		  # Flag OV
		set help_win_labels(OV_l) [	\
			label $flags_frm.ll_OV	\
			-bg {#FFFFFF}		\
			-pady 0			\
			-highlightthickness 0	\
			-text "OV"		\
		]
		grid $help_win_labels(OV_l) -row 0 -column 1 -sticky nswe -padx 1 -pady 1
		set help_win_labels(OV) [	\
			label $flags_frm.lr_OV	\
			-bg {#FFFFFF}		\
			-pady 0			\
			-highlightthickness 0	\
		]
		grid $help_win_labels(OV) -row 1 -column 1 -sticky nswe -padx 1 -pady 1
		  # Flag AC
		set help_win_labels(AC_l) [	\
			label $flags_frm.ll_AC	\
			-bg {#FFFFFF}		\
			-pady 0			\
			-highlightthickness 0	\
			-text "AC"		\
		]
		grid $help_win_labels(AC_l) -row 0 -column 2 -sticky nswe -padx 1 -pady 1
		set help_win_labels(AC) [	\
			label $flags_frm.lr_AC	\
			-bg {#FFFFFF} -bd 1	\
			-pady 0			\
			-highlightthickness 0	\
		]
		grid $help_win_labels(AC) -row 1 -column 2 -sticky nswe -padx 1 -pady 1
		 # (finalize creation of table of flags)
		grid columnconfigure $ins_help_window.msg 0 -minsize 80
		grid columnconfigure $ins_help_window.msg 1 -weight 1
	}

	proc initialize {} {
		set l [llength $HELP_FOR_DIRECTIVES_RAW]
		for {set i 0; set j 1} {$i < $l} {incr i 2; incr j 2} {
			lappend HELP_FOR_DIRECTIVES [lindex $HELP_FOR_DIRECTIVES_RAW $i]
			lappend HELP_FOR_DIRECTIVES [mc [subst [lindex $HELP_FOR_DIRECTIVES_RAW $j]]]
		}
	}
}

# Initialize
::InstructionDetails::initialize

# >>> File inclusion guard
}
# <<< File inclusion guard
