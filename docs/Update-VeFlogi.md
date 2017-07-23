# Update-VeFlogi

Extract the flogi entries from each switch in the SAN fabrics.

Command line help for this cmdlet is available by executing the following.

    Get-Help Update-VeFlog -full

***

Establishes a SSH session with the specified Cisco MDS FC switch in a SAN Fabric and
extracts the flogi entries into a csv file for each switch in the Fabric. The csv file is
name **[switchID]_flog.csv**.

When the Fabric folder is version controlled, the daily changes to the flogi logins can
be easily track from day to day.

It is also useful to have a capture of the flogi info before and after switch maintenance
to easily identify any WWNs failing to log back into the switch.

# Workflow

In the module directory 'local', is some code called **Start-WeeklyUpdates.ps1**.  This is an
example of the order of execution as well as a way to batch processs all of the cmdlets together.

The typical workflow is to execute this cmdlet at least daily. 

    Update-VeFlogi -FabricName SOS_Fabric_A
