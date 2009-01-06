#!/bin/sh

############################################################################
#                                                                          #
# Example of using dbus_snit library                                       #
#                                                                          #
# Copyright (c) 2008 Alexander Galanin <gaa.nnov@mail.ru>                  #
#                                                                          #
# This code placed into public domain.                                     #
#                                                                          #
############################################################################
# $Id: hello-server.tcl 26 2009-01-05 14:37:34Z al $

# \
exec tclsh "$0" "$@"

package require Tcl 8.5
package require dbus 0.7

lappend auto_path ../lib

package require dbus_snit 0.1

namespace import ::dbus::snit::*

source hello_interface.def

BusConnection bus session -names com.example.hello.server

::snit::type HelloServer {
    ::dbus::type

    ::dbus::implements com.example.hello.server.Iface

    method Hello {name country} {
        puts "Called method Hello with args: [ list $name $country ]"
        return "Hello, $name from $country!"
    }

}

set server [ HelloServer %AUTO% ]

bus bind /say/hello $server

vwait forever

