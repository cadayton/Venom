# Connect-VeFabric

Tests the SSH protocol connectivity to switch(s) for all or a specific SAN fabrics with an Organization scope and
creates SAN Fabric domain csv file.

Command line help for this cmdlet is available by executing the following.

    Get-Help Connect-VeFabric -full

***

Establishes a SSH session with the specified Cisco MDS FC switch specific in the fabric record found
in the XMLDB.

Creates a SAN Fabric domain csv file when the '-createCSV' option is specified.
**[execution folder]\\SwInfo-[org]\\[fabricname]\\[fabricname].csv**.  If this file already exists,
it is moved to the archive folder and new csv file is created.

The SAN Fabric domain csv file contains a record for each switch that is member of the SAN Fabric domain.

# Workflow

The typical workflow is to execute this cmdlet after defining the fabric record in the XMLDB or after
new switches are added or removed from the fabric.

    Connect-VeFabric -FabricName SOS_Fabric_A -createCSV

To just test SSH connectivity to switch(s) in a fabric.

    Connect-VeFabric -FabricName SOS_Fabric_A 
