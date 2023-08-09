#!/usr/bin/env tclsh
package require Thread 2.6

namespace eval asup {
    namespace eval mt {
        variable wk_result 0
        variable wk_error 0

        variable wk_thread {}

        proc init {} {
            variable wk_thread

            # if the worker thread is already initialized, there is nothing
            # else we can do
            if {$wk_thread != {}} {
                return
            }

            set wk_thread [thread::create -preserved {
                                # since Tcl threads are separate isolated
                                # interpreter contexts, we need to load
                                # the updater here initialially as well
                                set argv0 {}
                                source updater.tcl

                                # make sure we inform the updater that it
                                # is running in a separate worker thread
                                array set asup::config {USE_MT 1}
                                thread::wait
                           }]
        }

        proc enqueue {command {wait_cmd -}} {
            set var_name [join [list [namespace current] wk_result] ::]

            # initialize the worker thread if it hasn't been already done yet
            init

            # send the command to evaluate to the worker thread and obtain its
            # result directly
            variable wk_thread
            thread::send -async $wk_thread $command $var_name

            if {$wait_cmd != {-}} {
                # keep the event loop running using the specified vwait-like
                # command
                $wait_cmd $var_name

                # return the resulting execution value
                variable wk_result
                return $wk_result
            }
        }

        proc try_enqueue {command wait_cmd} {
            if {$wait_cmd == {} || $wait_cmd == {-}} {
                return -code error "must have a valid event loop command!"
            }

            asup::mt::set_var command $command
            asup::mt::enqueue {
                tsv::set wk result {}
                tsv::set wk error {}

                if {[catch $command result]} {
                    tsv::set wk error $result
                } else {
                    tsv::set wk result $result
                }
            } $wait_cmd

            set is_error [tsv::get wk error]

            if {[string length $is_error] > 0} {
                return -code error $is_error
            }

            variable wk_result
            set wk_result [tsv::get wk result]

            return $wk_result
        }

        proc set_var {name {value {}}} {
            # initialize the worker thread in advance just in case
            init

            # set the variable value inside the worker thread interpreter as
            # requested
            variable wk_thread
            thread::send $wk_thread [list set $name $value]
        }

        proc deinit {} {
            variable wk_thread

            if {$wk_thread == {}} {
                return
            }

            # release the worker thread and clean up
            thread::release $wk_thread
            set wk_thread {}
        }
    }
}
