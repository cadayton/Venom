# Set-VeSymmLogin

Creates Symmetrix alias for each initiator logged into a FA port.

Or records the login entries to a csv file and reports on the csv file entries in a Out-GridView.

Command line help for this cmdlet is available by executing the following.

    Get-Help Set-VeSymmLogin -full

***

Each login entry for a FA port is examined for existance of a node alias
and port alias.
        
If the initiator is logged into the FA port and the an alias name does not 
exist, a new alias name is established.  The alias naming convention is:

    [initiator-name] / [switch name]_[xxyy]

The **[initiator-name]** is determined by looking up the device-alias name found in flogi
database. Only the first part of the device-alias name is used to construct the 
[initiator-name].  The **[xxyy]** value is the blade and port value of the switch that the
initiator is connected to. Leading zeros are used for single digits.
        
If the initiator entry is not logged into the FA port, the initiator entry is removed from
the FA port.

# Workflow

In the module directory 'local', is some code called **Start-WeeklyUpdates.ps1**.  This is an
example of the order of execution as well as a way to batch processs all of the cmdlets together.

The typical work is to execute the following sequence of cmdlets on a schedule that is appropriate.

    Set-VeDeviceAlias -FabricName All

This generates a new device-alias command files for all switches in all fabrics.  See the documentation for this cmdlet.

    Set-VeDeviceAlias -FabricName All -apply

This reads each of the just created device-alias command files and **applies** the device-alias command on each of the switches. See the documentation for this cmdlet.

    Update-VeFlogi -FabricName All

This dumps a fresh set of flogi csv files for each of the switches in all fabrics.

With a fresh set of flogi records and device-alias names, update the Symmetrix aliases for each array.

    Set-VeSymmLogin -sid 0000

This generates a FA login csv file for each array in the directory,
[execution folder]\\FALogin\\[sid]-ListLogins-[Org].csv.

    Set-VeSymmLogin -sid 0000 -MergeLogin

This merges all of the individual login csv files into a single csv login file,
[execution folder]\\FALogin\\Current-ListLogins-[Org].csv.

**Wow** sounds like a lot steps doesn't it. Creating a function within a  
PowerShell profile that executes each of the above cmdlets will allow execution of these cmdlets as a single command.

