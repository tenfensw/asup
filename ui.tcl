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

            wm geometry $wm_wnd [join [list {=} $wm_width x $wm_height + $wm_x + $wm_y] {}]
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

            # make sure the window can't be quit that easily
            wm protocol . WM_DELETE_WINDOW {
                if {[tk_messageBox -default no -icon question \
                                   -message {Are you sure?} \
                                   -parent . \
                                   -type yesno]} {
                    asup::ui::deinit
                }
            }

            # obtain index.json contents first
            set_status 5 {Establishing connection...}
            asup::mt::enqueue { set index_json [asup::get_index_json] } tkvwait

            if {[dict get $wm_info CAN_CHECK_FOR_UPDATES]} {
                # mission #1 - make sure we are running the latest version
                check_for_updates
            }
        }

        proc deinit {{error_code 0}} {
            # terminate the background worker thread first
            asup::mt::deinit

            # destroy the progress window and exit with the specified error
            # code
            destroy .
            exit $error_code
        }

        # configuration window modal form
        namespace eval cwnd {
            variable wm_cresult 0

            variable wm_cname .cn
            variable wm_title {Configuration}

            variable wm_fields {}
            variable wm_contrs {}

            proc make_form {type caption value field} {
                variable wm_cname
                variable wm_contrs

                # Tk forces all control names to be lowercase, that's why we
                # have to do this
                set field [string tolower $field]
                set result {}

                # make sure the specified field is not known to us as of yet
                if {[dict exists $wm_contrs $field]} {
                    return -code error "form definition duplicate - \"$field\""
                }

                # make a label control first
                set caption_contr_name [join [list $field cap] {}]
                set caption_contr [ttk::label $wm_cname.$caption_contr_name \
                                              -text $caption]

                lappend result $caption_contr

                switch -glob -nocase -- $type {
                    dir* -
                    entry {
                        # make an entry box control then
                        set field_contr [ttk::entry $wm_cname.$field]
                        lappend result $field_contr

                        # set its current value to the default one provided
                        $field_contr insert 0 $value

                        if {[regexp -nocase {^dir*} $type]} {
                            set picker_contr_command [join [list [namespace current] \
                                                                  pick_dirp] {::}]
                            set picker_contr_command [list $picker_contr_command \
                                                           $field]

                            # make a directory picker button control
                            set picker_contr_name [join [list $field pick] {}]
                            set picker_contr [ttk::button $wm_cname.$picker_contr_name \
                                                          -text {...} \
                                                          -command $picker_contr_command]

                            lappend result $picker_contr

                            # make sure the entry box is disabled so that the
                            # user could only pick a valid directory path
                            $field_contr configure -state readonly
                        }
                    }

                    scale -
                    spin* {
                        if {! [string is digit $value]} {
                            return -code error "non-numeric value for a spinbox - $value"
                        }

                        # make a numeric scale control
                        set field_contr [ttk::scale $wm_cname.$field \
                                                    -value $value \
                                                    -from 1 -to 16]
                        lappend result $field_contr
                    }

                    default { return -code error "unknown form type - $type" }
                }

                dict set wm_contrs $field $result
            }

            proc pick_dirp {field} {
                variable wm_cname

                set root [tk_chooseDirectory -parent $wm_cname]
                puts stderr "root = \"$root\""

                if {[string length $root] > 0} {
                    set field_contr [join [list $wm_cname $field] .]

                    # set the entry control's value to the selected directory
                    $field_contr configure -state normal

                    $field_contr delete 0 end
                    $field_contr insert 0 $root

                    $field_contr configure -state readonly
                }
            }

            proc init {contr_map {title {}}} {
                variable wm_cname
                toplevel $wm_cname

                variable wm_title

                if {$title != {}} {
                    set wm_title $title
                }

                wm title $wm_cname $title
                wm resizable $wm_cname 0 0

                dict for {field field_type} $contr_map {
                    if {[llength $field_type] < 2} {
                        return -code error "incorrect form list for $field - need at least one of the types specified and a caption string as well"
                    }

                    set value [join [lrange $field_type 2 end] {}]
                    set caption [lindex $field_type 1]

                    set field_type [lindex $field_type 0]

                    puts stderr "type = $field_type, caption = $caption, value = $value"

                    # add the field to the form
                    make_form $field_type $caption $value $field
                }

                variable wm_contrs
                set row 0

                dict for {field grp} $wm_contrs {
                    puts stderr "griding field $field... (row $row)"

                    for {set column 0} {$column < [llength $grp]} {incr column} {
                        set contr [lindex $grp $column]
                        grid $contr -row $row -column $column -padx 5 -ipady 5
                    }

                    incr row
                }

                grid [ttk::button $wm_cname.okB -text {OK} -command {
                        asup::ui::cwnd::deinit ok
                      }] -row $row -column 1
                grid [ttk::button $wm_cname.caB -text {Cancel} -command {
                        asup::ui::cwnd::deinit cancel
                      }] -row $row -column 2

                wm protocol $wm_cname WM_DELETE_WINDOW {
                    asup::ui::cwnd::deinit cancel
                }
            }

            proc deinit {cresult} {
                variable wm_cresult
                set wm_cresult $cresult

                variable wm_cname
                variable wm_contrs

                set result {}

                foreach field [dict keys $wm_contrs] {
                    puts stderr "field = \"$field\""

                    set contr [join [list $wm_cname $field] .]
                    dict set result [string toupper $field] [$contr get]
                }

                if {$cresult == {ok}} {
                    variable wm_fields
                    set wm_fields $result
                }

                destroy $wm_cname
            }

            proc run {} {
                set var_name [join [list [namespace current] wm_cresult] {::}]
                tkwait variable $var_name

                variable wm_cresult
                variable wm_fields

                switch -glob -nocase -- $wm_cresult {
                    ok { return $wm_fields }
                    cancel { return {} }

                    0 -
                    default { return -code error "unknown dialog result - $wm_cresult" }
                }
            }
        }

        proc configure_package {name} {
            # pull the latest multiroot-related config keys (they are all a
            # part of the WM specs dictionary)  
            get_wm_info

            variable wm_info
            set form [dict create CURRENT_USERNAME \
                                  [list entry {In-game player name:} \
                                        [dict get $wm_info CURRENT_USERNAME]] \
                                  \
                                  CURRENT_ROOT \
                                  [list dirp {Installation directory:} \
                                        [dict get $wm_info CURRENT_ROOT]] \
                                  CURRENT_RAM_LIMIT \
                                  [list spin {RAM limit (in GB):} \
                                        [dict get $wm_info CURRENT_RAM_LIMIT]] ]

            # display the configuration form
            cwnd::init $form "Configure $name"
            set result [cwnd::run]

            if {$result == {}} {
                # package configuration cancelled
                return 0
            }

            dict for {key value} $result {
                # modify config values directly in the worker thread
                asup::mt::set_var asup::config($key) $value
            }

            # make sure the username gets stripped from all the ASCII-incompatible
            # characters
            asup::mt::enqueue { asup::guess_username } tkvwait

            # we're good!
            return 1
        }

        proc dump_config_to_ini {} {
            variable wm_info
            set config_path [dict get $wm_info CONFIG_PATH]

            puts stderr "config_path = \"$config_path\""
        }

        proc download_package {name} {
            set_status 60 "Downloading \"$name\"... (~15 minutes)"

            # begin downloading the package in the background
            asup::mt::set_var name $name
            asup::mt::enqueue { asup::download_package $index_json $name } tkvwait
        }

        proc launch_package {name} {
            set_status 80 "Launching \"$name\"..."
        }

        proc read_ascii args {
            # to call this procedure, we could have just imported the updater
            # library into the UI thread as well, but since the updater is
            # currently not a Tcl package, sourcing it again here directly
            # would be a huge overhead for just this one specific procedure
            # (and don't forget that the library would get re-initialized
            # again, but here, which is something we don't want!), so yeah...
            # hence why we're doing this in such a weird workaround way

            # call read_ascii directly with all the arguments preserved as is
            set args [linsert $args 0 asup::read_ascii]
            asup::mt::enqueue $args vwait

            return $asup::mt::wk_result
        }

        proc main {} {
            if {$::argv0 != [info script]} {
                # can't run the main loop when used as a package themselves
                return
            }

            set current_requested_packages {}
            set current_multiroot default

            set current_opts_path [join [list [file dirname $::argv0] \
                                              multiroot.txt] /]


            if {[file isfile $current_opts_path]} {
                set current_opts [read_ascii $current_opts_path utf-8 auto 1 0]

                set current_multiroot [lindex $current_opts 0]
                set current_requested_packages [lrange $current_opts 1 end]
            }

            # switch to the specified multiroot
            puts stderr "current multiroot: $current_multiroot"
            asup::mt::enqueue [list asup::reload_config_from_ini \
                                    $current_multiroot] tkvwait

            # obtain list of packages to download and launch
            set requested_packages $current_requested_packages

            variable wm_info
            if {[llength $requested_packages] < 1} {
                set requested_packages [dict get $wm_info CAN_DOWNLOAD_PACKAGE]
            }

            # make sure we have some in the first place
            if {[llength $requested_packages] < 1} {
                return -code error "nothing to download or launch"
            } elseif {[dict get $wm_info CAN_LAUNCH] &&
                      [llength $requested_packages] != 1} {
                return -code error "can only launch one package"
            }

            # if we do, download these packages and, maybe, even launch them
            foreach name $requested_packages {
                if {! [configure_package $name]} {
                    # configuration cancelled -> cannot continue
                    exit 0
                }

                download_package $name

                if {[dict get $wm_info CAN_LAUNCH]} {
                    launch_package $name
                }
            }
        }
    }
}

asup::ui::init
asup::ui::main
