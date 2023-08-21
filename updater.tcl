#!/usr/bin/env tclsh
package require Tcl 8.5

package require json 1.1
package require sha1 2.0

namespace eval asup {
    array set config [list CURRENT_PLATFORM $::tcl_platform(platform) \
                           \
                           CURRENT_OS $::tcl_platform(os) \
                           CURRENT_OS_VERSION $::tcl_platform(osVersion) \
                           \
                           CURRENT_ARCH $::tcl_platform(machine) \
                           \
                           CURRENT_USERNAME Player \
                           CURRENT_RAM_LIMIT 6G \
                           \
                           CURL_PATH "/usr/bin/curl" \
                           CURL_FLAGS {-kLf} \
                           \
                           TAR_PATH "/usr/bin/tar" \
                           SHASUM_PATH "/usr/bin/shasum" \
                           \
                           CURRENT_ROOT "/tmp/aa" \
                           CURRENT_VERSION {2023.08.02.5} \
                           \
                           INDEX_JSON "https://valche.fun/asup/index.json" \
                           VAR_SPECIALS {_} \
                           \
                           CAN_CHECK_FOR_UPDATES 1 \
                           CAN_FORCE_UPDATE 0 \
                           \
                           CAN_DOWNLOAD_PACKAGE {} \
                           CAN_FORCE_REDOWNLOAD 0 \
                           \
                           CAN_LAUNCH 0 \
                           CAN_VERIFY_JRE 1 \
                           \
                           USE_MULTIROOT 1 \
                           CURRENT_MULTIROOT default \
                           CURRENT_MULTIROOT_CONFIG {} \
                           \
                           USE_MT 0 \
                           \
                           WM_TITLE_TK "Ascention Updater" \
                           WM_STYLISH_TK 0 \
                           \
                           WM_W_TK 486 \
                           WM_H_TK 453 \
                           \
                           WM_L_TK 12 \
                           \
                           WM_FONT_FAMILY_TK Helvetica \
                           WM_FONT_SIZE_TK 14 \
                           \
                           WM_FONT_PADX_TK 10]
    array set config [list CURRENT_USER_AGENT "asup/v$config(CURRENT_VERSION)"]

    proc config_from_argv {argv} {
        variable config

        foreach arg $argv {
            if {[string length $arg] >= 2} {
                # both short and GNU-styled long options are supported
                set is_opt [expr {[string index $arg 0] == {-}}]
                set is_long_opt [expr {$is_opt && [string index $arg 1] == {-} &&
                                                  [string length $arg] >= 3}]

                # obtain short option flag and operand
                set flag [string index $arg 1]
                set operand [string range $arg 2 end]

                # long options have it differently however
                if {$is_long_opt} {
                    set operand [split $arg {=}]

                    set flag [string range [lindex $operand 0] 2 end]
                    set operand [join [lrange $operand 1 end] {=}]

                    # translate long option name into a short option flag
                    switch -glob -nocase -- $flag {
                        skip-updates-check { set flag {N} }
                        skip-verify-jre { set flag {J} }

                        force-update { set flag {u} }

                        pretty -
                        stylish -
                        ui { set flag {S} }

                        uri -
                        mirror { set flag {M} }

                        package* -
                        pkg* -
                        game { set flag {P} }

                        run -
                        launch { set flag {L} }

                        multiroot { set flag {C} }

                        usage -
                        help { set flag {?} }

                        verbose { set flag {v} }

                        default { set flag [string index $flag 0] }
                    }
                }

                # handle flag accordingly
                switch -glob -- $flag {
                    N { set config(CAN_CHECK_FOR_UPDATES) 0 }
                    u { set config(CAN_FORCE_UPDATE) 1 }

                    P { lappend config(CAN_DOWNLOAD_PACKAGE) $operand }

                    L { set config(CAN_LAUNCH) 1 }
                    J { set config(CAN_VERIFY_JRE) 0 }

                    D {
                        # declare a preset override value for a configuration
                        # key - the operand will be of key=value format
                        set operand [split $operand {=}]

                        set key [lindex $operand 0]
                        set value [lrange $operand 1 end]

                        set config($key) $value
                    }

                    S { set config(WM_STYLISH_TK) 1 }

                    M { set config(INDEX_JSON) $operand }
                    C { set config(CURRENT_MULTIROOT) $operand }

                    R { set config(CURRENT_ROOT) $operand }

                    v {
                        lappend config(CURL_FLAGS) {-v}
                    }

                    [uUhH?] {
                        # displays the help message and exists
                        if {! $config(USE_MT)} {
                            show_help
                            exit 1
                        }
                    }

                    default {
                        return -code error "unknown flag - '$flag'"
                        exit 1
                    }
                }
            }
        }
    }

    proc adapt_config_for_win32 {} {
        variable config

        if {[is_win32]} {
            set root [file dirname $::argv0]
            set prefix_root [join [list $root Library TenFen] /]

            set config_path [join [list $root updater.ini] /]

            set curl_path [join [list $prefix_root cURL 7.88.1 bin curl.exe] /]
            set tar_path [join [list $prefix_root BSDtar bin bsdtar.exe] /]

            set shasum_path [join [list $prefix_root sha1sum.exe] /]

            set current_root [join [list $::env(APPDATA) Ascention] /]

            array set config [list CURL_PATH [file nativename $curl_path] \
                                   TAR_PATH [file nativename $tar_path] \
                                   \
                                   SHASUM_PATH [file nativename $shasum_path] \
                                   \
                                   CURRENT_ROOT [file nativename $current_root] \
                                   CONFIG_PATH [file nativename $config_path] \
                                   \
                                   CURRENT_OS win32]
        }
    }

    proc is_win32 {} {
        variable config
        return [regexp -nocase {^win*} $config(CURRENT_OS)]
    }

    proc is_macos {} {
        variable config
        return [regexp -nocase {^(darwin|macos|osx)$} $config(CURRENT_OS)]
    }

    proc adapt_config_for_macos {} {
        variable config

        if {[is_macos]} {
            # we place config files and default packages root into macOS
            # native user directories
            set current_root [join [list $::env(HOME) Library \
                                         {Application Support} \
                                         Ascention] /]
            set config_path [join [list $::env(HOME) Library \
                                        Preferences Ascention.ini] /]

            # most other config options are relevant for macOS without
            # any additional modifications
            array set config [list CONFIG_PATH $config_path \
                                   CURRENT_ROOT $current_root \
                                   \
                                   CURRENT_OS darwin]
        }
    }

    proc log {args} {
        set where_to stderr

        # make sure the default channel to dump to is not overriden
        variable config
        if {[info exists config(WHERE_TO_LOG)]} {
            set where_to $config(WHERE_TO_LOG)
        }

        # don't log anything if so is requested
        if {$where_to == {} || $where_to == {-}} {
            return
        }

        # dump to the specified channel
        puts $where_to {*}$args
    }

    proc read_ini {path {encoding utf-8} {globals_name default}} {
        # the resulting dictionary containing the entirety of the INI contents
        set result {}
        # current section name
        set section_name {}

        # make sure the file we are about to read exists in the first place
        if {! [file isfile $path]} {
            return -code error "no such file - \"$path\""
        }

        # line counter
        set count 0

        # open file descriptor with the specified parameters accordingly
        set lines [read_ascii $path $encoding auto 1]

        for {set count 0} {$count < [llength $lines]} {incr count} {
            # obtain the line string trimmed out of stray whitespaces or 
            # new lines
            set line [string trim [lindex $lines $count]]

            if {[string length $line] < 1 ||
                [regexp {^(\;|\#)} $line]} {
                # skip all the comment lines
                continue
            } elseif {[string index $line 0] == {[}} {
                set section_name [string range $line 1 end-1]
                set section_name [string trim $section_name]

                if {[string length $section_name] < 1} {
                    return -code error "empty section name encountered (line $count)"
                }
            } else {
                # split key-value pair line
                set line [split $line {=}]

                # make sure it is one of these lines in the first place
                if {[llength $line] < 2} {
                    return -code error "expected key-value pair (line $count)"
                }

                set key [lindex $line 0]

                set value [lrange $line 1 end]
                set value [join $value {=}]

                if {$section_name == {}} {
                    set section_name $globals_name
                }

                # make up mind where are we going to save the key-value pair
                dict set result $section_name $key $value
            }
        }

        # the globals section must be always available, even if the input INI
        # file turned out to be empty or completely consisting out of comments
        if {! [dict exists $result $globals_name]} {
            dict set result $globals_name {}
        }

        return $result
    }

    proc dump_ini {input {globals_name global}} {
        set result {}

        dict for {section raw} $input {
            set is_globals [string equal -nocase $globals_name $section]
            set lines {}

            dict for {key value} $raw {
                lappend lines [join [list $key $value] {=}]
            }

            set lines [join $lines "\n"]

            if {$is_globals} {
                set result [linsert $result 0 $lines]
            } else {
                lappend result [join [list {[} $section {]}] {}]
                lappend result $lines
            }

            lappend result {}
        }

        return [join $result "\n"]
    }

    proc config_from_ini {path {encoding utf-8} {ignore_invalid_multiroot 1}} {
        if {! [file isfile $path]} {
            # no need to try to parse a non-existing config file
            return 0
        }

        # read in the entirety of the INI's contents into a dictionary
        set ini [read_ini $path $encoding]

        # obtain the root configuration section if possible
        variable config
        set multiroot_block {}

        if {[dict exists $ini $config(CURRENT_MULTIROOT)]} {
            set multiroot_block [dict get $ini $config(CURRENT_MULTIROOT)]
        } elseif {$config(USE_MULTIROOT)} {
            # make sure the multiroot is at least referred to in the global config
            # INI in some shape or form
            if {! [dict exists $ini multiroot $config(CURRENT_MULTIROOT)]} {
                if {$ignore_invalid_multiroot} {
                    # if requested, just display a warning and stop here
                    log "Warning! requested multiroot unavailable - $config(CURRENT_MULTIROOT)"
                    return
                }

                return -code error "multiroot unavailable - $config(CURRENT_MULTIROOT)"
            }

            set multiroot_config_path [dict get $ini multiroot \
                                                     $config(CURRENT_MULTIROOT)]

            # cache multiroot config INI path
            set config(CURRENT_MULTIROOT_CONFIG) $multiroot_config_path

            # read in separate multiroot config INI, if possible
            set multiroot_block [read_ini $multiroot_config_path $encoding]
            set multiroot_block [dict get $multiroot_block default]
        }

        dict for {key value} $multiroot_block {
            # all keys are treated in their uppercase form
            set key [string toupper $key]
            set potential_key [join [list CURRENT $key] {_}]

            # short aliases of CURRENT_* config keys are also permitted
            if {[info exists config($potential_key)]} {
                set key $potential_key
            }

            if {[info exists config($key)]} {
                # set the config key value as is
                set config($key) $value
            }
        }

        return 1
    }

    proc reload_config_from_ini {{name default}} {
        variable config

        # if requested (and permitted), switch to the specified multiroot
        if {$config(USE_MULTIROOT)} {
            set config(CURRENT_MULTIROOT) $name
        }

        # load the config INI
        return [config_from_ini $config(CONFIG_PATH)]
    }

    # obtains CPU arch from machine name
    proc get_arch {machine} {
        switch -glob -nocase -- $machine {
            amd64 -
            x86_64 { return x86_64 }

            aarch64 -
            arm64* { return arm64 }

            Power* -
            powerpc -
            ppc { return powerpc }

            intel -
            i?86 { return i386 }

            default { return -code error "unsupported machine - \"$machine\"" }
        }
    }

    proc guess_username {} {
        variable config
        set username $config(CURRENT_USERNAME)

        if {[info exists ::env(USERNAME)]} {
            set username $::env(USERNAME)
        } elseif {[info exists ::env(USER)]} {
            set username $::env(USER)
        }

        set result {}

        for {set index 0} {$index < [string length $username]} {incr index} {
            set current [string index $username $index]

            if {[string is space $current]} {
                set current _
            } elseif {! [string is ascii $current] ||
                      ! [string is alnum $current]} {
                scan $current %c current
                lappend result a
            }

            lappend result $current
        }

        set result [join $result {}]
        set result [string range $result 0 8]

        set config(CURRENT_USERNAME) $result

        return $result
    }

    # returns formatted specs for the progress window as a dictionary
    proc get_wm_dict {} {
        variable config
        set result [dict create]

        foreach key [array names config] {
            if {[regexp -- {^WM_*} $key] ||
                [lsearch -exact {CAN_DOWNLOAD_PACKAGE
                                 CAN_LAUNCH
                                 CAN_CHECK_FOR_UPDATES
                                 CURRENT_VERSION
                                 CURRENT_USERNAME
                                 CURRENT_RAM_LIMIT
                                 CURRENT_ROOT
                                 CONFIG_PATH} $key] >= 0} {
                dict set result $key $config($key)
            }
        }

        return $result
    }

    proc curl {uri {path {-}} {args {}}} {
        if {$path != {-}} {
            # make all parent directories of the specified output path in
            # advance
            set path_root [file dirname $path]

            if {! [file isdirectory $path_root]} {
                file mkdir $path_root
            }

            # don't forget to normalize path since we'll be passing it to
            # an external binary as an command-line argument
            set path [file nativename $path]
        }

        # run cURL with some predefined (and user-specified) options
        variable config
        return [exec -ignorestderr -- $config(CURL_PATH) {*}$config(CURL_FLAGS) \
                                                         -o $path \
                                                         -A $config(CURRENT_USER_AGENT) \
                                                         {*}$args \
                                                         $uri]
    }

    proc try_expand {path {target_root -}} {
        set expansion_relevant 1
        set expansion_flag {}

        switch -glob -nocase -- [file extension $path] {
            .*gz { set expansion_flag z }
            .*bz2 { set expansion_flag j }
            .*xz { set expansion_flag J }

            .tar { set expansion_flag {} }
            default { set expansion_relevant 0 }
        }

        if {$expansion_relevant} {
            if {$target_root == {-}} {
                set target_root [file dirname $path]
            } elseif {! [file isdirectory $target_root]} {
                file mkdir $target_root
            }

            set path [file nativename $path]
            set target_root [file nativename $target_root]

            log "Extracting in progress, this might take a while... (path = \"$path\")"

            variable config
            if {[catch {exec -ignorestderr -- $config(TAR_PATH) \
                                                        -C $target_root \
                                                        [join [list {-} x $expansion_flag f] {}] \
                                                        $path} reason]} {
                log "Warning! extracting \"$path\" failed - $reason"
                return 0
            }
        }

        return 1
    }

    proc verify_sha1 {sha1 path} {
        variable config

        if {! [file isfile $path]} {
            # can't verify non-existent files
            return 0
        } elseif {[string length $sha1] < 64 || [string equal -nocase $sha1 null]} {
            # there is no valid checksum to compare with
            return 1
        }

        log "Verifying \"$path\"..."

        # convert file path to OS-native one since we might be using external
        # binaries for checksum calculation if they are available
        set path [file nativename $path]
        set tgt {}

        if {[string length $config(SHASUM_PATH)] >= 1} {
            # "shasum" on UNIX and "sha1sum" from GnuPG for all platforms
            # are very fast, but they output the checksum with the file
            # name being aligned with tabs or spaces at the end - trim
            # these out
            set tgt [exec -- $config(SHASUM_PATH) $path]
            set tgt [lindex [split $tgt " \t"] 0]
        } else {
            # Tcllib sha1 is portable, but very slow
            set tgt [sha1::sha1 -hex -file $path]
        }

        # hexademical SHA-1 checksum strings are case-insensitive
        set result [string equal -nocase $tgt $sha1]

        log "sha1: $sha1, tgt: $tgt, path: \"$path\", matches: $result"
        return $result
    }

    proc find_jre8 {} {
        variable config

        set bundled_jvm_path [join [list $config(CURRENT_ROOT) Java bin java] /]
        set path {/usr/bin/java}

        if {[is_win32]} {
            set path {C:/Program Files/Java/jre-1.8/bin/java.exe}
            append bundled_jvm_path {.exe}
        }

        if {[file isfile $bundled_jvm_path]} {
            set path $bundled_jvm_path
        }

        if {[info exists config(JAVA_PATH)]} {
            set path $config(JAVA_PATH)
        }

        set path [file nativename $path]

        # test if JRE works
        if {$config(CAN_VERIFY_JRE) &&
            [catch {exec -ignorestderr -- $path -version} reason]} {
            return -code error "JVM at \"$path\" does not work - $reason"
        }

        return $path
    }

    proc combine_jvm_classpath {path} {
        set sep :

        if {[is_win32]} {
            set sep {;}
        }

        if {$path == {-}} {
            return $sep
        }

        if {! [file isfile $path]} {
            return -code error "cannot combine JVM classpath - no such file - \"$path\""
        }

        set path_root [file dirname $path]

        set result {}
        set classpath_contents [read_ascii $path utf-8 auto 1 0]

        foreach path_jar $classpath_contents {
            if {! [file isfile $path_jar]} {
                set path_jar [join [list $path_root $path_jar] /]
            }

            set path_jar [file nativename $path_jar]
            lappend result $path_jar
        }

        set result [join $result $sep]
        return $result
    }

    proc read_ascii {path {encoding utf-8} {translation auto}
                     {use_nl 0} {retain_empty_nls 1}} {
        if {! [file isfile $path]} {
            return -code error "no such file - \"$path\""
        }

        # setup a file descriptor with the specified parameters
        set fd [open $path r]
        fconfigure $fd -encoding $encoding -translation $translation

        set result {}

        if {$use_nl} {
            # make sure we are not trying to do the splitting in binary mode
            if {$encoding == {binary}} {
                close $fd
                return -code error "you cannot read line by line in binary mode - \"$path\""
            }

            while {! [eof $fd]} {
                set line [gets $fd]

                # read the file line by line and, unless restricted by enforced
                # length limits, add it to the resulting list as is
                if {$retain_empty_nls ||
                    [string length $line] > 0} {
                    lappend result $line
                }
            }
        } else {
            # read in the entirety of the file as is
            set result [read $fd]
        }

        close $fd

        # unless we were reading in binary mode, trim all whitespaces and stray
        # new lines from the resulting file contents string
        if {! [string equal -nocase $encoding binary]} {
            set result [string trim $result]
        }

        return $result
    }

    proc lowest_of {args} {
        set first 1
        set result 0

        for {set index 0} {$index < [llength $args]} {incr index} {
            set part [lindex $args $index]

            if {$first} {
                set result $part
                set first 0
            } elseif {$part < $result} {
                set result $part
            }
        }

        return $result
    }

    proc show_help {} {
        set str [join [list "Usage: $::argv0" \
                            {[-N] [-P<package name>] [-h]}] { }]
        log $str
    }

    proc get_index_json {} {
        variable config

        set index_json_uri $config(INDEX_JSON)
        set contents {{}}

        # obtain raw index.json contents first
        if {[file isfile $index_json_uri]} {
            # if it is a local file on the disk, we can just read it in as is
            set contents [read_ascii $index_json_uri]
        } else {
            # otheriwse, we have to fetch its contents via cURL
            set contents [curl $config(INDEX_JSON)]
        }

        # convert them into an indexeable Tcl dict
        set contents [json::json2dict $contents]

        return $contents
    }

    proc is_latest {index_json} {
        variable config

        if {$config(CAN_FORCE_UPDATE)} {
            return 0
        }

        set latest_version $config(CURRENT_VERSION)

        if {[dict exists $index_json general version]} {
            set latest_version [dict get $index_json general version]
        }

        set current_version [split $config(CURRENT_VERSION) .]
        set latest_version [split $latest_version .]

        set how_much [lowest_of [llength $latest_version] [llength $current_version]]

        for {set index 0} {$index < $how_much} {incr index} {
            set current_part [lindex $current_version $index]
            set latest_part [lindex $latest_version $index]

            if {$current_part < $latest_part} {
                return 0
            }
        }

        return 1
    }

    proc update_ourselves {index_json} {
        return -code error "TODO: implement"
    }

    proc download_package {index_json name} {
        variable config

        # make sure the requested package even exists in the first place
        if {! [dict exists $index_json $name] ||
            [lsearch -exact [dict get $index_json packages] $name] < 0} {
            return -code error "no such package - \"$name\""
        }

        # obtain package "downloads" block
        set package_block [dict get $index_json $name]
        set package_downloads_block {}

        if {[dict exists $package_block downloads]} {
            set package_downloads_block [dict get $package_block downloads]
        } elseif {[dict exists $package_block obsoleted_by]} {
            # TODO: get rid of recursion
            return [download_package $index_json \
                                     [dict get $package_block obsoleted_by]]
        }

        log "downloads block: $package_downloads_block"

        foreach package_download_block $package_downloads_block {
            set uri [dict get $package_download_block uri]
            set sha1 [dict get $package_download_block sha1]

            set os $config(CURRENT_OS)
            set arch [get_arch $config(CURRENT_ARCH)]

            if {[dict exists $package_download_block os]} {
                set os [subst_any_null [dict get $package_download_block os] $os]
            }

            if {[dict exists $package_download_block arch]} {
                set arch [subst_any_null [dict get $package_download_block arch] \
                                         $arch]
            }

            log "got uri: $uri"
            log "SHA1 checksum: $sha1"
            log "OS: $os"
            log "arch: $arch"

            # if the package is for our OS and platform, we can download it
            if {[string equal -nocase $os $config(CURRENT_OS)] &&
                [string equal -nocase $arch [get_arch $config(CURRENT_ARCH)]]} {
                log "eligible for download"

                set path [join [list $config(CURRENT_ROOT) [file tail $uri]] /]
                set path_sha1 [join [list $path sha1] .]

                set do_force_redownload $config(CAN_FORCE_REDOWNLOAD)

                if {[file isfile $path_sha1]} {
                    # unless there is either no .sha1 file for the package or
                    # the checksum does not match, there is no need to redownload
                    # the package
                    set path_sha1_current [read_ascii $path_sha1]

                    if {! [string equal -nocase $sha1 $path_sha1_current]} {
                        set do_force_redownload 1
                    }
                } else {
                    set do_force_redownload 1
                }

                log "do_force_redownload = $do_force_redownload"

                if {$do_force_redownload} {
                    # download it first
                    log "Downloading $uri (sha1: $sha1) into $path..."
                    curl $uri $path

                    log "Download completed!"

                    # verify its checksum (to make sure the downloaded file is
                    # not corrupted)
                    if {! [verify_sha1 $sha1 $path]} {
                        return -code error "SHA1 checksum mismatch, file corrupted - \"$path\""
                    }

                    log "Verification completed!"

                    # cache the checksum (since this is the way we'll be checking
                    # whether the installed package is up to date or not)
                    if {[catch {
                        set path_sha1_fd [open $path_sha1 w 0655]
                        fconfigure $path_sha1_fd -encoding utf-8 -translation auto

                        puts $path_sha1_fd $sha1

                        flush $path_sha1_fd
                        close $path_sha1_fd
                    } reason]} {
                        log "Warning! Failed to save checksum file - \"$path_sha1\" - $reason"
                        log "(this means that next time the package will be probably force re-downloaded)"
                    }

                    # expand the package, if it is an archive
                    if {[try_expand $path $config(CURRENT_ROOT)]} {
                        file delete -force -- $path
                    }
                }
            }
        }
    }

    proc interpolate_launch_string {str} {
        variable config

        set result {}
        set var {}

        for {set index 0} {$index < [string length $str]} {incr index} {
            set current [string index $str $index]

            if {$current == {$}} {
                set in_var 1
                incr index

                while {$index < [string length $str]} {
                    set current [string index $str $index]

                    if {! [string is alnum $current] &&
                        [lsearch -exact $config(VAR_SPECIALS) $current] < 0} {
                        # that's it!
                        set in_var 0
                        break
                    }

                    # otherwise, if the character matches the criteria, it is
                    # considered a part of the variable name
                    lappend var $current
                    incr index
                }

                # combine variable name string
                set var [join $var {}]

                if {[string length $var] > 0 && [string index $var 0] != {$}} {
                    if {[info exists config($var)]} {
                        # it is a config option
                        set var $config($var)
                    } elseif {[info exists ::env($var)]} {
                        # it is an environment variable
                        set var $::env($var)
                    } else {
                        # no such variable then
                        set var {}
                    }
                }

                # add the variable value as is
                lappend result $var

                if {! $in_var} {
                    lappend result $current
                }

                # don't forget to clean up
                set var {}
            } else {
                # add the character directly
                lappend result $current
            }
        }

        # combine the resulting string and return it
        set result [join $result {}]
        return $result
    }

    # substitute specified placeholder values with a default one, if necessary
    proc subst_any_null {str {value {}}} {
        if {[regexp -nocase {^(any|null)$} $str]} {
            return $value
        }

        return $str
    }

    proc get_flaired_key {key} {
        variable config

        set key_os [join [list $key $config(CURRENT_OS)] :]
        set key_os_arch [join [list $key_os $config(CURRENT_ARCH)] :]

        set result [list $key $key_os $key_os_arch]
        return $result
    }

    # launches the specified package if possible
    proc launch_package {index_json name} {
        variable config

        if {! [dict exists $index_json $name launch]} {
            return -code error "no such package (or package does not support execution) - \"$name\""
        }

        set launch_block [dict get $index_json $name launch]
        set launch_via [dict get $launch_block via]

        set launch_argv {}
        set launch_jvm [find_jre8]

        foreach potential_argv_list [get_flaired_key argv] {
            if {[dict exists $launch_block $potential_argv_list]} {
                # all the passed in CLI arguments must be interpolated
                foreach arg [dict get $launch_block $potential_argv_list] {
                    lappend launch_argv [interpolate_launch_string $arg]
                }
            }
        }

        # if specified, use the provided path when looking for OS-native Java
        # library dependencies
        if {[dict exists $launch_block jvm_shared_cp]} {
            lappend launch_argv [join [list {-Djava.library.path} [interpolate_launch_string [dict get $launch_block jvm_shared_cp]]] {=}]
        }

        # if necessary, combine the JVM classpath string (-cp) appropriately
        set launch_jvm_cp_combined {}
        set launch_jvm_cp_sep [combine_jvm_classpath -]

        foreach potential_jvm_cp_key [get_flaired_key jvm_cp] {
            if {[dict exists $launch_block $potential_jvm_cp_key]} {
                set launch_jvm_cp [interpolate_launch_string [dict get $launch_block $potential_jvm_cp_key]]

                if {! [file isfile $launch_jvm_cp]} {
                    return -code error "cannot combine JVM classpath - no such file - \"$launch_jvm_cp\""
                }

                set launch_jvm_cp [combine_jvm_classpath $launch_jvm_cp]
                lappend launch_jvm_cp_combined $launch_jvm_cp
            }
        }

        set launch_jvm_cp_combined [join $launch_jvm_cp_combined $launch_jvm_cp_sep]
        lappend launch_argv {-cp} $launch_jvm_cp_combined

        if {[dict exists $launch_block jvm_main]} {
            # call the main class directly (this is for cases when it is
            # contained in one of the referenced classpath JARs - for 
            # example, modern MC clients are loaded as libraries them-
            # selves)
            lappend launch_argv [dict get $launch_block jvm_main]
        } elseif {[dict exists $launch_block jvm_jar]} {
            # launch the specified JAR file
            set launch_jvm_jar [interpolate_launch_string [dict get $launch_block jvm_jar]]
            set launch_jvm_jar [file nativename $launch_jvm_jar]

            lappend launch_argv {-jar} $launch_jvm_jar
        } else {
            return -code error "no JVM main class or .jar specified"
        }

        if {[dict exists $launch_block jvm_main_argv_long_opts_mc]} {
            # conveniently combine all MC-styled spaced long opts into their
            # proper form (--KEY VALUE) and add them one by one to $launch_argv
            dict for {key value} [dict get $launch_block jvm_main_argv_long_opts_mc] {
                set key [join [list {--} $key] {}]
                set value [interpolate_launch_string $value]

                lappend launch_argv $key $value
            }
        }

        # both stdout and stderr will be saved to a separate log file
        set launch_log_path [join [list $config(CURRENT_ROOT) "launch.log"] /]

        # if exists, delete the previous log file
        if {[file exists $launch_log_path]} {
            file delete -force -- $launch_log_path
        }

        log "JVM binary: $launch_jvm"
        log "JVM argv: $launch_argv"

        # run JVM with post-processed CLI arguments
        exec -ignorestderr -- $launch_jvm {*}$launch_argv >& $launch_log_path
    }
}

# on macOS, different directories are used for packages root and config files
# by default
asup::adapt_config_for_macos
# on Micro$oft's OS, we bundle our own binaries for many UNIX tools
asup::adapt_config_for_win32

# guess in-game username from the OS
asup::guess_username

# read in the config INI file, if possible
asup::reload_config_from_ini

if {$::argv0 == [info script]} {
    # read in CLI options to configure our behaviour accordingly
    asup::config_from_argv $::argv

    asup::log [join [list $::asup::config(WM_TITLE_TK) \
                          version $::asup::config(CURRENT_VERSION)] { }]
    asup::log "(running on $::asup::config(CURRENT_OS)/$::asup::config(CURRENT_ARCH))\n"

    # obtain index.json contents first, since they contain basically everything
    # we need to work
    set index_json [asup::get_index_json]
    puts $index_json

    if {$::asup::config(CAN_CHECK_FOR_UPDATES)} {
        # make sure we are running the latest version of the updater
        if {! [asup::is_latest $index_json]} {
            # TODO: perform update
            asup::update_ourselves $index_json
        } else {
            asup::log "Up-to-date (version v$::asup::config(CURRENT_VERSION))"
        }
    }

    # make sure we have something to download, update or verify first
    if {[llength $::asup::config(CAN_DOWNLOAD_PACKAGE)] < 1} {
        error "expected package name to download/update, got nothing"
    } elseif {$::asup::config(CAN_LAUNCH) &&
              [llength $::asup::config(CAN_DOWNLOAD_PACKAGE)] >= 2} {
        error "can only launch one package"
    }

    foreach name $::asup::config(CAN_DOWNLOAD_PACKAGE) {
        puts $name
        asup::download_package $index_json $name

        if {$::asup::config(CAN_LAUNCH)} {
            asup::launch_package $index_json $name
        }
    }
}
