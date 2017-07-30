
# Non-Exported Functions

  . $PSScriptRoot\Local\Get-ArrayInfoXML.ps1
  . $PSScriptRoot\Local\Export-PSCredentials.ps1
  . $PSScriptRoot\Local\Import-PSCredentials.ps1

  function Get-PureIpAddress {
    Param( [string]$pureName)

    # Load XMLDB & Validate Org Param
      $Script:xmlDB = Get-ArrayInfoXML;

      if ([string]::IsNullOrEmpty($org)){
        $unique = $Script:xmlDB.SelectNodes("//Array") |
          Select-Object -Property Org, Name -Unique;
        $Script:org = $unique[0].Org
      } else {
        $unique = $Script:xmlDB.SelectNodes("//Array") |
          Where-Object {$_.Org -match $Org } |
          Select-Object -Property Org, Name -Unique;
        if ($unique -is [Object]) {
          $Script:org = $unique[0].Org  
        } else {
          Write-Host "$Org not not found in the XMLDB" -ForegroundColor Red
          return $null
        }
      }
      Write-Verbose "Org is $Script:org"
    #
          
    # Get Pure Storage array data
      $unique = $Script:xmlDB.SelectNodes("//Array") |
        Where-Object { $_.Class -match "Pure" -and $_.Org -match $Script:org -and $_.Name -eq $pureName} |
        Select-Object -Property Name, username, remote;

      if ($unique -is [Object]) {
        $ip = $unique[0].remote;
        $Script:username = $unique[0].username;
        Write-Verbose "Username: $Script:username"
        return $ip
      } else {
        Write-Host "$pureName " -ForegroundColor Red -NoNewline
        Write-Host "is not a valid " -ForegroundColor Blue -NoNewline
        Write-Host "Pure Storage " -ForegroundColor Red -NoNewline
        Write-Host "array in the XMLDB" -ForegroundColor Blue
        return $null
      }
    #

  }

  function Set-Credentials {
    Param ([string]$borg, [string]$username)

    $credBase = "-" + $borg + "-" + $env:COMPUTERNAME + $credExt;
    $Script:credfilename = $Global:CRPath + "\" + $username + $credBase;

    if (!(Test-Path $Script:credfilename)) { # create cache credential
      Write-Host "Pure Credentials require for $borg Storage" -ForegroundColor Green
      Export-PSCredential $username $credBase
      Start-Sleep 3;
    }

    $Script:cred = Import-PSCredential $Script:credfilename
    Write-Verbose "Loaded $Script:credfilename"

  }
    
  function Set-PureArray {
    param ([string]$ip,[object]$cr)
    
    try {
      $pure = New-PfaArray -EndPoint $ip -Credentials $cr -IgnoreCertificateError
    }
    catch {
      $pure = "New-PfaArray -EndPoint $ip failed";
    }
    
    return $pure;
  }

  function Test-VolumeMasking {
    param ([object]$pureObj, [string]$server, [string]$volName)

    $hostvols = Get-PfaHostVolumeConnections -array $pureObj -Name $server;
    [bool]$volMasked = $false;
    ForEach-Object -InputObject $hostvols {
      if ($_.vol -eq $volName) {$volMasked = $true}
    }
    return $volMasked
  }

#

# Exported Functions

  <#
    .SYNOPSIS
      Show volumes masked to named host on a given PureSystem storage array.
      
    .DESCRIPTION
      Executes cmdlets in the Pure Storage PowerShell SDK 1.7.4 module to display
      volumes masked to a host on a specific PureSystem storage array.

    .PARAMETER pureNAME
      PureSystem array name.
      
    .PARAMETER hostName
      Name of the desired host.
      
    .PARAMETER org
      Name of the organiztion responsible for the PureStorage array.

      Uses the default org value in the XMLDB

    .INPUTS
      <username>-<org>-<hostname>.emc.xml
      
      Contains encrypted credentials for the 'username' account.
      If the file is not present, there will be prompt for the
      credentials and the file will be regenerated.
      
      The file can only be decrypted on system it was created on.
      
    .OUTPUTS
      List of volumes masked to a host.
      
    .OUTPUTS
      <username>-<org>-<hostname>.emc.xml
      
      Pureuser account encrypted credentials.
      
    .EXAMPLE
      Show-VePureHostVols -pureName bowpure002 -hostname testdummy02

      vol             name        lun hgroup
      ---             ----        --- ------
      testdummy02_T   testdummy02   1
      testdummy01_S_X testdummy02   2

      name            created              source        Size(GB)
      ----            -------              ------        --------
      testdummy02_T   2017-06-05T21:19:59Z                     10
      testdummy01_S_X 2017-06-09T19:20:33Z testdummy01_S       10

    .EXAMPLE
      Show-VePureHostVols bowpure002 testdummy02
      Show-VePureHostVols -pureName bowpure002 -hostname testdummy02

      Same as the prior example but the options are explicitedly provided.

    .NOTES

      Requires Installation of PureSystem PowerShell module.	
      Execute the following to install PureStorage PowerShell module.
      
      Install-Module -Name PureStoragePowerShellSDK -scope currentuser
      
      Author: Craig Dayton
      0.0.2.4  07/29/2017 : cadayton : Initial Release

    .LINK
      https://github.com/cadayton/Venom

    .LINK
      http://venom.readthedocs.io

  #>

  function Show-VePureHostVols {
    # Show-VePureHostVols Params
      [cmdletbinding()]
        Param (        
          [Parameter(Position=0,
            Mandatory=$False,
            ValueFromPipeline=$True)]
          [string]$pureName,
          [Parameter(Position=1,
            Mandatory=$False,
            ValueFromPipeline=$True)]
          [string]$hostName,
          [Parameter(Position=2,
            Mandatory=$False,
            ValueFromPipeline=$True)]
          [string]$org
        )
    #

    Write-Host "Show-PureHostVols version 0.0.2.4" -ForegroundColor Green

    $ip = Get-PureIpAddress $pureName;
    Write-Verbose "$pureName IpAddress is $ip"

    if ([string]::IsNullOrEmpty($ip)) {
      Write-Host "Check your spelling" -ForegroundColor Blue;
      return 1;
    }

    Set-Credentials $Script:org $Script:username
    $pure = Set-PureArray $ip $Script:cred;

    if ($pure -is [String])  { # Object expected
      Write-Host $pure -ForegroundColor Red;
      Write-Host "Try pinging $pureName using the IP address" -ForegroundColor Blue;
      return 2;
    }

    try {
      $hostvols = Get-PfaHostVolumeConnections -array $pure -Name $hostName;
    }
    Catch {
      $errRslt = "Error processing Get-PfaHostVolumeConnections"
      Write-Host $errRslt -ForegroundColor Red
      Write-Host "Likely the host name $hostName doesn't exist on $pureName" -ForegroundColor Blue
      return 3;
    }

    $hostvols | Format-Table -AutoSize;
    ForEach-Object -InputObject $hostvols {
      $vols = $_.vol;
      $volattrs = @();
      if ($_.vol.count -gt 1) {
        for($i=0; $i -lt $_.vol.count; $i++) {
          $volattr = Get-PfaVolume -Array $pure -Name $vols[$i];
          $volattrs += $volattr;
        }
        $volattrs |
          Select-Object name, created, source, serial, @{Name="Size(GB)"; Expression={$_.size / 1GB}} |
          Format-Table -AutoSize;
      } else {
        Get-PfaVolume -Array $pure -Name $_.vol |
          Select-Object name, created, source, serial, @{Name="Size(GB)"; Expression={$_.size / 1GB}} |
          Format-Table -AutoSize;
      }
    }

  }

  <#
    .SYNOPSIS
      Creates a PureStorage SNAP volume from an existing disk volume.
      
    .DESCRIPTION
      Creates a SNAP of a host's volume and optionally masks the SNAP to a different host.

      If the SNAP volume exists, it will be overwritten.
      
      If the SNAP volume does not exist, it will be created.
      
      If a target host is specified, the SNAP volume will be masked to the target host.

    .PARAMETER pureName
      Name of the PureStorage array were volume exists.

    .PARAMETER source
      Host name who owns the volume from which a SNAP volume will be created.
      
    .PARAMETER vol
      Name of disk volume to be copied.

    .PARAMETER target

      Specify a target host name to mask the SNAP volume. If a target is not
      specified, the SNAP volume will not be masked to any host.
     
    .PARAMETER suffix
      A suffix value to be appended to the SNAP volume name.

      Default is "X" and max size is 4 characters.
      
    .INPUTS
      <username>-<org>-<hostname>.emc.xml
      
      Contains encrypted credentials for the user account.
      If the file is not present, there will be prompt for the
      credentials and the file will be regenerated.
      
      The file can only be decrypted on system it was created on.
      
    .OUTPUTS
      <username>-<org>-<hostname>.emc.xml
      
    .EXAMPLE
      Copy-ArPureHostVol -pureName bowpure002 -source testdummy02 -vol testdummy02_G -target testdummy01

      Verifies that the disk volume, testdummy02_G is masked to the source server, testdummy02 and creates or
      overwrites the SNAP volume, testdummy02_G_X.

      The SNAP volume, testdummy02_G_X will be masked to the target server, testdummy01 if need be.
      
      A different suffix can be applied to the new disk volume by specifying the -suffix option.

    .EXAMPLE
      Copy-ArPureHostVol -pureName bowpure002 -source testdummy02 -vol testdummy02_G 
      
      Creates a SNAP volume, testdummy02_G_X which is not masked to any host.


    .NOTES

      Requires Installation of PureSystem PowerShell module.	
      Execute the following to install PureStorage PowerShell module.
      
      Install-Module -Name PureStoragePowerShellSDK -scope currentuser
      
      Author: Craig Dayton
      0.0.2.4  07/29/2017 : cadayton : Initial Release

    .LINK
      https://github.com/cadayton/Venom

    .LINK
      http://venom.readthedocs.io

  #>
  function Copy-VePureHostVol {
    # Copy-VePureHostVol Params
      [cmdletbinding()]
      Param (        
        [Parameter(Position=0,
          Mandatory=$False,
          ValueFromPipeline=$True)]
        [string]$pureName,
        [Parameter(Position=1,
          Mandatory=$False,
          ValueFromPipeline=$True)]
        [string]$org,
        [Parameter(Position=1,
          Mandatory=$true,
          ValueFromPipeline=$True)]
          # [ValidateScript({
          #   if ($_ -match "dsssar") { $true } else {
          #     Write-Host "$_ source server name must contain 'dsssar'" -ForegroundColor Blue;
          #     Throw;
          #   }
          # })]
        [string]$source,
        [Parameter(Position=2,
          Mandatory=$true,
          ValueFromPipeline=$True)]
          # [ValidateScript({
          #   if ($_ -match "dsssar") { $true } else {
          #     Write-Host "$_ volume name must contain 'dsssar'" -ForegroundColor Blue;
          #     Throw;
          #   }
          # })]
        [string]$vol,
        [Parameter(Position=3,
          Mandatory=$true,
          ValueFromPipeline=$True)]
          # [ValidateScript({
          #   if ($_ -match "dsssar") { $true } else {
          #     Write-Host "$_ target server name must contain 'dsssar'" -ForegroundColor Blue;
          #     Throw;
          #   }
          # })]
        [string]$target,
        [Parameter(Position=4,
          Mandatory=$False,
          ValueFromPipeline=$True)]
          [ValidateScript({
            if ($_.length -le 4) { $true } else {
              Write-Host "$_ Max size for suffix option is 4 characters" -ForegroundColor Blue;
              Throw;
            }
          })]
        [string]$suffix = "X"
      )
    #

    Write-Host "Copy-PureHostVol version 0.0.2.4" -ForegroundColor Green

    $ip = Get-PureIpAddress $pureName;
    Write-Verbose "$pureName IpAddress is $ip"
    
    if ($ip -eq $null) {
      Write-Host "Check your spelling" -ForegroundColor Blue;
      return 1;
    }
    
    Set-Credentials $Script:org $Script:username
    $pure = Set-PureArray $ip $Script:cred;

    if ($pure -is [String])  { # Object expected
      Write-Host $pure -ForegroundColor Red;
      Write-Host "Try pinging $pureName using the IP address" -ForegroundColor Blue;
      return 2;
    }
  
    # Validate source volume is masked to source server.
      if (!(Test-VolumeMasking $pure $source $vol)) {
        $err = "Copy-VePureHostVol: The volume $vol is not masked to the source server, $source - $env:USERNAME"
        Write-Host $err -ForegroundColor Red
        return 3;
      }
    #

    # Set target volume name and determine masking status
      $newvol = $vol + "_" + $suffix;
      [bool]$maskNewVol = $false;
      if (!(Test-VolumeMasking $pure $target $newvol)) {
        Write-Verbose "The volume $newvol is not masked to the target server, $target - $env:USERNAME";
        $maskNewVol = $true;
      }
    #

    # Create new SNAP or overwrite existing SNAP

      try {
        New-PfaVolume -Array $pure -VolumeName $newvol -Source $vol -Overwrite | Out-Null;
      }
      Catch {
        $err = "Copy-VePureHostVol: Error creating or updating volume $newvol for target server, $target"
        Write-Host $err -ForegroundColor Red
        return 4;
      }

      Write-Host "SNAP created: $newvol" -ForegroundColor Green
    #

    # Mask new volume to target server if necessary
    
      if (!([string]::IsNullOrEmpty($target))) {
        if ($maskNewVol) {
          try {
            New-PfaHostVolumeConnection -array $pure -VolumeName $newVol -HostName $target | Out-Null
          }
          catch {
            $err = "Copy-VePureHostVol: Error masking $newVol to target server, $target - $env:USERNAME"
            Write-Host $err -ForegroundColor Red
            return 5;
          }
          Write-Host "SNAP $newVol masked to $target" -ForegroundColor Green
        }
      }
    #
    
  }

#