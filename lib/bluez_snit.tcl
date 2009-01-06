############################################################################
#                                                                          #
# Bluez bindings for dbus::snit                                            #
#                                                                          #
# See Bluez API documentation for details:                                 #
# http://wiki.bluez.org/wiki/                                              #
# http://bluez.cvs.sourceforge.net/*checkout*/bluez/utils/hcid/dbus-api.txt#
#                                                                          #
# Copyright (c) 2008 Alexander Galanin <gaa.nnov@mail.ru>                  #
#                                                                          #
# License: LGPLv3 or later                                                 #
#                                                                          #
############################################################################
# $Id: bluez_snit.tcl 26 2009-01-05 14:37:34Z al $

package provide bluez_snit 0.1

package require dbus_snit 0.1

namespace eval ::bluez::snit {

namespace export \
    getManager \
    getAdapter

# getManager --
#
#   Get instance of Bluez Manager object
#
# Arguments:
#   conn    Connection to system bus (object of type
#           ::dbus::snit::BusConnection)

proc getManager {conn} {
    return [ ::dbus::snit::RemoteObject %AUTO% \
        $conn org.bluez /org/bluez \
        org.bluez.Manager org.bluez.Database org.bluez.Security \
    ]
}

# getAdapter --
#
#   Get instance of bluetooth adapter object at specified path.
#
# Arguments:
#   conn    Bus connectio object
#   path    Path to object on the bus (like /org/bluez/hci0)

proc getAdapter {conn path} {
    return [ ::dbus::snit::RemoteObject %AUTO% \
        $conn org.bluez $path \
        org.bluez.Adapter org.bluez.Security \
    ]
}

# Interfaces definitions

::dbus::snit::Interface org.bluez.Manager {
    method InterfaceVersion {out u}
    method DefaultAdapter {out s}
    method FindAdapter {in s, out s}
    method ListAdapters {out as}
    method FindService {in s, out s}
    method ListServices {out as}
    method ActivateService {in s, out s}

    signal AdapterAdded {s}
    signal AdapterRemoved {s}
    signal DefaultAdapterChanged {s}
    signal ServiceAdded {s}
    signal ServiceRemoved {s}
}

::dbus::snit::Interface org.bluez.Database {
    method AddServiceRecord {in ay, out u}
    method AddServiceRecordFromXML {in s, out u}
    method UpdateServiceRecord {in u, in ay}
    method UpdateServiceRecordFromXML {in u, in s}
    method RemoveServiceRecord {in u}
}

::dbus::snit::Interface org.bluez.Security {
    method RegisterDefaultPasskeyAgent {in s}
    method UnregisterDefaultPasskeyAgent {in s}
    method RegisterPasskeyAgent {in s, in s}
    method UnregisterPasskeyAgent {in s, in s}
    method RegisterDefaultAuthorizationAgent {in s}
    method UnregisterDefaultAuthorizationAgent {in s}
}

::dbus::snit::Interface org.bluez.Adapter {
    method GetInfo {out a{sv}}
    method GetAddress {out s}
    method GetVersion {out s}
    method GetRevision {out s}
    method GetManufacturer {out s}
    method GetCompany {out s}
    method ListAvailableModes {out as}
    method GetMode {out s}
    method SetMode {in s}
    method GetDiscoverableTimeout {out u}
    method SetDiscoverableTimeout {in u}
    method IsConnectable {out b}
    method IsDiscoverable {out b}
    method IsConnected {in s, out b}
    method ListConnections {out as}
    method GetMajorClass {out s}
    method ListAvailableMinorClasses {out as}
    method GetMinorClass {out s}
    method SetMinorClass {in s}
    method GetServiceClasses {out as}
    method GetName {out s}
    method SetName {in s}
    method GetRemoteInfo {in s, out a{sv}}
    method GetRemoteServiceRecord {in s, in u, out ay}
    method GetRemoteServiceRecordAsXML {in s, in u, out s}
    method GetRemoteServiceHandles {in s, in s, out au}
    method GetRemoteServiceIdentifiers {in s, out as}
    method FinishRemoteServiceTransaction {in s}
    method GetRemoteVersion {in s, out s}
    method GetRemoteRevision {in s, out s}
    method GetRemoteManufacturer {in s, out s}
    method GetRemoteCompany {in s, out s}
    method GetRemoteMajorClass {in s, out s}
    method GetRemoteMinorClass {in s, out s}
    method GetRemoteServiceClasses {in s, out as}
    method GetRemoteClass {in s, out u}
    method GetRemoteFeatures {in s, out ay}
    method GetRemoteName {in s, out s}
    method GetRemoteAlias {in s, out s}
    method SetRemoteAlias {in s, in s}
    method ClearRemoteAlias {in s}
    method LastSeen {in s, out s}
    method LastUsed {in s, out s}
    method DisconnectRemoteDevice {in s}
    method CreateBonding {in s}
    method CancelBondingProcess {in s}
    method RemoveBonding {in s}
    method HasBonding {in s, out b}
    method ListBondings {out as}
    method GetPinCodeLength {in s, out y}
    method GetEncryptionKeySize {in s, out y}
    method StartPeriodicDiscovery {}
    method StopPeriodicDiscovery {}
    method IsPeriodicDiscovery {out b}
    method SetPeriodicDiscoveryNameResolving {in b}
    method GetPeriodicDiscoveryNameResolving {out b}
    method DiscoverDevices {}
    method CancelDiscovery {}
    method DiscoverDevicesWithoutNameResolving {}
    method ListRemoteDevices {out as}
    method ListRecentRemoteDevices {in s, out as}
    method SetTrusted {in s}
    method IsTrusted {in s, out b}
    method RemoveTrust {in s}
    method ListTrusts {out as}

    signal DiscoveryStarted {}
    signal DiscoveryCompleted {}
    signal ModeChanged {s}
    signal DiscoverableTimeoutChanged {u}
    signal MinorClassChanged {s}
    signal NameChanged {s}
    signal PeriodicDiscoveryStarted {}
    signal PeriodicDiscoveryStopped {}
    signal RemoteDeviceFound {s, u, n}
    signal RemoteDeviceDisappeared {s}
    signal RemoteClassUpdated {s, u}
    signal RemoteNameUpdated {s, s}
    signal RemoteNameFailed {s}
    signal RemoteNameRequested {s}
    signal RemoteAliasChanged {s, s}
    signal RemoteAliasCleared {s}
    signal RemoteDeviceConnected {s}
    signal RemoteDeviceDisconnectRequested {s}
    signal RemoteDeviceDisconnected {s}
    signal RemoteIdentifiersUpdated {s, as}
    signal BondingCreated {s}
    signal BondingRemoved {s}
    signal TrustAdded {s}
    signal TrustRemoved {s}
}

::dbus::snit::Interface org.bluez.PasskeyAgent {
    method Request {in s adapterPath, in s address, in b numeric, out s}
    method Cancel {in s path, in s address}
    method Release {}
}

}

