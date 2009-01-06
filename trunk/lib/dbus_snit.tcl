############################################################################
#                                                                          #
# High level Tcl bindings to D-Bus using Snit object system                #
#                                                                          #
# Copyright (c) 2008 Alexander Galanin <gaa.nnov@mail.ru>                  #
#                                                                          #
# License: LGPLv3 or later                                                 #
#                                                                          #
############################################################################
# $Id: dbus_snit.tcl 28 2009-01-06 01:27:34Z al $

package provide dbus_snit 0.1

package require snit 2.0
package require dbus 0.7
package require uevent 0.1

namespace eval ::dbus::snit {

namespace export \
    BusConnection \
    RemoteObject \
    Interface

::snit::type BusConnection {
    variable bus
    variable conn

    option -yield \
        -readonly true \
        -default false \
        -type snit::boolean 

    option -replace \
        -readonly true \
        -default false \
        -type snit::boolean

    option -noqueue \
        -readonly true \
        -default false \
        -type snit::boolean

    # Names that should be requested for the connection
    option -names \
        -readonly true \
        -default {} \
        -type snit::listtype

    # constructor --
    #
    #   Create connection to bus
    #
    # Arguments:
    #   bus     Bus id (can be session or system)
    #   args    List of arguments
    #           -names      List of names that sould be assigned to this
    #                       connection
    #           -yield      Release the requested name when some other
    #                       application requests the same name
    #           -replace    Take over the ownership of the name from the
    #                       application that is currently the primary owner
    #           -noqueue    Name request should not be queued

    constructor {id args} {
        set bus $id
        set conn [ ::dbus::connect $bus ]

        $self configurelist $args

        # Try to assign each specified name
        set nameopts {}
        foreach opt {-yield -replace -noqueue} {
            if $options($opt) {
                lappend nameopts $opt
            }
        }
        foreach name $options(-names) {
            ::dbus::name {*}$nameopts $name
        }
    }

    # destructor --
    #
    #   Disconnect from bus

    destructor {
        #TODO: dbus::disconnect are missing at the current moment
        catch {
            ::dbus::disconnect $bus
        }
    }

    # bus --
    #
    #   Return bus ID

    method bus {} {
        return $bus
    }

    # bind --
    #
    #   Bind proc or object to be called when method_call message arrived
    #   for the specified path.

    method bind {path object} {
        ::dbus::filter $bus add \
            -destination $conn \
            -path $path \
            -type method_call
        ::dbus::register $bus \
            -async \
            $path [ list apply {
                {bus object info args} {
                    dict set info bus $bus
                    $object dbus call $info {*}$args
                }
            } $bus $object ]

        # Unregister commands where object or proc is removed.
        trace add command $object delete [ list apply {
            {bus conn path args} {
                ::dbus::filter $bus remove \
                    -destination $conn \
                    -path $path \
                    -type method_call
                ::dbus::register $bus \
                    $path {}
            }
        } $bus $conn $path ]
    }

}

::snit::type RemoteObject {

    variable bus
    variable conn
    variable path
    variable ifaces

    # Handle unknown methods using 'call' command
    delegate method * using "%s call %m"

    # constructor --
    #
    #   Create snit object that provides access to remote D-Bus object
    #
    # Arguments:
    #   busobj      Object of type BusConnection that keeps bus information
    #   name        D-Bus connection to use (for example, org.bluez or :22.0)
    #   objpath     Object path
    #   args        List of interfaces (previously defined by
    #               ::dbus::snit::registerInterface)

    constructor {busobj name objpath args} {
        set bus [ $busobj bus ]
        set conn $name
        set path $objpath
        set ifaces $args

        ::dbus::filter $bus add \
            -sender $conn \
            -path $path \
            -type signal
        ::dbus::register $bus \
            $path [ mymethod ProcessSignal ]
    }

    # destructor --
    #
    #   Unregister signal handlers.

    destructor {
        catch {
            ::dbus::filter $bus remove \
                -sender $conn \
                -path $path \
                -type signal
            ::dbus::register $bus \
                $path {}
        }
    }

    # ProcessSignal --
    #
    #   Generate event by uevent::generate call using object name as 'tag',
    #   fully-qualified signal name as 'event' and pair of signal info and
    #   signal arguments as 'details'.

    method ProcessSignal {info args} {
        ::uevent::generate $win \
            [ dict get $info interface ].[ dict get $info member ] \
            [ list $info $args ]
    }

    # Call --
    #
    #   Call specified method and return result immediately or via callback.
    #   See call and asyncCall comments for details.
    #
    # Arguments:
    #   method      Method name (FQN or short name)
    #   args        List of method arguments
    #   handler     (optional) Callback procedure to invoke where result
    #               available. If specified, method will return immediately.

    method Call {method args {handler {}}} {
        if ![ regexp -nocase {^((?:\w+\.)*\w+)\.(\w+)$} $method \
                dummy iface method ] {
            # If short (without interface) method name given then
            # search for matching method in all interfaces
            set iface {}
            foreach i $ifaces {
                if [ ::$i method exists $method ] {
                    set iface $i
                    break
                }
            }
            if {$iface == ""} {
                error "Method $method are not found!"
            }
        }

        set sign [ ::$iface method signature $method in ]

        # set noreply flag if it is needed
        if [ ::$iface method param $method noreply ] {
            set responceFlag [ list -timeout -1 ]
        } else {
            set responceFlag {}
        }

        if {$handler != ""} {
            set handlerFlag [ list -handler $handler ]
        } else {
            set handlerFlag {}
        }

        # call method and return result
        return [ ::dbus::call $bus \
            -dest $conn \
            -signature $sign \
            {*}$responceFlag \
            {*}$handlerFlag \
            $path $iface $method {*}$args \
        ]
    }

    # call --
    #
    #   Call specified (by full or short name) method with args and wait
    #   for result.
    #   Either fully-qualified or short method name can be given.
    #   If short name passed, search for method with equal name will be
    #   performed over all implemented interfaces. If there are more than
    #   one methods with the same name, behaviour is unexpected.
    #
    # Arguments:
    #   method      Method name (FQN or short name)
    #   args        Method arguments.

    method call {method args} {
        $self Call $method $args
    }

    # asyncCall --
    #
    #   Call method asynchronously and invoke callback on return value or
    #   error message availability.
    #   Either fully-qualified or short method name can be given.
    #   If short name passed, search for method with equal name will be
    #   performed over all implemented interfaces. If there are more than
    #   one methods with the same name, behaviour is unexpected.
    #
    # Arguments:
    #   callback    Command to execute when method execution finished.
    #               Will be concatenated with D-Bus method information dict
    #               and method return values and then eval-ed.
    #   method      Method name (FQN or short name)
    #   args        Method arguments.

    method asyncCall {callback method args} {
        $self Call $method $args $callback
    }

    # bind --
    #
    #   Bind command to D-Bus signal. Callback command will be concatenated
    #   with extra signal information specified as 'extra' argument and
    #   signal arguments.
    #
    # Arguments:
    #   signal  Signal name (can be FQN or short name)
    #   handler Command to execute when signal occurs on the bus.
    #   extra   Extra signal information to append to handler call.
    #           Can be info, object or signal to attach D-Bus message
    #           information dict, object name and fully-qualified signal
    #           name correspondingly.
    #
    # Returns:
    #   Token that can be used in unbind method.

    method bind {signal handler {extra {}}} {
        if ![ regexp -nocase {^((?:\w+\.)*\w+)\.(\w+)$} $signal \
                dummy iface signal ] {
            # If short (without interface) signal name given then
            # search for matching signal in all interfaces
            set iface {}
            foreach i $ifaces {
                if [ ::$i signal exists $signal ] {
                    set iface $i
                    break
                }
            }
            if {$iface == ""} {
                error "Signal $signal are not found!"
            }
        }
        set callback [ list apply {{callback extra object signal arg} {
            lassign $arg info args
            set extraArg {}
            foreach v $extra {
                lappend extraArg [ set $v ]
            }
            eval $callback $extraArg $args
        }} $handler $extra ]
        return [ ::uevent::bind $win $iface.$signal $callback ]
    }

    # unbind --
    #
    #   Unbind command from signal. Takes token returned from bind call.

    method unbind {token} {
        ::uevent::unbind $token
    }

}

# Private namespace for keeping methods and signals information on interface
# definition.
namespace eval private {

variable methods {}
variable signals {}

# init --
#
#   Clean variables in a private namespace.

proc init {} {
    variable methods {}
    variable signals {}
}

# method --
#
#   Used in Interface to define method signature that can be used
#   in D-Bus calls
#
# Arguments:
#   name    Method name
#   arg     Comma-separated list of argument specifications.
#           Every argument specification must be a list of the following
#           elements:
#               in|out type ?name?
#           Where first element must be 'in' for input arguments and 'out'
#           for return values. 'type' is D-Bus type signature. 'name' can be
#           omitted.
#   args    Extra method parameters. Can be one of following:
#               noreply     Do not expect a reply to the method call

proc method {name arg args} {
    variable methods

    set in {}
    set out {}
    foreach spec [ split $arg , ] {
        lassign $spec dir type id
        switch -exact $dir {
            in -
            out {
                lappend $dir $type $id
            }
            default {
                error "Unknown direction: $dir"
            }
        }
        if {$type == ""} {
            error "Type can not be empty!"
        }
    }
    dict set methods $name [ dict create \
        in $in \
        out $out \
        params $args \
    ]
}

# signal --
#
#   Used in Interface to define signal that can be emitted or received over
#   the bus.
#
# Arguments:
#   name    Signal name
#   arg     Comma-separated list of argument specifications in format:
#               type ?name?
#           Where 'type' is D-Bus type signature. 'name' is argument name and
#           can be omitted.

proc signal {name arg} {
    variable signals

    set p {}
    foreach spec [ split $arg , ] {
        lassign $spec t n
        if {$t == ""} {
            error "Type can not be empty!"
        }
        lappend p $t $n
    }
    dict set signals $name $p
}

}

# Interface --
#
#   Define new D-bus interface. Use method, signal and property macros
#   in interface body to define corresponding D-Bus essences.

proc Interface {name body} {
    namespace inscope private init
    namespace inscope private $body

    InterfaceClass ::$name \
        [ set [ namespace current ]::private::methods ] \
        [ set [ namespace current ]::private::signals ]
}

# InterfaceClass --
#
#   Class that keeps D-Bus class representation.

snit::type InterfaceClass {
    variable methods
    variable signals

    constructor {meth sign} {
        set methods $meth
        set signals $sign
    }

    # method list --
    #
    #   Return list of methods

    method {method list} {} {
        return [ dict keys $methods ]
    }

    # methos exists --
    #
    #   Check that method $name defined in the interface

    method {method exists} {name} {
        return [ dict exists $methods $name ]
    }

    # method arguments --
    #
    #   Return list of arguments for method $name
    #
    # Arguments:
    #   name        Method name
    #   direction   Can be 'in' or 'out' for input and output parameters
    #               correspondingly
    #
    # Returns:
    #   List of elements type and name
    #       type    D-Bus type signature
    #       name    Parameter name (can be empty)

    method {method arguments} {name direction} {
        return [ dict get $methods $name $direction ]
    }

    # method signature --
    #
    #   Return D-Bus method signature
    #
    # Arguments:
    #   name        Method name
    #   direction   'in' or 'out'
    
    method {method signature} {name direction} {
        set s {}
        foreach {t n} [ dict get $methods $name $direction ] {
            append s $t
        }
        return $s
    }

    # method param --
    #
    #   Check that param $param is defined for method $name

    method {method param} {name param} {
        return [ expr \
            [ lsearch [ dict get $methods $name params ] $param ] >= 0 \
        ]
    }

    # signal list --
    #
    #   Return list of a defined signals

    method {signal list} {} {
        return [ dict keys $signals ]
    }

    # signal arguments --
    #
    #   Return list of signal arguments
    #
    # Arguments:
    #   name    Signal name
    #
    # Returns:
    #   List of elements type and name
    #       type    D-Bus type signature
    #       name    Parameter name (can be empty)

    method {signal arguments} {name} {
        return [ dict get $signals $name ]
    }

    # signal exists --
    #
    #   Check that signal $name defined in the interface

    method {signal exists} {name} {
        return [ dict exists $signals $name ]
    }

}

}

# ::dbus::type --
#
#   Marker macro that used to indicate that class is a dbus::snit class.
#   Provides 'dbus *' functions.

::snit::macro ::dbus::type {} {
    variable dbus_msgid
    typevariable dbus_asyncmethods {}
    typevariable dbus_interfaces {}

    # dbus call --
    #
    #   Dispatch method call to corresponding method.
    #   If method is not marked as 'asynchronous' using ::dbus::async macro,
    #   return value or error will be sent to the bus immediately.
    #   Otherwise method is responsible to return value or error using
    #   '$self dbus return' or '$self dbus error' call.
    #   If there are no method with specified interface, error will be
    #   returned.
    #
    # Arguments:
    #   info    D-Bus message info
    #   args    Method arguments

    method {dbus call} {info args} {
        set dbus_msgid $info

        set iface [ dict get $info interface ]
        set member [ dict get $info member ]

        if {[ lsearch [ set [ mytypevar dbus_interfaces ] ] $iface ] < 0} {
            # Return error message if interface is not implemented
            $self dbus error $info \
                "Interface '$iface' was not found" \
                org.freedesktop.DBus.Error.UnknownInterface
            return
        }

        if {[ $self info methods $iface.$member ] != ""} {
            # If method with the full interface name exists
            set mymethod $iface.$member
        } else {
            # Otherwise try to call method by short name
            set mymethod $member
        }

        set async [ $self dbus method async $mymethod ]
        set err [ catch {$self $mymethod {*}$args} res ]

        if {!$async} {
            if $err {
                $self dbus error $info $res
            } else {
                set outCount [ expr \
                    [ llength [ ::$iface method arguments $member out ] ]/2 \
                ]
                if {$outCount == 1 } {
                    # If method returns single value...
                    set res [ list $res ]
                } elseif {$outCount == 0} {
                    # If method returns void...
                    set res {}
                }
                $self dbus return $info {*}$res
            }
        }
    }

    # dbus msgid --
    #
    #   Return current message ID. Useful in implementing 'async' methods.

    method {dbus msgid} {} {
        return $dbus_msgid
    }

    # dbus method --
    #
    #   Return various method information
    #
    # Arguments:
    #   op      Operation. Can be one of:
    #               async   Check that method defined as 'async'
    #   name    Method name

    method {dbus method} {op name} {
        switch -exact $op {
            async {
                return [ expr \
                    [ lsearch \
                        [ set [ mytypevar dbus_asyncmethods ] ] \
                        $name \
                    ] >= 0 \
                ]
            }
            default {
                error "Unknown operation $op!"
            }
        }
    }

    # dbus return --
    #
    #   Send return message to the bus.
    #   If original message specifies 'no_reply' flag, method does nothing.
    #
    # Arguments:
    #   msgid   Message ID returned from '$self dbus msgid' call
    #   args    Return values

    method {dbus return} {msgid args} {
        if [ dict get $msgid noreply ] {
            return
        }

        set iface [ dict get $msgid interface ]
        set member [ dict get $msgid member ]
        set sign [ ::$iface method signature $member out ]

        ::dbus::return [ dict get $msgid bus ] \
            -signature $sign \
            [ dict get $msgid sender ] [ dict get $msgid serial ] \
            {*}$args
    }

    # dbus error --
    #
    #   Send error message to the bus.
    #   If original message specifies 'no_reply' flag, method does nothing.
    #
    # Arguments:
    #   msgid   Message ID returned from '$self dbus msgid' call
    #   error   Error message
    #   errtype Error class (example: org.example.Error.Interface)

    method {dbus error} {msgid error {errtype org.freedesktop.DBus.Error.Failed}} {
        if [ dict get $msgid noreply ] {
            return
        }
        ::dbus::error [ dict get $msgid bus ] \
            -name $errtype \
            [ dict get $msgid sender ] [ dict get $msgid serial ] \
            $error
    }

    # dbus interfaces --
    #
    #   Return list of D-Bus interfaces implemented by class

    method {dbus interfaces} {} {
        return [ set [ mytypevar dbus_interfaces ] ]
    }

}

# ::dbus::implements --
#
#   Snit macro that used to tell that specified class implements
#   one or more D-Bus interfaces.

::snit::macro ::dbus::implements {args} {
    typevariable dbus_interfaces $args
}

# ::dbus::async --
#
#   Marks specified methods as 'asynchronous'. It means that method return
#   value will never be sent to sender automatically.
#   'Asynchronous' methods whould return it values and errors using
#   '$self dbus return' and '$self dbus error' methods correspondingly.

::snit::macro ::dbus::async {args} {
    typevariable dbus_asyncmethods $args
}

