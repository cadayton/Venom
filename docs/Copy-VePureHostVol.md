# Copy-VePureHostVol

Creates a SNAP volume or overwrites an exising SNAP volume from a specified host disk volume and
can optionally mask the SNAP volume to a specified target host.

Command line help for this cmdlet is available by executing the following.

    Get-Help Copy-VePureHostVol -full

***

**Example**

    Copy-VePureHostVol -pureName bowpure002 -source TestDummy01 -vol TestDummy01_S -target TestDummy02

Verifies that the disk volume, testdummy01_S is masked to the source server, TestDummy01 and creates or
overwrites the SNAP volume, testdummy01_S_X.

The SNAP volume, testdummy01_S_X is masked to the target server, Testdummy02 if need be.

A different suffix can be applied to the SNAP volume by specifying the -suffix option.

If the **-target** option is not specified, then the SNAP volume will not be masked.

