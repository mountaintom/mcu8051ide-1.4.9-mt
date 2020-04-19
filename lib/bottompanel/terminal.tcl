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
if { ! [ info exists _TERMINAL_TCL ] } {
set _TERMINAL_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides terminal emulator for bottom notebook
# --------------------------------------------------------------------------

class Terminal {
	# Terminal emulator configuration
	public common configuration
	public common configuration_def [subst {
		bg		#FFFFFF
		fg		#000000
		font_size	12
		font_family	{$::DEFAULT_FIXED_FONT}
	}]

	private variable terminal_counter	0	;# Int: Counter of terminal emulator instances
	private variable terminal_frame			;# Widget: ID of terminal container frame
	private variable wrapper_frame			;# Widget: Wrapper frame for $terminal_frame
	private variable parent				;# Widget: Parent frame
	private variable term_gui_initialized	0	;# Bool: GUI initialized
	private variable terminal_pid		{}	;# Int: PID of terminal emulator

	destructor {
		terminal_kill_childern
	}

	## Prepare this tab for GUI creation
	 # @parm Widget _parent -
	 # @return void
	public method PrepareTerminal {_parent} {
		set parent $_parent
		set term_gui_initialized 0
	}

	## Inform this tab than it has became active
	 # @return void
	public method TerminalTabRaised {} {
		focus $terminal_frame
	}

	## Create GUI
	 # @return void
	public method CreateTerminalEmulGUI {} {
		if {$term_gui_initialized || !${::PROGRAM_AVAILABLE(urxvt)}} {return}
		set term_gui_initialized 1

		set wrapper_frame [frame $parent.wrapper_frame -relief sunken -bd 2]
		pack $wrapper_frame -fill both -expand 1
		terminal_recreate_terminal
		unset parent
	}

	## Internal procedure -- (re)create frame with terminal emulator
	 # @return void
	public method terminal_recreate_terminal {} {
		if {![winfo exists $wrapper_frame]} {return}
		set terminal_frame [frame $wrapper_frame.terminal_frame_${terminal_counter} -container 1]
		bind $terminal_frame <Destroy> "$this terminal_recreate_terminal"

		set pwd [pwd]
		if {[catch {
			cd [$this cget -projectPath]
		}]} then {
			cd ~
		}
		if {[catch {
			set terminal_pid [exec -- urxvt				\
				-embed [expr [winfo id $terminal_frame]]	\
				-sr -b 0 -w 0 -bg ${configuration(bg)}		\
				-fg ${configuration(fg)}			\
				-fn "xft:$configuration(font_family):pixelsize=$configuration(font_size)" & \
			]
		} result]} then {
			tk_messageBox		\
				-parent .	\
				-icon warning	\
				-type ok	\
				-title [mc "Unable to find urxvt"]	\
				-message [mc "Unable to execute program \"urxvt\", terminal emulator is eiter not available or badly configured."]
			puts stderr $result
		}
		cd $pwd
		pack $terminal_frame -fill both -expand 1
		incr terminal_counter
	}

	## Restart terminal emulator
	 # @return void
	public method terminal_restart {} {
		if {!$term_gui_initialized} {return}
		if {!${::PROGRAM_AVAILABLE(urxvt)}} {return}
		foreach pid $terminal_pid {
			if {$pid == [pid] || $pid == 0} {
				continue
			}
			catch {
				exec -- kill $pid
			}
		}
	}

	## Kill terminal emulator
	 # @return void
	public method terminal_kill_childern {} {
		if {$term_gui_initialized} {
			if {[info exists terminal_frame] && [winfo exists $terminal_frame]} {
				bind $terminal_frame <Destroy> {}
			}
			foreach pid $terminal_pid {
				if {$pid == [pid] || $pid == 0} {
					continue
				}
				catch {
					exec -- kill $pid
				}
			}
		}
	}
}

# Initialize NS variables
array set ::Terminal::configuration ${::Terminal::configuration_def}

# >>> File inclusion guard
}
# <<< File inclusion guard
