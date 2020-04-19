#!/usr/bin/tclsh

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
if { ! [ info exists _MATH_TCL ] } {
set _MATH_TCL _
# <<< File inclusion guard
# --------------------------------------------------------------------------
# DESCRIPTION
# Primarily implements convertions between numeric systems and angle units.
# --------------------------------------------------------------------------

## ----------------------------------------------------------------------
## Converts between numeric systems and checks numbers types
 #
 # Supported num. systems: binary, octal, decimal, hexadecimal and ASCII.
 # note: Excepting H->Q and Q->H, are all convertions computed
 #       directly (for speed improvement).
 #       By default maximal number length after dot is 20 (for DEC -> ...).
 # ----------------------------------------------------------------------
 #
 # USAGE:
 #
 #	puts [ NumSystem::hex2dec F.4	]	;# --> 15.25
 #	puts [ NumSystem::hex2oct F.4	]	;# --> 17.2
 #	puts [ NumSystem::hex2bin F.4	]	;# --> 1111.01
 #
 #	puts [ NumSystem::dec2hex 15.25	]	;# --> F.4
 #	puts [ NumSystem::dec2oct 15.25	]	;# --> 17.2
 #	puts [ NumSystem::dec2bin 15.25	]	;# --> 1111.01
 #
 #	puts [ NumSystem::oct2hex 17.2	]	;# --> F.4
 #	puts [ NumSystem::oct2dec 17.2	]	;# --> 15.25
 #	puts [ NumSystem::oct2bin 17.2	]	;# --> 1111.01
 #
 #	puts [ NumSystem::bin2hex 1111.01 ]	;# --> F.4
 #	puts [ NumSystem::bin2dec 1111.01 ]	;# --> 15.25
 #	puts [ NumSystem::bin2oct 1111.01 ]	;# --> 17.2
 #
 #	puts [ NumSystem::ascii2dec @ ]		;# --> 64
 #	puts [ NumSystem::ascii2bin @ ]		;# --> 01000000
 #
 #	puts [ NumSystem::ishex F.4	]	;# --> 1
 #	puts [ NumSystem::isdec 15.25	]	;# --> 1
 #	puts [ NumSystem::isoct 17.2	]	;# --> 1
 #	puts [ NumSystem::isbin 1111.01	]	;# --> 1
 # -----------------------------------------------------------------------

namespace eval NumSystem {

	variable precision	{20}		;# maximal number of digits after dot

	# -----------------------------------------------------------------------
	# NUMERIC SYSTEMS CONVERTIONS
	# -----------------------------------------------------------------------

	# HEX -> ...

	## Hexadecimal -> Decimal
	 # required procedures: `is_X', `hexoct_to_dec', `aux_hexoct_to_dec', `asserthex', `ishex'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc hex2dec {number} {
		return [hexoct_to_dec 16 $number]
	}

	## Hexadecimal -> Octal
	 # required procedures: `is_X', `bin2oct', `hex2bin', `asserthex', `assertbin', `ishex', isbin'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc hex2oct {number} {
		return [bin2oct [hex2bin $number]]
	}

	## Hexadecimal -> Binary
	 # required procedures: `asserthex', `ishex'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc hex2bin {number} {

		# verify value validity
		asserthex $number

		# Number can be negative value
		set sign {}
		if {[string index $number 0] == {-}} {
			set number [string range $number 1 end]
			set sign {-}
		}

		# make it upper-case
		set number [string toupper $number]

		# split value to list of chars
		set number [split $number ""]

		# convert value
		set result {}
		foreach char $number {
			switch $char {
				{0}	{append result {0000}}
				{1}	{append result {0001}}
				{2}	{append result {0010}}
				{3}	{append result {0011}}
				{4}	{append result {0100}}
				{5}	{append result {0101}}
				{6}	{append result {0110}}
				{7}	{append result {0111}}
				{8}	{append result {1000}}
				{9}	{append result {1001}}
				{A}	{append result {1010}}
				{B}	{append result {1011}}
				{C}	{append result {1100}}
				{D}	{append result {1101}}
				{E}	{append result {1110}}
				{F}	{append result {1111}}
				{.}	{append result {.}}
			}
		}

		# return result
		regsub {^0+} $result {} result
		if {[regexp {\.} $result]} {
			regsub {0+$} $result {} result
		}
		regsub {\.$} $result {} result
		regsub {^\.} $result {0.} result
		if {[string length $result] == 0} {
			set result 0
		}
		return $sign$result
	}

	# DEC -> ...

	## Decimal -> Hexadecimal
	 # required procedures: `is_X', `assertdec', isdec'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc dec2hex {number} {
		return [dec_to_X 16 $number]
	}

	## Decimal -> Octal
	 # required procedures: `is_X', `assertdec', isdec'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc dec2oct {number} {
		return [dec_to_X 8 $number]
	}

	## Decimal -> Binary
	 # required procedures: `is_X', `assertdec', `isdec'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc dec2bin {number} {
		return [dec_to_X 2 $number]
	}

	# OCT -> ...

	## Octal -> Hexadecimal
	 # required procedures: `is_X', `bin2hex', `oct2bin', `bin_to_hexoct',
	 #   `aux_hexoct_to_dec', `assertoct', `assertbin',`isbin',`isoct'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc oct2hex {number} {
		return [bin2hex [oct2bin $number]]
	}

	## Octal -> Decimal
	 # required procedures: `is_X', `bin_to_hexoct', `aux_hexoct_to_dec', `assertoct',`isoct'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc oct2dec {number} {
		return [hexoct_to_dec 8 $number]
	}

	## Octal -> Binary
	 # required procedures: `is_X', `assertoct', isoct'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc oct2bin {number} {

		# verify value validity
		assertoct $number

		# Number can be negative value
		set sign {}
		if {[string index $number 0] == {-}} {
			set number [string range $number 1 end]
			set sign {-}
		}

		# split value to list of chars
		set number [split $number ""]

		# convert value
		set result {}
		foreach char $number {
			switch $char {
				{0}	{append result {000}}
				{1}	{append result {001}}
				{2}	{append result {010}}
				{3}	{append result {011}}
				{4}	{append result {100}}
				{5}	{append result {101}}
				{6}	{append result {110}}
				{7}	{append result {111}}
				{.}	{append result {.}}
			}
		}

		# return result
		regsub {^0+} $result {} result
		if {[regexp {\.} $result]} {
			regsub {0+$} $result {} result
		}
		regsub {\.$} $result {} result
		regsub {^\.} $result {0.} result
		if {[string length $result] == 0} {
			set result 0
		}
		return $sign$result
	}

	# BIN -> ...

	## Binary -> Hexadecimal
	 # required procedures: `is_X', `assertbin', isbin', `bin_to_hexoct'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc bin2hex {number} {
		assertbin $number			;# verify value validity
		return [bin_to_hexoct 16 $number]	;# convert value
	}

	## Binary -> Decimal
	 # required procedures: `is_X', `assertbin', isbin'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc bin2dec {number} {

		# verify value validity
		assertdec $number

		# Number can be negative value
		set sign {}
		if {[string index $number 0] == {-}} {
			set number [string range $number 1 end]
			set sign {-}
		}

		# split value to int. part
		regexp {^\d+} $number int

		# split value to frac. part
		if {[regexp {\.\d+$} $number frac]} {
			set frac [string range $frac 1 end]
			set nofrac 0
		} else {
			set frac {}
			set nofrac 1
		}

		# compute int. part
		set tmp [expr [string length $int] -1]
		regexp {^\d+} [expr pow(2,$tmp)] tmp
		set result 0
		foreach value [split $int ""] {
			if {$value} {
				set result [expr {$result+$tmp}]
			}
			set tmp [expr {$tmp / 2}]
			if {$tmp == 0} {break}
		}
		set int $result

		# compute frac. part
		if {!$nofrac} {
			set tmp 0.5
			set result 0
			foreach value [split $frac ""] {
				if {$value} {
					set result [expr {$result+$tmp}]
				}
				set tmp [expr {$tmp / 2}]
			}
			regexp {\d+$} $result frac

			# return converted value with frac.
			return $sign$int.$frac
		}

		# return converted value without frac.
		return $sign$int
	}

	## Binary -> Octal
	 # required procedures: `is_X', `assertbin', isbin', `bin_to_hexoct'
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc bin2oct {number} {
		assertbin $number			;# verify value validity
		return [bin_to_hexoct 8 $number]	;# convert value
	}

	## Ascii char -> Bin
	 # required procedures: (none)
	 # @parm Char number - value to convert
	 # @return mixed - converted value or an empty string
	proc ascii2bin {number} {
		if {[string bytelength $number] != 1} {
			return {}
		}

		set result {}
		scan $number {%c} result
		if {$result != {}} {
			return [dec2bin $result]
		}

		return $result
	}

	## Ascii char -> Dec
	 # required procedures: (none)
	 # @parm Char number - value to convert
	 # @return mixed - converted value or an empty string
	proc ascii2dec {number} {
		if {[string bytelength $number] != 1} {
			return {}
		}
		set result {}
		scan $number {%c} result

		return $result
	}

	# -----------------------------------------------------------------------
	# TYPE ASSERTION
	# -----------------------------------------------------------------------

	## Raise error if the given string is not an hexadecimal value
	 # require procedures: `is_X',`ishex'
	 # @parm String number - string to evaluate
	 # @return mixed - void (failure) or 1 (successful)
	proc asserthex {number} {
		if {![ishex $number]} {
			error "asserthex: Excepted hexadecimal value but got \"$number\""
		} else {
			return 1
		}
	}

	## Raise error if the given string is not an decimal value
	 # require procedures: `is_X',`isdec'
	 # @parm String number - string to evaluate
	 # @return mixed - void (failure) or 1 (successful)
	proc assertdec {number} {
		if {![isdec $number]} {
			error "assertdec: Excepted decimal value but got \"$number\""
		} else {
			return 1
		}
	}

	## Raise error if the given string is not an octal value
	 # require procedures: `is_X',`isoct'
	 # @parm String number - string to evaluate
	 # @return mixed - void (failure) or 1 (successful)
	proc assertoct {number} {
		if {![isoct $number]} {
			error "assertoct: Excepted octal value but got \"$number\""
		} else {
			return 1
		}
	}

	## Raise error if the given string is not an binary value
	 # require procedures: `is_X',`isbin'
	 # @parm String number - string to evaluate
	 # @return mixed - void (failure) or 1 (successful)
	proc assertbin {number} {
		if {![isbin $number]} {
			error "assertbin: Excepted binary value but got \"$number\""
		} else {
			return 1
		}
	}

	# -----------------------------------------------------------------------
	# TYPE CHECKING
	# -----------------------------------------------------------------------

	## Check if the given string can be an Hexadecimal value
	 # require procedure: `is_X'
	 # @parm String number - value to evaluate
	 # @return bool
	proc ishex {number} {
		return [is_X {^[0-9A-Fa-f\.]+$} $number]
	}

	## Check if the given string can be an Decimal value
	 # require procedure: `is_X'
	 # @parm String number - value to evaluate
	 # @return bool
	proc isdec {number} {
		return [is_X {^[0-9\.]+$} $number]
	}

	## Check if the given string can be an Octal value
	 # require procedure: `is_X'
	 # @parm String number - value to evaluate
	 # @return bool
	proc isoct {number} {
		return [is_X {^[0-7\.]+$} $number]
	}

	## Check if the given string can be an Binary value
	 # require procedure: `is_X'
	 # @parm String number - value to evaluate
	 # @return bool
	proc isbin {number} {
		return [is_X {^[01\.]+$} $number]
	}

	# -----------------------------------------------------------------------
	# AUXILIARY PROCEDURES
	# -----------------------------------------------------------------------

	## Auxiliary procedure for convering hex. and oct. to dec.
	 # require procedures: `is_X',`aux_hexoct_to_dec', `assertoct', `asserthex', `ishex', `isoct'
	 # @access PRIVATE
	 # @parm base - source numeric system, posible values are: 8 and 16
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc hexoct_to_dec {base number} {

		# Number can be negative value
		set sign {}
		if {[string index $number 0] == {-}} {
			set number [string range $number 1 end]
			set sign {-}
		}

		# make number upper-case
		set number [string toupper $number]

		# verify value validity
		if {$base == 8} {
			assertoct $number
			set char_len 3
		} else {
			asserthex $number
			set char_len 4
		}

		# split value to int. part
		regexp {^[^\.]+} $number int

		# split value to frac. part
		if {[regexp {\.[^\.]+$} $number frac]} {
			set frac [string range $frac 1 end]
			set nofrac 0
		} else {
			set frac {}
			set nofrac 1
		}

		# compute int. part
		if {$base == 8} {
			set int [expr "0$int"]
		} else {
			set int [expr "0x$int"]
		}

		# compute frac. part
		if {!$nofrac} {
			set frac [aux_hexoct_to_dec [split $frac {}] 1.0 $base]
			regexp {\d+$} $frac frac
			return $sign$int.$frac
		}
		return $sign$int
	}

	## Auxiliary procedure for convering hex. and oct. to dec.
	 # require procedures: none
	 # @access PRIVATE
	 # @parm List vals_list - value to convert splited to a single characters
	 # @parm Number v0 - decimal value of highes bit in the number multipled by 2
	 # @parm base - source numeric system, posible values are: 8 and 16
	 # @return Number - converted value
	proc aux_hexoct_to_dec {vals_list v0 base} {
		set result 0

		foreach char $vals_list {

			if {$base == 8} {
				set v3 $v0
			} else {
				set v3 [expr {$v0 / 2}]
			}
			set v2 [expr {$v3 / 2}]
			set v1 [expr {$v2 / 2}]
			set v0 [expr {$v1 / 2}]

			switch $char {
				{0}	{set bool_map {0 0 0 0}}
				{1}	{set bool_map {0 0 0 1}}
				{2}	{set bool_map {0 0 1 0}}
				{3}	{set bool_map {0 0 1 1}}
				{4}	{set bool_map {0 1 0 0}}
				{5}	{set bool_map {0 1 0 1}}
				{6}	{set bool_map {0 1 1 0}}
				{7}	{set bool_map {0 1 1 1}}
				{8}	{set bool_map {1 0 0 0}}
				{9}	{set bool_map {1 0 0 1}}
				{A}	{set bool_map {1 0 1 0}}
				{B}	{set bool_map {1 0 1 1}}
				{C}	{set bool_map {1 1 0 0}}
				{D}	{set bool_map {1 1 0 1}}
				{E}	{set bool_map {1 1 1 0}}
				{F}	{set bool_map {1 1 1 1}}
			}

			foreach cond $bool_map value "$v3 $v2 $v1 $v0" {
				if {$cond} {
					set result [expr {$result+$value}]
				}
			}
		}
		return $result
	}

	## Auxiliary procedure for convering bin. to hex. and oct.
	 # require procedures: none
	 # @access PRIVATE
	 # @parm Int base - target numeric system, posible values are: 8 and 16
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc bin_to_hexoct {base number} {

		# Number can be negative value
		set sign {}
		if {[string index $number 0] == {-}} {
			set number [string range $number 1 end]
			set sign {-}
		}

		# set some essential variables
		if {$base == 8} {
			set modulo 3
			set mod_1 2
			set padding {}
			set convCmd {oct_to_bin}
		} else {
			set modulo 4
			set mod_1 3
			set padding {0}
			set convCmd {hex_to_bin}
		}

		# split value to int. and frac. part
		regexp {^\d+} $number int
		if {[regexp {\.\d+$} $number frac]} {
			set frac [string range $frac 1 end]
			set nofrac 0
		} else {
			set frac {}
			set nofrac 1
		}

		# convert int
		set result {}

		set length [string length $int]
		set length [expr {($length % $modulo) - 1}]
		if {$length >= 0} {
			set firstvalue [string range $int 0 $length]
			set int [string range $int [expr {$length + 1}] end]

			switch $length {
				{0}	{set firstvalue "${padding}00$firstvalue"}
				{1}	{set firstvalue "${padding}0$firstvalue"}
				{2}	{set firstvalue "${padding}$firstvalue"}
			}

			lappend result $firstvalue
		}

		while {$int != ""} {
			lappend result [string range $int 0 $mod_1]
			set int [string range $int $modulo end]
		}

		set int [$convCmd $result]
		regsub {^0+} $int {} int
		if {$int == {}} {set int 0}

		# convert frac
		set result {}
		if {!$nofrac} {
			# make list
			set idx -1
			while {$frac != ""} {
				lappend result [string range $frac 0 $mod_1]
				set frac [string range $frac $modulo end]
				incr idx
			}

			set lastValue [lindex $result $idx]
			switch [string length $lastValue] {
				{1}	{lset result $idx "${lastValue}${padding}00"}
				{2}	{lset result $idx "${lastValue}${padding}0"}
				{3}	{lset result $idx "${lastValue}${padding}"}
			}

			set frac [$convCmd $result]
			regsub {0+$} $frac {} frac
			if {$frac == {}} {set frac 0}

			# return converted value with frac.
			return $sign$int.$frac
		}

		# return converted value without frac.
		return $sign$int
	}

	## Auxiliary procedure for convering dec to hex, oct, bin
	 # require procedures: `is_X', `assertdec', `isdec'
	 # @access PRIVATE
	 # @parm Int base - target numeric system, posible values are: 2, 8, 10, 16
	 # @parm Number number - value to convert
	 # @return Number - converted value
	proc dec_to_X {base number} {
		variable precision

		# verify values validity
		if {!($base==16 || $base==10 || $base==8 || $base==2)} {
			error "dec_to_X: Unrecognized numeric system \"$base\". Possible values are: 2, 8, 10, 16"
		}
		assertdec $number

		# Number can be negative value
		set sign {}
		if {[string index $number 0] == {-}} {
			set number [string range $number 1 end]
			set sign {-}
		}

		# split value to int. and frac. part
		regexp {^\d+} $number int
		if {[regexp {\.\d+$} $number frac]} {
			set frac [string range $frac 1 end]
			set nofrac 0
		} else {
			set frac {}
			set nofrac 1
		}

		if {[string length $int] > 12} {
			error "Unable to convert, value is too high"
		}

		# convert integer part
		set reminder $int
		set int ""
		while {$reminder > 0} {
			set tmp [expr {$reminder % $base}]
			if {$base == 16} {
				switch $tmp {
					10	{set tmp A}
					11	{set tmp B}
					12	{set tmp C}
					13	{set tmp D}
					14	{set tmp E}
					15	{set tmp F}
				}
			}
			set int ${tmp}${int}
			regexp {^\d+} [expr {$reminder / $base}] reminder
		}
		if {$int == {}} {set int 0}

		# convert frac. part
		if {!$nofrac} {
			set reminder "0.$frac"
			set frac ""
			for {set i 0} {$i < $precision} {incr i} {
				set reminder [expr {$reminder * $base}]
				regexp {^\d+} $reminder tmp
				set reminder [expr {$reminder - $tmp}]
				if {$base == 16} {
					switch $tmp {
						10	{set tmp A}
						11	{set tmp B}
						12	{set tmp C}
						13	{set tmp D}
						14	{set tmp E}
						15	{set tmp F}
					}
				}
				append frac $tmp
				if {$reminder == 0} {break}
			}
			if {$frac == {}} {set frac 0}

			# return converted value with frac.
			return $sign$int.$frac
		}

		# return converted value without frac.
		return $sign$int
	}

	## Auxiliary procedure for convering oct to bin
	 # require procedures: none
	 # @access PRIVATE
	 # @parm List vals_list - value to convert splited to single characters
	 # @return Number - converted value
	proc oct_to_bin {vals_list} {

		# iterate over items in list and traslate them
		set result ""
		foreach char $vals_list {
			# convert item
			switch $char {
				{000}	{append result 0}
				{001}	{append result 1}
				{010}	{append result 2}
				{011}	{append result 3}
				{100}	{append result 4}
				{101}	{append result 5}
				{110}	{append result 6}
				{111}	{append result 7}
			}
		}

		# done
		return $result
	}

	## Auxiliary procedure for convering hex to bin
	 # require procedures: none
	 # @access PRIVATE
	 # @parm List vals_list - value to convert splited to single characters
	 # @return Number - converted value
	proc hex_to_bin {vals_list} {

		# iterate over items in list and traslate them
		set result ""
		foreach char $vals_list {
			# convert item
			switch $char {
				{0000}	{append result 0}
				{0001}	{append result 1}
				{0010}	{append result 2}
				{0011}	{append result 3}
				{0100}	{append result 4}
				{0101}	{append result 5}
				{0110}	{append result 6}
				{0111}	{append result 7}
				{1000}	{append result 8}
				{1001}	{append result 9}
				{1010}	{append result A}
				{1011}	{append result B}
				{1100}	{append result C}
				{1101}	{append result D}
				{1110}	{append result E}
				{1111}	{append result F}
			}
		}

		# done
		return $result
	}

	## Auxiliary procedure for num. checking
	 # Check if the given string contain 0 or 1 dot and match the given
	 # regular expression
	 # @access PRIVATE
	 # @parm String regexpr - reg. exp. of allowed symbols
	 # @parm String number - string to evaluate
	 # return bool
	proc is_X {regexpr number} {

		# The given number can begin with minus sign
		if {[string index $number 0] == {-}} {
			set number [string range $number 1 end]
		}

		# 1st condition (check for allowed symbols)
		if {![regexp $regexpr $number]} {
			return 0
		}

		# 2nd condition (must contain maximaly one dot)
		set cnd1 [split $number {\.}]
		if {[llength $cnd1] > 2} {
			return 0
		}

		# 3rd condition (dot must not be at the beginning or end)
		if {[regexp {^\.} $number]} {return 0}
		if {[regexp {\.$} $number]} {return 0}

		# return result
		return 1
	}
}


## ----------------------------------------------------------------------
## Converts between angle units and normalizes angle values
 #
 # Supported angle units: rad, deg, grad
 # note: all converted angles are normalized before convertion
 # -----------------------------------------------------------------------
 #
 # USAGE:
 #
 #	puts [ Angle::adjustAngle deg -700 ]	;# --> 20.0000000016 (should be exactly 20)
 #
 #	puts [ Angle::rad2deg	$Angle::PI]	;# --> 180.0
 #	puts [ Angle::rad2grad	$Angle::PI]	;# --> 200.0
 #
 #	puts [ Angle::deg2rad	180	]	;# --> 3.141592654
 #	puts [ Angle::deg2grad	180	]	;# --> 200.0
 #
 #	puts [ Angle::grad2deg	200	]	;# --> 180.0
 #	puts [ Angle::grad2rad	200	]	;# --> 3.141592654
 #
 #	puts $Angle::PI				;# --> 3.141592654
 # -----------------------------------------------------------------------

namespace eval Angle {

	variable PI		{3.141592654}	;# Pi

	# CONVERSION OF ANGLE VALUES
	# --------------------------

	## Radians -> Degrees
	 # require procedure: `adjustAngle'
	 # @parm Number angle - angle value to convert
	 # @return Nubmber - converted value
	proc rad2deg {angle} {
		variable PI

		set angle [adjustAngle rad $angle]
		return [expr {(180 / $PI) * $angle}]
	}

	## Radians -> GRAD
	 # require procedure: `adjustAngle'
	 # @parm Number angle - angle value to convert
	 # @return Nubmber - converted value
	proc rad2grad {angle} {
		variable PI

		set angle [adjustAngle rad $angle]
		return [expr {(200 / $PI) * $angle}]
	}

	## Degrees -> Radians
	 # require procedure: `adjustAngle'
	 # @parm Number angle - angle value to convert
	 # @return Nubmber - converted value
	proc deg2rad {angle} {
		variable PI

		set angle [adjustAngle deg $angle]
		return [expr {($PI / 180) * $angle}]
	}

	## Degrees -> Radians
	 # require procedure: `adjustAngle'
	 # @parm Number angle - angle value to convert
	 # @return Nubmber - converted value
	proc deg2grad {angle} {
		set angle [adjustAngle deg $angle]
		return [expr {(10 / 9.0) * $angle}]
	}

	## GRAD -> Degrees
	 # require procedure: `adjustAngle'
	 # @parm Number angle - angle value to convert
	 # @return Nubmber - converted value
	proc grad2deg {angle} {
		set angle [adjustAngle grad $angle]
		return [expr {0.9 * $angle}]
	}

	## GRAD -> Radians
	 # require procedure: `adjustAngle'
	 # @parm Number angle - angle value to convert
	 # @return Nubmber - converted value
	proc grad2rad {angle} {
		variable PI

		set angle [adjustAngle grad $angle]
		return [expr {($PI / 200) * $angle}]
	}

	## Ajust angle value and polarity
	 # @parm String unit - unit of angle (rad | deg | grad)
	 # @parm angle angle - value of angle
	 # @return angle - adjusted angle value
	proc adjustAngle {unit angle} {
		variable PI

		# verify if the given angle is a valid number
		if {![regexp {^\-?\d+(\.\d+)?$} $angle]} {
			error "adjustAngle: Excepted integer or float but got \"$angle\""
		}

		# determinate base for division
		switch $unit {
			{rad}	{set base [expr {$PI * 2}]}
			{deg}	{set base 360.0}
			{grad}	{set base 400.0}
			default	{error "Unrecognized option \"$unit\""}
		}

		# is negative or something else ?
		if {$angle < 0} {
			set minus 1
		} else {
			set minus 0
		}

		# adjust angle value
		set angle [expr {$angle / $base}]
		regsub {^[-]?\d+} $angle {0} angle
		set angle [expr {$angle * $base}]

		# adjust angle polarity
		if {$minus} {return [expr {$base - $angle}]}
		return $angle
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard
