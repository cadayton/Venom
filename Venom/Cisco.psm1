
# Module Declarations

  # Constants

    Set-Variable -Name SWDir -Value "SWInfo"              -Option Constant -Scope Global -Visibility Private -Description "SWInfo folder";
    Set-Variable -Name SWPath -Value "$PWD\$Global:SWDir" -Option Constant -Scope Global -Visibility Private -Description "SWInfo path";
   
  #

  [String[]]$dcnmHeader   = "Fabric", "VSANID", "EnclosureName", "DeviceAlias", "PortWWN", "FCID", "SwitchInterface",
                            "LinkStatus", "Vendor", "SerialNumber", "Model", "FirmwareVer", "DriverVer", "Information";
  [String[]]$flogiHeader  = "Interface", "VSANID", "FCID", "PortWWN", "NodeWWN", "Flags", "DeviceAlias";
  [String[]]$peerHeader   = "SwitchWWN", "SwitchIP", "Local", "SwitchID";
  [String[]]$portHeader   = "Interface", "VSANID", "Desc";
  [String[]]$LogInHeader  = "Array", "DirPort", "WWN", "NodeName", "PortName", "FCID", "LoggedIN", "OnFabric";

#

# Non-Exported Functions

  . $PSScriptRoot\Local\Export-PSCredentials.ps1
  . $PSScriptRoot\Local\Import-PSCredentials.ps1
  . $PSScriptRoot\Local\Get-ArrayInfoXML.ps1

  # Security Functions

    function Get-FabricCredentials {
      Param ([string]$borg)

      $xmlDB = Get-ArrayInfoXML;

      if ([string]::IsNullOrEmpty($borg)) { # org value from first record since none specified
        $unique = $xmlDB.SelectNodes("//Fabric") |
          Select-Object -Property Org, Fabric, switchID, username, -Unique;
          $borg = $unique[0].Org
        
      } else {
        $unique = $xmlDB.SelectNodes("//Fabric") |
          Where-Object { $_.Org -match $borg } |
          Select-Object -Property Org, Fabric, switchID, username -Unique;
      }

      $Script:usr =  $unique[0].username

      $credBase = "-" + $borg + "-Cisco-" + $env:COMPUTERNAME + $credExt;
      $Script:credfilename = $Global:CRPath + "\" + $Script:usr + $credBase;

      if ([string]::IsNullOrEmpty($borg) ) {
        $Script:FabricName = $unique[0].Fabric
      } else {
        $Script:FabricName = $FabricName
      }

      if (!(Test-Path $Script:credfilename)) { # create cache credential
        Write-Host "MDS requires credentials for $borg Storage" -ForegroundColor Green
        Export-PSCredential $Script:usr $credBase
        Start-Sleep 3;
      }

      $Script:cred = Import-PSCredential $Script:credfilename
      $Script:org = $borg;

      #TODO: return $cr;
    }

  #

  # SSH Functions

    function Get-NewSSHSession {
      param ([string]$mds, [bool]$swlogin = $false)

      $sess = New-SSHSession -ComputerName $mds -Credential $Script:cred -AcceptKey;
      $Script:sessID = $sess.SessionID
      
      if (($swlogin) -or ($EnablePort)) {
        Write-Host "SSHSession object $sess created SessionID: $Script:sessID to $mds" -ForegroundColor Green
      } else {
        Write-Verbose "SSHSession object $sess created SessionID: $Script:sessID to $mds"
      }
      Start-Sleep 2

      return $sess;
    }

    function Get-SSHStream {
      param ([string]$switch, [bool]$swlogin = $false)

      if ($swlogin) {
        Write-Host "      creating SSH stream to $switch" -ForegroundColor White
      } else {
        Write-Verbose "      creating SSH stream to $switch"
      }
      
      $Script:sshstr = New-SSHShellStream -Index $Script:sessID
      While (!($Script:sshstr.DataAvailable)) { Start-Sleep -Seconds 2; }
      $logInInfo = $Script:sshstr.read();  # login verbage

    }
    
    function Stop-SSHsession {
      param ( [string]$mds, [bool]$swlogin = $false )

      if ($Script:sessID -ne $null) {
        if (($swlogin) -or ($EnablePort)) {
          Write-Host "      SSH processing done, terminating $mds SSH session" -ForegroundColor White
        } else {
          Write-Verbose "      SSH processing done, terminating $mds SSH session"
        }
        
        $Script:sshstr.Dispose();
        Remove-SSHSession -index $Script:sessID | Out-Null
        $Script:sessID = $null;
      }

    }

    function Set-NXOS-CMD {
      param ( [string]$mdscmd, [int]$delay, [string]$switch)

      Write-Verbose "$switch executing: $mdscmd";
      [int]$timeout = 0;
      $Script:sshstr.WriteLine($mdscmd);  # Execute command on switch
      While ((!($Script:sshstr.DataAvailable)) -and ($timeout -lt 3)) { $timeout++; Start-Sleep -Seconds $delay; }
      if ($Script:sshstr.DataAvailable) {
        $response = $Script:sshstr.read();  # get cmd output
        Write-Verbose $response;

        # If command is successful only $delay lines will exist in the response;
        #  first line the command itself
        #  second line switch command prompt or info prompt line
        #  third line switch command prompt
        $lineCnt = $response | Measure-Object -Line;

        if ($lineCnt.Lines -le $delay) { # no errors
          return $true;
        } else {
          return $false;
        }
      } else {
        Write-Host "$switch timeout: $mdscmd" -ForegroundColor Magenta
        return $false;
      }

    }

    function Set-NXOS-CMDrslt {
      param ( [string]$mdscmd, [int]$delay, [string]$switch)

      [int]$timelmt = 30 / $delay; # 30 second timeout in $delay increments
      [int]$timeout = 0;
      Write-Verbose "        $switch executing: $mdscmd";
      #$Script:sshstr.Flush();
      $Script:sshstr.WriteLine($mdscmd);  # Execute command on switch

      While ((!($Script:sshstr.DataAvailable)) -and ($timeout -lt $timelmt)) { $timeout++; Start-Sleep -Seconds $delay; }
      if ($Script:sshstr.DataAvailable) {
        $response = $Script:sshstr.read();  # get cmd output
        return $response;
      } else {
        Write-Host "       $switch timeout: $mdscmd" -ForegroundColor Magenta;
        return "timeout";
      };


    }

    function Get-Zoned {
      param ([string]$vsan, [string]$wwn)

      #show zone active vsan XXXX | in "PortWWN"
      $cmd = "show zone active vsan $vsan " + " | in $wwn n 6" ;
      Write-Verbose "$switch executing: $cmd";

      $Script:sshstr.WriteLine($cmd);  # See if $wwn is zoned
      [int]$timeout = 0;

      While ((!($Script:sshstr.DataAvailable)) -and ($timeout -lt 3)) { $timeout++; Start-Sleep -Seconds 10; };

      if ($Script:sshstr.DataAvailable) {
        $timeout = 0;
        $zoneInfo = $Script:sshstr.read();  # get cmd output
        # If wwn not in a zone only 2 lines will exist in the cmd response;
        #  first line the command itself
        #  second line switch command prompt
        $lineCnt = $zoneInfo | Measure-Object -Line;
      }

      if ($timeout -ne 0) {
        Write-Host "timeout: $cmd" -ForegroundColor Magenta
        return $false;
      }

      if ($lineCnt.Lines -lt 3) { # not zoned
        return $true;
      } else {
        return $false;
      }

    }

    function Set-PortValue {
      param ([string]$pv)

      ($blade,$port) = $pv.Split("/");
      if ($blade.Length -eq 4) { $blade = $blade.Substring(2,2) } else { $blade = "0" + $blade.Substring(2,1) }
      if ($port.Length -eq 1) { $port = "0" + $port };
      $tmp = $blade + $port;
      return $tmp;
    }

    function Set-PortName {
      param ([string]$pname)

      ($x1, $x2, $x3) = $pname -split '[\n]';
      $pname = $x2;
      $pname = $pname.Trim();
      ($d1,$d2,$d3,$des) = $pname.Split(" ");
      if ([string]::IsNullOrEmpty($SwitchName)) {
        ($portname,$leftover) = $des -split '[" ",_\-]'; # split on space, comma, underscore, or dash
      } else {
        ($portname,$leftover) = $des -split '[" "]'; # split on space only
      }
      if ($portname.Length -le 0) { $portname = "unknown"}
      return $portname.ToLower();

    }

    function Get-ZoneName {
      param ( [string]$mdscmd, [int]$delay, [string]$mds, [string]$pwwn)

      $cmdRslt = Set-NXOS-CMDrslt $mdscmd $delay $mds;

      if ($cmdRslt -eq "timeout") { return $cmdRslt};

      $fileName = "$mds" + "-temp.txt";
      $filePath = $Script:FBPath + "\" + $fileName;
      if (Test-Path $filePath) { Remove-Item -Path $filePath };
      $cmdRslt -replace "`r`n","`n" | set-content -path $filePath

      $zoneName = $null;
      get-content -Path $filePath | ForEach-Object {  # process each input line
        if ($_ -match "^zone name") {
          $zline = $_;
          ($z1,$z2,$zonename,$z3,$z4) = $zline.Split();
        }
      }
      Remove-Item -Path $filePath
      $switchType = $mds.ToCharArray();
      if (($switchType[3] -match "h") -and ($zoneName -ne $null)) { # host edge switch & Zoned
        # device-alias = basename of zone plus last 4 digits of WWN;
        ($zname,$junk) = $zonename -split '[" ",_\-]';
        if ($zname -eq "vipr") {
          ($zname,$junk) = $junk -split '[" ",_\-]';
        }
        $wwn4 = $pwwn.Substring(18,5);
        $wwn4 = $wwn4 -replace ":", "";
        $zonename = $zname + "_" + $wwn4
        $zonename = $zonename.ToLower()
      }
      return $zonename;
    }

  #

  # Peer Switch Functions

      function Move-ToArchive {
        param ([string]$filePath, [string]$fileName )

        $dateTS = Get-Date -Format "yyMMdd-HHmmss"
        $newName = "$dateTS" + "-" + "$fileName";
        $newPath = $Script:FBPath + "\Archive\" + $newName;
        Move-Item -Path $filePath -Destination $newPath;
      }

      function Show-Flogi {
        begin { [int]$Script:dacnt = 0 }

        process {
          $Script:dacnt++
        }

        end {
          Write-Host "        $Script:dacnt Interfaces are missing a Device-Alias assignment"
        }
      }

      function Show-Peer {
        begin { [int]$reccnt = 0 }
        process {
          $reccnt++
          $swname = $_.SwitchID
          Write-Host "Switch: $swname"  -ForegroundColor -Green
        }
        end {
          Write-Host "        $reccnt switches in $FabricName Fabric" -ForegroundColor Green
        }
      }

      function Convert-FlogiToCSV {
        param ([string]$fname,[string]$switch)

        $oldflogi = $null;
        $csvFile = $FBPath + "\" + "$switch" + "_flogi.csv";
        $misFile = $Global:SWPath + "\" + "Flogi_missing.csv";

        if (Test-Path $csvFile) {
          if ($flogiCompare) {
            $oldflogi = Get-Content -Path $csvFile;  # save prior flogi content
          }
          Remove-Item -Path $csvFile
        };

        # process each input line
        get-content -Path $fname | ForEach-Object {
          # any lines not starting with 'fc', space, or 'po' are ignored
          if (($_ -match "^fc") -or ($_ -match "^ ") -or ($_ -match "^po")) {
            $curLine = $_;
            if ($curline -match "^ ") { # this line contains the device-alias name
              $bufLine += $_;
              # replace multiple spaces with a single comma aka CSV file format
              $buf = $bufLine -replace "\s+", ",";
              $buf | Out-File -Append -Encoding ascii -FilePath $csvFile
              $bufLine = $null;
            } else {
              if ($bufLine -ne $null) {
                $buf = $bufLine -replace "\s+", ",";
                if ($buf -match "$,") { $buf += ",,"} else { $buf += "," }
                $buf | Out-File -Append -Encoding ascii -FilePath $csvFile
                $bufLine = $null;
              }
              $bufLine = $_;
            }
          }
        }

        if (Test-Path $fname) { Remove-Item -Path $fname };
        $swary = $switch.ToCharArray();
        if (($flogiCompare) -and ($oldflogi -ne $null) -and ($swary[3] -eq "s")) {  # Compare & Report on flogi differences
          $newflogi = Get-Content -Path $csvFile;
          $diff = Compare-Object $newflogi $oldflogi;
          if ($diff -ne $null) {
            if ($diff.InputObject.gettype().name -eq "String") { # single record difference
              if ($diff.SideIndicator -eq "=>") { # missing flogi entry
                $dateTS = Get-Date -Format "yyMMdd-HHmm"
                $flogientry = $switch + "," + "$dateTS" + "," + $diff.InputObject;
                Write-Host "  Missing: $flogientry" -ForegroundColor Red
                $flogientry | Out-File -Append -Encoding ascii -FilePath $misFile
              } else {
                $flogientry = $diff.InputObject;
                Write-Host "  New: $flogientry" -ForegroundColor Blue
              }
            } else {
              [int]$sz = $diff.InputObject.Length;
              for ($i=0; $i -lt $sz; $i++) {
                if ($diff.SideIndicator[$i] -eq "=>") { # missing flogi entry
                  $dateTS = Get-Date -Format "yyMMdd-HHmm"
                  $flogientry = $switch + "," + "$dateTS" + "," + $diff.InputObject[$i];
                  Write-Host "  Missing: $flogientry" -ForegroundColor Red;
                  $flogientry | Out-File -Append -Encoding ascii -FilePath $misFile
                } else {
                  $flogientry = $diff.InputObject[$i];
                  Write-Host "  New: $flogientry" -ForegroundColor Blue
                }
              }
            }
          }
        }

        return $csvFile;
      }

      function Convert-PeerToCSV {
        param ([string]$fname)

        $csvFile  = "$FBPath" + "\" + "$FabricName" + ".csv";
        $bufLine  = $null;
        get-content -Path $fname | ForEach-Object {  # process each input line
          # any lines not starting with 2 spaces or a space and a digit are ignored
          if (($_ -match "^ \d") -or ($_ -match "^  ")) {
            $curLine = $_;
            if ($curline -match "^  ") { # this line contains the switch name
              if ($bufLine -notmatch "Local") { $bufLine += ","};
              $bufLine += $_;
              # replace multiple spaces with a single comma aka CSV file format
              $buf = $bufLine -replace "\s+", ",";
              $buf = $buf -replace "\[", "";
              $buf = $buf -replace "\]", "";
              $buf = $buf -replace ".gsm1900.org", "";
              $buf | Out-File -Append -Encoding ascii -FilePath $csvFile
              $bufLine = $null;
            } else {
              $bufLine = $_; $bufLine = $bufLine.Trim();
            }
          }
        }

        if (Test-Path $fname) { Remove-Item -Path $fname };
        return $csvFile;

      }

      function Set-DeviceAliasCmds {
        param ([string]$mds)
        
        begin {
          [int]$reccnt  = 0;
          $cmdFile      = $null;
        }

        process {

          $reccnt++;
          $swint            = $_.Interface;
          $PortWWN          = $_.PortWWN;
          $Flags            = $_.Flags;
          $VSANID           = $_.VSANID;

          if ($cmdFile -eq $null ) { # setup output file
            $cmdFile = $Script:FBPath + "\" + "$mds" + "_Alias.cmd"
            if ((Test-Path $cmdFile)) { # Remove old cmdFile
              Remove-Item $cmdFile | Out-Null
            }
          }
        
          if ($Script:sshstr.CanWrite) { # Ready to accept SSH commands

            if (Get-Zoned $VSANID $PortWWN) { # PortWWN is not zoned
              if (($Flags -eq "P" -or ($Flags -eq ""))) { # a physical port
                # show int fc1/10 | in "Port description is"
                $cmd = "show int " + $swint + " | in " + """Port description is""";
                $portDes = Set-NXOS-CMDrslt $cmd 5 $switch;

                if ($portDes -ne "timeout") {
                  $portname = Set-Portname $portDes;
                } else {
                  $portname = "timeout"
                }
                  
                # Create Port alias command to $cmdFile
                $swport = Set-PortValue $swint;
                $portAlias = "$portname" + "_" + "$mds" + "_" + "$swport";
                $Aliascmd = "device-alias name " + "$portAlias" + " pwwn " + "$PortWWN";
                $Aliascmd | Out-File -Append -Encoding ascii -FilePath $cmdFile;
                if ($portname -eq "timeout") {
                  Write-Host "    Review Alias command file for any alias names starting with 'timeout'" -ForegroundColor Blue
                }
          
              } else { # a virtual port NPIV
                Write-Host "        $swint $PortWWN with a port flag of $Flags must be zoned to set a device-alias " -ForegroundColor Red;
              }

            } else { # PortWWN is zoned
              $cmd = "show zone active VSAN $VSANID | in $PortWWN p 3";
              $zonename = Get-ZoneName $cmd 5 $mds $PortWWN;
              if (($zonename -ne $null) -and ($zonename -ne "timeout")) {
                $Aliascmd = "device-alias name " + "$zonename" + " pwwn " + "$PortWWN";
                $Aliascmd | Out-File -Append -Encoding ascii -FilePath $cmdFile;
              } elseif ($zonename -eq "timeout") {
                Write-Host "        Timeout: $swint $cmd" -ForegroundColor Magenta
              } else {
                Write-Host "        $swint $PortWWN zonename not found a device-alias will not be created" -ForegroundColor Red
              }
            }
          }
        }

        end { }

      }

      function New-DeviceAliasCmds {
        param ([string]$mds)
        
        begin {
          [int]$cmdcnt    = 0;
          [int]$commitcnt = 0;
          [int]$Script:cfgError = 0;
          [string]$Script:cfgErrMsg = $null;
        }

        process {

          if (!($Script:cfgError)) {
            if ($Script:sshstr.CanWrite) { # Ready to accept SSH commands
              if ($cmdcnt -eq 0) { 
                if (!(Set-NXOS-CMD "show cfs lock" 2 $mds )) { # Check for CFS lock
                  $Script:cfgErrMsg = "CFS is currently locked $mds";
                  $Script:cfgError = 1;
                  Write-Host $Script:cfgErrMsg -ForegroundColor Red
                  return $null;
                }
                if (!(Set-NXOS-CMD "config t" 3 $mds )) { # Enter config mode
                  $Script:cfgErrMsg = "Error entering config mode on $mds";
                  $Script:cfgError = 2;
                  Write-Host $Script:cfgErrMsg -ForegroundColor Red
                  return $null;
                }
                if (!(Set-NXOS-CMD "device-alias database" 2 $mds )) { # Enter Device-Alias DB
                  $Script:cfgErrMsg = "Error entering config mode on $mds";
                  $Script:cfgError = 3;
                  Write-Host $Script:cfgErrMsg -ForegroundColor Red
                  return $null;
                }
              }

              $cmdcnt++;
              $cmd = $_;
              ($cmdName,$cmdParm) = $cmd.Split();
              
              if ($cmdName -match "device-alias") {
                
                $commitcnt++;
                
                if (!(Set-NXOS-CMD $cmd 2 $mds )) { # 
                  Write-Host "$cmd FAILED" -ForegroundColor Red
                } else {
                  Write-Host "$cmd COMPLETED" -ForegroundColor Green
                }

                if ($commitcnt -ge 100) { 
                  $commitcnt = 0;       
                  if (!(Set-NXOS-CMD "device-alias commit" 2 $mds )) { # Commit Changes
                    Write-Host "device-alias commit ERROR on $mds" -ForegroundColor Red
                    return $null; # exit;
                  } else {
                    Write-Host "device-alias commit COMPLETED" -ForegroundColor Magenta
                  }

                  Start-Sleep -Seconds 10;

                  if (!(Set-NXOS-CMD "device-alias database" 2 $mds )) { # Enter Device-Alias DB
                    Write-Host "Error entering device-alias database on $mds" -ForegroundColor Red
                  return $null; # exit;
                  } 
                }
              } else {
                Write-Host "Invalid command: $cmd NOT EXECUTED" -ForegroundColor Red
              }
              Start-Sleep -Seconds 1;
            }

          }

        }

        end {

          if ($commitcnt -ne 0) { 
            if (!(Set-NXOS-CMD "device-alias commit" 2 $mds )) { # Commit Changes
              Write-Host "device-alias commit ERROR on $mds" -ForegroundColor Red
            } else {
              Write-Host "Remaining device-alias changes committed" -ForegroundColor Magenta
            }
          }

          if (!($Script:cfgError)) {
            Start-Sleep -Seconds 10;

            Write-Host "Backing up running configuration from $mds" -ForegroundColor Magenta
            Set-NXOS-CMD "copy run start fabric" 3 $mds | Out-Null
            Set-NXOS-CMD "y" 2 $mds | Out-Null

            Start-Sleep -Seconds 15;

            Write-Host "Processed $cmdcnt device-alias commands" -ForegroundColor Magenta
        
          } else {
            switch ($cfgError) {
              1 {
                  Write-Host " CFS is Locked, try changes after the lock is released " -ForegroundColor Red
                  Write-Host " 'show cfs lock' " -ForegroundColor Blue -NoNewline
                  Write-Host " This will show which switch and user has acquired the lock"
              }
              Default {
                Write-Host " Try logging into the switch and enter the commmand " -ForegroundColor Blue
              }
            }
          }

          Stop-SSHsession $mds;

        }

      }

      function Get-DeviceAliasCmds {
        param ([string]$mds)

        $fName   = "$mds" + "_Alias.cmd";
        $cmdFile = $Script:FBPath + "\" + "$fName";

        if (Test-Path $cmdFile) {
          Write-Host "Applying device-alias commands on switch, $mds" -ForegroundColor White
          get-content -Path $cmdFile | New-DeviceAliasCmds $mds
          if (!($Script:cfgError)) {
            Move-ToArchive $cmdFile $fname;
          }
        } else {
          Write-Host "$cmdfile no updates required" -ForegroundColor White
        }

      }
      
      function Get-Flogi-Details {

        begin {}

        process {
          $switch = $_.SwitchID

          if (([string]::IsNullOrEmpty( $SwitchName)) -or ($SwitchName -eq $switch)) {
            
            $sess = Get-NewSSHSession $switch

            if ($sess.Connected) {
              $Script:sessID = $sess.SessionID;
              # Create a SSH stream session
              Get-SSHstream $switch;

              $csvFile = $Script:FBPath + "\" + "$switch" + "_flogi.csv";

              if ($Script:org -eq "EIT") {
                # True if host edge switch or switch name explicitly specified via -SwitchName param
                $swarray = $switch.ToCharArray();
                [bool]$switchCtrl = (($swarray[3] -eq "h") -or ($switch -eq $SwitchName));
              } else {
                # True if switch name explicitly specified via -SwitchName param
                [bool]$switchCtrl = ($switch -eq $SwitchName)
              }

              if ((($applyAll) -or (($switchCtrl) -and ($apply)))) {
                Get-DeviceAliasCmds $switch;
                # Remove-Item -Path $csvFile | Out-Null;
              } elseif (($Script:sshstr.CanWrite) -and (!($apply)) ) { # Ready to accept SSH commands
                # show flogi database details
                $cmd = "show flogi database details | no-more"
                Write-Host "$switch executing: $cmd";
                $flogiInfo = Set-NXOS-CMDrslt $cmd 2 $switch; # Get flogi details on switch  

                if ($flogiInfo -ne "timeout") {
                  $fileName = $Script:FBPath + "\" + "$switch" + "_flogi-temp.txt";
                  $flogiInfo | Out-File -Append -Encoding ascii -FilePath $fileName

                  $csvFile = Convert-FlogiToCSV $fileName $switch;
                
                  if (!($Script:flogiOnly)) {
                    Import-CSV -Path $csvFile -Header $flogiHeader |
                      Where-Object { $_.DeviceAlias -eq ""} |
                      Show-Flogi; # Count the number of flogi records missing a device-alias
                    
                    if ($Script:dacnt -gt 0) {
                      Import-CSV -Path $csvFile -Header $flogiHeader |
                        Where-Object { $_.DeviceAlias -eq "" } |
                        Set-DeviceAliasCmds $switch; # Create device-alias cmd file.
                    }
              
                    if (Test-Path $fileName) {
                      Remove-Item -Path $fileName;
                    }
                  }
                } else {
                    Write-Host "Timeout: $switch excuting $cmd" -ForegroundColor Yellow
                }

              }
              Stop-SSHsession $switch;
            } else { Write-Host "SSH session to $switch failed" -ForegroundColor Red }
          }
        }

        end {}
      }

      function Get-CFSPeers {
        param ([string]$switch, [bool]$swlogin = $false)

        $sess = Get-NewSSHSession $switch

        if ($sess.Connected) {
          $Script:sessID = $sess.SessionID;
          # Create a SSH stream session
          Get-SSHstream $switch;

          if ($Script:sshstr.CanWrite) { # Ready to accept SSH commands
            # show cfs peers | no-more
            $cmd = "show cfs peers | no-more"
            Write-Host "$switch executing: $cmd";
            $peerInfo = Set-NXOS-CMDrslt $cmd 2 $switch; # Get flogi details on switch  

            if ($peerInfo -ne "timeout") {
              $fileName = "$switch" + "_peer-temp.txt";
              $filePath = $Script:FBPath + "\" + $fileName;
              $peerinfo -replace "`r`n","`n" | set-content -path $filePath

              $csvFile = Convert-PeerToCSV $filePath
              #Import-CSV -Path $csvFile -Header $peerHeader | Show-Peer
              Stop-SSHsession $switch;
              if (!($swLogin)) {                 
                Import-CSV -Path $csvFile -Header $peerHeader | Get-Flogi-Details
              }
            }
          }

          if ($Script:sessID -ne $null) { Stop-SSHsession $switch };

        }

      }

      function Set-SwitchPorts {
        param ([string]$mds)

        begin {
          if (!(Set-NXOS-CMD "config t" 3 $mds )) { # Enter config mode
            Write-Host "Error entering config mode on $mds" -ForegroundColor Red
            Stop-SSHsession $mds
            return $null; # exit
          }
          [int]$portCnt = 0;

        }

        process {
          $portCnt++;
          $swint = $_.Interface;
          $portVSAN = $_.VSANID;
          $portDesc = $_.Desc;

          $cmd = "VSAN database";
          if (!(Set-NXOS-CMD $cmd 3 $mds )) { # Enter interface mode
            Write-Host "Error entering VSAN database mode for $swint on $mds" -ForegroundColor Red
            Stop-SSHsession $mds
            return $null; # exit
          }

          $cmd = "VSAN $portVSAN interface $swint";
          if (!(Set-NXOS-CMD $cmd 3 $mds )) { # Enter interface mode
            Write-Host "Error entering VSAN $portVSAN for $swint on $mds" -ForegroundColor Red
            Stop-SSHsession $mds
            return $null; # exit
          }

          $cmd = "interface $swint";
          if (!(Set-NXOS-CMD $cmd 3 $mds )) { # Enter interface mode
            Write-Host "Error entering interface mode on $mds" -ForegroundColor Red
            Stop-SSHsession $mds
            return $null; # exit
          }

          $cmd = "switchport description  $portDesc";
          if (!(Set-NXOS-CMD $cmd 3 $mds )) { # Enter interface mode
            Write-Host "Error entering switchport on $mds" -ForegroundColor Red
            Stop-SSHsession $mds
            return $null; # exit
          }

          $cmd = "no shut";
          if (!(Set-NXOS-CMD $cmd 3 $mds )) { # Enter interface mode
            Write-Host "Error entering no shut for $swint on $mds" -ForegroundColor Red
            Stop-SSHsession $mds
            return $null; # exit
          }

          Write-Host "      $swint set to VSAN $portVSAN and enabled" -ForegroundColor White

        }

        end {

          Write-Host "      Backing up running configuration from $mds" -ForegroundColor Magenta
          Set-NXOS-CMD "copy run start fabric" 3 $mds | Out-Null
          Set-NXOS-CMD "y" 2 $mds | Out-Null

          Start-Sleep -Seconds 15;

          Write-Host "      Enabled $portCnt ports on $mds" -ForegroundColor Magenta

          Stop-SSHsession $mds;
        }

      }

      function Get-SwitchPorts {
        param ([string]$switch, [string]$fileName)

        $sess = Get-NewSSHSession $switch

        if ($sess.Connected) {
          $Script:sessID = $sess.SessionID;
          # Create a SSH stream session
          Get-SSHstream $switch;

          if ($Script:sshstr.CanWrite) { # Ready to accept SSH commands
            $filePath = $Script:FBPath + "\" + $fileName;
            Write-Host "      Processing $filePath" -ForegroundColor White
            Import-CSV -Path $filePath -Header $portHeader | Set-SwitchPorts $switch
            Stop-SSHsession $switch;
            Move-ToArchive $filePath $fileName;   
          }
        }
      }

      function Get-Symm-Details {

        begin {

          function Get-DeviceAlias {
            param ([string]$wwn)

            $pwwn = $wwn -replace "([0-9A-Fa-f]{2})",'$1:' # Insert ':'
            $pwwn = $pwwn.TrimEnd(":",1);  # Remove trailing ':'

            # This code snippet searches all the fabric folders searching for a matching
            # flogi entry in the files named,  "*_flogi.csv".

            [bool]$flogiFound = $false;
            Get-ChildItem $Global:SWPath |
              ForEach-Object { # Processing flogi for each folder in C:\bin\ps\SWInfo
                $FBPath = $_.PSPath;
                if (!($flogiFound)) {
                  Get-ChildItem $FBPath -Filter "*_flogi.csv" |
                    Where-Object { $_.Attributes -ne "Directory"} |
                    ForEach-Object {
                      If (Get-Content $_.FullName | Select-String -List -SimpleMatch -Encoding ascii -Pattern $pwwn ) {
                        # $_.FullName;  # C:\bin\ps\SWInfo\PX_RN_Fabric_A\pxac103_flogi.csv
                        # $_.PSParentPath; # C:\bin\ps\SWInfo\PX_RN_Fabric_A
                        # $_.PSChildName; # pxac103_flogi.csv
                        $flogiFound = $True;
                        ($switch,$s1) = $_.PSChildName.Split("_");  # GET SWITCH NAME
                        $swChars = $switch.ToCharArray();
                        # EXTRACT THE RECORD FROM THE FILE
                        $obj = Select-String -Path $_.FullName -List -SimpleMatch -Encoding ascii -Pattern $pwwn
                        # REMOVE SQUARE BRACKETS SURROUNDING THE DEVICE-ALIAS NAME
                        $found = $obj.Line
                        $found = $found -replace "\[", "";
                        $found = $found -replace "\]", "";
                        # Write-Host "   Flogi Entry: $switch - $found";
                        # Read-Host "waiting"
                        # CONVERT RECORD INTO CSV OBJECT
                        $flogiObj = ConvertFrom-CSV -InputObject $found -Header $flogiHeader;
                        $DeviceAlias = $flogiObj.DeviceAlias;

                        if (($swChars -eq "h") -and ($DeviceAlias -eq $null)) { # host edge switch & missing a device-alias
                          $portWWN  = $pwwn;
                          $VSANID   = $flogiObj.VSANID;
                          $swint    = $flogiObj.Interface;
                          $cmdFile  = $_.PSParentPath + "\" + $switch + "_Alias.cmd";

                          # Open SSH session & etc...
                          $sess = Get-NewSSHSession $switch

                          if ($sess.Connected) {
                            $Script:sessID = $sess.SessionID;
                            # Create a SSH stream session
                            Get-SSHstream $switch;

                            $cmd = "show zone active VSAN $VSANID | in $PortWWN p 3";
                            # Write-Host "cmd: $cmd"
                            # Read-Host "waiting"
                            $zonename = Get-ZoneName $cmd 5 $switch $PortWWN;

                            if (($zonename -ne $null) -and ($zonename -ne "timeout")) {
                              $Aliascmd = "device-alias name " + "$zonename" + " pwwn " + "$PortWWN";
                              $Aliascmd | Out-File -Append -Encoding ascii -FilePath $cmdFile;
                            } elseif ($zonename -eq "timeout") {
                              Write-Host " Timeout: $switch $swint $cmd" -ForegroundColor Magenta
                            } else {
                              Write-Host "   $switch $swint $PortWWN zonename not found a device-alias will not be created" -ForegroundColor Red
                            }
                          }

                          Stop-SSHsession $switch;
                        } else {
                          Write-Host "   Non host edge switch or Device-Alias already established skipping"
                        }
                        
                      }
                    }
                }
              }
          }

        }

        process {
          $array          = $_.Array;
          $dirport        = $_.DirPort;
          $pwwn           = $_.WWN;

          Write-Host "  Evaluating WWN: $pwwn from VMAX $array on $dirport" -ForegroundColor Green
          Get-DeviceAlias $pwwn

        }

        end { }

      }

      function Get-SwitchName {
        param ([string]$fabName)

        $xmlDB = Get-ArrayInfoXML;

        $fabricInfo = $xmlDB.SelectNodes("//Fabric") |
          Where-Object { $_.Fabric -match $fabName } |
          Select-Object -Property Org, Fabric, switchID, username -Unique;

        if ($fabricInfo -is [Object]) {
          return $fabricInfo.switch
        } else {
          return $null
        }

      }

      function Add-FabricFolders {
        param([string]$OrgPath)

        $xmlDB = Get-ArrayInfoXML;

        $xmlDB.SelectNodes("//Fabric") |
          Where-Object { $_.Org -match $Script:org} |
          ForEach-Object {
            $folder = $OrgPath + "\" + $_.fabric;
            if (!(Test-Path $folder)) {
              New-Item $folder -ItemType Directory | Out-Null;
              $farchive = $folder + "\archive"
              New-Item $farchive -ItemType Directory | Out-Null;
            }
          }

      }

      function Set-Defaults {

        Get-FabricCredentials $org

        $Script:SwOrgPath = $Global:SWPath + "-" + $Script:org; # c:\bin\ps\SWInfo-EIT

        if (!(Test-Path $Script:SwOrgPath)) {
          New-Item $Script:SwOrgPath -ItemType Directory | Out-Null;
          # need to create folder for each FabricName in Org
          Add-FabricFolders $Script:SwOrgPath
        }

      }

      function Show-FabricNames {

          $xmlDB = Get-ArrayInfoXML;
          
          $fabNames = $xmlDB.SelectNodes("//Fabric") |
            Select-Object -Property Org, Fabric, switchID;

          $fabNames | Format-Table -AutoSize
      
      }

      function Connect-Switch {
        begin {}

        process{
          $switch = $_.SwitchID
          $sess = Get-NewSSHSession $switch $true

          if ($sess.Connected) {
            $Script:sessID = $sess.SessionID;
            # Create a SSH stream session
            Get-SSHstream $switch $true;
            Start-Sleep -Seconds 3;
            Stop-SSHsession $switch $true;
          } else {
            Write-Host "SSH session to $switch failed" -ForegroundColor Red
          }

        }

        end {}
      }

  #

#

# Exported Functions

  # Connect-VeFabric
    
    <#
      .SYNOPSIS
        Tests the SSH protocol connectivity to switch(s) for all or a specific SAN fabrics within an Organization scope and
        creates SAN Fabric domain csv file.

      .DESCRIPTION
        Establishes a SSH session with the specified Cisco MDS FC switch specific in the fabric record found
        in the XMLDB.
        
        Creates a SAN Fabric domain csv file when the '-createCSV' option is specified.
        '<execution folder>\SwInfo-<org>\<fabricname>\<fabricname>.csv'.  If this file already exists, it is moved
        to the archive folder and new csv file is created.

        The SAN Fabric domain csv file contain a record for each switch that is member of the SAN Fabric domain.
        
      .PARAMETER FabricName
        Tests SSH login for each switch that is a member of the FabricName with in the default Orgranization.

      .PARAMETER Org
        Is the Organization name responsible for the SAN Fabric(s). This parameter is require to process
        non-default Organization records.

      .PARAMETER createCSV
        Creates the SAN Fabric domain csv file for each SAN Fabric in the Organizaiton domain and then tests ability
        to log into each switch. Existing csv file is moved to the archive folder.

        This option is used when initially setting up a new fabric domain folder or when the membership of the fabric
        domain changes.

      .INPUTS
        The XMLDB is accessed to validate the FabricName parameter.

        The set of switches associated with a SAN Fabric domain is contained in a csv file named,
        '<execution folder>\SwInfo-<org>\<fabricname>\<fabricname>.csv'.

      .OUTPUTS
        Creates SAN Fabric domain csv file for each switch in the SAN Fabric domain. The file is named,
        '<execution folder>\SwInfo-<org>\<fabricname>\<fabricname>.csv'.

      .EXAMPLE
        Connect-VeFabric -FabricName Bow_Fabric_A -createCSV

        Creates the SAN Fabric domain csv file for the SAN Fabric named, 'Bow_Fabric_A' in
        the default Organization and then tests SSH login to each switch.

        If SAN Fabric domain csv file already exists, it is moved to the archive folder.

        This option must be executed when initially setting up a new SAN Fabric folder or
        when the membership of the SAN Fabric changes.

        The SAN fabric folder structure is automatically generated base on the fabric records
        specified in the XMLDB.

      .EXAMPLE
        Connect-VeFabric -createCSV

        Creates the SAN Fabric domain csv file for each SAN Fabric in the default Organization and tests
        SSH login to each switch.
        
      .EXAMPLE
        Connect-VeFabric

        Test SSH login login to each switch in the default SAN Fabric for the default Organization.

        The default SAN Fabric and Organization is determine by the settings in the first fabric record
        found in the XMLDB.
        
      .EXAMPLE
        Connect-VeFabric -FabricName ALL

        Test SSH login to each switch in all SAN Fabrics in the default Organization.

        The default Organization is determine by the settings in the first fabric record
        found in the XMLDB.

      .EXAMPLE
        Connect-VeFabric -FabricName Mojo_Fabric_A -Org Mojo

        Tests SSH login to each switch in the SAN Fabric, 'Mojo_Fabric_A' that is associated with the
        'Mojo' organization.

        The '-org' must be used when referencing non-default SAN fabrics.

      .NOTES
        Must have the Posh-SSH module installed for processing.
        
        Install-Module Posh-SSH -scope currentuser
        
        Author: Craig Dayton
        0.0.2.0  07/15/2017 : cadayton : Initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
         http://venom.readthedocs.io
    #>

    function Connect-VeFabric {
      # Update-VeFlogi Params

        [cmdletbinding()]
          Param(
            [Parameter(Position=0,
              Mandatory=$false,
              HelpMessage = "Enter a Fabric Name",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$FabricName = $null,
            [Parameter(Position=1,
              Mandatory=$False,
              HelpMessage = "Enter an Organization name",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$org = $null,
            [Parameter(Position=2,
              Mandatory=$False,
              HelpMessage = "Enter an Organization name",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [switch]$createCSV
        )

      #
      
      Write-Host "Connect-VeFabric version 0.0.2.0" -ForegroundColor Green

      Set-Defaults;

      if ($createCSV) {
        if ([string]::IsNullOrEmpty($FabricName)) {
          $Script:FabricName = "All";
        } else {
          $Script:FabricName = $FabricName;
        }
        
        $xmlDB = Get-ArrayInfoXML;

        if ($Script:FabricName -eq "All") {
          $xmlDB.SelectNodes("//Fabric") |
            Where-Object { $_.Org -match $Script:org} |
            ForEach-Object {
              $Script:FBPath = $Script:SwOrgPath + "\" + $_.fabric;

              # Archive current Fabric csvfile if it exists.
              $csvFile = $_.fabric + ".csv";
              $csvPath = $FBPath + "\" + $csvFile;
              if (Test-Path $csvPath) { Move-ToArchive $csvPath $csvFile}

              # Generate new Fabric csvfile
              $switch = $_.switchID;
              Get-CFSPeers $_.switchID $true
            }
        } else {
          $xmlDB.SelectNodes("//Fabric") |
            Where-Object { $_.Fabric -match $Script:FabricName -and $_.Org -match $Script:org} |
            ForEach-Object {
              $Script:FBPath = $Script:SwOrgPath + "\" + $_.fabric;

              # Archive current Fabric csvfile if it exists.
              $csvFile = $_.fabric + ".csv";
              $csvPath = $FBPath + "\" + $csvFile;
              if (Test-Path $csvPath) { Move-ToArchive $csvPath $csvFile}

              # Generate new Fabric csvfile
              $switch = $_.switchID;
              Get-CFSPeers $switch $true
            }
        }
      }

      if ($Script:FabricName -match "All") { # Switch login for all fabrics
        Get-ChildItem $Script:SwOrgPath |
          Where-Object { $_.Attributes -eq "Directory"} |
          ForEach-Object { # Processing flogi for each folder in C:\bin\ps\SWInfo-<org>
            $FBPath = $_.PSPath;
            $fname = $_.PSChildname + ".csv";
            $csvFile = $FBPath + "\" + $fname;
            Import-CSV -Path $csvFile -Header $peerHeader | Connect-Switch
          }
      } else { # Switch Login for a specific fabric

        $xmlDB = Get-ArrayInfoXML;

        $fabValidate = $xmlDB.SelectNodes("//Fabric") |
          Where-Object { $_.Fabric -match $Script:FabricName -and $_.Org -match $Script:org };

        if ($fabValidate -is [Object]) {
          $FBPath = $Script:SwOrgPath + "\" + $Script:FabricName;
          $csvFile = $FBPath + "\" + $Script:FabricName + ".csv";
          if (Test-Path $csvfile) {
            Import-CSV -Path $csvFile -Header $peerHeader | Connect-Switch
          } else {
            $Script:FBPath = $FBPath;
            $switch = $fabValidate.switchID;
            Get-CFSPeers $switch $true; # create fabric domain csv file

            if (Test-Path $csvFile) {
              Import-CSV -Path $csvFile -Header $peerHeader | Connect-Switch
            } else {
              Write-Host "$csvFile not found"  -ForegroundColor Red;
              Write-Host "Likely a communication problem accessing switch, $fabValidate.switch" -ForegroundColor Green;
            }
          }
        
        } else {
          Write-Host "$Script:FabricName was not found in the XMLDB" -ForegroundColor Red
          Write-Host "Valid Fabric names are: " -ForegroundColor Green
          Show-FabricNames;
        }

      }

    }

  #

  # Enable-VePorts

    <#
      .SYNOPSIS
        Enable ports on a switch.

      .DESCRIPTION
        Enables switch port(s) specified in csv file located in the FabricName folder.  The csv file
        consists of 3 fields, interface,VSAN, and Description.

        interface field:   fcx/y where x is the blade number and y is the port number.
        VSAN field:        numeric value of the desired VSAN.
        Description field: device-alias name followed by a space then the description.

        i.e. fc1/6,100,bowvmx099_fa05h Engine 1 X X

        A file titled, <switchname>_enable.csv is expected to found in the FabricName folder. The
        FabricName folder as the following naming convention.
         
         <execution folder>\SwInfo-<org>\<fabricname>

         Example: C:\bin\ps\SwInfo-Mojo\Mojo_Fabric_A

        Each port will be added to the VSAN, enabled, and description field set.  Once the
        port(s) have been enabled, the csv file is move to the Archive folder.
        
      .PARAMETER FabricName
        The FabricName containing the switches for the port(s) needing to be enabled
        within the default Orgranization.

      .PARAMETER Org

        Is the Organization name responsible for the SAN Fabric(s). This parameter is require to process
        non-default Organization records.

        When the org parameter is not specified, the default organization will be used.  The default organization is
        determined by find the first fabric record in the XMLDB.

      .INPUTS
        A csv file titled, <switchname>_enable.csv found in the SAN Fabric folder.

      .OUTPUTS
        None.

      .EXAMPLE
        Enable-VePorts

        Searches the default SAN Fabric in the default Organization for files titled,
        '<switchname>_enable.csv'. Then enables the specified port(s).

        The default SAN Fabric and Orgranization are set by finding the first fabric record
        in the XMLDB.
        
      .EXAMPLE
        Enable-VePorts -FabricName Mojo_Fabric_A

        Searches the SAN Fabric folder <fabricname> in the default Organization for files titled,
        '<switchname>_enable.csv'. Then enables the specified port(s).

        The default Organization is determine by the settings in the first fabric record
        found in the XMLDB.
        
      .EXAMPLE
        Enable-VePorts -FabricName Mojo_Fabric_A -Org Mojo

        Searches the SAN Fabric folder, '<execution folder>\SwInfo-Mojo\Mojo_Fabric_A' for files titled,
        '<switchname>_enable.csv'. Then enables the specified port(s).

      .NOTES
        Must have the Posh-SSH module installed for processing.
        
        Install-Module Posh-SSH -scope currentuser
        
        Author: Craig Dayton
        0.0.2.0  07/15/2017 : cadayton : Initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
         http://venom.readthedocs.io
    #>

    function Enable-VePorts {
      # Enable-VeFlogi Params

        [cmdletbinding()]
          Param(
            [Parameter(Position=0,
              Mandatory=$false,
              HelpMessage = "Enter a Fabric Name",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$FabricName = $null,
            [Parameter(Position=1,
              Mandatory=$False,
              HelpMessage = "Enter an Organization name",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$org = $null
        )

      #

      Write-Host "Enable-VePorts version 0.0.2.0" -ForegroundColor Green

      Set-Defaults;

      $Script:FBPath = $Script:SwOrgPath + "\" + $Script:FabricName;

      Get-ChildItem -Path $Script:FBPath\* -Include *_enable.csv | ForEach-Object { #
        $fname = $_.PSChildName;
        ($switch,$s1,$s2) = $fname.Split("_");
        Get-SwitchPorts $switch $fname
      }
    }
  #

  # Update-VeFlogi

    <#
      .SYNOPSIS
        Extract the flogi entries from each switch in the SAN fabrics.

      .DESCRIPTION
        Establishes a SSH session with the specified Cisco MDS FC switch in a SAN Fabric and
        extracts the flogi entries into a csv file.

        Typically, this cmdlet should be executed at least daily with the SAN Fabric folder
        version controlled. This will allow one to easily determine the daily changes in the SAN
        Fabric.
        
      .PARAMETER FabricName

        Is the Fabric name containing a set of switches for which flogi entries will be
        extracted.

      .PARAMETER Org

        Is the Organization name responsible for the SAN Fabric(s) and must be specified when
        working with non-default SAN Fabric.  The default SAN Fabric is determined by the first
        fabric record in the XMLDB>

      .INPUTS
        The XMLDB is accessed to validate the FabricName parameter.

        The set of switches associated with a SAN Fabric domain is contained in a csv file named,
        '<execution folder>\SwInfo-<org>\<fabricname>.csv'.

      .OUTPUTS
        A flogi csv file for each switch in the SAN Fabric domain. The flogi csv file is named,
        '<execution folder>\SwInfo-<org>\<fabricname>\<switchname>_flogi.csv'.
        
      .EXAMPLE
        Update-VeFlogi -FabricName Bow_Fabric_A

        Creates a flogi csv file for each switch in the SAN Fabric named, 'Bow_Fabric_A' for the default Organization.

        The default SAN Fabric and Organization is determine by the settings in the first fabric record
        found in the XMLDB.

      .EXAMPLE
        Update-VeFlogi -FabricName ALL

        Creates a flogi csv file for each switch in all SAN Fabrics in the default Organization.

        The default Organization is determine by the settings in the first fabric record
        found in the XMLDB.

      .EXAMPLE
        Update-VeFlogi -FabricName ALL -Org Mojo

        Creates a flogi csv file for each switch in all SAN Fabrics in the organization, 'Mojo'.

      .EXAMPLE
        Update-VeFlogi

        Creates a flogi csv file for each switch in the default SAN Fabric for the default Organization.

        The default SAN Fabric and Organization is determine by the settings in the first fabric record
        found in the XMLDB.

      .EXAMPLE
        Update-VeFlogi -FabricName Mojo_Fabric_A -Org Mojo

        Creates a flogi csv file for each switch in the SAN Fabric, 'Mojo_Fabric_A' that is associated with the
        'Mojo' organization.

      .NOTES
        Must have the Posh-SSH module installed for processing.
        
        Install-Module Posh-SSH -scope currentuser
        
        Author: Craig Dayton
        0.0.2.0  07/15/2017 : cadayton : Initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
         http://venom.readthedocs.io
      
    #>

    function Update-VeFlogi {
      # Update-VeFlogi Params

        [cmdletbinding()]
          Param(
            [Parameter(Position=0,
              Mandatory=$false,
              HelpMessage = "Enter a Fabric Name",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$FabricName = $null,
            [Parameter(Position=1,
              Mandatory=$False,
              HelpMessage = "Enter an Organization name",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$org = $null
        )

      #
      
      Write-Host "Update-VeFlogi version 0.0.2.0" -ForegroundColor Green

      Set-Defaults;
      $Script:flogiOnly = $true;
        
      if ($Script:FabricName -match "All") { # flogi csv for all fabrics
        Get-ChildItem $Script:SwOrgPath |
          Where-Object { $_.Attributes -eq "Directory"} |
          ForEach-Object { # Processing flogi for each folder in C:\bin\ps\SWInfo-<org>
            $FBPath = $_.PSPath;
            $fname = $_.PSChildname + ".csv";
            $csvFile = $FBPath + "\" + $fname;
            Import-CSV -Path $csvFile -Header $peerHeader | Get-Flogi-Details
          }
      } else { # flogi csv for a specific fabric

        $xmlDB = Get-ArrayInfoXML;

        $fabValidate = $xmlDB.SelectNodes("//Fabric") |
          Where-Object { $_.Fabric -match $Script:FabricName -and $_.Org -match $Script:org};

        if ($fabValidate -is [Object]) {
          $Script:FBPath = $Script:SwOrgPath + "\" + $Script:FabricName;
          $csvFile = $Script:FBPath + "\" + $Script:FabricName + ".csv";
          if (Test-Path $csvfile) {
            Import-CSV -Path $csvFile -Header $peerHeader | Get-Flogi-Details
          } else {
            Write-Host "$csvFile not found" -ForegroundColor Red
            Write-Host " ";
            Write-Host "Execute " -ForegroundColor Blue -NoNewline
            Write-Host "'Connect-VeFabric -FabricName $Script:FabricName -org $Script:org' " -ForegroundColor Yellow -NoNewline
            Write-Host "to create the file" -ForegroundColor Blue
          }
        
        } else {
          Write-Host "$Script:FabricName was not found in the XMLDB" -ForegroundColor Red
          Write-Host "Valid Fabric names are: " -ForegroundColor Green
          Show-FabricNames;
        }

      }
    }

  #

  # Set-SymmAlias

      <# block logic not implement
        # Search /FAInfo/Current_ListLogins.csv
        #
        $logInFile = $Global:FAPath + "\" + "Current_ListLogins.csv";
        $finfo = Get-ChildItem -Path $logInFile;
        $lwrite = $finfo.LastWriteTime;
        $lup = Get-Date -Date $lwrite -Format g;
        Write-Host "Processing from $logInFile" -ForegroundColor Green;
        Write-Host " Last Updated: $lup" -ForegroundColor Magenta;
        Write-Host " ";
        $logInObj = Get-ArrayLogin -name NULL -loginHost Yes -obj;

        # Since the initiator is logged into the storage port a zone must exist for it.
        # Lookup the wwn in the flogi.csv files and assign an alias if needed.
        $logInObj | Get-Symm-Details;
      #>

  #

  # Set-VeDeviceAlias

    <#
      
      .SYNOPSIS
        Creates device-aliases on Cisco SAN fabric for initiators and optionally targets
        missing a device-alias assignment.

      .DESCRIPTION
        Establishes a SSH session with the specified Cisco MDS FC switch and sets a device-alias
        name for initiators and optionally targets without a device-alias.
        
        For physical ports NOT in a zone, the new device-alias name is formed using the first node
        value in the switch's port description field following by switch name and port location.
        
        Example device-alias for a phyiscal port:  bowWinServer_mdsbow01_0939

        For virtual ports (NPIV), the device-alias name will be the first node of the zone name.  It is assumed
        the first node in the zone name is the host name.

        Example Zone Name:  BowWinServer01_HBA1_bowpure001

        Example derived Device-Alias name:  BowWinServer01_2c1a

        The last four characters of the device-alias is the last for octets of the WWN. This helps keep all
        device-alias names unique.

        The SAN Fabric folder contains a set of flogi csv files which are used for assessing which interfaces
        are missing a device-alias assignment. A SAN Fabric folder named, <execution folder>\SWInfo-<org>\<fabricname> will be
        searched for flogi csv files.  The naming convention for the flogi csv files is: <switchID>_flogi.csv. 
        
        A Cisco command file is created in the SAN Fabric folder containing a device-alias commands for each interface missing
        a device-alias. The command file naming convention is <switch name>_Alias.cmd.

        All SAN Fabric related files are contained in the specific SAN Fabric folder.  Each SAN Fabric folder
        contains a sub-folder named, Archive for historical tracking of changes.
        
      .PARAMETER FabricName
        Is the SAN Fabric name containing a set of switches to used for processing. If the 'FabricName' option is not
        specified, then the default FabricName value will be used.  The default FabricName value is determined by the
        first fabric record found in the XMLDB.
        
      .PARAMETER Org
        This option is the organization responsible for the SAN Fabric.  If the 'Org' option is not specified,
        then the default Org value will be used.  The default 'Org' value is determined by the first fabric record
        found in the XMLDB> 

      .PARAMETER apply
        Executes the device-alias commands found in the file <switch name>_Alias.cmd for
        all switches in the specified FabricName. If the '-SwitchName' is also specified,
        only the specified switch name will be processed.

      .PARAMETER SwitchName
        Limits the action to the specified SwitchName.

      .PARAMETER SymmAlias
        The file /FAInfo/Current_ListLogins.csv is searched for logged in entries containing
        a Nodename equal "NULL" and a loggedIN value of "Yes".  The wwn value of the record is
        then used to lookup the flogi entry in the /SWInfo/<FabricName> directory.

        If the flogi entry is not a device-alias, then a device-alias is established.

      .INPUTS
        The Fabric domain csv file which is located FabricName folder.

        <execution path>\SwInfo-<org>\<fabricname>\<fabricname>.csv

      .OUTPUTS
        A set files listed below may be found in each Fabric folder.

          1. <fabric name>.csv        - listing of peer switches in the fabric.
          2. <switch name>_flogi.csv  - show flogi database details output for each switch.
          3. <switch name>_Alias.cmd  - set of device-alias commands for device-alias command execution.
          4. <switch name>_enable.csv - contains a set of ports requiring to be enabled on the switch.
          
          Aged files are moved to the 'Archive' folder in each Fabric named folder.

      .EXAMPLE
        Set-DeviceAlias -FabricName Mojo_Fabric_A

        Will read the input file, <fabric name>.csv and generate an output files, <switch name>_flog.csv
        and generate files named, <switch name>_Alias.cmd containing a set of device-alias commands.
        
        Manually review the files named, <switch name>_Alias.cmd to ensure appropriate device-alias names
        have been assigned prior to applying the device-alias assignments.

      .EXAMPLE
        Set-DeviceAlias -FabricName Mojo_Fabric_A -apply

        Will read the input file, <switch name>_Alias.cmd and execute the device-alias commands
        on the switch.

      .EXAMPLE
        Set-DeviceAlias -FabricName All
        
        Same as example 1 but will process all SAN fabric folders.  Once this execution has completed,
        the following example will apply on the changes.

        Set-DeviceAlias -FabricName All -apply.

      .EXAMPLE
        Set-DeviceAlias -FabricName Mojo_Fabric_A -SwitchName mdshay01

        Limits the generation of device-alias command files to the switch named, 'mdshay01'
        in the SAN Fabric, Mojo_Fabric_A

      .NOTES
        Must have the POSH-SSH module installed for processing.
        
        Execute the following command to install POSH-SSH module
          > Install-Module Posh-SSH -scope currentuser
        
        Author: Craig Dayton
        0.0.2.0  07/15/2017 : cadayton : Initial release.
        
      .LINK
        https://github.com/cadayton/Venom

      .LINK
        http://venom.readthedocs.io
    #>

    function Set-VeDeviceAlias {
      # Set-DeviceAlias Params

        [cmdletbinding()]
          Param(
            [Parameter(Position=0,
              Mandatory=$false,
              HelpMessage = "Enter a SAN Fabric Name",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$FabricName = $null,
            [Parameter(Position=1,
              Mandatory=$False,
              HelpMessage = "Organizational owner of the SAN Fabric",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$Org = $null,
            [Parameter(Position=2,
              Mandatory=$False,
              HelpMessage = "Apply Device-Alias commands for all host edge switches",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [switch]$apply,
            [Parameter(Position=3,
              Mandatory=$False,
              HelpMessage = "Enter switch name in a Fabric",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [string]$SwitchName = $null,
            [Parameter(Position=4,
              Mandatory=$False,
              HelpMessage = "Examine Current_ListLogins.csv for missing aliases",
              ValueFromPipeline)]
              [ValidateNotNullorEmpty()]
            [switch]$symmAlias
        )

      #

      Write-Host "Set-VeDeviceAlias version 0.0.2.0" -ForegroundColor Green

      if (!(Get-module POSH-SSH )) {
        Import-Module POSH-SSH
      }

      Set-Defaults;
      $Script:flogiOnly = $false;

      if ($Script:FabricName -match "All") { # process all fabric folder
        Get-ChildItem $Script:SwOrgPath |
          ForEach-Object { # Processing flogi for each folder in <execute folder>\SWInfo-<org>
            $Script:FBPath = $_.PSPath;
            Get-ChildItem $Script:FBPath -Filter "*_Fabric_*.csv" |
              Where-Object { $_.Attributes -ne "Directory"} |
                ForEach-Object {
                  $csvFile = $_.PSPath;
                  Import-CSV -Path $csvFile -Header $peerHeader | Get-Flogi-Details
                }
          }
      } else { # Work within a specific fabric directory
        $Script:FBPath = $Script:SwOrgPath + "\" + $Script:FabricName;  # <execute folder>\SWInfo-<org>\<fabricname>
        $csvFile = $Script:FBPath + "\" + $Script:FabricName + ".csv";  # <execute folder>\SWInfo-<org>\<fabricname>\<fabricname>.csv

        if (Test-Path $csvFile) {
          Import-CSV -Path $csvFile -Header $peerHeader | Get-Flogi-Details
        } else { # Get principal switch

          $switch = Get-SwitchName $Script:FabricName

          if ([string]::IsNullOrEmpty($switch)) {
            Write-Host "$Script:FabricName not found in the XMLDB" -ForegroundColor Red
            Write-Host "Valid Fabric names are: " -ForegroundColor Green
            Show-FabricNames;
          } else {
            Get-CFSPeers $switch
          }
        }
      }
        
    }

  #

#