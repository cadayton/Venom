By default, the Unisphere RESTAPI is called to collect capacity metrics for each of the
symmetrix arrays.

One can query either an online (local or remote) or an offline copy of the symapi database
and updates capacity metrics.

PureSystem's PureStoragePowerShellSDK is used update Pure Storage arrays.

For PureSystem arrays, the module **PureStoragePowerShellSDK** is used to make RESTAPI calls
to collect the data.
***
To get detailed help information and/or examples of executing **Update-VeArrayInfo** can be
displayed by entering, the following command.

    PS> get-help Update-VeArrayInfo -full

**Update-VeArrayInfo** is a CLI based method of execution and supports specific parameters.
Using default values of the parameters will cause the Unisphere RESTAPI to be used to collect
capacity metrics from Symmetrix and Pure System storage arrays and generate a new XML DB file,
**ArrayInfo-MM-DD-YY.xml** in the sub-folder, **ArrayInfo** of the working directory.

Executing this script without parameters starts the updating process using RESTAPI to the Symmetrix and Pure Storage arrays.

    PS> Update-VeArrayInfo

If a encrypted cached credential file, doesn't exist in the folder, **CredInfo** a prompt for
the array password will appear on the PowerShell console. The account name used is the one specified in the array's record in the XMLDB.  If the **CredInfo** folder doesn't exist, it will be created automatically.


After the updating process has been completed, the new capacity metrics can be viewed by executing,
**Get-VeArrayInfo**.

    PS> .\Get-VeArrayInfo
