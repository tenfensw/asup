#!/usr/bin/env wish
source -encoding utf-8 updater.tcl

package require Tk 8.5
package require canvas::gradient 0.2

namespace eval asup {
    namespace eval ui {
        variable pBar {}

        proc get_config {} {
            set var [join [list [namespace parent [namespace current]] \
                                config] ::]
            return $var
        }

        proc show_alert {args} {
            tk_messageBox -message [join $args { }] -icon warning \
                          -default ok -type ok
        }

        proc center_window {{pWnd .} {window_w 0} {window_h 0}} {
            set screen_w [winfo screenwidth $pWnd]
            set screen_h [winfo screenheight $pWnd]

            if {$window_w < 1} {
                set window_w [winfo width $pWnd]
            }

            if {$window_h < 1} {
                set window_h [winfo height $pWnd]
            }

            set result_x [expr {($screen_w / 2) - ($window_w / 2)}]
            set result_y [expr {($screen_h / 2) - ($window_h / 2)}]

            set result_geometry [join [list = $window_w x $window_h \
                                            + $result_x + $result_y] {}]

            wm geometry $pWnd $result_geometry
        }

        proc set_pbar {{value 0} {text {}}} {
            if {$value < 0 || $value > 100} { return }

            variable [get_config]

            set progress_y [expr {$config(WM_H_TK) - ($config(WM_L_TK) * 2)}]
            set caption_y [expr {$progress_y - $config(WM_L_TK) - ($config(WM_FONT_PADX_TK) / 2)}]

            set progress_w [expr {ceil(($config(WM_W_TK) / 100.0) * $value)}]

            variable pBar
            variable pFont

            if {[llength $pBar] < 2} {
                set pBar [.pBG create line 0 $progress_y \
                                           $progress_w $progress_y \
                                           \
                                           -fill white \
                                           \
                                           -capstyle butt \
                                           -joinstyle miter \
                                           -smooth bezier \
                                           \
                                           -width $config(WM_L_TK)]
                set pCaption [.pBG create text \
                                    $config(WM_FONT_PADX_TK) $caption_y \
                                                             -anchor sw \
                                                             -text $text \
                                                             -fill grey]

                font create .pFont -family $config(WM_FONT_FAMILY_TK) \
                                   -size $config(WM_FONT_SIZE_TK) \
                                   -weight normal
                .pBG itemconfigure $pCaption -font .pFont

                set pBar [list $pBar $pCaption]
            } else {
                .pBG coords [lindex $pBar 0] 0 $progress_y \
                                             $progress_w $progress_y

                if {[string length $text] >= 1} {
                    .pBG itemconfigure [lindex $pBar end] -text $text
                }
            }

            update
        }

        proc init {} {
            # make borderless parent window first
            variable [get_config]
            wm overrideredirect . 1

            # setup its title and position and size on screen
            wm title . $config(WM_TITLE_TK)
            center_window . $config(WM_W_TK) $config(WM_H_TK)

            set center_x [expr {$config(WM_W_TK) / 2}]
            set center_y [expr {$config(WM_H_TK) / 2}]

            # make sure it's not resizable
            wm resizable . 0 0

            # make a nice gradient background
            canvas .pBG -background black
            canvas::gradient .pBG -direction r -color1 grey -color2 black

            # load the logo in the center
            image create photo .pLogo -file logo.png
            .pBG create image $center_x $center_y -image .pLogo

            pack .pBG -fill both -expand 1
        }

        proc make_form_pair {wnd base name {type entry} {row 0} {args {}}} {
            set name_var $wnd.[join [list $base Label] {}]
            set value_var $wnd.$base

            set picker_var {}
            label $name_var -text $name

            switch -glob -nocase -- $type {
                entry { entry $value_var {*}$args }
                dirp {
                    set picker_var $wnd.[join [list $base Button] {}]

                    entry $value_var {*}$args
                    button $picker_var -text {Choose...}
                }

                scale -
                slider {
                    scale $value_var {*}$args
                }

                default { return -code error "unknown form field type - \"$type\"" }
            }

            set result [list $name_var $value_var]

            if {[string length $picker_var] >= 1} {
                lappend result $picker_var
            }

            for {set index 0} {$index < [llength $result]} {incr index} {
                grid [lindex $result $index] -column $index -row $row \
                                             -padx 10 -pady 10
            }

            return $result
        }

        proc init_mc_config {} {
            variable [get_config]

            set wnd [toplevel .mcConfig]

            wm title $wnd $config(WM_TITLE_TK)
            wm resizable $wnd 0 1

            make_form_pair $wnd mcRoot "Installation directory:" \
                                       dirp 0 \
                                       -textvariable [get_config](CURRENT_ROOT)
            make_form_pair $wnd mcUsername "In-game username:" \
                                       entry 1 \
                                       -textvariable [get_config](CURRENT_USERNAME)

            make_form_pair $wnd mcRAM "Maximum GB of RAM available in-game:" \
                                       scale 2 \
                                       -from 8 -to 1

            button $wnd.mcOK -text "OK"
            grid $wnd.mcOK -column 2 -row 3

            return $wnd
        }
    }
}

if {$::argv0 == [info script]} {
    # set the Tk UI flair accordingly
    array set ::asup::config {USE_TK 1}

    # process CLI args into config first
    asup::config_from_argv $::argv

    # display main progress window
    asup::ui::init
    asup::ui::set_pbar 0 "Initializing..."

    if {$::asup::config(CAN_CHECK_FOR_UPDATES)} {
        asup::ui::set_pbar 2 "Checking for updates..."
    }
}
