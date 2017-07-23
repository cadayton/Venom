## Overview

Two fictitious Data Centers called the Snake and the Samish has a storage environment consisting of 97 storage arrays.  The SAN infrastructure consists of 78 director class fiber channel switches with over 24,000 host intiators and over 1,900 storage target ports. The SOS and Mojo organizations are the two primary tenants of the data centers. At any given time, there are about a million IOs in flight among the two data centers.

The **Venom** module is a collection of PowerShell scripts that ease the burden of maintaining a storage infrastructure of this scale.  This module is designed for the storage engineer who is in the trenches and desires quick access to SAN information.

Both PowerShell and this module are used daily for reporting on SAN inventory, capacity and performance data. A goal of the module is not to become the authoritive source for any SAN information but rather be a simple interface for presenting authoritive SAN information from various storage devices in real-time. Having quick access to key SAN information, allows the storage engineer to quickly identify potential issues and then launch the appropriate management tool for deeper analysis.

The listing of scripts below are in the process being converted to be cmdlets available through the **Venom** module.  A varity of access methods are used communicate with the storage devices, including native CLI, RESTAPI, and the SSH protocol.

All the scripts are functioning today indivdually on Windows 10 and I'm going through the labor of converting them to be available in **Venom** module.

**cmdlets currently available in the Venom module**

cmdlet | Description | Version | Date | Author
-------| ----------- | ------- | ---- | -------
Get-VeArrayInfo | Storage array inventory & capacity data. | 0.0.2.0 | 07/07/2017 | cadayton
Update-VeArrayInfo | Updates capacity data for most storage arrays. | 0.0.2.1 | 07/10/2017 | cadayton
Get-VeSymmMetrics | View various Symmetrix performance data. | 0.0.2.0 | 07/07/2017 | cadayton
Set-VeSymmAlias | Set Symm Aliases or View FA login entries | 0.0.2.3 | 07/20/2017 | cadayton
Find-VeSymmAlias | Search for specific FA login in entries | 0.0.2.3 | 07/20/2017 | cadayton
Start-VeUnisphere | Launch Unisphere given a SID | 0.0.2.3 | 07/20/2017 | cadayton
Start-VeVappManager | Launch VappManager given a SID | 0.0.2.3 | 07/20/2017 | cadayton
Start-VeEcomConfig | Launch EcomConfig interface given a SID | 0.0.2.3 | 07/20/2017 | cadayton
Get-VePureMetrics | View various Pure Storage performance data | 0.0.2.0 | 07/10/2017 | cadayton
Set-VeDeviceAlias | Automates setting Cisco device-aliases | 0.0.2.2 | 07/16/2017 | cadayton
Connect-VeFabric | Discovers Cisco Fabric Domains | 0.0.2.2 | 07/16/2017 | cadayton
Update-VeFlogi | Maintain Cisco switch flogi entries | 0.0.2.2 | 07/16/2017 | cadayton
Enable-VePorts | Automates enabling of Cisco ports | 0.0.2.2 | 07/16/2017 | cadayton

Some functionality of these cmdlets will not be available until all of the PowerShell scripts have been converted to module cmdlets.

The module can be installed on either a Windows desktop for individual usage or centrally on a Windows server for centralized usage.

After installing the module and the prerequisites, the **Get-VeArrayInfo** cmdlet needs to be executed to create the XMLDB files, located in the folder, **ArrayInfo**.  Both the folder and XMLDB files are created automatically upon the first execution.  I recommend using **Visual Studio Code** to update the XMLDB file to match your storage environment, but any ASCII editor will work too.  See the XMLDB documentation for further details.

Since each of the cmdlets will depend upon a specific underlining folder structure, pick a common folder location where upon all cmdlets will be executed. Each cmdlet will automatically create the needed folders. See the individual cmdlet documentation for specific folder dependencies. Each cmdlet provides command line help and can be displayed by entering the following command for each cmdlet.

    Get-Help Get-VeArrayInfo -full

***

**PowerShell scripts currently being converted to Venom module cmdlets**

Script | Description
------ | -----------
Get-VPlexMetrics | Reports on VPlex performance by downloading data via SSH and using RESTAPI.
Get-SRDFInfo | Out-Gridview of all SRDF sessions in the xml DB file.
Update-SRDFInfo | Builds inventory of SRDF sessions and creates devicefile for each SRDF Session.
Get-SANInfo | Display of ISL and Port-Channels in the Cisco SAN Fabrics.
