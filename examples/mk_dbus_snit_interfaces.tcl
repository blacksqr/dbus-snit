#!/bin/sh

############################################################################
#                                                                          #
# Example of using dbus::snit library                                      #
#                                                                          #
# Generate dbus_snit interface definitions for object on bus that supports #
# org.freedesktop.DBus.Introspectable interface.                           #
#                                                                          #
# Copyright (c) 2008 Alexander Galanin <gaa.nnov@mail.ru>                  #
#                                                                          #
# This code placed into public domain.                                     #
#                                                                          #
############################################################################
# $Id$

# \
exec tclsh "$0" "$@"

lappend auto_path ../lib

package require Tcl 8.5
package require dbus 0.7
package require dbus_snit 0.1
package require xml

# usage --
#
#       Print usage information

proc usage {} {
    foreach {line} {
        "Usage: mk_dbus_snit_interfaces.tcl bus path ?destination?"
        ""
        "Generate dbus_snit interface definitions for object on bus that"
        "supports org.freedesktop.DBus.Introspectable interface."
        ""
    } {
        puts $line
    }
}

# getIntrospectionXml --
#
#   Get introspection information from D-Bus object using
#   org.freedesktop.DBus.Introspectable.Introspect call
#
# Arguments:
#   bus     Bus name (system or session)
#   path    Path to object
#   dest    D-Bus destination (can be in form :22.1 or org.example.test)

proc getIntrospectionXml {bus path {dest {}}} {
    set a [ list $bus ]
    if {$dest !=""} {
        lappend a -dest $dest
    }
    lappend a $path org.freedesktop.DBus.Introspectable Introspect
    return [ dbus::call {*}$a ]
}

# buildInterfaces --
#
#   Get introspection information from object and build interfaces
#   definitions.
#
# Arguments:
#   bus     Bus name (system or session)
#   path    Path to object
#   dest    D-Bus destination (can be in form :22.1 or org.example.test)
#
# Results:
#   Result are printed to stdout

proc buildInterfaces {bus path {dest {}}} {
    global ns

    set parser [ xml::parser \
        -elementstartcommand ${ns}::elementstartcommand \
        -elementendcommand ${ns}::elementendcommand \
        -reportempty 0 \
    ]
    $parser parse [ getIntrospectionXml $bus $path $dest ]
    $parser free
}

# put --
#
#   Put arguments to stdout as list

proc put {args} {
    puts $args
}

# line --
#
#   Put empty line to stdout

proc line {} {
    puts {}
}

set ns ::private 
namespace eval $ns {
    variable topLevelNodeProcessed 0
    variable 1st 0

    proc elementstartcommand {name attlist args} {
        variable topLevelNodeProcessed
        variable 1st

        array set attr $attlist
        switch -exact $name {
            node {
                # Ignore sub-nodes
                if !$topLevelNodeProcessed {
                    set topLevelNodeProcessed 1
                    put package require dbus_snit
                    put namespace import dbus::snit::*
                    line
                }
            }
            interface {
                puts "[ list Interface $attr(name) ] \{"
            }
            method -
            signal {
                # Workaround for bug in tclxml-libxml2 that does not report
                # -empty flag
                if $1st {
                    # Close previously opened method or signal arg list
                    puts \}
                }

                set 1st 1
                puts -nonewline "    [ list $name $attr(name) ] \{"
            }
            arg {
                if $1st {
                    set 1st 0
                } else {
                    puts -nonewline ", "
                }
                if [ info exists attr(direction) ] {
                    set a [ list $attr(direction) ]
                }
                lappend a $attr(type)
                if [ info exists attr(name) ] {
                    lappend a $attr(name)
                }
                puts -nonewline $a
            }
            property {
                #TODO: Properties are not supported in dbus_snit 0.1
            }
            default {
                error "Unknown tag $name!"
            }
        }
    }

    proc elementendcommand {name args} {
        variable 1st

        switch -exact $name {
            interface {
                puts \}
                line
            }
            method -
            signal {
                # Workaround for bug in tclxml-libxml2 that does not report
                # -empty flag
                if !$1st {
                    puts \}
                }
            }
        }
    }
}

############################################################################
# MAIN
############################################################################

if {$argc != 2 && $argc != 3} {
    usage
    exit 1
}

set bus [ lindex $argv 0 ]

::dbus::connect $bus

buildInterfaces {*}$argv

