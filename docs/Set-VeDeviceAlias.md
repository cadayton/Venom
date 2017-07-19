# Set-VeDeviceAlias

Creates device-aliases on Cisco SAN fabric for initiators and optionally targets missing a device-alias assignment.

Command line help for this cmdlet is available by executing the following.

    Get-Help Set-VeDeviceAlias -full

***

Establishes a SSH session with the specified Cisco MDS FC switch and sets a device-alias name for
initiators and optionally targets without a device-alias.
        
For physical ports NOT in a zone, the new device-alias name is formed using the first node value in
the switch's port description field following by switch name and port location.
        
    Example: bowWinServer_mdsbow01_0939

For virtual ports (NPIV), the device-alias name will be the same as the zone name that it is a member of.

The SAN Fabric folder contains a set of flogi csv files which are used for assessing which interfaces
are missing a device-alias assignment. A SAN Fabric folder named, **[execution folder]\\SWInfo-[org]\\[fabricname]**
will be searched for flogi csv files.  The naming convention for the flogi csv files is: **[switchID]_flogi.csv**. 
        
A Cisco command file is created in the SAN Fabric folder containing a device-alias commands for each
interface missing a device-alias. The command file naming convention is **[switch name]_Alias.cmd**.

All SAN Fabric related files are contained in the specific SAN Fabric folder.  Each SAN Fabric folder
contains a sub-folder named, Archive for historical tracking of changes.

# Workflow

The typical work is to execute the following sequence of cmdlets on schedule that is appropriate.

    Set-VeDeviceAlias -FabricName SOS_Fabric_A

If any WWNs are missing a device-alias, one or more **[switch name]_Alias.cmd** will be created in the
SAN Fabric folder.  Review the alias command file to ensure the device-alias names are desired.

Apply the device-aliases to the SAN Fabric.

    Set-VeDeviceAlias -FabricName SOS_Fabric_a -apply

The alias command in each of the files is then executed and the command files are moved to the
archive folder.
