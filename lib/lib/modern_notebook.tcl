#! /usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2012 by Martin Ošmera                                   #
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

proc ModernNoteBook {pathname args} {
	if {[llength $args]} {
		return [ModernNoteBookClass #auto $pathname $args]
	} else {
		return [ModernNoteBookClass #auto $pathname]
	}
}
class ModernNoteBookClass {
	public common font_size	12
	public common button_font [font create -family {helvetica} -size [expr {int(-$font_size * $::font_size_factor)}] -weight {normal}]

	private variable button_counter		0
	private variable tab_but_enter_cmd	{}
	private variable tab_but_leave_cmd	{}
	private variable event_bindings		[list]
	private variable common_tab_but_width	0
	private variable common_tab_but_height	0
	private variable scroll_buttons_visible	0
	private variable total_tabbar_width	0
	private variable last_width		-1

	private variable pages			[list]
	private variable options

	private variable current_page		-1
	private variable tabbar_hidden		0

	private variable main_frame
	private variable tab_bar_frame
	private variable pages_area_frame
	private variable pages_area_frame_f
	private variable tab_bar_frame_left
	private variable tab_bar_frame_middle
	private variable tab_bar_frame_middle_sc
	private variable tab_bar_frame_right
	private variable tab_bar_frame_left_b
	private variable tab_bar_frame_right_b

	constructor {pathname args} {
		set options(pathname)		$pathname
		set options(homogeneous)	0
		set options(autohide)		0
		set options(tabpady)		0
		set options(nomanager)		0

		set args [lindex $args 0]
		set length [llength $args]
		for {set i 0; set j 1} {$i < $length} {incr i 2; incr j 2} {
			set attr [lindex $args $i]
			set val [lindex $args $j]

			switch -- $attr {
				{-homogeneous} {
					if {![string is boolean $val]} {
						error "Argument to option $attr must be a boolean."
					}
					set options(homogeneous) $val
				}
				{-autohide} {
					if {![string is boolean $val]} {
						error "Argument to option $attr must be a boolean."
					}
					set options(autohide) $val
				}
				{-tabpady} {
					if {![string is digit $val]} {
						error "Argument to option $attr must be an integer."
					}
					set options(tabpady) $val
				}
				{-nomanager} {
					if {![string is boolean $val]} {
						error "Argument to option $attr must be a boolean."
					}
					set options(nomanager) $val
				}
				{-font} {
					set button_font $val
					set font_size [expr {abs([font configure $val -size])}]
				}
				default {
					error "Unknown argument: $attr"
				}
			}
		}

		set main_frame [frame $pathname]
		set tab_bar_frame [frame $main_frame.tab_bar_frame]
		set pages_area_frame_f [frame $main_frame.pages_area_frame -bd 1 -relief raised]
		pack $pages_area_frame_f -side bottom -fill both -expand 1
		set pages_area_frame [PagesManager $pages_area_frame_f.pages_manager]

		set tab_bar_frame_right [frame $tab_bar_frame.right_frame]
		set tab_bar_frame_middle [frame $tab_bar_frame.middle_frame]

		if {!$options(autohide)} {
			pack $tab_bar_frame -side top -fill both -before $pages_area_frame_f
		} else {
			set tabbar_hidden 1
			$pages_area_frame_f configure -bd 0
		}
		if {!$options(nomanager)} {
			pack $pages_area_frame -side bottom -fill both -expand 1
		} else {
			pack forget $pages_area_frame_f
		}

		pack $tab_bar_frame_right -side right -fill y
		pack $tab_bar_frame_middle -fill x -expand 1 -side left -after $tab_bar_frame_right

		set tab_bar_frame_middle [ScrollableFrame $tab_bar_frame_middle.inner_frame -height $common_tab_but_height]
		set tab_bar_frame_middle_sc [$tab_bar_frame_middle getframe]
		pack $tab_bar_frame_middle -fill x

		set tab_bar_frame_left [ttk::button	\
			$tab_bar_frame_right.button_l	\
			-style Flat.TButton		\
			-image ::ICONS::16::1leftarrow	\
			-command [list $tab_bar_frame_middle xview scroll -10 units]	\
		]
		set tab_bar_frame_right [ttk::button	\
			$tab_bar_frame_right.button_r	\
			-style Flat.TButton		\
			-image ::ICONS::16::1rightarrow	\
			-command [list $tab_bar_frame_middle xview scroll 10 units]	\
		]
	}


	public method show_pages_area {} {
		if {$options(nomanager)} {
			pack $pages_area_frame -side bottom -fill both -expand 1
			set options(nomanager) 0
		}
	}
	public method hide_pages_area {} {
		if {!$options(nomanager)} {
			pack forget $pages_area_frame
			set options(nomanager) 1
		}
	}
	public method deselect_tab_button {} {
		set current_page -1
		redraw_tab_bar
	}

	public method get_nb {} {
		return $options(pathname)
	}

	public method itemconfigure {page args} {
		set idx [lsearch -index 0 -ascii -exact $pages $page]
		if {$idx == -1} {
			error "No such page: $page"
			return
		}
		set page_spec [lindex $pages $idx]

		set arg_createcmd	[lindex $page_spec 1]
		set arg_image		[lindex $page_spec 2]
		set arg_leavecmd	[lindex $page_spec 3]
		set arg_raisecmd	[lindex $page_spec 4]
		set arg_state		[lindex $page_spec 5]
		set arg_text		[lindex $page_spec 6]
		set arg_helptext	[lindex $page_spec 7]
		set length [llength $args]
		for {set i 0; set j 1} {$i < $length} {incr i 2; incr j 2} {
			set attr [lindex $args $i]
			set val [lindex $args $j]

			switch -- $attr {
				{-createcmd} {
					set arg_createcmd $val
				}
				{-image} {
					set arg_image $val
				}
				{-leavecmd} {
					set arg_leavecmd $val
				}
				{-raisecmd} {
					set arg_raisecmd $val
				}
				{-state} {
					if {$val == {normal}} {
						set val 0
					} elseif {$val == {disabled}} {
						set val 1
					} else {
						error "Possible values of $attr are: \"normal\" and \"disabled\"."
					}
					set arg_state $val
				}
				{-text} {
					set arg_text $val
				}
				{-helptext} {
					set arg_helptext $val
				}
				default {
					error "Unknown argument: $attr"
				}
			}
		}

		set pages [lreplace $pages $idx $idx [list $page $arg_createcmd $arg_image $arg_leavecmd $arg_raisecmd $arg_state $arg_text $arg_helptext {} 0]]
		redraw_tab_bar_completely
	}

	private method redraw_tab_bar_completely {} {
		set common_tab_but_width	0
		set common_tab_but_height	0
		redraw_tab_bar 1
		redraw_tab_bar
		handle_resize
	}

	public method insert {index page args} {
		set arg_createcmd	{}
		set arg_image		{}
		set arg_leavecmd	{}
		set arg_raisecmd	{}
		set arg_state		0
		set arg_text		{}
		set arg_helptext	{}
		set length [llength $args]
		for {set i 0; set j 1} {$i < $length} {incr i 2; incr j 2} {
			set attr [lindex $args $i]
			set val [lindex $args $j]

			switch -- $attr {
				{-createcmd} {
					set arg_createcmd $val
				}
				{-image} {
					set arg_image $val
				}
				{-leavecmd} {
					set arg_leavecmd $val
				}
				{-raisecmd} {
					set arg_raisecmd $val
				}
				{-state} {
					if {$val == {normal}} {
						set val 0
					} elseif {$val == {disabled}} {
						set val 1
					} else {
						error "Possible values of $attr are: \"normal\" and \"disabled\"."
					}
					set arg_state $val
				}
				{-text} {
					set arg_text $val
				}
				{-helptext} {
					set arg_helptext $val
				}
				default {
					error "Unknown argument: $attr"
				}
			}
		}

		if {[lsearch -ascii -exact -index 0 $pages $page] != -1} {
			error "Page already exists: $page"
		}

		if {$current_page != -1} {
			set current_page_id [lindex $pages [list $current_page 0]]
		}
		set pages [linsert $pages $index [list $page $arg_createcmd $arg_image $arg_leavecmd $arg_raisecmd $arg_state $arg_text $arg_helptext 0 {} 0]]
		$pages_area_frame add $page
		[$pages_area_frame getframe $page] configure -bg ${::COMMON_BG_COLOR} -padx 5 -pady 5
		if {$current_page != -1} {
			set current_page [lsearch -index 0 -ascii -exact $pages $current_page_id]
			if {$current_page != -1} {
				$this see $current_page_id
			}
		}

		redraw_tab_bar_completely

		if {$options(autohide) && ([llength $pages] > 1)} {
			show_hide_tabbar 1
		}

		return [$pages_area_frame getframe $page]
	}
	public method bindtabs {event command} {
		if {$event == {<Enter>}} {
			set tab_but_enter_cmd $command
		} elseif {$event == {<Leave>}} {
			set tab_but_leave_cmd $command
		} else {
			set idx [lsearch -ascii -exact -index 0 $event_bindings $event]
			if {$idx == -1} {
				lappend event_bindings [list $event $command]
			} else {
				set event_bindings [lreplace $event_bindings $idx $idx [list $event $command]]
			}
			reset_event_bindings
		}
	}

	public method see {page} {
		set idx [lsearch -index 0 -ascii -exact $pages $page]
		if {$idx == -1} {
			error "No such page: $page"
			return
		}

		$tab_bar_frame_middle see [lindex $pages [list $idx end-1]]
	}
	public method getframe {page} {
		return [$pages_area_frame getframe $page]
	}

	public method move {page index} {
		set idx [lsearch -index 0 -ascii -exact $pages $page]
		if {$idx == -1} {
			error "No such page: $page"
			return
		}
		if {$index != {end} && $index >= [llength $pages]} {
			error "Index out of range: $index"
			return
		}

		if {$current_page != -1} {
			set current_page_id [lindex $pages [list $current_page 0]]
		}
		set page_spec [lindex $pages $idx]
		set pages [lreplace $pages $idx $idx]
		set pages [linsert $pages $index $page_spec]
		if {$current_page != -1} {
			set current_page [lsearch -index 0 -ascii -exact $pages $current_page_id]
			if {$current_page != -1} {
				$this see $current_page_id
			}
		}
		redraw_tab_bar
	}
	public method pages {} {
		set result [list]
		foreach page_spec $pages {
			lappend result [lindex $page_spec 0]
		}
		return $result
	}
	public method index {page} {
		return [lsearch -index 0 -ascii -exact $pages $page]
	}
	public method delete {page} {
		set idx [lsearch -index 0 -ascii -exact $pages $page]
		if {$idx == -1} {
			error "No such page: $page"
			return
		}
		$pages_area_frame delete $page
		if {($current_page != -1) && ($current_page != $idx)} {
			set current_page_id [lindex $pages [list $current_page 0]]
		}
		set pages [lreplace $pages $idx $idx]
		if {![llength $pages]} {
			set current_page -1
		} elseif {$current_page == $idx} {
			set current_page -1
		} elseif {$current_page != -1} {
			set current_page [lsearch -index 0 -ascii -exact $pages $current_page_id]
			if {$current_page != -1} {
				$this see $current_page_id
			}
		}
		if {$options(autohide) && ([llength $pages] < 2)} {
			show_hide_tabbar 0
		} else {
			redraw_tab_bar_completely
		}
	}
	public method show_hide_tabbar {{show {}}} {
		if {$show == {}} {
			return $tabbar_hidden
		}

		if {![string is boolean $show]} {
			error "show must be a boolean ({$show} given)"
		}

		if {$show && $tabbar_hidden} {
			# Show it
			if {$options(nomanager)} {
				pack $tab_bar_frame -side top -fill both
			} else {
				pack $tab_bar_frame -side top -fill both -before $pages_area_frame_f
			}
			set tabbar_hidden 0
			$pages_area_frame_f configure -bd 1
		} elseif {!$show && !$tabbar_hidden} {
			# Hide it
			pack forget $tab_bar_frame
			set tabbar_hidden 1
			$pages_area_frame_f configure -bd 0
		}
	}

	public method raise {{page {}} {by_click 0}} {
		if {$page == {}} {
			if {$current_page == -1} {
				return {}
			}
			return [lindex $pages [list $current_page 0]]
		}

		set idx [lsearch -index 0 -ascii -exact $pages $page]
		if {$idx == -1} {
			error "No such page: $page"
			return
		}
		if {$current_page == $idx || [lindex $pages [list $idx 5]]} {
			return
		}

		if {$current_page != -1 && $current_page < [llength $pages]} {
			uplevel #0 [lindex $pages [list $current_page 3]]
			set_tab_but_bg_color n [lindex $pages [list $current_page end-1]]
		}

		$pages_area_frame raise $page
		$this see $page

		set current_page $idx
		if {$by_click} {
			set_tab_but_bg_color ae [lindex $pages [list $current_page end-1]]
		} else {
			set_tab_but_bg_color a [lindex $pages [list $current_page end-1]]
		}
		if {![lindex $pages [list $current_page end]]} {
			lset pages [list $current_page end] 1
			set createcmd [lindex $pages [list $current_page 1]]
			if {$createcmd != {}} {
				uplevel #0 $createcmd
			}
		}
		set raisecmd [lindex $pages [list $current_page 4]]
		if {$raisecmd != {}} {
			uplevel #0 $raisecmd
		}
	}

	private method redraw_tab_bar {{only_compute 0}} {
		if {!$only_compute} {
			destroy $tab_bar_frame_middle
			ScrollableFrame $tab_bar_frame_middle -height $common_tab_but_height
			set tab_bar_frame_middle_sc [$tab_bar_frame_middle getframe]
			pack $tab_bar_frame_middle -fill x -expand 1

			bind $tab_bar_frame_middle <Configure> [list $this handle_resize]
		}

		set total_tabbar_width 0
		set i -1
		foreach page_spec $pages {
			incr i
			set tab_but [draw_button $tab_bar_frame_middle_sc $i [lindex $page_spec 6] [lindex $page_spec 2] [lindex $page_spec 7] $only_compute]
			lset pages [list $i end-1] $tab_but

			if {$only_compute} {
				continue
			}

			pack $tab_but -side left
			if {![lindex $page_spec 5]} {
				bind $tab_but <Button-1> [format "%s\n%s" update [list $this raise [lindex $page_spec 0] 1]]
			}
		}
	}

	private method draw_button {target page_idx {text {}} {image {}} {helptext {}} {only_compute 0}} {
		set label_width [font measure $button_font $text]
		set image_width 0
		set image_height 0
		if {$image != {}} {
			set image_width [image width $image]
			set image_height [image height $image]
		} else {
			set image_height 16
		}
		set canvas_width [expr {$label_width + $image_width + 15}]
		set canvas_height [expr {(($font_size > $image_height) ? $font_size : $image_height) + 6 + $options(tabpady)}]
		if {$image_width} {
			incr canvas_width 5
		}

		if {$options(homogeneous)} {
			if {$canvas_width > $common_tab_but_width} {
				set common_tab_but_width $canvas_width
			} else {
				set canvas_width $common_tab_but_width
			}
		}
		if {$canvas_height > $common_tab_but_height} {
			set common_tab_but_height $canvas_height
		} else {
			set canvas_height $common_tab_but_height
		}

		if {$only_compute} {
			return {}
		}

		set cnv [canvas $target.b_$button_counter -bg {#E0E0E0} -width $canvas_width -height $canvas_height \
			-bd 0			\
			-highlightthickness 0	\
		]

		set x 7
		set y [expr {1 + int($canvas_height / 2)}]
		if {$image != {}} {
			$cnv create image $x $y -image $image -anchor w
			incr x $image_width
			incr x 5
			if {$image_height > $canvas_height} {
				incr y [expr {int(ceil(($image_height - $canvas_height) / 2))}]
			}
		}
		$cnv create text $x $y -font $button_font -anchor w -justify left -text $text -tags txt

		$cnv create line 1 0 [expr {$canvas_width - 1}] 0 -tags bg1
		$cnv create line 1 1 [expr {$canvas_width - 1}] 1 -tags bg2
		$cnv create line 0 1 0 $canvas_height -tags bg1
		$cnv create line 1 1 1 $canvas_height -tags bg2
		$cnv create line [expr {$canvas_width - 1}] 1 [expr {$canvas_width - 1}] $canvas_height -tags bg1
		$cnv create line [expr {$canvas_width - 2}] 1 [expr {$canvas_width - 2}] $canvas_height -tags bg3
		if {[lindex $pages [list $page_idx 5]]} {
			set_tab_but_bg_color d $cnv
		} elseif {$page_idx == $current_page} {
			set_tab_but_bg_color a $cnv
		} else {
			set_tab_but_bg_color n $cnv
		}

		if {$helptext != {}} {
			DynamicHelp::add $cnv -text $helptext
		}

		bind $cnv <Enter> +[list $this tab_but_enter $page_idx]
		bind $cnv <Leave> +[list $this tab_but_leave $page_idx]
		set_event_bindings $cnv $page_idx

		incr button_counter
		incr total_tabbar_width $canvas_width
		return $cnv
	}

	private method set_event_bindings {but page_idx} {
		foreach env_cmd $event_bindings {
			bind $but [lindex $env_cmd 0] [format "%s %s" [lindex $env_cmd 1] [lindex $pages $page_idx 0]]
		}
	}

	private method reset_event_bindings {} {
		set i -1
		foreach page_spec $pages {
			incr i
			set_event_bindings [lindex $page_spec end-1] $i
		}
	}

	public method handle_resize {} {
		if {$tabbar_hidden || ![winfo exists $tab_bar_frame_middle] || ![winfo viewable $tab_bar_frame_middle]} {
			return
		}
		set current_width [winfo width $tab_bar_frame_middle]
		if {$current_width == $last_width} {
			return
		}
		set last_width $current_width

		if {($current_width < $total_tabbar_width) && !$scroll_buttons_visible} {
			set scroll_buttons_visible 1
			pack $tab_bar_frame_left -side left
			pack $tab_bar_frame_right -side left
		} elseif {($current_width >= $total_tabbar_width) && $scroll_buttons_visible} {
			set scroll_buttons_visible 0
			pack forget $tab_bar_frame_left
			pack forget $tab_bar_frame_right
		}
	}

	private method set_tab_but_bg_color {code but} {
		switch -- $code {
			{a} {
				set bg0 {#E0E0FF}
				set bg1 {#9999FF}
				set bg2 {#AAAAFF}
				set bg3 {#CFCDFF}
				set txt_fg {#000000}
			}
			{ae} {
				set bg0 {#CCCCFF}
				set bg1 {#9999FF}
				set bg2 {#AAAAFF}
				set bg3 {#CFCDFF}
				set txt_fg {#000000}
			}
			{n} {
				set bg0 ${::COMMON_BG_COLOR}
				set bg1 {#BBBBBB}
				set bg2 {#EEEBE7}
				set bg3 {#CFCDC8}
				set txt_fg {#000000}
			}
			{ne} {
				set bg0 {#CCCCFF}
				set bg1 {#9999CC}
				set bg2 {#AAAADD}
				set bg3 {#CFCDC8}
				set txt_fg {#000000}
			}
			{d} {
				set bg0 ${::COMMON_BG_COLOR}
				set bg1 {#BBBBBB}
				set bg2 {#EEEBE7}
				set bg3 {#CFCDC8}
				set txt_fg {#888888}
			}
			default {
				error "ModernNoteBookClass::set_tab_but_bg_color: Invalid argument: code={$code}"
			}
		}

		$but configure -bg $bg0
		$but itemconfigure bg1 -fill $bg1
		$but itemconfigure bg2 -fill $bg2
		$but itemconfigure bg3 -fill $bg3
		$but itemconfigure txt -fill $txt_fg
	}

	public method tab_but_enter {page_idx} {
		set but [lindex $pages [list $page_idx end-1]]
		if {[lindex $pages [list $page_idx 5]]} {
			return
		} elseif {$current_page == $page_idx} {
			set_tab_but_bg_color ae $but
		} else {
			set_tab_but_bg_color ne $but
		}
		if {$tab_but_enter_cmd != {}} {
			uplevel #0 [format "%s %s" $tab_but_enter_cmd [lindex $pages $page_idx 0]]
		}
	}

	public method tab_but_leave {page_idx} {
		set but [lindex $pages [list $page_idx end-1]]
		if {[lindex $pages [list $page_idx 5]]} {
			return
		} elseif {$current_page == $page_idx} {
			set_tab_but_bg_color a $but
		} else {
			set_tab_but_bg_color n $but
		}
		if {$tab_but_leave_cmd != {}} {
			uplevel #0 [format "%s %s" $tab_but_leave_cmd [lindex $pages $page_idx 0]]
		}
	}
}
