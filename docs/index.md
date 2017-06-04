## Overview

Collection of PowerShell scripts reporting on storage array inventory, capacity and performance data.

The following scripts are being converted to be available through the **Venom module**.  A varity of access methods are used communicate with the storage arrays, including native CLI, REST API, and the SSH protocol.

All the scripts are functioning today indivdually on Windows 10 and I'm going through the labor of coverting them to be available in **Venom module**.

CmdLet | Description
------ | -----------
Get-ArrayInfo  | Script for maintaining array inventory and capacity records in a XML DB.
Update-ArrayInfo | Script for updating capacity details in the XML DB.
Get-ArrayMetrics   | Script for displaying various Dell/EMC symmetrix performance data via the RESTAPI.
Get-PureMetrics | Script for displaying PureSystem array performance data via the RESTAPI.
Get-VPlexMetrics | Reports on VPlex performance by downloading data via SSH and using RESTAPI.
Get-SRDFInfo | Out-Gridview of all SRDF sessions in the xml DB file.
Update-SRDFInfo | Builds inventory of SRDF sessions and creates devicefile for each SRDF Session.
Get-ArrayLogin | List initiators logged into storage arrays based on specified search criteria.
Get-SANInfo | Display of ISL and Port-Channels in the Cisco SAN Fabrics.
Set-DeviceAlias | Creates device-aliases on Cisco SAN fabric for initiators and optionally targets missing a device-alias assignment. Or can enable specific switch port(S) and assign a VSAN value and a port description
Set-SymmAlias | Creates Symmetrix alias for each initiator logged into a FA port. Or records the login entries to a csv file and reports on the csv file entries in a Out-GridView.
