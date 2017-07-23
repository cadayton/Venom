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

    Update-VeFlogi -FabricName SOS_Fabric_A

This updates the flogi database records maintained locally in the csv files.  All flogi entries can
be updated with one execution.

    Update-VeFlogi -FabricName All

With a fresh set of flogi records and device-alias names, update the Symmetrix aliases for each array.

    Set-VeSymmLogin -sid 0134
