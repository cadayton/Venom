# Module Constants

  # Global/Private constants are available to all nested modules
  # These constants will be required by other nested modules & the Venom module
  New-Variable -Name AIDir -Value "ArrayInfo"           -Option Constant -Scope Global -Visibility Private -Description "XMLDB folder name";
  New-Variable -Name CRDir -Value "CredInfo"            -Option Constant -Scope Global -Visibility Private -Description "Credential folder name";
  New-Variable -Name AIPath -Value "$PWD\$Global:AIDir" -Option Constant -Scope Global -Visibility Private -Description "XMLDB path";
  New-Variable -Name CRPath -Value "$PWD\$Global:CRDir"  -Option Constant -Scope Global -Visibility Private -Description "Credential path";
  
  $Script:usr = $null
  $Script:pw  = $null
  $Script:org = $null

#

# Non-Exported Functions

  # Dot Sourced Functions

    . $PSScriptRoot\Local\Set-Ignore-SelfSignedCerts.ps1
    . $PSScriptRoot\Local\Export-PSCredentials.ps1
    . $PSScriptRoot\Local\Import-PSCredentials.ps1
    . $PSScriptRoot\Local\Get-ArrayInfoXML.ps1

  #

  # Get-VeArrayInfo functions
    function Select-Report {

      $reports = @();
      $reports += [pscustomobject]@{Array="All-Arrays";
          Description = " Capacity Summary of all block arrays"}
      $reports += [pscustomobject]@{Array="Symmetrix";
          Description = " Capacity Summary of all Symmetrix arrays"};
      $reports += [pscustomobject]@{Array="VPLEX";
          Description = " Summary of all VPLEX arrays"};
      $reports += [pscustomobject]@{Array="Pure";
          Description = " Capacity Summary of all PureSystem arrays"};
      $reports += [pscustomobject]@{Array="IBM";
          Description = " Capacity Summary of all IBM arrays"};
      $reports += [pscustomobject]@{Array="VNX";
          Description = " Capacity Summary of all VNX arrays"};
      $reports += [pscustomobject]@{Array="Trend";
          Description = " Historical Capacity Trend of one or more VMAX arrays"};

      $title = "Select the desired Array Capacity Report"
      $selectA_report = $reports | Out-GridView -Title $title -OutputMode Single;

      if ($selectA_report -eq $null) {
          return $null
      }

      return $selectA_report.Array

    }

    function Convert-ArrayXMLDB {
      begin {$PSArrays = @();}
      process {
        $PSArray = New-Object -typename PSObject
        $PSArray | Add-Member -MemberType NoteProperty -Name "Array" -Value $_.Name
        $PSArray | Add-Member -MemberType NoteProperty -Name "Sid" -Value $_.sid
        $PSArray | Add-Member -MemberType NoteProperty -Name "Org" -Value $_.Org
        $PSArray | Add-Member -MemberType NoteProperty -Name "Class" -Value $_.Class
        $PSArray | Add-Member -MemberType NoteProperty -Name "Model" -Value $_.Model
        $PSArray | Add-Member -MemberType NoteProperty -Name "Usage" -Value $_.usage
        $PSArray | Add-Member -MemberType NoteProperty -Name "Data Center" -Value $_.DataCenter
        #$PSArray | Add-Member -MemberType NoteProperty -Name "Remote" -Value $_.Remote
        $useable = $_.total_usable_tb
        $PSArray | Add-Member -MemberType NoteProperty -Name "Usable (TB)" -Value $useable
        $PSArray | Add-Member -MemberType NoteProperty -Name "Used (TB)" -Value $_.total_used_tb
        $PSArray | Add-Member -MemberType NoteProperty -Name "Free (TB)" -Value $_.total_free_tb
        $PSArray | Add-Member -MemberType NoteProperty -Name "Full%" -Value $_.percent_full
        $PSArray | Add-Member -MemberType NoteProperty -Name "Subs%" -Value $_.subs_percent
        $PSArray | Add-Member -MemberType NoteProperty -Name "T0 Full%" -Value $_.t0_percent_full
        $PSArray | Add-Member -MemberType NoteProperty -Name "T0 Subs%" -Value $_.t0_subs_percent
        $PSArray | Add-Member -MemberType NoteProperty -Name "T1 Full%" -Value $_.t1_percent_full
        $PSArray | Add-Member -MemberType NoteProperty -Name "T1 Subs%" -Value $_.t1_subs_percent
        $PSArray | Add-Member -MemberType NoteProperty -Name "T2 Full%" -Value $_.t2_percent_full
        $PSArray | Add-Member -MemberType NoteProperty -Name "T2 Subs%" -Value $_.t2_subs_percent
        $PSArray | Add-Member -MemberType NoteProperty -Name "Updated" -Value $_.LastUpdated
        $PSArray | Add-Member -MemberType NoteProperty -Name "RestAPI" -Value $_.restapi
        $PSArrays += $PSArray
      }
      # return an array of storage arrays
      end { $PSArrays }
    }

    function Convert-ArrayXMLDB-Trend {
      begin {$PSArrays = @();}
      process {
        $PSArray = New-Object -typename PSObject
        $PSArray | Add-Member -MemberType NoteProperty -Name "Array" -Value $_.Name
        $PSArray | Add-Member -MemberType NoteProperty -Name "Sid" -Value $_.sid
        $PSArray | Add-Member -MemberType NoteProperty -Name "Org" -Value $_.Org
        $PSArray | Add-Member -MemberType NoteProperty -Name "Class" -Value $_.Class
        $PSArray | Add-Member -MemberType NoteProperty -Name "Model" -Value $_.Model
        $PSArray | Add-Member -MemberType NoteProperty -Name "Usage" -Value $_.usage
        $PSArray | Add-Member -MemberType NoteProperty -Name "Data Center" -Value $_.DataCenter

        <#
            $PSArray | Add-Member -MemberType NoteProperty -Name "Remote" -Value $_.Remote
            $PSArray | Add-Member -MemberType NoteProperty -Name "Usable (TB)" -Value $_.total_usable_tb
            $PSArray | Add-Member -MemberType NoteProperty -Name "Used (TB)" -Value $_.total_used_tb
            $PSArray | Add-Member -MemberType NoteProperty -Name "Free (TB)" -Value $_.total_free_tb
            $PSArray | Add-Member -MemberType NoteProperty -Name "Full%" -Value $_.percent_full
            $PSArray | Add-Member -MemberType NoteProperty -Name "Subs%" -Value $_.subs_percent
            $PSArray | Add-Member -MemberType NoteProperty -Name "Updated" -Value $_.LastUpdated
        #>

        $PSArrays += $PSArray
      }
      # return an array of storage arrays
      end { $PSArrays }
    }

    function Convert-TrendXML {
      begin {$PSTrends = @() }
      process {
        $PSTrend = New-Object -typename PSObject
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Array" -Value $_.Name
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Sid" -Value $_.sid
        $PSArray | Add-Member -MemberType NoteProperty -Name "Org" -Value $_.Org
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Class" -Value $_.Class
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Model" -Value $_.Model
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Usage" -Value $_.usage
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Data Center" -Value $_.DataCenter
        #$PSTrend | Add-Member -MemberType NoteProperty -Name "Remote" -Value $_.Remote
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Usable (TB)" -Value $_.total_usable_tb
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Used (TB)" -Value $_.total_used_tb
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Free (TB)" -Value $_.total_free_tb
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Full%" -Value $_.percent_full
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Subs%" -Value $_.subs_percent
        $PSTrend | Add-Member -MemberType NoteProperty -Name "T0 Full%" -Value $_.t0_percent_full
        $PSTrend | Add-Member -MemberType NoteProperty -Name "T0 Subs%" -Value $_.t0_subs_percent
        $PSTrend | Add-Member -MemberType NoteProperty -Name "T1 Full%" -Value $_.t1_percent_full
        $PSTrend | Add-Member -MemberType NoteProperty -Name "T1 Subs%" -Value $_.t1_subs_percent
        $PSTrend | Add-Member -MemberType NoteProperty -Name "T2 Full%" -Value $_.t2_percent_full
        $PSTrend | Add-Member -MemberType NoteProperty -Name "T2 Subs%" -Value $_.t2_subs_percent
        $PSTrend | Add-Member -MemberType NoteProperty -Name "Updated" -Value $_.LastUpdated
        $PSTrends += $PSTrend
      }
      # return an array of storage arrays
      end { $PSTrends }
    }

    function Test-Trend {
        $title = "Select a Storage Array for the Trend Report";
        $doc.SelectNodes("//Array") |
            Where-Object {$_.Model -match "VMAX"} |
            Convert-ArrayXMLDB-Trend | Out-GridView -OutputMode Single -Title $title |
            ForEach-Object { $sid = $_.Sid; $name = $_.Name };
            #ForEach-Object { Write-Host "You selected:" $_.Sid}

        $trd = new-object "System.Xml.XmlDocument"
        $AIFile.Fullname | ForEach-Object {
            $trd.Load($_); $trd.SelectNodes("//Array") |
            Where-Object {$_.sid -match $sid} | Convert-TrendXML
        } | Out-GridView -Title "VMAX Trend Report";

    }

    function Show-VMAX-TrendReport {

      $trd = new-object "System.Xml.XmlDocument"
      $title = "Select one or more VMAX arrays for the Trend Report";
      $doc.SelectNodes("//Array") |
        Where-Object {$_.Model -match "VMAX"} |
        Convert-ArrayXMLDB-Trend | Out-GridView -OutputMode Multiple -Title $title |
        ForEach-Object { $SidSelected = $_.Sid
            $AIFile.Fullname | ForEach-Object {
                $trd.Load($_); $trd.SelectNodes("//Array") |
                Where-Object {$_.sid -match $SidSelected} | Convert-TrendXML
            } # | Out-GridView -Title "VMAX Trend Report" # Grid per SID
        } | Out-GridView -Title "VMAX Trend Report";      # One Grid for all arrays
    }

    function Add-ArrayInfoDB {
      New-Item -Path $PWD\$Global:AIDir -ItemType Directory | Out-Null;
      $tod = Get-Date -Format "MM-dd-yyyy"
      $yed = (Get-Date).AddDays(-1)
      $yo1 = $yed.ToString("MM-dd-yyyy")

      $basenm   = $Global:AIDir
      $newfile  = $Global:AIPath + "\" + $basenm + "-" + $tod + ".xml"
      $oldfile  = $Global:AIPath + "\" + $basenm + "-" + $yo1 + ".xml"

      Copy-Item -Path $PSScriptRoot\Data\ArrayInfo-Example.xml -Destination $newfile;
      Copy-Item -Path $PSScriptRoot\Data\ArrayInfo-Example.xml -Destination $oldfile;

    }
  #

  # Update-VeArrayInfo Functions

    function ConvertSize {
      param(
          [validateset("Bytes","KB","MB","VMAXTK","GB","TB","PB")]
          [string]$From,
          [validateset("Bytes","KB","MB","GB","TB","PB")]
          [string]$To,
          [Parameter(Mandatory=$true)]
          [double]$Value,
          [int]$Precision = 0
      )
      switch($From) {
          "Bytes" {$value = $Value }
          "KB" {$value = $Value * 1024 }
          "MB" {$value = $Value * 1024 * 1024}
        "VMAXTK" {$value = ($Value * $vmaxtk)}
          "GB" {$value = $Value * 1024 * 1024 * 1024}
          "TB" {$value = $Value * 1024 * 1024 * 1024 * 1024}
        "PB" {$value = $Value * 1024 * 1024 * 1024 * 1024 * 1024}
      }
      switch ($To) {
          "Bytes" {return $value}
          "KB" {$Value = $Value/1KB}
          "MB" {$Value = $Value/1MB}
          "GB" {$Value = $Value/1GB}
          "TB" {$Value = $Value/1TB}
          "PB" {$Value = $Value/1PB}

      }

      $rslt = [Math]::Round($value,$Precision,[MidPointRounding]::AwayFromZero)
      [string]$srslt = $rslt
      return $srslt
    }

    function Set-Symcli-Connect {
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

    function Update-Symm-ArrayInfo {
      begin { }

      process {
        $remote = $_.remote;
        $symm = $_.Model
        $symmSid = $_.sid;

        if ($remote -match "none") {
          Write-Host "Skipping $symm : $symmSid no symcli server available" -ForegroundColor Red;
        } else {
          Set-Symcli-Connect $remote
          Write-Host "Processing $symm : $symmSid on $remote" -ForegroundColor Green;

          if ($symm -match "VMAX") {
            #Write-Host "$symm"
            [xml]$xml = symcfg -sid $_.sid list -pool -thin -detail -out xml_element
            if ($LastExitCode -eq 0) { # last command executed without error
              [int]$value = $xml.SymCLI_ML.Symmetrix.Totals.total_usable_tracks_gb
              $_.total_usable_tb = ConvertSize -From GB -TO TB -value $value

              [int]$value = $xml.SymCLI_ML.Symmetrix.Totals.total_used_tracks_gb
              $_.total_used_tb = ConvertSize -From GB -TO TB -value $value

              [int]$value = $xml.SymCLI_ML.Symmetrix.Totals.total_free_tracks_gb
              $_.total_free_tb = ConvertSize -From GB -TO TB -value $value

              $_.percent_full = [string]$xml.SymCLI_ML.Symmetrix.Totals.percent_full
              $_.subs_percent = [string]$xml.SymCLI_ML.Symmetrix.Totals.subs_percent
              $_.LastUpdated = [string]$dt = Get-Date -Format "MM/dd/yyy HH:mm"

              [string]$t0full, [string]$t0subs = " ";
              [string]$t1full, [string]$t1subs = " ";
              [string]$t2full, [string]$t2subs = " ";

              $xml.SymCLI_ML.Symmetrix.DevicePool | ForEach-Object {
                if ($_.technology -eq "EFD") {
                  $t0full = $_.percent_full
                  $t0subs = $_.subs_percent
                }
                if ($_.technology -eq "FC") {
                  $t1full = $_.percent_full
                  $t1subs = $_.subs_percent
                }
                if ($_.technology -eq "SATA") {
                  $t2full = $_.percent_full
                  $t2subs = $_.subs_percent
                }
              }

              $_.t0_percent_full = [string]$t0full
              $_.t0_subs_percent = [string]$t0subs
              $_.t1_percent_full = [string]$t1full
              $_.t1_subs_percent = [string]$t1subs
              $_.t2_percent_full = [string]$t2full
              $_.t2_subs_percent = [string]$t2subs
            }
          } elseif ($symm -match "DMX") {
            #Write-Host "DMX: $symm"
            [xml]$xml = symdisk -sid $_.sid list -dskgrp_summary -out xml_element
            if ($LastExitCode -eq 0) { # last command executed without error
              [int]$value = $xml.SymCLI_ML.Symmetrix.Disk_Group_Summary_Totals.total
              $_.total_usable_tb = ConvertSize -From MB -TO TB -value $value
              [int]$usable = $_.total_usable_tb

              [int]$value = $xml.SymCLI_ML.Symmetrix.Disk_Group_Summary_Totals.free
              $_.total_free_tb = ConvertSize -From MB -TO TB -value $value
              [int]$free = $_.total_free_tb

              [int]$used = $usable - $free
              [string]$sused = $used
              $_.total_used_tb = $sused

              [int]$fullp = [Math]::Round(($used / $usable) * 100, 0)
              [string]$sfullp = $fullp
              $_.percent_full = $sfullp

              $_.subs_percent = "NA"
              $_.LastUpdated = [string]$dt = Get-Date -Format "MM/dd/yyy HH:mm"
            }
          } else {
            Write-Host "Error Processing: $symmSid - $LastExitCode"
          }
        }
      }

      end { }
    }

    function Update-Symm-ArrayInfo1 {

      begin {
        # set requests, to use TLSv1.2 protocol
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        # tell Windows to ignore self-signed certs
        Set-Ignore-SelfSignedCerts;
      }

      process {
        $AIobj			= $_;
        $symm 			= $_.Model
        $symmSid 		= $_.sid;
        $org        = $_.org
        $symmsn 		= $_.sn;
        $URIserver 	= $_.restapi;
        $usrname		= $_.username;
        $URIport		= ":8443";
        $userver		= $URIserver + $URIport;

        Write-Host "Processing $symm : $symmSid via RESTAPI to $URIServer" -ForegroundColor Green;

        if ($Script:org -ne $org ) {  # assume same credentials for all Unisphere servers in Org
          $Script:org = $org;

          $credBase = "-" + $org + "-" + $env:COMPUTERNAME + $credExt;
          $Script:credfilename = $Global:CRPath + "\" + $usrname + $credBase;
          
          if (!(Test-Path $Script:credfilename)) { # create cache credential
            Write-Host "Unisphere Credentials require for $org Storage" -ForegroundColor Green
            Export-PSCredential $usrname $credBase
            Start-Sleep 3;
          }

          $cred = Import-PSCredential $Script:credfilename
          $Script:usr = $cred.UserName;
          $Script:pw  = $cred.GetNetworkCredential().Password;
          
        }

        $EUP = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Script:usr,$Script:pw)))
        $Headers=@{'Authorization'="Basic $($EUP)";'Content-type'='application/xml';'Accept'='application/xml'}

        $ierr = $null
        if ($_.Model -match "VMAX2") {
          # https://admassan45:8443/univmax/restapi/provisioning/symmetrix/000292600479/thinpool
          $URI = "https://$userver/univmax/restapi/provisioning/symmetrix/$symmsn/thinpool"
          try { $response = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers }
          catch {
            Write-Host $_ -ForegroundColor "Red";
            $ierr = $_;
            Write-Verbose "userver: $userver  symmsn: $symmsn"
            Write-Verbose $URI
          }
          if ($ierr -eq $null) {
            [int]$total_usable_gb = 0;
            [int]$total_used_gb = 0;
            [int]$total_free_gb = 0;
            [string]$t0full, [string]$t0subs = " ";
            [string]$t1full, [string]$t1subs = " ";
            [string]$t2full, [string]$t2subs = " ";

            $response.listThinPoolResult.poolId | ForEach-Object {
              $tpool = $_;
              # "https://admassan45:8443/univmax/restapi/provisioning/symmetrix/000292600479/thinpool/$tpool"
              $URI = "https://$userver/univmax/restapi/provisioning/symmetrix/$symmsn/thinpool/$tpool"
              try	{ $poolResp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers }
              catch { Write-Host $_ -ForegroundColor Magenta; $ierr = $_; }

              if ($ierr -eq $null) {
                if ($poolResp.getThinPoolResult.thinPool.diskTechnology -eq "EFD") {
                  $t0full = $poolResp.getThinPoolResult.thinPool.percent_allocated
                  $t0subs = $poolResp.getThinPoolResult.thinPool.percent_subscription
                }
                if ($poolResp.getThinPoolResult.thinPool.diskTechnology -eq "FC") {
                  $t1full = $poolResp.getThinPoolResult.thinPool.percent_allocated
                  $t1subs = $poolResp.getThinPoolResult.thinPool.percent_subscription
                }
                if ($poolResp.getThinPoolResult.thinPool.diskTechnology -eq "SATA") {
                  $t2full = $poolResp.getThinPoolResult.thinPool.percent_allocated
                  $t2subs = $poolResp.getThinPoolResult.thinPool.percent_subscription
                }

                $total_usable_gb	+= $poolResp.getThinPoolResult.thinPool.total_gb;
                $total_used_gb 		+= $poolResp.getThinPoolResult.thinPool.used_gb;
                $total_free_gb		+= $poolResp.getThinPoolResult.thinPool.free_gb;

                $AIobj.t0_percent_full	= [string]$t0full
                $AIobj.t0_subs_percent	= [string]$t0subs
                $AIobj.t1_percent_full	= [string]$t1full
                $AIobj.t1_subs_percent	= [string]$t1subs
                $AIobj.t2_percent_full	= [string]$t2full
                $AIobj.t2_subs_percent	= [string]$t2subs
                $AIobj.total_usable_tb	= ConvertSize -From GB -TO TB -value $total_usable_gb
                $AIobj.total_used_tb		=	ConvertSize -From GB -TO TB -value $total_used_gb
                $AIobj.total_free_tb		= ConvertSize -From GB -TO TB -value $total_free_gb

                [double]$full						= [Math]::Round(($total_used_gb / $total_usable_gb) * 100, 0)
                $AIobj.percent_full			= [string]$full
                #$AIobj.subs_percent		= " ";
                [string]$dt 						= Get-Date -Format "MM/dd/yyyy HH:mm"
                $AIobj.LastUpdated 			= $dt;
              }
            }
          }
        }

        $ierr = $null
        if ($_.Model -match "VMAX3") {
          # https://pxvmx0316:8443/univmax/restapi/sloprovisioning/symmetrix/000197000316/srp
          $URI = "https://$userver/univmax/restapi/sloprovisioning/symmetrix/$symmsn/srp";
          try { $response = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers }
          catch { Write-Host $_ -ForegroundColor "Red"; $ierr = $_; }

          if ($ierr -eq $null) {
            [int]$total_usable_gb = 0;
            [int]$total_used_gb = 0;
            [int]$total_free_gb = 0;
            [string]$t0full, [string]$t0subs = " ";
            [string]$t1full, [string]$t1subs = " ";
            [string]$t2full, [string]$t2subs = " ";

            $response.listSRPResult.srpId | ForEach-Object {
              $srpId = $_;
              # https://pxvmx0316:8443/univmax/restapi/sloprovisioning/symmetrix/000197000316/srp/SRP_EFD_R5
              $URI = "https://$userver/univmax/restapi/sloprovisioning/symmetrix/$symmsn/srp/$srpId"
              try	{ $srpResp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers }
              catch { Write-Host $_ -ForegroundColor Magenta; $ierr = $_; }

              if ($ierr -eq $null) {
                $total_usable_gb	= $srpResp.getSRPResult.srp.total_usable_cap_gb;
                $total_used_gb 		= $srpResp.getSRPResult.srp.total_allocated_cap_gb;
                $total_sub_gb			= $srpResp.getSRPResult.srp.total_subscribed_cap_gb;
                $total_free_gb		= $total_usable_gb - $total_used_gb;

                [double]$full			= [Math]::Round(($total_used_gb / $total_usable_gb) * 100, 0)
                $t0full 					= $full
                [double]$sub			= [Math]::Round(($total_sub_gb / $total_usable_gb) * 100, 0)
                $t0subs						= $sub

                $AIobj.t0_percent_full	= [string]$t0full
                $AIobj.t0_subs_percent	= [string]$t0subs
                $AIobj.t1_percent_full	= [string]$t1full
                $AIobj.t1_subs_percent	= [string]$t1subs
                $AIobj.t2_percent_full	= [string]$t2full
                $AIobj.t2_subs_percent	= [string]$t2subs
                $AIobj.total_usable_tb	= ConvertSize -From GB -TO TB -value $total_usable_gb
                $AIobj.total_used_tb		=	ConvertSize -From GB -TO TB -value $total_used_gb
                $AIobj.total_free_tb		= ConvertSize -From GB -TO TB -value $total_free_gb

                $AIobj.percent_full			= " ";
                $AIobj.subs_percent			= " ";
                [string]$dt 						= Get-Date -Format "MM/dd/yyyy HH:mm"
                $AIobj.LastUpdated 			= $dt
              }
            }
          }
        }
      }

      end { }

    }

    function Update-Pure-ArrayInfo {
      begin {

        $xmlDB = Get-ArrayInfoXML;

        if ($Script:org -eq $null) { # org value from first record since none specified
          $unique = $xmlDB.SelectNodes("//Array") |
            Where-Object { $_.Class -match "Pure"} |
            Select-Object -Property Org, username, domainname -Unique;
            $Script:org = $unique[0].Org;
          
        } else {
          $unique = $xmlDB.SelectNodes("//Array") |
            Where-Object { $_.Class -match "Pure" -and $_.Org -match $Script:org} |
            Select-Object -Property Org, username, domainname -Unique;
        }
        
        $usrname = $unique[0].username;
        $credBase = "-" + $Script:org + "-" + $env:COMPUTERNAME + $credExt;
        $Script:credfilename = $Global:CRPath + "\" + $usrname + $credBase;
        Write-Verbose "Pure Credentials : $Script:credfilename";

        if (!(Test-Path $Script:credfilename)) { # create cache credential
          Export-PSCredential $usrname $credBase
          Start-Sleep 3;
        }
        $cred = Import-PSCredential $Script:credfilename
      }

      process {
        $pureIP = $_.remote;
        $pureName = $_.Name;
        Write-Host "Processing Pure Array : $pureName via RESTAPI" -ForegroundColor Green;
        $pure = New-PfaArray -EndPoint $pureIP -Credentials $cred -IgnoreCertificateError;
        $rslt = Get-PfaArraySpaceMetrics -array $pure;

        [double]$usable = $rslt.capacity;
        $_.total_usable_tb = ConvertSize -From Bytes -TO TB -value $usable;

        [double]$vols = $rslt.volumes;
        [double]$shared = $rslt.shared_space;
        [double]$used = $vols + $shared;
        $_.total_used_tb = ConvertSize -From Bytes -TO TB -value $used;

        [double]$free = $usable - $used;
        $_.total_free_tb = ConvertSize -From Bytes -TO TB -value $free;

        [double]$full = ($used/$usable) * 100;
        $value = [Math]::Round($full)
        $_.percent_full = [string]$value

        [int]$sub = $rslt.total_reduction;
        $value = [Math]::Round($sub,1);
        $_.subs_percent = [string]$value;
        [string]$dt = Get-Date -Format "MM/dd/yyy HH:mm"
        $_.LastUpdated = $dt;

      }

      end {

      }
    }

  #

#

# Exported Functions

  <#
      .SYNOPSIS
          Report of capacity metrics of specified storage arrays
          presented in an Excel like column and row table.

          Filters and sorting supported.

      .DESCRIPTION
          Generates an array of PSObjects based on xml input content
          and presents the metrics in a Out-Gridview table.

      .PARAMETER symm
          Switch for reporting on symmetrix arrays only.

      .PARAMETER vmax
          Switch for reporting on VMAX arrays only.

      .PARAMETER dmx
          Switch for reporting on DMX arrays only

      .PARAMETER vnx
          Switch for reporting on VNX arrays only.

      .PARAMETER trend
          Processes all the XML files in the sub-directory, 'ArrayInfo'.
          Out-GridView is presented for selection of specific VMAX arrays.

      .INPUTS
          Uses the most current file named, ArrayInfo-MM-DD-YYYY.xml in
          the sub-folder called, 'ArrayInfo'.

          For trending reports, Out-Gridview is presented for selection
          of one or more VMX arrays.

      .OUTPUTS
          Displays a Out-Gridview of the array capacity metrics.

      .EXAMPLE
        Get-VeArrayInfo            # Out-GridView of all arrays

        If multiple options are specified, only first one is processed.

      .EXAMPLE
        Get-VeArrayInfo -vnx       # Out-GridView of all VNX arrays

      .EXAMPLE
          Get-VeArrayInfo -vnx -vmax 	# 2nd option is ignored.

      .EXAMPLE
          Get-VeArrayInfo -trend     # Trend Report for selected VMAX arrays.

          An Out-Gridview of all VMAX arrays is presented for selection of one or more VMAX arrays.

      .NOTES
          Author: Craig Dayton
          0.0.2.0: 07/07/2017 : cadayton : converted to Venom module.
          Updated: 11/31/2016 Added integration with Get-Pure-Metrics.ps1
          Updated: 10/17/2016 added integration with Get-Array-Metrics.ps1

      .LINK
          https://github.com/cadayton/Venom
      
      .LINK
          http://venom.readthedocs.io
  #>

  function Get-VeArrayInfo  {
    # Get-ArrayInfo
      [cmdletbinding()]
        Param(
          [Parameter(Position=0,
            Mandatory=$false,
            ValueFromPipeline=$True)]
            [switch]$symm,
          [Parameter(Position=2,
            Mandatory=$false,
            ValueFromPipeline=$True)]
            [switch]$vmax,
          [Parameter(Position=3,
            Mandatory=$false,
            ValueFromPipeline=$True)]
            [switch]$dmx,
          [Parameter(Position=4,
            Mandatory=$false,
            ValueFromPipeline=$True)]
            [switch]$vnx,
          [Parameter(Position=4,
            Mandatory=$false,
            ValueFromPipeline=$True)]
            [switch]$trend
        )

    #

    # Main Routine

      if (!(Test-Path $Global:AIDir)) { Add-ArrayInfoDB }

      $AIFile = Get-ChildItem -Path $Global:AIPath |
          Where-Object {$_.PSChildName -like "ArrayInfo*.xml"} |
          Sort-object -property @{Expression={$_.LastWriteTime}; Ascending=$false};

      $FileIn = $Global:AIPath + "\" + $AIFile.PSChildName[0];

      $doc = new-object "System.Xml.XmlDocument"
      $doc.Load($FileIn)

      if ($symm) {
        $title = "List of Symmetrix storage arrays";
        $doc.SelectNodes("//Array") | Where-Object {$_.Class -match "Symmetrix"} | Convert-ArrayXMLDB | Out-GridView -Title $title
      } elseif ($vmax) {
        $title = "List of VMAX storage arrays";
        $doc.SelectNodes("//Array") | Where-Object {$_.Model -match "VMAX"} | Convert-ArrayXMLDB | Out-GridView -Title $title
      } elseif ($dmx) {
        $title = "List of DMX storage arrays";
        $doc.SelectNodes("//Array") | Where-Object {$_.Model -match "DMX"} | Convert-ArrayXMLDB | Out-GridView -Title $title
      } elseif ($vnx) {
        $title = "List of VNX storage arrays";
        $doc.SelectNodes("//Array") | Where-Object {$_.Class -match "VNX"} | Convert-ArrayXMLDB | Out-GridView -Title $title
      } elseif ($trend) {
        Show-VMAX-TrendReport
      } else {
        $rptloop = $true;
        While ($rptloop) {
          $rptType = Select-Report;

          switch ($rptType) {
            "All-Arrays" {
              $title = "List of All storage arrays";
              $report = $doc.SelectNodes("//Array") |
                  Convert-ArrayXMLDB |
                  Out-GridView -Title $title -OutputMode Single
            }
            "Symmetrix" {
              $title = "List of Symmetrix storage arrays";
              $report = $doc.SelectNodes("//Array") |
                  Where-Object {$_.Class -match "Symmetrix"} |
                  Convert-ArrayXMLDB |
                  Out-GridView -Title $title -OutputMode Single
              if ($report -ne $null) {
                  $selsid = $report.sid;
                  $unisphere = $report.restapi
                  Write-Host "Display Performance Reports for VMAX $selsid (Y or N)?" -NoNewline -ForegroundColor Green
                  [string]$resp = Read-Host;
                  if ($resp -match "Y") {
                      Get-VeSymmMetrics $unisphere $selsid
                  };
              }
            }
            "VPLEX" {
              $title = "List of VPLEX storage arrays";
              $report = $doc.SelectNodes("//Array") |
                  Where-Object {$_.Class -match "VPLEX"} |
                  Convert-ArrayXMLDB |
                  Out-GridView -Title $title -OutputMode Single
              $vplex = $report.Array
              Write-Host "Display $rptType Performance metrics for $vplex (Y or N)?" -NoNewline -ForegroundColor Green
              [string]$resp = Read-Host;
              if (($resp -match "Y") -and ($report -ne $null)) { Get-VeVPlexMetrics $vplex  }
            }
            "Pure" {
              $title = "List of PureSystem storage arrays";
              $report = $doc.SelectNodes("//Array") |
                  Where-Object {$_.Class -match "Pure"} |
                  Convert-ArrayXMLDB |
                  Out-GridView -Title $title -OutputMode Single
              $pure = $report.Array
              Write-Host "Display $rptType Performance metrics(Y or N)?" -NoNewline -ForegroundColor Green
              [string]$resp = Read-Host;
              if (($resp -match "Y") -and ($report -ne $null)) { Get-VePureMetrics }
            }
            "IBM" {
              $title = "List of Fraud IBM storage arrays";
              $report = $doc.SelectNodes("//Array") |
                  Where-Object {$_.Class -match "IBM"} |
                  Convert-ArrayXMLDB |
                  Out-GridView -Title $title -OutputMode Single
            }
            "VNX" {
              $title = "List of VNX storage arrays";
              $report = $doc.SelectNodes("//Array") |
                  Where-Object {$_.Class -match "VNX"} |
                  Convert-ArrayXMLDB |
                  Out-GridView -Title $title -OutputMode Single
            }
            "Trend" {
              Show-VMAX-TrendReport
              $report = "none"
            }
            Default {
                Write-Host "Report operation cancelled" -ForegroundColor Red
            }
          }

          Write-Host "Select a different Array report (Y or N)?" -NoNewline -ForegroundColor Green
          [string]$resp = Read-Host;
          if ($resp -match "N") { $rptloop = $false };

          # if ($report -ne $null) { Performance-Report $report }
          #if ($report -ne $null) { Get-VeVPlexMetrics }
        }
      }

    #

  }

  <#
    .SYNOPSIS
      By default, the Unisphere RESTAPI is called to collect capacity
      metrics for each of the symmetrix arrays.

      Can query either an online (local or remote) or an offline
      copy of the symapi database and updates capacity metrics.

      PureSystem's PureStoragePowerShellSDK is used update
      Pure Storage arrays.

    .DESCRIPTION
      The most recent XML file titled, ArrayInfo-MM-DD-YYYY.xml within the
      sub-directory, ArrayInfo is loaded as input.

    .PARAMETER offline
      Process against an offline copy of the symapi_db.bin
      NOT IMPLEMENTED in module version of the cmdlet.

    .PARAMETER hostnm
      Host name of where the symcli commands will be executed.

      If offline is true, the assumption is the host is a unix
      host and SSH will be used to get an offline copy of the
      symapi database.

      If offline is false, the assumption is the host is a Windows
      host with the symapi server implemented for processing symcli
      remote commands.

    .PARAMETER netcfgnm
      By default, the value is 'restapi' which invokes the Unisphere
      RESTAPI.

      If it is desired to use the symcli, then the value should be a
      name listed in the netcfg file to reference the symcli hostnm.

    .INPUTS
      /ArrayInfo/ArrayInfo-MM-DD-YYYY.xml

    .OUTPUTS
      A new file as /ArrayInfo/ArrayInfo-MM-DD-YYYY.xml

    .EXAMPLE
      Update-ArrayInfo

      The RESTAPI is used to update capacity metrics in the new ArrayInfo file.

      Get-ArrayInfo.ps1 is used to display the array information using the
      Out-GridView feature within PowerShell.

    .EXAMPLE
      Update-ArrayInfo -netcfgnm _PX038

      The netcfg entry referenced by _PX038 is used for remote symcli execution.

    .NOTES
      Must have the POSH-SSH module installed for processing
      of an offline copy of the symapi database from a Unix host.

      Execute the following command to install POSH-SSH module
      iex (New-Object Net.WebClient).DownloadString("https://gist.github.com/darkoperator/6152630/raw/c67de4f7cd780ba367cccbc2593f38d18ce6df89/instposhsshdev")

      Must have PureStoragePowerShellSDK installed to support Pure arrays.

      Execute the following to install PureStorage PowerShell module.
      Install-Module -Name PureStoragePowerShellSDK

      Author: Craig Dayton
      0.0.2.0: 07/07/2017 : cadayton : converted to Venom module.
      Updated: 01/05/2016 - Added support for Unisphere RESTAPI
      Updated: 10/29/2016 - Added Support for Pure Arrays
      Updated: 08/24/2015 - Initial Release

    .LINK
      https://github.com/cadayton/Venom

  #>
  function Update-VeArrayInfo {
    #.TODO
	    #	Backup provisioning groups: symaccess -sid 2394 backup -f backup_2394.grps
    #

    # Update-VeArrayInfo
      [cmdletbinding()]
        Param(
          [Parameter(Position=0,
            Mandatory=$false,
            ValueFromPipeline=$True)]
          [bool]$offline = $false,
          [Parameter(Position=1,
            Mandatory=$false,
            ValueFromPipeline=$True)]
          [string]$hostnm = "admassan38",
          [Parameter(Position=2,
            Mandatory=$false,
            ValueFromPipeline=$True)]
          [string]$netcfgnm = "restapi"
        )

    #

    # Declarations

      New-Variable -Name vmaxtk -Value 64KB -Option Constant
      Set-Variable credExt ".enc.xml" -Option Constant

    #

    # Main Routine

      <#  Logic for moving data to share location
        #todo: may need to add credentials to access share

        $cShare = "\\my.share.org\scratch"
        $cName  = "AI"
        New-PSDrive -name $cName -psprovider filesystem -Root $cShare | Out-Null
        $NetPath = $cName + ":\$Global:AIDir";
      #>

      $AIFile = Get-ChildItem -Path $Global:AIPath |
        Where-Object {$_.PSChildName -like "ArrayInfo*.xml"} |
        Sort-object -property @{Expression={$_.LastWriteTime}; Ascending=$false};

      $FileIn = $AIFile.FullName[0]
      $basenm,$x = $FileIn.split("-")
      $tod = Get-Date -Format "MM-dd-yyyy"
      $newfile = $basenm + "-" + $tod + ".xml"

      $Script:org = $org;

      if ((Test-Path $FileIn)) { # input file exist?
        $doc = new-object "System.Xml.XmlDocument"
        $doc.Load($FileIn)

        if ($netcfgnm -match "restapi") {
          $doc.SelectNodes("//Array") | Where-Object {$_.Class -match "Symmetrix" -and $_.Org -match "EIT"} | Update-Symm-ArrayInfo1
        } else {
          $doc.SelectNodes("//Array") | Where-Object {$_.Class -match "Symmetrix" -and $_.Org -match "EIT"} | Update-Symm-ArrayInfo
        }

        $doc.SelectNodes("//Array") | Where-Object {$_.Class -match "Pure" -and $_.Org -match "EIT"} | Update-Pure-ArrayInfo

        # need to generate new xml file ArrayInfo-dd-mm-yyyy.xml
        $doc.Save($newfile);

        <# copy to share location
          Copy-Item $newfile -Destination $NetPath -Force | Out-Null
          Remove-PSDrive -name $cName | Out-Null
        #>

      } else {
        Write-Host "$FileIn not found" -ForegroundColor Red
      }

    #

  }

#