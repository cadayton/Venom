# Module Declarations

  [String[]]$flogiHeader  = "Interface", "VSANID", "FCID", "PortWWN", "NodeWWN", "Flags", "DeviceAlias";
  [String[]]$LogInHeader  = "Array", "DirPort", "WWN", "NodeName", "PortName", "FCID", "LoggedIN", "OnFabric";

#

# Non-Exported Functions

  . $PSScriptRoot\Local\Get-ArrayInfoXML.ps1

  function Set-SYMCLI-Options {
	
    if ($env:SYMCLI_WAIT_ON_GK -eq $null) {
      New-Item -Path env:SYMCLI_WAIT_ON_GK -Value "1" | Out-Null
    } else { Set-Item -Path env:SYMCLI_WAIT_ON_GK -Value "1" | Out-Null; }

    if ($env:SYMCLI_WAIT_ON_DB -eq $null) {
      New-Item -Path env:SYMCLI_WAIT_ON_DB -Value "1" | Out-Null
    } else { Set-Item -Path env:SYMCLI_WAIT_ON_DB -Value "1" | Out-Null; }

    if ($env:SYMCLI_CTL_ACCESS -eq $null) {
      New-Item -Path env:SYMCLI_CTL_ACCESS -Value "PARALLEL" | Out-Null;
    } else { Set-Item -Path env:SYMCLI_CTL_ACCESS -Value "PARALLEL" | Out-Null; }

  }

  function Set-symapi_db {
    if ($env:SYMCLI_OFFLINE -eq $null) {
      New-Item -Path env:SYMCLI_OFFLINE -Value "0" | Out-Null
    } else { Set-Item -Path env:SYMCLI_OFFLINE -Value "0" | Out-Null; }

    Set-SYMCLI-Options
  }

  function Set-SymcliConnect {
    param ([string]$connectName)
    
      if ($env:SYMCLI_CONNECT -eq $null) {
        New-Item -Path env:SYMCLI_CONNECT -Value $connectName | Out-Null
        New-Item -Path env:SYMCLI_CONNECT_TYPE -Value "REMOTE" | Out-Null
        Write-Verbose "New-Item $env:SYMCLI_CONNECT & $env:SYMCLI_CONNECT_TYPE";
        #symcfg discover
      } elseif ($env:SYMCLI_CONNECT -match $connectName) {
      } else {
        Set-Item -Path env:SYMCLI_CONNECT -Value $connectName | Out-Null
        Write-Verbose "Set-Item $env:SYMCLI_CONNECT";
        #symcfg discover
      }
  }

  function Get-SymcliConnect {
    param ([string]$cliServer)
      
      if ($env:COMPUTERNAME -notmatch $hostnm) { # processing against remote symapi_db		
        Set-SymcliConnect $cliServer
      } elseif (($env:COMPUTERNAME -match $hostnm) -and ($remote -match $cliServer)) {
        # symcli processed locally on this host
        if ($env:SYMCLI_CONNECT -ne $null) {
          Remove-Item -Path env:SYMCLI_CONNECT | Out-Null
          Write-Verbose "Remove-Item SYMCLI_CONNECT"
        }
        if ($env:SYMCLI_CONNECT_TYPE -ne $null) {
          Remove-Item -Path env:SYMCLI_CONNECT_TYPE | Out-Null
          Write-Verbose "Remove-Item SYMCLI_CONNECT_TYPE"
        }	
      } else {
        Set-SymcliConnect $cliServer
      }
  }

  function Remove-FALogin {
    param ([string]$symmID, [string]$faPort, [string]$wwn)

    #$yn = Read-Host ("   symaccess -sid $symmID -wwn $wwn -dirport $faPort -login remove -nopr");
    #if ($yn -match "y") {

      $rslt = symaccess -sid $symmID -wwn $wwn -dirport $faPort -login remove -nopr;
      if ($LastExitCode -eq 0) { # last command executed without error
        Write-Verbose "   $wwn Login removed from $faPort on $symmID";
      } else {
        Write-Host "   Error: $wwn Login removed from $faPort on $symmID" -ForegroundColor Red;
      }

    #}

  }

  function Set-PortValue {
    param ([string]$pv)

    ($blade,$port) = $pv.Split("/");
    if ($blade.Length -eq 4) { $blade = $blade.Substring(2,2) } else { $blade = "0" + $blade.Substring(2,1) }
    if ($port.Length -eq 1) { $port = "0" + $port };
    $tmp = $blade + $port;
    return $tmp;
  }

  function Set-WwnAlias {
    param ([string]$symmID, [string]$wwn)

    $pwwn = $wwn -replace "([0-9A-Fa-f]{2})",'$1:' # Insert ':'
    $pwwn = $pwwn.TrimEnd(":",1);  # Remove trailing ':'

    # This code snippet searches all the fabric folders searching for a matching
    # flogi entry in the files named,  "*_flogi.csv".

    [bool]$flogiFound = $false;
    Get-ChildItem $Script:SwOrgPath |
      ForEach-Object { # Processing flogi for each folder in <execution path>\SWInfo-<org>
        $FBPath = $_.PSPath;
        if (!($flogiFound)) {
          Get-ChildItem $FBPath -Filter "*_flogi.csv" |
            Where-Object { $_.Attributes -ne "Directory"} |
            ForEach-Object {
              If (Get-Content $_.FullName | Select-String -List -SimpleMatch -Encoding ascii -Pattern $pwwn ) {
                # $_.FullName;  # <execution path>\SWInfo-<org>\<fabricname>\<switchname>_flogi.csv
                # $_.PSChildName; # <switchname>_flogi.csv
                $flogiFound = $True;
                ($switch,$s1) = $_.PSChildName.Split("_");  # GET SWITCH NAME
                $swChars = $switch.ToCharArray();
                # EXTRACT THE RECORD FROM THE FILE
                  $obj = Select-String -Path $_.FullName -List -SimpleMatch -Encoding ascii -Pattern $pwwn
                  # REMOVE SQUARE BRACKETS SURROUNDING THE DEVICE-ALIAS NAME
                  $found = $obj.Line
                  $found = $found -replace "\[", "";
                  $found = $found -replace "\]", "";
                  Write-Verbose "   found: $found"
                #
                # CONVERT RECORD INTO CSV OBJECT
                  $flogiObj = ConvertFrom-CSV -InputObject $found -Header $flogiHeader;
                #
                # EXTRACT HOSTNAME or StorageArray FROM DEVICE-ALIAS
                $DeviceAlias = $flogiObj.DeviceAlias;
                if ($DeviceAlias -eq $null) { # 
                  $dvAlias = $flogiObj.Flags;
                  if ($swChars -eq "s") { # it's a storage edge switch
                    $hostn = $dvAlias;
                  } else {
                    ($hostn,$hostHba ) = $dvAlias.Split("_");
                  }
                } else { 
                  if ($swChars -eq "s") { # it's a storage edge switch
                    $hostn = $DeviceAlias;
                  } else {
                    ($hostn,$hostHba) = $DeviceAlias.Split("_");
                  }
                };

                <#
                  # take first numeric to end of HBA string.
                  $sz = $hostHba.Length - 1;
                  $hary = $hostHba.ToCharArray();
                  for ($i=0;$i -le $sz;$i++) { if ($hary[$i] -match "[0-9]") {$offset = $i; continue;} }
                  $len = ($sz - $offset) + 1;
                  $intnum = $hostHba.Substring($offset,$len);
                #>
                
                if ( ($hostn -ne "VP") -and ($hostn -ne "V") -and ($hostn -ne "P") ) {
                  # ADD LEADING ZEROS TO Blade and port if needed
                  $portname = Set-PortValue $flogiObj.Interface;
                  $hostn = $hostn.ToLower();

                  $alias = "$hostn" + "/" + "$switch" + "_" + "$portname";

                  if ($alias.Length -gt 29) { # Max size of the alias field
                    $hostn = $hostn.Replace("0",""); # Remove ZEROS from hostname
                    $alias = "$hostn" + "/" + "$switch" + "_" + "$portname";
                  }

                  $symmAlias = '"' + $alias + '"';

                  symaccess -sid $symmid rename -wwn $wwn -alias $symmAlias 2> $errFile;

                  if ($LastExitCode -eq 0) { # last command executed without error
                    Write-Host "   $wwn set to $symmAlias on $symmID";
                  } else {
                    $errRslt = Get-Content -Path $errFile;
                    $errLine = $errRslt -match "already assigned";
                    if ($errLine) { # found line indicating duplicate name
                      $hbanum = $hostHba -replace '\D+(\d+)','$1'; # extract numeric value
                      if ($hbnum -eq $hostHba) { $hbanum = "9"}; # no numeric in string;
                      $alias = "$hostn" + "_" + "$hbanum" +  "/" + "$switch" + "_" + "$portname";
                      $symmAlias = '"' + $alias + '"';
                      symaccess -sid $symmid rename -wwn $wwn -alias $symmAlias 2> $errFile;
                      if (Test-Path $errFile) { Remove-Item -Path $errFile };
                      if ($LastExitCode -eq 0) { Write-Host "   $wwn set to $symmAlias on $symmID"; };
                    } else {
                      Write-Host "   Error: $wwn setting $symmAlias on $symmID" -ForegroundColor Red;
                      Write-Host "   Flogi Entry: $found" -ForegroundColor Magenta
                      #Read-Host " Waiting on Error Result @285"
                    }
                  }
                } else {
                  Write-Host "   $pwwn missing device-alias assignment" -ForegroundColor Red;
                }
              
              } else {
                # Flogi entry not found is this fabric
              } 
            }
            if (Test-Path $errFile) { Remove-Item -Path $errFile };
        }
      }
  }

  function Update-FALogin {
    param ([string]$symmID, [string]$faPort)
    
    begin { }
    
    process {
      $wwn    = $_.originator_port_wwn;
      $node   = $_.awwn_node_name;
      $pname  = $_.awwn_port_name;
      $onFab  = $_.on_fabric;
      $onFA   = $_.logged_in;

      if ($onFA -match "No") {
        Remove-FaLogin $symmID $faPort $wwn
        <# to delete selected NOT logged in initiators
          if ( ($node -eq "NULL") -or ($node -eq $wwn) -or ($node -match "vmx") ) {
            Remove-FaLogin $symmID $faPort $wwn
          }
        #>
      } elseif (($node -eq "NULL") -or ($node -eq $wwn) -or ($node -match "not") ) {
        $Script:initCnt++;
        Set-WwnAlias $symmID $wwn
      } else {
        $Script:initCnt++
      }

    }
    end { }

  }

  function Set-CSVFALogin {
    param ([string]$symmID, [string]$faPort)
    begin { }
    process {
      $wwn    = $_.originator_port_wwn;
      $node   = $_.awwn_node_name;
      $pname  = $_.awwn_port_name;
      $fcid   = $_.fcid;
      $onFab  = $_.on_fabric;
      $onFA   = $_.logged_in;

      if ($onFA -eq "Yes") { $Script:initCnt++; } else { $Script:notCnt++ };

      if ($SetLogin) {
        $csvRec = $symmID + "," + $faPort + "," + $wwn + "," + $node + "," + $pname + ",";
        $csvRec += $fcid + "," + $onFA + "," + $onFab;

        $csvRec | Out-File -Append -Encoding ascii -FilePath $csvFile
      }

    }
    end { }
  }

  function Get-FALogins {
    param ([string]$symmID, [string]$faPort)

    symaccess -sid $symmID list logins -dirport $faPort 2>$1 > $rstFile;  # suppressing error output
    if ($LastExitCode -eq 0) {
      [xml]$faLogin = symaccess -sid $symmID list logins -dirport $faPort -out xml_element;
      if ($LastExitCode -eq 0) { # last command executed without error
        if (($SetLogin) -or ($SumLogin)) {
          $faLogin.SelectNodes("//Login") | Set-CSVFALogin $symmID $faPort
        } else {
          $faLogin.SelectNodes("//Login") | Update-FALogin $symmID $faPort
        }
      } else {

      }
    } else {
      if (!($SetLogin) -and (!($SumLogin))) {
        Write-Host "  No device masking login entries for $faPort on $symmID" -ForegroundColor Magenta
      }
    }
  }

  function Get-DirectorInfo {
    param([string]$symmID)
    
    begin { };

    process {
      $faID = $_.Dir_Info.id;
      ($f1,$fa) = $faID.Split("-");
      [int]$portCnt = $_.Dir_Info.ports;
      Write-Verbose "  Processing FA $fa";

      ForEach-Object -InputObject $_.Port {
        for ($i=0; $i -lt $portCnt; $i++) {
          $port = $_.Port_Info.port[$i];
          $faPort = $fa + ":" + $port;
          if (($SetLogin) -or ($SumLogin)) {
            Write-Host "  Processing FA Port - $faPort" -ForegroundColor Green -NoNewline
          } else {
            Write-Host "  Processing FA Port - $faPort" -ForegroundColor Green
          }
          $Script:initCnt = 0; $Script:notCnt = 0;
          Get-FALogins $symmID $faPort;
          if (($SetLogin) -or ($SumLogin)) {
            Write-Host "  $Script:initCnt logged in $faPort  Not Logged In $Script:notCnt" -ForegroundColor Magenta
          } else {
            Write-Host "  $Script:initCnt initiators logged into $faPort" -ForegroundColor Magenta
            Write-Host " "
          }
       
        }
      }
    };

    end { };

  }

  function Get-Symm-ArrayInfo {
    begin { }

    process {
      $remote = $_.remote;
      $symm = $_.Model
      $symmSid = $_.sid;
      
      if ([string]::IsNullOrEmpty($remote)) {
        Write-Host "Skipping $symm : $symmSid no symcli server available" -ForegroundColor Red;
      } else {
        Get-SymcliConnect $remote
        Write-Host "Processing $symm : $symmSid on $remote" -ForegroundColor Green;

        [xml]$faXml = symcfg -sid $symmSid list -FA all -out xml_element
        if ($LastExitCode -eq 0) { # last command executed without error
          $faXml.SelectNodes("//Director") | Get-DirectorInfo $symmSid
        } else {
          Write-Host "Error Getting FA Info for $symmSid" -ForegroundColor Red
        }

      }
    }

    end { }
  }

  function Show-Logins {
    $matchMe = "*_ListLogins-" + $Script:org + ".csv"
    $loginFile = Get-ChildItem -Path $Global:FAPath |
	    Where-Object {$_.PSChildName -Like $matchME} |
	    Sort-object -property @{Expression={$_.LastWriteTime}; Ascending=$false}; 
    #$loginFile | get-member | Out-Host
    if ($loginFile.count -gt 1) {
      $FileIn = $loginFile.FullName[0]
    } else {
      $FileIn = $loginFile.FullName
    }
    #Read-Host "file: $FileIn - $faPath"
    Import-CSV -Path $FileIn -Header $LogInHeader | Out-GridView -Title $FileIn
  }

  function Set-SymmDefaults {
    
    if (!(Test-Path $Global:FAPath)) {
      New-Item $Global:FADir -ItemType Directory | Out-Null;
    }

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
          $unique = $Script:xmlDB.SelectNodes("//Array") |
            Select-Object -Property Org -Unique;
          Write-Host "Valid Org name values are:" -ForegroundColor Green
          $unique | Format-Table -AutoSize
          return $null
        }
      }
    #

    $Script:SwOrgPath = $Global:SWPath + "-" + $Script:org;
    $noErrors = "0"
    
    return $noErrors

  }
#

# Exported Functions

  # Set-VeSymmLogin

    <#
      .SYNOPSIS
        Creates Symmetrix alias for each initiator logged into a FA port.

        Or records the login entries to a csv file and reports on the csv file
        entries in a Out-GridView.

      .DESCRIPTION
        Each login entry for a FA port is examined for existance of an alias.
        
        If the initiator is logged into the FA port and the an alias name does not 
        exist, a new alias name is established.  The alias naming convention is:

        <initiator-name> / <switch name>_<xxyy>

        The <initiator-name> is determined by looking up the device-alias name found in flogi
        database. Only the first part of the device-alias name is used to construct the 
        <initiator-name>.  The <xxyy> value is the blade and port value of the switch that the
        initiator is connected to.
        
        If the initiator entry is not logged into the FA port, the initiator entry is removed from
        the FA port.
        
      .PARAMETER sid
        The four digit Symmetric ID value

      .PARAMETER SetLogin
        Adds the storage port login entries from the specified sid to a csv file found in the folder:

        <execution path>\FAInfo\Current_ListLogins-<Org>.csv

      .PARAMETER ListLogin
        Displays the contents of the most recent login csv file named:

        <execution path>\FAInfo\Current_ListLogins-<Org>.csv

      .PARAMETER SumLogin
        Displays a count of the initiators logged in and not logged in per storage port.

      .PARAMETER Org
        Each XMLDB record has an Org value. By default the first record in the XMLDB
        determines the default Org value to be used.

        To process logins for the non-default Org, the parameter must be specified a valid
        Org value.
      
      .PARAMETER Api
        Determines which communication access method used to access the array.

        symcli  - Solution Enabler (command line interface)
        restapi - RESTAPI protocol
        
        The restapi is not implemented at this time.

      .INPUTS
        The folders named, SWInfo/<fabric name> each contain an extracted copy of the flogi
        database from each switch in a CSV file format.  This folder structure is maintained
        by Set-DeviceAlias.ps1.

        The WWN value found in the FA login entry is used to search for the flogi entry located
        in the SWInfo/<fabric name> directory structure.

      .OUTPUTS
        Out-Gridview of login entries
        
      .EXAMPLE
        Set-VeSymmLogin -sid 0153

        Remove initiators not logged into the FA ports and for initiators missing
        a symm alias a value,  an alias value is added in the following form:

          <WWN name>\<switch_xxpp>

          Where <WWN name> is extracted from the device-alias.
          Where <switch> is the switch name where WWN is logged in.
          Where <xx> is the switch blade.
          Where <pp> is the switch port.

      .EXAMPLE
        Set-VeSymmLogin -sid 1136 -SetLogin

        Adds storage port login entries, to a csv file named,
        <execution path>\FAInfo\Current_ListLogins-<Org>.csv for VMAX array 1136.

        Set-SymmLogin -sid 0000 -SetLogin

        For each symmetric array in the XMLDB, the storage port login entries will
        be appended to the csv file named:

        <execution path>\FAInfo\Current_ListLogins-<Org>.csv

        If the csv file has a 'LastWriteTime' older than 24 hours, the current csv file
        will be rename to OLD and a new csv file will be created.

      .EXAMPLE
        Set-VeSymmLogin -sid 0134 -ListLogin

        Displays the storage port login entries in the most recent csv file.

      .EXAMPLE
        Set-VeSymmAlias -sid 0955 -SumLogin

        Displays a count of the initiators login status per storage port.

      .NOTES

        Author: Craig Dayton
        0.0.2.3  07/20/2017 : cadayton : Converted to cmdlet, Set-VeSymmLogin
        Updated: 02/11/2017 - initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
        http://venom.readthedocs.io

    #>

    function Set-VeSymmLogin {
      # Set-VeSymmLogin Params
        [cmdletbinding()]
          Param(
            [Parameter(Position=0,
              Mandatory=$false,
              HelpMessage = "Enter four digit Symm ID",
              ValueFromPipeline=$True)]
              [ValidatePattern("^[0-9]{4}$")]
            [string]$sid,
            [Parameter(Position=1,
              Mandatory=$false,
              HelpMessage = "Either symcli or restapi",
              ValueFromPipeline=$True)]
              [ValidateSet("symcli","restapi")]
            [string]$api = "symcli",
            [Parameter(Position=2,
              Mandatory=$false,
              HelpMessage = "Create FA Login CSV file",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [switch]$SetLogin,
            [Parameter(Position=3,
              Mandatory=$false,
              HelpMessage = "View FA Login CSV file",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [switch]$ListLogin,
            [Parameter(Position=4,
              Mandatory=$false,
              HelpMessage = "View FA Login CSV file",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [switch]$SumLogin,
            [Parameter(Position=5,
              Mandatory=$false,
              HelpMessage = "Organization Name",
              ValueFromPipeline=$True)]
            [string]$Org = $null
            
        )
      #

      Write-Host "Set-VeSymmLogin version 0.0.2.3" -ForegroundColor Green

      $rdom       = Get-Random -Maximum 999 -Minimum 101;

      $rstFile    = "$PWD\rslt-" + "$rdom" + ".txt";
      $errFile    = "$PWD\errRslt-" + "$rdom" + ".txt";
      $hostnm     = "Mojo69";

      $rslt = Set-SymmDefaults;

      if ([string]::IsNullOrEmpty($rslt)) {
        return 
      }

      $csvFile = $Global:FAPath + "\" + "Current_ListLogins-" + $Script:org + ".csv";
      $oldFile = $Global:FAPath + "\" + "Old_ListLogins-" + $Script:org + ".csv";

      # Age off $csvFile if older that 24 hours
        if ($SetLogin) {
          if (Test-Path $csvFile) {
            $ci = Get-ChildItem -Path $csvFile;
            $lastWrite = $ci.LastWriteTime;
            $lwAge = New-TimeSpan -Start $lastWrite;
            $lwDayInHours = $lwAge.Days * 24;
            $lwHours = $lwAge.Hours + $lwDayInHours;
            if ($lwHours -gt 24) { # rename to old
              if (Test-Path $oldFile) {
                Remove-Item $oldFile;
              }
              Rename-Item -Path $csvFile -NewName $oldFile;
            }
          }
        }
      #

      switch ($api) {
        "symcli" {
          Set-symapi_db;
          if ($sid) {
            if ($ListLogin) {
              Show-Logins;
            } elseif ($sid -ne "0000") {
              $Script:xmlDB.SelectNodes("//Array") | Where-Object {$_.sid -match $sid -and $_.Org -match $Script:org} | Get-Symm-ArrayInfo
            } else {
              $Script:xmlDB.SelectNodes("//Array") | Where-Object {$_.Model -match "VMAX" -and $_.Org -match $Script:org} | Get-Symm-ArrayInfo
            }
          }
          if ($SetLogin) { Write-Host "Created $csvFile" -ForegroundColor Magenta };
          if (Test-Path $rstFile) { Remove-Item -Path $rstFile; }
        }
        "restapi" {
          Write-Host "Sorry RESTAPI not implemented yet!" -ForegroundColor Green
        }
        default {
          Write-Host "$api is not a valid choice" -ForegroundColor Red
        }
      }
    }

  #

  # Find-VeSymmLogin

    <#
      .SYNOPSIS
        List initiators logged into storage arrays based on specified search criteria.

      .DESCRIPTION
        Find Initiator login on storage ports.

        The csv file named, Current_ListLogins-<org>.csv is searched based on the specified search criteria.
        If no search criteria is specified, then all login entries are displayed in an Out-GridView.

        The search criteria is anyone or combination of sid, WWN, Name, switch, FCID, or Login value.

        Reports on the differences between the current login entries and prior login entries.

      .PARAMETER sid
        Limits the search to a specific symmetrix array four digit serial number or a
        specific array name.

      .PARAMETER dirport
        Limits the search to a specific director port.

      .PARAMETER WWN
        Limits the search to a specific WWN value.

      .PARAMETER Name
        Limits the search to a specific initiator name.  A initiator name can be either
        a host name or an array name.

      .PARAMETER switch
        Limits the search to a specific switch name.

      .PARAMETER fcid
        Limits the search to a FCID value.

      .PARAMETER Login
        Limits the search to a Login value of Yes or No.

      .PARAMETER compare
        Compare the current login entries to the prior login entries
        and list the differences.

      .PARAMETER Obj
        The selected entries are returned as an object rather than console output.

      .INPUTS
        The csv file, FAInfo/Current_ListLogins-<org>.csv.

      .OUTPUTS
        Console Output, Out-Gridview or object returned
        
      .EXAMPLE
        Find-VeSymmLogin -sid 0153 -dirport 2e:0

        Lists all the login entries for VMAX array 0153 on director 2e port 0.

      .EXAMPLE
        Find-VeSymmLogin -name mojo69

        Lists all login entries for host, 'mojo69' on all storage arrays. 

      .EXAMPLE
        Find-VeSymmLogin -wwn 1000c4346b200498

        or

        Find-VeSymmLogin -wwn 10:00:c4:34:6b:20:04:98

        Lists all login entries associated with the WWN value.

      .EXAMPLE
        Find-VeSymmLogin -login No

        List all login entries NOT logged into a storage array port.

      .EXAMPLE
        Find-VeSymmLogin -switch mdsmojo01_04

        List all login entries from switch pxbh102 on blade 04.

      .EXAMPLE
        Find-VeSymmLogin -compare

        List the differences between the current Login DB and the prior Login DB.

      .NOTES

        Author: Craig Dayton
        0.0.2.3  07/20/2017 : cadayton : Converted to cmdlet, Find-VeSymmLogin
        Updated: 02/11/2017 - initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
        http://venom.readthedocs.io

    #>

    function Find-VeSymmLogin {
      
      # Find-VeSymmAlias Params
        [cmdletbinding()]
          Param(
            [Parameter(Position=0,
              Mandatory=$false,
              HelpMessage = "Enter four digit Symm ID",
              ValueFromPipeline=$True)]
              [ValidatePattern("^[0-9]{4}$")]
            [string]$sid,
            [Parameter(Position=1,
              Mandatory=$false,
              HelpMessage = "Enter a director and port number (i.e. 2e:0)",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [string]$dirport,
            [Parameter(Position=2,
              Mandatory=$false,
              HelpMessage = "Enter a WWN",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [string]$wwn,
            [Parameter(Position=3,
              Mandatory=$false,
              HelpMessage = "Enter a host or array name",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [string]$name,
            [Parameter(Position=4,
              Mandatory=$false,
              HelpMessage = "Enter a switch name value",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [string]$switch,
            [Parameter(Position=5,
              Mandatory=$false,
              HelpMessage = "Enter a FCID value",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [string]$fcid,
            [Parameter(Position=6,
              Mandatory=$false,
              HelpMessage = "Enter a FCID value",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [string]$loginHost,
            [Parameter(Position=7,
              Mandatory=$false,
              HelpMessage = "Enter a FCID value",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [string]$loginAll,
            [Parameter(Position=8,
              Mandatory=$false,
              HelpMessage = "Enter a FCID value",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [switch]$compare,
            [Parameter(Position=9,
              Mandatory=$false,
              HelpMessage = "Output returned as object",
              ValueFromPipeline=$True)]
              [ValidateNotNullorEmpty()]
            [switch]$obj,
            [Parameter(Position=10,
              Mandatory=$false,
              HelpMessage = "Organization Name",
              ValueFromPipeline=$True)]
            [string]$Org = $null
        )
      #

      # Main Routine

        Write-Host "Find-VeSymmLogin version 0.0.2.3" -ForegroundColor Green

        $rslt = Set-SymmDefaults;

        if ([string]::IsNullOrEmpty($rslt)) {
          return 
        }

        $matchMe = "*_ListLogins-" + $Script:org  + ".csv";
        $loginFile = Get-ChildItem -Path $Global:FAPath |
          Where-Object {$_.PSChildName -Like $matchME} |
          Sort-object -property @{Expression={$_.LastWriteTime}; Ascending=$false};
        if ($loginFile.count -gt 1) {
          $FileIn = $loginFile.FullName[0];
          $FileIn1 = $loginFile.FullName[1];
        } else {
          $FileIn = $loginFile.FullName;
        }

        $logins = Import-CSV -Path $FileIn -Header $LogInHeader; # All logins

        if ($compare) { # Difference between Login entries DBs

          if ($loginFile.count -gt 1) {
            Write-Host "";
            Write-Host "Listing the difference between:" -ForegroundColor Green;
            Write-Host " $FileIn and " -ForegroundColor Green
            Write-Host " $FileIn1" -ForegroundColor Green;
            Write-Host "";

            $logins1 = Import-CSV -Path $FileIn1 -Header $LogInHeader; # All Prior logins
            $diff = Compare-Object $logins $logins1;

            if ($diff -ne $null) {
              if ($diff.InputObject.gettype().name -eq "String") { # single record difference
                  if ($diff.SideIndicator -eq "=>") { # missing login entry
                    $dateTS = Get-Date -Format "yyMMdd-HHmm"
                    $loginentry = $diff.InputObject;
                    Write-Host "  Missing: $logientry" -ForegroundColor Red
                  } else {
                    $logientry = $diff.InputObject;
                    Write-Host "  New: $flogientry" -ForegroundColor Blue
                  }
              } else {
                  [int]$sz = $diff.InputObject.Length;
                  for ($i=0; $i -lt $sz; $i++) {
                    if ($diff.SideIndicator[$i] -eq "=>") { # missing flogi entry
                      $logientry = $diff.InputObject[$i];
                      Write-Host "  Missing: $logientry" -ForegroundColor Red;
                    } else {
                      $logientry = $diff.InputObject[$i];
                      Write-Host "  New: $logientry" -ForegroundColor Blue
                    }
                  }
              }
            } else {
              Write-Host "No differences Found" -ForegroundColor Green;
            }
          } else {
            Write-Host "There is only one file in $Script:FAPath so nothing to compare" -ForegroundColor Red
            return $null
          }

        } else { # Process filter criteria

          [bool]$filtered = $false;

          # search filters
            if ($sid) { 
              $logins = $logins | Where-Object { $_.Array -eq $sid }
              $filtered = $true;
            }

            if ($dirport) { 
              $logins = $logins | Where-Object { $_.DirPort -eq $dirport }
              $filtered = $true;
            }

            if ($wwn) {
              if ($wwn -match ":") {
                $wwn = $wwn -replace ":", "";
              }
              $logins = $logins | Where-Object { $_.WWN -eq $wwn }
              $filtered = $true;
            }

            if ($name) {
              $logins = $logins | Where-Object { $_.NodeName -match $name }
              $filtered = $true;
            }

            if ($switch) {
              $logins = $logins | Where-Object { $_.PortName -match $switch }
              $filtered = $true;
            }

            if ($fcid) {
              $logins = $logins | Where-Object { $_.FCID -eq $fcid }
              $filtered = $true;
            }

            if ($loginHost) {
              $logins = $logins | Where-Object { $_.LoggedIN -match $loginHost } |
                Where-Object { $_.NodeName -notmatch "vmx"};
                # Where-Object { $_.NodeName -notmatch "NULL"}
              $filtered = $true;
            } elseif ($loginAll) {
              $logins = $logins | Where-Object { $_.LoggedIN -match $loginAll }
              $filtered = $true;
            }
          
          #

          if ($obj) {
            return $login
          } elseif ($logins -ne $null) {
            Write-Host "";
            $finfo = Get-ChildItem -Path $FileIn;
            $lwrite = $finfo.LastWriteTime;
            $lup = Get-Date -Date $lwrite -Format g;
            Write-Host "Search Results from $FileIn" -ForegroundColor Green;
            write-Host "  Last Updated: $lup" -ForegroundColor Magenta;
            if ($filtered) {
              $logins | Format-Table -AutoSize
              Write-Host "Output search results to GridView GUI? (Y or N)" -ForegroundColor Green -NoNewline
              $rslt = Read-Host " ";
              if ($rslt -match "Y") {
                Write-Host "  Building Out-GridView Table" -ForegroundColor Green
                $logins | Out-GridView -Title $FileIn
              }
            } else {
              Write-Host "  Building Out-GridView Table" -ForegroundColor Green
              $logins | Out-GridView -Title $FileIn
            }
          } else {
            Write-Host "  Found no login entries matching the specified criteria" -ForegroundColor Red
          }
        }
      
      #
    }
  
  #

  # Start-VeUnisphere

    <#
      .SYNOPSIS
        Starts the Unisphere Manager interface for the specified <sid>

      .PARAMETER sid
        Four digit Symmetrix ID of the Unisphere Manager to launch.
        
      .EXAMPLE
        Start-VeUnisphere -sid 0153

        Starts the Unisphere Manager managing VMAX array 0153.

      .NOTES
        Author: Craig Dayton
        0.0.2.3  07/20/2017 : cadayton : initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
        http://venom.readthedocs.io

    #>

    function Start-VeUnisphere {
      param ([string][ValidatePattern("^[0-9]{4}$")]$sid )

      Write-Host "Start-VeUnisphere version 0.0.2.3" -ForegroundColor Green

      $xmlDB = Get-ArrayInfoXML;
          
      $unique = $xmlDB.SelectNodes("//Array") |
        Where-Object { $_.Model -match "VMAX" -and $_.sid -eq $sid} |
        Select-Object -Property restapi -Unique;
          
      if ($unique -is [Object]) {
        $userver = $unique[0].restapi;
        $URL = "https://" + $userver + ":8443/univmax/#"
        Write-Host "Starting Unisphere: $URL" -ForegroundColor Green
        Start-Process $URL
      } else {
        Write-Host "$sid " -ForegroundColor Red -NoNewline
        Write-Host "is not a valid " -ForegroundColor Blue -NoNewline
        Write-Host "VMAX " -ForegroundColor Red -NoNewline
        Write-Host "array in the XMLDB" -ForegroundColor Blue
        (new-object Media.SoundPlayer "$PSScriptRoot\Data\LOL.wav").play();
      }

    }

  #

  # Start-VeVappManager

    <#
      .SYNOPSIS
        Starts the VappManager interface for the specified <sid>

      .PARAMETER sid
        Four digit Symmetrix ID of the VappManager to launch.
        
      .EXAMPLE
        Start-VeVppManager -sid 0153

        Starts the VppManager for VMAX array 0153.

      .NOTES
        Author: Craig Dayton
        0.0.2.3  07/20/2017 : cadayton : initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
        http://venom.readthedocs.io

    #>

    function Start-VeVappManager {
      param ([string][ValidatePattern("^[0-9]{4}$")]$sid )

      Write-Host "Start-VeVappManager version 0.0.2.3" -ForegroundColor Green

      $xmlDB = Get-ArrayInfoXML;
          
      $unique = $xmlDB.SelectNodes("//Array") |
        Where-Object { $_.Model -match "VMAX3" -and $_.sid -eq $sid} |
        Select-Object -Property restapi -Unique;
          
      if ($unique -is [Object]) {
        $userver = $unique[0].restapi;
        $URL = "https://" + $userver + ":5480/"
        Write-Host "Starting VappManager: $URL" -ForegroundColor Green
        Start-Process $URL
      } else {
        Write-Host "$sid " -ForegroundColor Red -NoNewline
        Write-Host "is not a valid " -ForegroundColor Blue -NoNewline
        Write-Host "VMAX3 " -ForegroundColor Red -NoNewline
        Write-Host "array in the XMLDB" -ForegroundColor Blue
        (new-object Media.SoundPlayer "$PSScriptRoot\Data\LOL.wav").play();
      }

    }

  #

  # Start-VeEcomConfig

    <#
      .SYNOPSIS
        Starts the EcomConfig interface for the specified <sid>

      .PARAMETER sid
        Four digit Symmetrix ID of the EcomConfig to launch.
        
      .EXAMPLE
        Start-VeEcomConfig -sid 0153

        Starts the VeEcomConfig for VMAX array 0153.

      .NOTES
        Author: Craig Dayton
        0.0.2.3  07/20/2017 : cadayton : initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
        http://venom.readthedocs.io

    #>

    function Start-VeEcomConfig {
      param ([string][ValidatePattern("^[0-9]{4}$")]$sid )

      Write-Host "Start-VeEcomConfig version 0.0.2.3" -ForegroundColor Green

      $xmlDB = Get-ArrayInfoXML;
          
      $unique = $xmlDB.SelectNodes("//Array") |
        Where-Object { $_.Model -match "VMAX3" -and $_.sid -eq $sid} |
        Select-Object -Property restapi -Unique;
          
      if ($unique -is [Object]) {
        $userver = $unique[0].restapi;
        $URL = "https://" + $userver + ":5889/ECOMConfig"
        Write-Host "Starting EcomConfig: $URL" -ForegroundColor Green
        Start-Process $URL
      } else {
        Write-Host "$sid " -ForegroundColor Red -NoNewline
        Write-Host "is not a valid " -ForegroundColor Blue -NoNewline
        Write-Host "VMAX3 " -ForegroundColor Red -NoNewline
        Write-Host "array in the XMLDB" -ForegroundColor Blue
        (new-object Media.SoundPlayer "$PSScriptRoot\Data\LOL.wav").play();
      }

    }
  
  #

#