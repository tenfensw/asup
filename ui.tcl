#!/usr/bin/env wish
source mt.tcl

proc tkvwait {name} {
    tkwait variable $name
}

namespace eval asup {
    namespace eval ui {
        # progress window and UI operations specs
        variable wm_info {}

        proc get_wm_info {} {
            variable wm_info
            set wm_info [asup::mt::enqueue { asup::get_wm_dict } vwait]
        }

        proc center_wm {{wm_wnd .} {wm_info {}}} {
            set wm_width [dict get $wm_info WM_W_TK]
            set wm_height [dict get $wm_info WM_H_TK]

            set sc_width [winfo screenwidth .]
            set sc_height [winfo screenheight .]

            set wm_x [expr {($sc_width / 2) - ($wm_width / 2)}]
            set wm_y [expr {($sc_height / 2) - ($wm_height / 2)}]

            wm geometry . [join [list {=} $wm_width x $wm_height + $wm_x + $wm_y] {}]
        }

        proc init_stylish {wm_info} {
        }

        proc check_for_updates {} {
            set_status 10 {Checking for updates...}

            if {! [asup::mt::enqueue { asup::is_latest $index_json } tkvwait]} {
                # obtain new version flair first
                set new_version [asup::mt::enqueue { dict get $index_json general version } \
                                                   vwait]
                # obtain the current version flair as well
                variable wm_info
                set current_version [dict get $wm_info CURRENT_VERSION]

                # compose the message box text
                set new_caption [join [list "A newer version ($new_version) is available" \
                                            "(you are currently running $current_version)." \
                                            "Would you like to update now?"] { }]

                # ask the user if we maybe want to update now
                if {[tk_messageBox -icon question -default yes \
                                   -text $new_caption -type yesno]} {
                    # TODO: self-update
                }
            }
        }

        proc set_status {percent {brief {}}} {
            if {$percent < 0 || $percent > 100} {
                return -code error "$percent doesn't fit into 0-100 range and, hence, is invalid"
            }

            set do_update_brief [expr {[string length $brief] > 0}]

            variable wm_info

            if {! [dict get $wm_info WM_STYLISH_TK]} {
                .pbBar configure -value $percent

                if {$do_update_brief} {
                    .pbCap configure -text $brief
                }
            }
        }

        proc init {} {
            if {$::argv0 == [info script]} {
                # make sure we don't ignore the CLI args if we are running in standalone mode
                asup::mt::enqueue [list asup::config_from_argv $::argv] vwait
            }

            # obtain UI-related info dictionary
            get_wm_info
            variable wm_info

            if {[dict get $wm_info WM_STYLISH_TK]} {
                # initialize a prettified UI window
                init_stylish $wm_info
            } else {
                # initialize a bare-bones window
                wm title . [dict get $wm_info WM_TITLE_TK]
                center_wm . $wm_info

                # add a label and a progress bar to it (we have to use TTK since regular Tk
                # controls are broken on micro$oft's OS)
                ttk::label .pbCap -text {Initializing...}
                ttk::progressbar .pbBar -mode indeterminate

                # don't forget to add all these controls to the window properly
                pack .pbCap .pbBar -fill x -padx 5 -pady 5
            }

            # obtain index.json contents first
            set_status 5 {Establishing connection...}
            asup::mt::enqueue { set index_json [asup::get_index_json] } tkvwait

            if {[dict get $wm_info CAN_CHECK_FOR_UPDATES]} {
                # mission #1 - make sure we are running the latest version
                check_for_updates
            }
        }

        proc download_package {name} {
            set_status 10 "Preparing \"$name\"..."

            asup::mt::set_var name $name
            asup::mt::enqueue { asup::download_package $index_json $name } tkvwait
        }

        proc configure_package {name} {
            set_status 60 "Configuring \"$name\"..."
        }

        proc launch_package {name} {
            set_status 90 "Launching \"$name\"..."
        }

        proc main {} {
            if {$::argv0 != [info script]} {
                # can't run the main loop when used as a package themselves
                return
            }

            # obtain list of packages to download and launch
            variable wm_info
            set requested_packages [dict get $wm_info CAN_DOWNLOAD_PACKAGE]

            # make sure we have some in the first place
            if {[llength $requested_packages] < 1} {
                return -code error "nothing to download or launch"
            } elseif {[dict get $wm_info CAN_LAUNCH] &&
                      [llength $requested_packages] != 1} {
                return -code error "can only launch one package"
            }

            # if we do, download these packages and, maybe, even launch them
            foreach name $requested_packages {
                download_package $name
                configure_package $name

                launch_package $name
            }
        }
    }
}

asup::ui::init
asup::ui::main
