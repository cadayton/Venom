# Find-VeSymmLogin

List initiators logged into storage arrays based on specified search criteria.

Command line help for this cmdlet is available by executing the following.

    Get-Help Find-VeSymmLogin -full

***

Find Initiator login on storage ports.

The csv file named, Current_ListLogins-<org>.csv is searched based on the specified search criteria.
If no search criteria is specified, then all login entries are displayed in an Out-GridView.

The search critera is anyone or combination of sid, WWN, Name, switch, FCID, or Login value.

    Find-VeSymmLogin -sid 0153 -dirport 2e:0

Lists all the login entries for VMAX array 0153 on director 2e port 0.
