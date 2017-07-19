# Enable-VePorts

Enables switch port(s) and sets port's VSAN and description fields.

Command line help for this cmdlet is available by executing the following.

    Get-Help Enable-VePorts -full

***

Enables switch port(s) specified in a csv file located in the FabricName folder.  The csv file
consists of 3 fields, interface,VSAN, and Description.

    interface field:   fcx/y where x is the blade number and y is the port number.
    VSAN field:        numeric value of the desired VSAN.
    Description field: device-alias name followed by a space then the description.

    i.e. fc1/6,100,bowvmx099_fa05h Engine 1 X X

A file titled, **[switchname]_enable.csv** is expected to found in the FabricName folder.

Each port will be added to the VSAN, enabled, and description field set.  Once the
port(s) have been enabled, the csv file is move to the Archive folder.

# Workflow

The typical workflow is to execute this cmdlet after creating the csv file.

    Enable-VePorts -FabricName SOS_Fabric_A

