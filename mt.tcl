#!/usr/bin/env tclsh
package require Thread 2.6

namespace eval asup {
    namespace eval mt {
        variable wk_result 0
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

        proc enqueue {command} {
            set var_name [join [list [namespace current] wk_result] ::]

            # initialize the worker thread if it hasn't been already done yet
            init

            # send the command to evaluate to the worker thread and obtain its
            # result directly
            variable wk_thread
            thread::send -async $wk_thread $command $var_name
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
