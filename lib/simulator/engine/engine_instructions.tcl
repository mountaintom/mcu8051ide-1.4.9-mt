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
if { ! [ info exists _ENGINE_INSTRUCTIONS_TCL ] } {
set _ENGINE_INSTRUCTIONS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# INSTRUCTION PROCEDURES
# --------------------------------------------------------------------------


## Instruction: ACALL
 # @parm Int haddr	- High part of the target address
 # @parm Int laddr	- Low part of the target address
 # @return void
private method ins_acall {haddr laddr} {
	set time 2
	stepback_save_spec_subprog 2

	stack_push [expr {($pc & 255)}]
	stack_push [expr {($pc & 0xFF00) >> 8}]

	incr laddr [expr {($haddr << 8) | $pc & 0x0f800}]
	incr run_statistics(6)
	$this subprograms_call 1 $pc $laddr
	$this stack_monitor_set_last_values_as 1 2
	set pc $laddr
}

## Instruction: ADD
 # @parm Int val	- Value to add to Acc
 # @return void
private method ins_add {val} {
	set time 1

	alo_add $val
	incr_pc 1

	evaluate_sfr 224
}

## Instruction: ADD A, addr
 # @parm Int addr	- Direct address
 # @return void
private method ins_add_D {addr} {
	if {[check_address_validity D $addr]} {
		ins_add [undefined_octet]
		return
	}
	if {$addr < 128} {
		ins_add $ram($addr)
	} else {
		ins_add [read_sfr $addr]
	}
}

## Instruction: ADD A, @Ri
 # @parm Int addr	- Indirect address
 # @return void
private method ins_add_ID {addr} {
	set time 1
	incr_pc 1
	if {[check_address_validity I $addr]} {
		alo_add [undefined_octet]
	} else {
		alo_add $ram($addr)
	}
	evaluate_sfr 224
}

## Instruction: ADDC
 # @parm Int val	- Value to add to Acc
 # @return void
private method ins_addc {val} {
	set time 1

	alo_addc $val
	incr_pc 1

	evaluate_sfr 224
}

## Instruction: ADDC A, addr
 # @parm Int addr	- Value to add to Acc
 # @return void
private method ins_addc_D {addr} {
	if {[check_address_validity D $addr]} {
		ins_addc [undefined_octet]
		return
	}
	if {$addr < 128} {
		ins_addc $ram($addr)
	} else {
		ins_addc [read_sfr $addr]
	}
}

## Instruction: ADDC A, @Ri
 # @parm Int addr	- Indirect address
 # @return void
private method ins_addc_ID {addr} {
	set time 1
	incr_pc 1
	if {[check_address_validity I $addr]} {
		alo_addc [undefined_octet]
		return
	} else {
		alo_addc $ram($addr)
	}
}

## Instruction: AJMP
 # @parm Int haddr	- High part of the target address
 # @parm Int laddr	- Low part of the target address
 # @return void
private method ins_ajmp {haddr laddr} {
	set time 2
	incr laddr [expr {($haddr << 8) | $pc & 0x0f800}]
	set pc $laddr
}

## Instruction: ANL
 # @parm Int addr	- Register address
 # @parm Int val	- Operation arument
 # @return void
private method ins_anl {addr val} {
	set time 2
	if {[check_address_validity D $addr]} {return}
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set ram($addr) [expr {$ram($addr) & $val}]
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		set rmw_instruction 1
		write_sfr $addr [expr {[read_sfr $addr] & $val}]
		evaluate_sfr $addr
	}
}

## Instruction: ANL A
 # @parm Int val	- Operation arument
 # @return void
private method ins_anl_A {val} {
	set time 1
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	set sfr(224) [expr {$sfr(224) & $val}]
	incr_pc 1
	evaluate_sfr 224
}

## Instruction: ANL A, addr
 # @parm Int addr	- Address of register containing value to add
 # @return void
private method ins_anl_A_D {addr} {
	if {[check_address_validity D $addr]} {return}
	if {$addr < 128} {
		ins_anl_A $ram($addr)
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		ins_anl_A [read_sfr $addr]
		evaluate_sfr $addr
	}
}

## Instruction: ANL A, @Ri
 # @parm Int addr	- Indirect address
 # @return void
private method ins_anl_A_ID {addr} {
	set time 1
	incr_pc 1
	if {[check_address_validity I $addr]} {return}
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	set sfr(224) [expr {$sfr(224) & $ram($addr)}]
	evaluate_sfr 224
}

## Instruction: ANL C, bit
 # @parm Int addr	- Bit address
 # @return void
private method ins_anl_C {addr} {
	set time 2
	if {[check_address_validity B $addr]} {return}
	if {![getBit $addr]} {setBit $symbol(C) 0}
	evaluate_bit $symbol(C)
}

## Instruction: ANL C, /bit
 # @parm Int addr	- Bit address
 # @return void
private method ins_anl_C_N {addr} {
	set time 2
	if {[check_address_validity B $addr]} {
		setBit $symbol(C) [expr {rand() > 0.5}]
	} else {
		if {[getBit $addr]} {setBit $symbol(C) 0}
	}
	evaluate_bit $symbol(C)
}

## Instruction: CJNE A, addr ...
 # @parm Int addr	- 2nd value to compare
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_cjne_AD {addr roff} {
	if {[check_address_validity D $addr]} {
		set val [undefined_octet]
	} else {
		if {$addr < 128} {
			set val $ram($addr)
		} else {
			set val $sfr($addr)
		}
	}
	ins_cjne $sfr(224) $val $roff
}

## Instruction: CJNE
 # @parm Int val0	- 1st value to compare
 # @parm Int val1	- 2nd value to compare
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_cjne {val0 val1 roff} {
	set time 2

	if {$val0 != $val1} {
		if {$roff > 127} {incr roff -256}
		incr_pc $roff
	}
	if {$val0 < $val1} {
		setBit $symbol(C) 1
	} else {
		setBit $symbol(C) 0
	}
}

## Instruction: CJNE @Ri, ...
 # @parm Int addr	- Indirect address
 # @parm Int val1	- 2nd value to compare
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_cjne_ID {addr val1 roff} {
	set time 2

	if {[check_address_validity I $addr]} {
		set val0 [undefined_octet]
	} else {
		set val0 $ram($addr)
	}
	if {$val0 != $val1} {
		if {$roff > 127} {incr roff -256}
		incr_pc $roff
	}
	if {$val0 < $val1} {
		setBit $symbol(C) 1
	} else {
		setBit $symbol(C) 0
	}
}

## Instruction: CLR
 # @parm String opr	- Register name or bit address
 # @return void
private method ins_clr {opr} {
	set time 1
	incr_pc 1

	# Primary accumulator (Acc)
	if {$opr == {A}} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S 224
		}
		set sfr(224) 0
		evaluate_sfr 224
	# Bit PSW.C
	} elseif {$opr == {C}} {
		setBit $symbol(C) 0
		evaluate_bit $symbol(C)
	# Some bit
	} else {
		if {[check_address_validity B $opr]} {return}
		set rmw_instruction 1
		setBit $opr 0
		evaluate_bit $opr
	}
}

## Instruction: CPL
 # @parm String opr	- Register name or bit address
 # @return void
private method ins_cpl {opr} {
	set time 1
	incr_pc 1

	# Primary accumulator (Acc)
	if {$opr == {A}} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S 224
		}
		set sfr(224) [expr {$sfr(224) ^ 255}]
		evaluate_sfr 224
	# Bit PSW.C
	} elseif {$opr == {C}} {
		if {[getBit $symbol(C)]} {
			setBit $symbol(C) 0
		} else {
			setBit $symbol(C) 1
		}
		evaluate_bit $symbol(C)
	# Some bit
	} else {
		if {[check_address_validity B $opr]} {return}
		set rmw_instruction 1
		if {[getBit $opr]} {
			setBit $opr 0
		} else {
			setBit $opr 1
		}
		evaluate_bit $opr
	}
}

## Instruction: DA
 # @return void
private method ins_da {} {
	set time 1
	incr_pc 1

	set hi [expr {($sfr(224) & 240) >> 4}]
	set lo [expr {$sfr(224) & 15}]

	if {($lo > 9) || [getBit $symbol(AC)]} {
		incr lo 6
		if { $lo > 15 } {
			incr lo -16
			incr hi 1
			if { $hi > 15 } {
				incr hi -16
				setBit $symbol(C) 1
			}
		}
	}
	setBit $symbol(AC) 0

	if {($hi > 9) || [getBit $symbol(C)]} {
		incr hi 6
		if { $hi > 15 } {
			incr hi -16
			setBit $symbol(C) 1
		}
	}

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	set sfr(224) [expr {($hi << 4) + $lo}]
	evaluate_sfr 224
}
## Instruction: DEC
 # @parm Int addr	- Register to decrement
 # @return void
private method ins_dec {addr} {
	set rmw_instruction 1
	set time 1
	incr_pc 1
	incr_8b D $addr -1
}

## Instruction: DEC @Ri
 # @parm Int addr	- Register to decrement (indirect address)
 # @return void
private method ins_dec_ID {addr} {
	set time 1
	incr_pc 1
	incr_8b I $addr -1
}

## Instruction: DIV
 # @return void
private method ins_div {} {
	set time 4
	incr_pc 1

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S $symbol(A)
		stepback_reg_change S $symbol(B)
	}

	setBit $symbol(C) 0
	if {$sfr($symbol(B)) == 0} {
		setBit $symbol(OV) 1
		set sfr(224) 0
		set sfr($symbol(B)) 0
	} else {
		setBit $symbol(OV) 0
		set A $sfr(224)
		set sfr(224) [expr {$A / $sfr($symbol(B))}]
		set sfr($symbol(B)) [expr {$A % $sfr($symbol(B))}]
	}

	evaluate_sfr 224
	evaluate_sfr 240
}

## Instruction: DJNZ
 # @parm Int addr	- Register to decrement
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_djnz {addr roff} {
	set rmw_instruction 1
	set time 2

	if {[incr_8b D $addr -1]} {return}
	if {$addr > 127} {
		if {[read_sfr $addr] != 0} {
			if {$roff > 127} {incr roff -256}
			incr_pc $roff
		}
		evaluate_sfr $addr
	} else {
		if {$ram($addr) != 0} {
			if {$roff > 127} {incr roff -256}
			incr_pc $roff
		}
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	}
}

## Instruction: INC
 # @parm Int addr	- Register to increment
 # @return void
private method ins_inc {addr} {
	set rmw_instruction 1
	set time 1
	incr_pc 1
	if {[incr_8b D $addr 1]} {return}
	if {$addr > 127} {
		evaluate_sfr $addr
	} elseif {$sync_ena} {
		$this Simulator_sync_reg $addr
	}
}

## Instruction: INC @Ri
 # @parm Int addr	- Register to increment (indirect address)
 # @return void
private method ins_inc_ID {addr} {
	set time 1
	incr_pc 1
	incr_8b I $addr 1
}

## Instruction: INC DPTR
 # @return void
private method ins_inc_DPTR {} {
	set time 2
	incr_pc 1

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S $symbol($DPL)
		stepback_reg_change S $symbol($DPH)
	}

	incr sfr($symbol($DPL))
	if {$sfr($symbol($DPL)) > 255} {
		set sfr($symbol($DPL)) 0
		incr sfr($symbol($DPH))
	}

	if {$sfr($symbol($DPH)) > 255} {
		set sfr($symbol($DPH)) 0
	}

	evaluate_sfr $symbol($DPH)
	evaluate_sfr $symbol($DPL)
}

## Instruction: JB
 # @parm Int addr	- Bit to test
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_jb {addr roff} {
	set time 2
	if {[check_address_validity B $addr]} {
		set val [expr {rand() > 0.5}]
	} else {
		set val [getBit $addr]
	}
	if {$val} {
		if {$roff > 127} {incr roff -256}
		incr_pc $roff
	}
}

## Instruction: JNB
 # @parm Int addr	- Bit to test
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_jnb {addr roff} {
	set time 2
	if {[check_address_validity B $addr]} {
		set val [expr {rand() > 0.5}]
	} else {
		set val [getBit $addr]
	}
	if {!$val} {
		if {$roff > 127} {incr roff -256}
		incr_pc $roff
	}
}

## Instruction: JBC
 # @parm Int addr	-
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_jbc {addr roff} {
	set rmw_instruction 1
	set time 2
	if {[check_address_validity B $addr]} {
		set val [expr {rand() > 0.5}]
	} else {
		set val [getBit $addr]
	}
	if {$val} {
		setBit $addr 0
		if {$roff > 127} {incr roff -256}
		incr_pc $roff
	}
}

## Instruction: JC
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_jc {roff} {
	ins_jb $symbol(C) $roff
}

## Instruction: JNC
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_jnc {roff} {
	ins_jnb $symbol(C) $roff
}

## Instruction: JZ
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_jz {roff} {
	set time 2
	if {$sfr(224) == 0} {
		if {$roff > 127} {incr roff -256}
		incr_pc $roff
	}
}

## Instruction: JNZ
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_jnz {roff} {
	set time 2

	if {$sfr(224) != 0} {
		if {$roff > 127} {incr roff -256}
		incr_pc $roff
	}
}

## Instruction: JMP
 # @return void
private method ins_jmp {} {
	set time 2
	set pc [expr {($sfr(224) + $sfr($symbol($DPL))) + ($sfr($symbol($DPH)) << 8)}]
	if {$pc > 65535} {
		incr pc -65536
	}
}

## Instruction: LCALL
 # @parm Int haddr	- High part of the target address
 # @parm Int laddr	- Low part of the target address
 # @return void
private method ins_lcall {haddr laddr} {
	set time 2
	stepback_save_spec_subprog 2

	stack_push [expr {$pc & 255}]
	stack_push [expr {($pc & 0xFF00) >> 8}]

	set target [expr {($haddr << 8) + $laddr}]
	incr run_statistics(6)
	$this subprograms_call 0 $pc $target
	$this stack_monitor_set_last_values_as 1 2
	set pc $target
}

## Instruction: LJMP
 # @parm Int haddr	- High part of the target address
 # @parm Int laddr	- Low part of the target address
 # @return void
private method ins_ljmp {haddr laddr} {
	set time 2
	set pc [expr {($haddr << 8) + $laddr}]
}

## Instruction: MOV
 # @parm Int addr	- Register to set
 # @parm Int val	- New value
 # @return void
private method ins_mov {addr val} {
	set time 1
	incr_pc 1

	if {[check_address_validity D $addr]} {return}
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set ram($addr) $val
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		write_sfr $addr $val
		evaluate_sfr $addr
	}
}

## Instruction: MOV
 # @parm Int addr1	- Source register
 # @parm Int addr0	- Target register
 # @return void
private method ins_mov_D {addr1 addr0} {
	set time 1
	incr_pc 1

	if {[check_address_validity D $addr0]} {return}
	if {[check_address_validity D $addr1]} {
		set val [undefined_octet]
	} else {
		if {$addr1 < 128} {
			set val $ram($addr1)
		}  {
			set val [read_sfr $addr1]
		}
	}

	if {$addr0 < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr0
		}
		set ram($addr0) $val
		if {$sync_ena} {
			$this Simulator_sync_reg $addr0
		}
	} else {
		write_sfr $addr0 $val
		evaluate_sfr $addr0
	}
}

## Instruction: MOV @Ri, addr
 # @parm Int addr0	- Register to set (indirect addresing)
 # @parm Int addr1	- Source register
 # @return void
private method ins_mov_ID2 {addr0 addr1} {
	if {[check_address_validity D $addr1]} {
		ins_mov_ID0 $addr0 [undefined_octet]
	} else {
		if {$addr1 < 128} {
			ins_mov_ID0 $addr0 $ram($addr1)
		} else {
			ins_mov_ID0 $addr0 [read_sfr $addr1]
		}
	}
	set time 2
}

## Instruction: MOV
 # @parm Int addr	- Register to set
 # @parm Int addr_id	- Address of new value (indirect addresing)
 # @return void
private method ins_mov_ID1 {addr addr_id} {
	set time 1
	incr_pc 1

	if {[check_address_validity D $addr]} {return}
	if {[check_address_validity I $addr_id]} {
		set val [undefined_octet]
	} else {
		set val $ram($addr_id)
	}
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set ram($addr) $val
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		write_sfr $addr $val
		evaluate_sfr $addr
	}
}

## Instruction: MOV @Ri, ..
 # @parm Int addr	- Register to set (indirect addresing)
 # @parm Int val	- New value
 # @return void
private method ins_mov_ID0 {addr val} {
	set time 1
	incr_pc 1

	if {[check_address_validity I $addr]} {return}
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change I $addr
	}
	set ram($addr) $val
	if {$sync_ena} {
		$this Simulator_sync_reg $addr
	}
}

## Instruction: MOV DPTR
 # @parm Int haddr	- High part of the new value
 # @parm Int laddr	- Low part of the new value
 # @return void
private method ins_mov_DPTR {hval lval} {
	set time 2

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S $symbol($DPL)
		stepback_reg_change S $symbol($DPH)
	}
	set sfr($symbol($DPL)) $lval
	set sfr($symbol($DPH)) $hval

	evaluate_sfr $symbol($DPH)
	evaluate_sfr $symbol($DPL)
}

## Instruction: MOV Rx
 # @parm Int idx	- Register index (0..7) (target)
 # @parm Int addr	- Register address (source)
 # @return void
private method ins_mov_Rx_ADDR {idx addr} {
	set time 2

	set t_addr [R $idx]
	if {[check_address_validity D $addr]} {return}

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change I $t_addr
	}
	if {$addr < 128} {
		set ram($t_addr) $ram($addr)
	} else {
		set ram($t_addr) [read_sfr $addr]
	}

	if {$sync_ena} {
		$this Simulator_sync_reg $t_addr
	}
}

## Instruction: MOV bit
 # @parm String dest	- Destination bit or 'C'
 # @parm String source	- Source bit or 'C'
 # @return void
private method ins_mov_bit {dest source} {
	set time 1
	if {$dest == {C}} {
		if {[check_address_validity B $source]} {
			set val [expr {rand() < 0.5}]
		} else {
			set val [getBit $source]
		}
		if {$val} {
			setBit $symbol(C) 1
		} else {
			setBit $symbol(C) 0
		}
	} else {
		set rmw_instruction 1
		incr time
		if {[check_address_validity B $dest]} {return}
		if {[getBit $symbol(C)]} {
			setBit $dest 1
		} else {
			setBit $dest 0
		}
	}
}

## Instruction: MOVC
 # @parm String arg	- Offset register (one of {DPTR PC})
 # @return void
private method ins_movc {arg} {
	set time 2
	incr_pc 1

	# MOVC A, @A+DPTR
	if {$arg == {DPTR}} {
		set addr [expr {($sfr(224) + $sfr($symbol($DPL))) + ($sfr($symbol($DPH)) << 8)}]
	# MOVC A, @A+PC
	} else {
		set addr $pc
		incr addr $sfr(224)
	}

	if {$addr > 65535} {
		incr addr -65356
	}

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	if {[check_address_validity C $addr]} {
		set sfr(224) [undefined_octet]
	} elseif {$code($addr) != {}} {
		set sfr(224) $code($addr)
	} else {
		set sfr(224) [undefined_octet]
	}

	evaluate_sfr 224
}

## Instruction: MOVX
 # @parm String opr0	- Register name (one of {A R0 R1 DPTR})
 # @parm String opr1	- Register name (one of {A R0 R1 DPTR})
 # @return void
private method ins_movx {opr0 opr1} {
	set time 2
	incr_pc 1

	if {$opr1 == {R0}} {
		set Saddr $ram([R 0])
	} elseif {$opr1 == {R1}} {
		set Saddr $ram([R 1])
	} elseif {$opr1 == {DPTR}} {
		set Saddr [expr {($sfr($symbol($DPH)) << 8) + $sfr($symbol($DPL))}]
	}

	if {$opr0 == {A}} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S 224
		}

		# Read from expanded data memory
		if {$Saddr < $eram_size && !$controllers_conf(EXTRAM)} {
			if {[check_address_validity E $Saddr]} {
				set sfr(224) [undefined_octet]
			} else {
				set sfr(224) $eram($Saddr)
			}
		# Read from data EEPROM
		} elseif {$Saddr < $eeprom_size && $controllers_conf(EEMEN)} {
			if {[check_address_validity P $Saddr]} {
				set sfr(224) [undefined_octet]
			} else {
				set complement_MSB 0
				foreach reg $eeprom_prev {
					if {$Saddr == [lindex $reg 0]} {
						set complement_MSB 1
						break
					}
				}
				if {$complement_MSB} {
					set sfr(224) [expr {$eeprom($Saddr) ^ 0x80}]
				} else {
					set sfr(224) $eeprom($Saddr)
				}
			}
		# Read from external data memory
		} else {
			if {$feature_available(xram) && [$this pale_is_enabled]} {
				for {set i -3} {$i < 0} {incr i} {
					if {!$controllers_conf(X2)} {
						$this pale_WPBBL $PIN(RD) {X} $i
						$this pale_WPBL 0 X $i
						$this pale_WPBL 2 X $i
						incr i
						$this pale_WPBBL $PIN(RD) {X} $i
						$this pale_WPBL 0 X $i
						$this pale_WPBL 2 X $i
					} else {
						incr i
						$this pale_WPBL 0 X [expr {int($i / 2)}]
						$this pale_WPBL 2 X [expr {int($i / 2)}]
						$this pale_WPBBL $PIN(RD) {X} [expr {int($i / 2)}]
					}
				}
			}
			if {[check_address_validity X $Saddr]} {
				set sfr(224) [undefined_octet]
			} else {
				set sfr(224) $xram($Saddr)
			}
		}

		evaluate_sfr 224
		return
	} elseif {$opr0 == {R0}} {
		set Daddr $ram([R 0])
	} elseif {$opr0 == {R1}} {
		set Daddr $ram([R 1])
	} elseif {$opr0 == {DPTR}} {
		set Daddr [expr {($sfr($symbol($DPH)) << 8) + $sfr($symbol($DPL))}]
	}

	# Write to expanded data memory
	if {$Daddr < $eram_size && !$controllers_conf(EXTRAM)} {
		if {[check_address_validity E $Daddr]} {return}
		set eram($Daddr) $sfr(224)

	# Write to data EEPROM
	} elseif {$Daddr < $eeprom_size && $controllers_conf(EEMEN)} {
		# Check if this operation is valid
		if {[check_address_validity P $Daddr]} {return}
		if {
			!$controllers_conf(EEMWE)	||
			!$controllers_conf(RDYBSY)	||
			!$controllers_conf(WRTINH)
		} then {
			if {!${::Simulator::ignore_EEPROM_WR_fail}} {
				$this simulator_EEPROM_WR_fail $pc $Line($pc)
				internal_shutdown
			}
			return
		}

		# Append value to the buffer
		set low_addr [expr {$Daddr & 0x1F}]
		set eeprom_WR_buff($low_addr) $sfr(224)

		# Synchronize with write buffer window
		::X::sync_eeprom_write_buffer $low_addr $this
		set offset [format %X [expr {$Daddr & 0xFFE0}]]
		set len [string length $offset]
		if {$len < 4} {
			set offset "[string repeat 0 [expr {4 - $len}]]$offset"
		}
		set eeprom_WR_ofs "0x$offset"
		::X::eeprom_write_buffer_set_offset $eeprom_WR_ofs $this

		# Start EEPROM programming cycle
		if {!$controllers_conf(EELD)} {
			# Write data to data EEPROM
			set eeprom_prev {}
			set addr [expr {$Daddr & 0xFFE0}]
			for {set i 0} {$i < 32} {incr i; incr addr} {
				if {$eeprom_WR_buff($i) != {}} {
					lappend eeprom_prev [list $addr $eeprom($addr)]
					stepback_reg_change P $addr
					set eeprom($addr) $eeprom_WR_buff($i)
					::X::sync_eeprom_mem_window [format %X $addr] 1 $this
				}
				set eeprom_WR_buff($i) {}
			}

			# Clear write buffer hex editor
			::X::eeprom_write_buffer_set_offset {} $this
			::X::clear_eeprom_write_buffer $this

			# Clear flag EECON.RDYBSY (EEPROM is busy)
			$this sim_GUI_bit_set_clear 0 EECON RDYBSY
			set sfr(150) [expr {$sfr(150) & 0xFD}]
			set controllers_conf(RDYBSY) 0
			if {${::Simulator::reverse_run_steps}} {
				stepback_reg_change S 150
			}
			if {$sync_ena} {
				$this Simulator_GUI_sync S 150
			}

			# Adjust engine configuration
			set eeprom_WR_time 1
			set eeprom_WR 1

			$this simulator_GUI_invoke_write_to_eeprom
		}
		return

	# Write to external data memory
	} else {
		if {$feature_available(xram) && [$this pale_is_enabled]} {
			for {set i -3} {$i < 0} {incr i} {
				if {!$controllers_conf(X2)} {
					$this pale_WPBBL $PIN(WR) {X} $i
					$this pale_WPBL 0 X $i
					$this pale_WPBL 2 X $i
					incr i
					$this pale_WPBBL $PIN(WR) {X} $i
					$this pale_WPBL 0 X $i
					$this pale_WPBL 2 X $i
				} else {
					incr i
					$this pale_WPBL 0 X [expr {int($i / 2)}]
					$this pale_WPBL 2 X [expr {int($i / 2)}]
					$this pale_WPBBL $PIN(WR) {X} [expr {int($i / 2)}]
				}
			}
		}

		if {[check_address_validity X $Daddr]} {return}
		stepback_reg_change X $Daddr
		set xram($Daddr) $sfr(224)
	}

	if {$sync_ena} {
		$this Simulator_XDATA_sync $Daddr
	}
}

## Instruction: MUL
 # @return void
private method ins_mul {} {
	set time 4
	incr_pc 1

	setBit $symbol(C) 0

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
		stepback_reg_change S 240
	}

	set result [expr {$sfr(224) * $sfr(240)}]
	if {$result > 255} {
		set sfr(240) [expr {($result & 0xFF00) >> 8}]
		setBit $symbol(OV) 1
	} else {
		set sfr(240) 0
		setBit $symbol(OV) 0
	}
	set sfr(224) [expr {$result & 255}]

	evaluate_sfr 224
	evaluate_sfr 240
}

## Instruction: NOP
 # @return void
private method ins_nop {} {
	set time 1
	incr_pc 1
}

## Instruction: ORL
 # @parm Int addr	- Register addres
 # @parm Int val	- Operation argument
 # @return void
private method ins_orl {addr val} {
	set time 1
	incr_pc 1

	if {[check_address_validity D $addr]} {return}
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set ram($addr) [expr {$ram($addr) | $val}]
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		set rmw_instruction 1
		write_sfr $addr [expr {[read_sfr $addr] | $val}]
		evaluate_sfr $addr
	}
}

## Instruction: ORL Addr0, Addr1
 # 1st operand must be 224 !
 # @parm Int addr0	- Register addres
 # @parm Int addr1	- Operation argument
 # @return void
private method ins_orl_D {addr0 addr1} {
	if {[check_address_validity D $addr1]} {
		ins_orl $addr0 [undefined_octet]
	} elseif {$addr1 < 128} {
		ins_orl $addr0 $ram($addr1)
	} else {
		ins_orl $addr0 [read_sfr $addr1]
	}
}

## Instruction: ORL .., @Ri
 # @parm Int addr	- Target addres
 # @parm Int addr_id	- Source address (indirect)
 # @return void
private method ins_orl_ID {addr addr_id} {
	set time 1
	incr_pc 1

	if {[check_address_validity D $addr]} {return}
	if {[check_address_validity I $addr_id]} {
		set val [undefined_octet]
	} else {
		set val $ram($addr_id)
	}
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set ram($addr) [expr {$ram($addr) | $val}]
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		set rmw_instruction 1
		write_sfr $addr [expr {[read_sfr $addr] | $val}]
		evaluate_sfr $addr
	}
}

## Instruction: ORL C, /bit
 # @parm Int addr	- Bit address
 # @return void
private method ins_orl_not_bit {addr} {
	set time 2

	if {[check_address_validity B $addr]} {
		setBit $symbol(C) [expr {rand() < 0.5}]
	} elseif {[getBit $symbol(C)] || ![getBit $addr]} {
		setBit $symbol(C) 1
	} else {
		setBit $symbol(C) 0
	}
}

## Instruction: ORL C, bit
 # @parm Int addr	- Bit address
 # @return void
private method ins_orl_bit {addr} {
	set time 2

	if {[check_address_validity B $addr]} {
		setBit $symbol(C) [expr {rand() < 0.5}]
	} elseif {[getBit $symbol(C)] || [getBit $addr]} {
		setBit $symbol(C) 1
	} else {
		setBit $symbol(C) 0
	}
}

## Instruction: POP
 # @parm Int addr	- Register address (target)
 # @return void
private method ins_pop {addr} {
	set time 2
	stepback_save_spec_subprog 6

	if {[check_address_validity D $addr]} {return}
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set ram($addr) [stack_pop]
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		write_sfr $addr [stack_pop]
		evaluate_sfr $addr
	}
}

## Instruction: PUSH
 # @parm Int addr	- Register address (source)
 # @return void
private method ins_push {addr} {
	set time 2
	stepback_save_spec_subprog 5

	if {[check_address_validity D $addr]} {
		stack_push [undefined_octet]
	} elseif {$addr < 128} {
		stack_push $ram($addr)
	} else {
		stack_push $sfr($addr)
	}

	$this stack_monitor_set_last_values_as 0 1
}

## Instruction: RET
 # @return void
private method ins_ret {} {
	set time 2
	stepback_save_spec_subprog 4

	set pch [stack_pop]
	set pcl [stack_pop]

	set pc [expr {($pch << 8) + $pcl}]
	incr run_statistics(7)
	$this subprograms_return 0
}

## Instruction: RETI
 # @return void
private method ins_reti {} {
	set time 2

	if {[llength $inter_in_p_flags]} {
		stepback_save_spec_subprog 3
		set skip_interrupt	1
		set interrupt_on_next	0
		$this interrupt_monitor_reti	[lindex $inter_in_p_flags end]
		set interrupts_in_progress	[lreplace $interrupts_in_progress end end]
		set inter_in_p_flags		[lreplace $inter_in_p_flags end end]
		if {$::GUI_AVAILABLE} {
			if {[llength $interrupts_in_progress]} {
				set vector [format %X [intr2vector [lindex $interrupts_in_progress end]]]
				simulator_Sbar [mc "Interrupt at vector 0x%s  " $vector] 1 $this
			} else {
				simulator_Sbar {} 0 $this
			}
		}
	} else {
		$this simulator_invalid_reti_dlg $pc $Line($pc)
	}

	set pch [stack_pop]
	set pcl [stack_pop]

	set pc [expr {($pch << 8) + $pcl}]
	incr run_statistics(8)
	$this subprograms_return 1
}

## Instruction: RL
 # @return void
private method ins_rl {} {
	set time 1
	incr_pc 1

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	set sfr(224) [expr {$sfr(224) << 1}]
	if {$sfr(224) > 255} {
		incr sfr(224) -255
	}

	evaluate_sfr 224
}

## Instruction: RLC
 # @return void
private method ins_rlc {} {
	set time 1
	incr_pc 1

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	set sfr(224) [expr {$sfr(224) << 1}]

	if {[getBit $symbol(C)]} {
		incr sfr(224)
	}
	if {$sfr(224) > 255} {
		incr sfr(224) -256
		setBit $symbol(C) 1
	} else {
		setBit $symbol(C) 0
	}

	evaluate_sfr 224
}

## Instruction: RR
 # @return void
private method ins_rr {} {
	set time 1
	incr_pc 1

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	if {[expr {$sfr(224) % 2}]} {
		set C 1
	} else {
		set C 0
	}

	set sfr(224) [expr {$sfr(224) / 2}]

	if {$C} {incr sfr(224) 128}

	evaluate_sfr 224
}

## Instruction: RRC
 # @return void
private method ins_rrc {} {
	set time 1
	incr_pc 1

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	if {[expr {$sfr(224) % 2}]} {
		set C 1
	} else {
		set C 0
	}

	set sfr(224) [expr {$sfr(224) / 2}]

	if {[getBit $symbol(C)]} {
		incr sfr(224) 128
	}

	if {$C} {
		setBit $symbol(C) 1
	} else {
		setBit $symbol(C) 0
	}

	evaluate_sfr 224
}

## Instruction: SETB
 # @parm String opr	- Bit address or 'C'
 # @return void
private method ins_setb {opr} {
	set time 1
	incr_pc 1

	if {$opr == {C}} {
		setBit $symbol(C) 1
	} else {
		if {[check_address_validity B $opr]} {return}
		set rmw_instruction 1
		setBit $opr 1
	}
}

## Instruction: SJMP
 # @parm Int roff	- Relative offset for jump
 # @return void
private method ins_sjmp {roff} {
	set time 2

	if {$roff > 127} {incr roff -256}
	incr_pc $roff
}

## Instruction: SUBB A, ...
 # @parm Int val	- Value
 # @return void
private method ins_subb {val} {
	set time 1
	incr_pc 1
	alo_subb $val

	evaluate_sfr 224
}

## Instruction: SUBB A, Addr
 # @parm Int addr	- Value
 # @return void
private method ins_subb_D {addr} {
	if {[check_address_validity D $addr]} {
		ins_subb [undefined_octet]
	} elseif {$addr < 128} {
		ins_subb $ram($addr)
	} else {
		ins_subb $sfr($addr)
	}
}

## Instruction: SUBB A, @Ri
 # @parm Int addr	- Indirect address
 # @return void
private method ins_subb_ID {addr} {
	set time 1
	incr_pc 1
	if {[check_address_validity I $addr]} {
		ins_subb [undefined_octet]
	} else {
		alo_subb $ram($addr)
	}
	evaluate_sfr 224
}

## Instruction: SWAP
 # @return void
private method ins_swap {} {
	set time 1
	incr_pc 1

	set lo [expr {$sfr(224) & 15}]
	set hi [expr {($sfr(224) & 240) >> 4}]

	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}
	set sfr(224) [expr {($lo << 4) + $hi}]

	evaluate_sfr 224
}

## Instruction: XCH
 # @parm Int addr	- Register address
 # @return void
private method ins_xch {addr} {
	set time 1
	incr_pc 1

	if {[check_address_validity D $addr]} {return}
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}

	set A $sfr(224)
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set sfr(224) $ram($addr)
		set ram($addr) $A
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		set sfr(224) [read_sfr $addr]
		write_sfr $addr $A
		evaluate_sfr $addr
	}
	evaluate_sfr 224
}

## Instruction: XCH @Ri
 # @parm Int addr	- Register address (indirect addressing)
 # @return void
private method ins_xch_ID {addr} {
	set time 1
	incr_pc 1

	if {[check_address_validity I $addr]} {return}
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
		stepback_reg_change I $addr
	}

	set A $sfr(224)
	set sfr(224) $ram($addr)
	set ram($addr) $A

	evaluate_sfr 224
	if {$sync_ena} {
		$this Simulator_sync_reg $addr
	}
}

## Instruction: XCHD
 # @parm Int addr	- Register address
 # @return void
private method ins_xchd {addr} {
	set time 1
	incr_pc 1

	if {[check_address_validity I $addr]} {
		set val [undefined_octet]
	} elseif {$addr < 128} {
		set val $ram($addr)
	} else {
		set val $sfr($addr)
	}
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
		if {$addr < 128} {
			stepback_reg_change I $addr
		} else {
			stepback_reg_change S $addr
		}
	}

	set nibble0 [expr {$sfr(224) & 15}]
	set nibble1 [expr {$val & 15}]

	set sfr(224) [expr {($sfr(224) & 240) + $nibble1}]
	set val [expr {($val & 240) + $nibble0}]
	if {$addr < 128} {
		set ram($addr) $val
	} else {
		set sfr($addr) $val
	}

	evaluate_sfr 224
	if {$sync_ena} {
		$this Simulator_sync_reg $addr
	}
}

## Instruction: XRL
 # @parm Int addr	- Register address
 # @parm Int val	- Operation argument
 # @return void
private method ins_xrl {addr val} {
	set time 1
	incr_pc 1

	if {[check_address_validity D $addr]} {return}
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set ram($addr) [expr {$ram($addr) ^ $val}]
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		set rmw_instruction 1
		write_sfr $addr [expr {[read_sfr $addr] ^ $val}]
		evaluate_sfr $addr
	}
}

## Instruction: XRL ..., addr
 # @parm Int addr0	- Target register
 # @parm Int addr1	- Source register
 # @return void
private method ins_xrl_D {addr0 addr1} {
	if {[check_address_validity D $addr1]} {
		ins_xrl $addr0 [undefined_octet]
	} elseif {$addr1 < 128} {
		ins_xrl $addr0 $ram($addr1)
	} else {
		ins_xrl $addr0 [read_sfr $addr1]
	}
}

## Instruction: XRL .., @Ri
 # @parm Int addr	- Register address
 # @parm Int addr_id	- Indirect address
 # @return void
private method ins_xrl_ID {addr addr_id} {
	set rmw_instruction 1
	set time 1
	incr_pc 1

	if {[check_address_validity I $addr_id]} {
		set val [undefined_octet]
	} else {
		set val $ram($addr_id)
	}
	if {$addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}
		set ram($addr) [expr {$ram($addr) ^ $val}]
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}
	} else {
		set rmw_instruction 1
		write_sfr $addr [expr {[read_sfr $addr] ^ $val}]
		evaluate_sfr $addr
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard
