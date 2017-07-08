# Using
  using module .\Progress.psm1
#

# Module Declarations

  # Global/Private constants are available to all nested modules
  # These constants will be required by other nested modules & the Symm module
  New-Variable -Name SGDir -Value "SGInfo"              -Option Constant -Scope Global -Visibility Private -Description "SG folder";
  New-Variable -Name FADir -Value "FAInfo"              -Option Constant -Scope Global -Visibility Private -Description "FA folder";
  New-Variable -Name MEDir -Value "MetInfo"             -Option Constant -Scope Global -Visibility Private -Description "Symm Metrics folder";
  New-Variable -Name SGPath -Value "$PWD\$Global:SGDir" -Option Constant -Scope Global -Visibility Private -Description "SG path";
  New-Variable -Name FAPath -Value "$PWD\$Global:FADir" -Option Constant -Scope Global -Visibility Private -Description "FA path";
  New-Variable -Name MEPath -Value "$PWD\$Global:MEDir" -Option Constant -Scope Global -Visibility Private -Description "Symm Metrics path";
  
  $Script:PureMetricsCSV	= "PureMetrics.csv";
  $Script:SymmMetricsCSV  = "SymmMetrics.csv";

  $Script:usr = $null;
  $Script:pw  = $null;
  $Script:org = $null;
  $Script:DomainName = $null;

  New-Variable -Name credExt -Value ".enc.xml" -Option Constant -Scope Script;

#

# Non-Exported Functions
  
  . $PSScriptRoot\Local\Set-Ignore-SelfSignedCerts.ps1
  . $PSScriptRoot\Local\Get-JSON-RequestBody.ps1
  . $PSScriptRoot\Local\ConvertSize.ps1
  . $PSScriptRoot\Local\Convert-UTC.ps1
  . $PSScriptRoot\Local\Export-PSCredentials.ps1
  . $PSScriptRoot\Local\Import-PSCredentials.ps1
  . $PSScriptRoot\Local\Get-ArrayInfoXML.ps1

  # XML Get Functions

    function Get-FA-SGPorts {
      # Get a list of port groups masked to a specific FA 
      param ([string]$dirport)

      $URI = "https://$userver/univmax/restapi/$Script:prv/symmetrix/" + "$Script:sidsn/portgroup?dir_port=" + $dirport;

      try {
        $resp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers2;
        return $resp
      }
      catch {
        Write-Host $_ -ForegroundColor Magenta
        Write-Host "URI: $URI" -ForegroundColor Yellow
        return $null
      }
    }

    function Get-MaskingView {
      param([string]$mv)
      
      try {
        $URI = "https://$userver/univmax/restapi/$Script:prv/symmetrix/" + 
          "$Script:sidsn/maskingview/" + $mv;
        $resp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers2;
        # return Masking view details.
        return $resp
      }
      catch {
        #Write-Host $_ -ForegroundColor Magenta
        #Write-Host "URI: $URI" -ForegroundColor Yellow
        #exit
      }

    }

    function Get-PGViews {
      param ([ProgressManager]$pm)
      
      begin { };

      process {
        $pg = $_
        
        $URI = "https://$userver/univmax/restapi/$Script:prv/symmetrix/" + "$Script:sidsn/maskingview?port_group_name=" + $pg;
        $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(3, "Getting view info for $pg"))
        
        try {
          $resp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers2;
        }
        catch {
          Write-Host $_ -ForegroundColor Magenta
          Write-Host "URI: $URI" -ForegroundColor Yellow
          return $null
        }
        
        $mviews = $resp.listMaskingViewResult.maskingViewId

        if ($mviews -ne $null) {
          $childv, $parentv = $mviews.Split(" ");
          if ($parentv -ne $null) { $childv = $parentv }  # ignore parent view & replace with child
        
          $vresp = Get-MaskingView $childv

          # Create a PSObject containing View info of port groups masked to a director port.
          $PGview = New-Object -typename PSObject
        
          $val = $vresp.getMaskingViewResult.maskingview.maskingViewId

          if ($val -ne $null) {
            $PGview | Add-Member -MemberType NoteProperty -Name "View" -Value $val
            $PGview | Add-Member -MemberType NoteProperty -Name "Initiator_ig" -Value $vresp.getMaskingViewResult.maskingview.hostId
            $PGview | Add-Member -MemberType NoteProperty -Name "Storage_sg" -Value $vresp.getMaskingViewResult.maskingview.storageGroupId
            $PGview | Add-Member -MemberType NoteProperty -Name "Port_pg" -Value $vresp.getMaskingViewResult.maskingview.portGroupID
        
            $Script:PGViews += $PGview;
          }

        } else {
          Write-Host "$pg is not in a masking view" 
        }
        
      }
      end { };
    }

    function Get-ArrayKeyInfo {
      param ([string]$userver)

      begin {$Script:ArrayKeys = @();}

      process {
        $Keys = New-Object -typename PSObject
        # $_ is System.Xml.XmlElement
        $Keys | Add-Member -MemberType NoteProperty -Name "sid" -Value $_.symmetrixId
        $sid = $_.symmetrixId
        if ($sid -ne $null) {  # filter out null responses typically for newly added arrays.
          $sutc = $_.firstAvailableDate
          # Convert to local time
          $sutc10 = $sutc.Substring(0,10);
          $Keys | Add-Member -MemberType NoteProperty -Name "start" -Value $sutc10
          $start = Convert-UTC $sutc10
          $Keys | Add-Member -MemberType NoteProperty -Name "localstart" -Value $start
          # Convert to local time
          $eutc = $_.lastAvailableDate
          $eutc10 = $eutc.Substring(0,10)
          $Keys | Add-Member -MemberType NoteProperty -Name "end" -Value $eutc10
          $end = Convert-UTC $eutc10
          $Keys | Add-Member -MemberType NoteProperty -Name "localend" -Value $end
          $Keys | Add-Member -MemberType NoteProperty -Name "uniserver" -Value $userver
          $Script:ArrayKeys += $Keys;
        }

      }

      end {}
    }

    function Get-FEKeyInfo {
      param ([string]$userver, [string]$sidsn)

      begin {$Script:FEKeys = @();}

      process {
        $Keys = New-Object -typename PSObject
        # $_ is System.Xml.XmlElement
        $Keys | Add-Member -MemberType NoteProperty -Name "sid" -Value $sidsn
        $Keys | Add-Member -MemberType NoteProperty -Name "fedir" -Value $_.directorID
        $sutc = $_.firstAvailableDate
        # Convert to local time
        $sutc10 = $sutc.Substring(0,10);
        $Keys | Add-Member -MemberType NoteProperty -Name "start" -Value $sutc10
        $start = Convert-UTC $sutc10
        $Keys | Add-Member -MemberType NoteProperty -Name "localstart" -Value $start
        # Convert to local time
        $eutc = $_.lastAvailableDate
        $eutc10 = $eutc.Substring(0,10)
        $Keys | Add-Member -MemberType NoteProperty -Name "end" -Value $eutc10
        $end = Convert-UTC $eutc10
        $Keys | Add-Member -MemberType NoteProperty -Name "localend" -Value $end
        $Keys | Add-Member -MemberType NoteProperty -Name "uniserver" -Value $userver
        $Script:FEKeys += $Keys;
      }

      end {}
    }

    function Get-SGKeyInfo {
      param ([string]$userver, [string]$sidsn)

      begin {$Script:SGKeys = @();}

      process {
        $Keys = New-Object -typename PSObject
        # $_ is System.Xml.XmlElement
        $Keys | Add-Member -MemberType NoteProperty -Name "sid" -Value $sidsn
        $Keys | Add-Member -MemberType NoteProperty -Name "StorageGroup" -Value $_.storageGroupID
        $sutc = $_.firstAvailableDate
        # Convert to local time
        $sutc10 = $sutc.Substring(0,10);
        $Keys | Add-Member -MemberType NoteProperty -Name "start" -Value $sutc10
        $start = Convert-UTC $sutc10
        $Keys | Add-Member -MemberType NoteProperty -Name "localstart" -Value $start
        # Convert to local time
        $eutc = $_.lastAvailableDate
        $eutc10 = $eutc.Substring(0,10)
        $Keys | Add-Member -MemberType NoteProperty -Name "end" -Value $eutc10
        $end = Convert-UTC $eutc10
        $Keys | Add-Member -MemberType NoteProperty -Name "localend" -Value $end
        $Keys | Add-Member -MemberType NoteProperty -Name "uniserver" -Value $userver
        $Script:SGKeys += $Keys;
      }

      end {}
    }

    function Get-Array-SN {
      param([string]$sid1)
      
      $URI = "https://$userver/univmax/restapi/performance/Array/keys"
      Try {
        $resp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers
      }
      catch {
        Write-Host $_ -ForegroundColor Red
        Write-Host $URI -ForegroundColor Red
        return $null
      }

      if ($resp.gettype().name -eq "XmlDocument") {
        $resp.arrayKeyResult.arrayInfo | Get-ArrayKeyInfo $URIserver

        foreach ($vmax in $Script:ArrayKeys) {
          $sid = $vmax.sid
          $sid4 = $sid.Substring(8,4);
          if ($sid1 -eq $sid4) {
            return $sid
          }
        }

        Write-Host "Array $sid1 was not found" -ForegroundColor Red
        return $null

      } else {
        Write-Host "XML data not returned from: Get-Array-SN" -ForegroundColor Red
        Write-Host $URI -ForegroundColor Yellow
        return $null
      }
    }

    function Get-SG-CapInfo {
      param([string]$storageGroup)
      
      $URI = "https://$userver/univmax/restapi/$Script:prv/symmetrix/$Script:sidsn/storagegroup/$storageGroup"
      try {
        $resp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers2
      }
      Catch {
        Write-Host $_ -ForegroundColor Magenta
        Write-Host "URI: $URI" -ForegroundColor Yellow
        return $null
      }	
        
      $CapGB = $resp.getstorageGroupResult.storagegroup.cap_gb
      $Vols = $resp.getstorageGroupResult.storagegroup.num_of_vols
      
      $capmet = $CapGB + "_" + $Vols;
      return $capmet;
      
    }

    function Get-SGInfo {
      param([string]$sid4)

      begin { };

      process {
        # $_ is System.Xml.XmlElement
        $storageGroupID = $_.StorageGroupID
      
        ForEach ($storageGroup in $_.StorageGroupID) {
          $SGInfo = New-Object -typename PSObject
          $SGInfo | Add-Member -MemberType NoteProperty -Name "StorageGroup" -Value $storageGroup
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Sid" -Value $sid4
          
          $URI = "https://$userver/univmax/restapi/$Script:prv/symmetrix/$Script:sidsn/storagegroup/$storageGroup"
          $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Getting $storageGroup Metrics on $sid4"))

          try {
            $resp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers2
          }
          Catch {
            Write-Host $_ -ForegroundColor Magenta
            Write-Host "URI: $URI" -ForegroundColor Yellow
            return $null
          }

          $val = [Math]::Round($resp.getStorageGroupResult.storageGroup.cap_gb)
          $va6 = $val.ToString().PadLeft(6,'0');
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Size (GB)" -Value $va6;
          
          $val = $resp.getStorageGroupResult.storageGroup.num_of_vols
          $va4 = $val.ToString().PadLeft(4,'0');
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Vols" -Value $va4
          
          $SGInfo | Add-Member -MemberType NoteProperty -Name "View" -Value $resp.getStorageGroupResult.storageGroup.maskingview
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Views" -Value $resp.getStorageGroupResult.storageGroup.num_of_masking_views
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Type" -Value $resp.getStorageGroupResult.storageGroup.type
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Policy" -Value $resp.getStorageGroupResult.storageGroup.fast_policy_name
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Priority" -Value $resp.getStorageGroupResult.storageGroup.fast_policy_priority
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Parent" -Value $resp.getStorageGroupResult.storageGroup.num_of_parent_sgs
          $SGInfo | Add-Member -MemberType NoteProperty -Name "Child" -Value $resp.getStorageGroupResult.storageGroup.num_of_child_sgs
          $SGInfo | Add-Member -MemberType NoteProperty -Name "QoS-IOps" -Value $resp.getStorageGroupResult.storageGroup.hostIOLimit.host_io_limit_io_sec
          $SGInfo | Add-Member -MemberType NoteProperty -Name "QoS-MBps" -Value $resp.getStorageGroupResult.storageGroup.hostIOLimit.host_io_limit_mb_sec
          
          $Script:SGInfo += $SGInfo;
        }
      }

      end { };
    }

  #

  # Other XML Functions

    function Add-MetInfoPath {
      New-Item -Path $PWD\$Global:MEDir -ItemType Directory | Out-Null;

      $amXML  = $Global:MEPath + "\" + "ArrayMetrics.xml"
      $feXML  = $Global:MEPath + "\" + "FrontEnd.xml"
      $qdXML  = $Global:MEPath + "\" + "QDC-FrontEnd.xml"
      $sgXML  = $Global:MEPath + "\" + "SGPerformance.xml"
     
      Copy-Item -Path $PSScriptRoot\Data\ArrayMetrics.xml -Destination $amXML;
      Copy-Item -Path $PSScriptRoot\Data\FrontEnd.xml -Destination $feXML;
      Copy-Item -Path $PSScriptRoot\Data\QDC-FrontEnd.xml -Destination $qdXML;
      Copy-Item -Path $PSScriptRoot\Data\SGPerformance.xml -Destination $sgXML;

    }

    function Get-Keys-JSON {
      param ([string]$keytype)
      
      if ($sidr -eq "0000") {
        Write-Host "Must specify a SID value for $report report" -ForegroundColor Red;
        return $null
      } else {
        # Get the full symmetrix SN
        $Script:sidsn = Get-Array-SN $sidr
        $jsonBody = Get-JSON-RequestBody $Script:sidsn
      }

      $URI = "https://$userver/univmax/restapi/performance/" + "$keytype/keys"

      try {
        $resp = Invoke-RestMethod -Method Post -Uri $URI -Headers $Headers1 -Body $jsonBody;
        return $resp
      }
      catch {
        Write-Host $_ -ForegroundColor Magenta
        Write-Host "URI: $URI" -ForegroundColor Yellow
        return $null
      }
    }

    function Show-Metrics {

      begin {
        $ArrayMetrics = @();
      }

      process {

        $Met = New-Object -typename PSObject
        # $_ is System.Xml.XmlElement
        $ts = $_.timestamp
        $utc = $ts.Substring(0,10);
        $ts = Convert-UTC $utc;

        if ($report -match "Summary") {
          $Met | Add-Member -MemberType NoteProperty -Name "Array" -Value $Script:ArrayNam;
          $Met | Add-Member -MemberType NoteProperty -Name "Model" -Value $Script:ArrayMod;
        }

        $Met | Add-Member -MemberType NoteProperty -Name "Time Stamp" -Value $ts
        $iorate = [Math]::Round($_.HostIOs)
        $Met | Add-Member -MemberType NoteProperty -Name "IO (ps)" -Value $iorate
        $readrt = [Math]::Round($_.ReadResponseTime,1);
        $Met | Add-Member -MemberType NoteProperty -Name "Read RT (ms)" -Value $readrt
        $writert = [Math]::Round($_.WriteResponseTime,1);
        $Met | Add-Member -MemberType NoteProperty -Name "Write RT (ms)" -Value $writert
        $readps = [Math]::Round($_.HostMBReads)
        $Met | Add-Member -MemberType NoteProperty -Name "Reads (MB)" -Value $readps
        $writeps = [Math]::Round($_.HostMBWritten)
        $Met | Add-Member -MemberType NoteProperty -Name "Writes (MB)" -Value $writeps
        $readpct = [Math]::Round($_.PercentReads)
        $Met | Add-Member -MemberType NoteProperty -Name "READ %" -Value $readpct
        $hitpct = [Math]::Round($_.PercentHit)
        $Met | Add-Member -MemberType NoteProperty -Name "HIT %" -Value $hitpct
        $ArrayMetrics += $Met

      }

      end {
        if ($report -match "Summary") {
          $Script:SumMetrics += $ArrayMetrics[$ArrayMetrics.Length - 1];
        } else {
          return $ArrayMetrics
        }
      }

    }

    function Get-SGMetrics-Summary {
      param ([string]$sgID, [int]$count, [string]$sid4)

      begin { 
        $tsmax = "0";
        $IOmax = "0"; $IOsum = 0; $RIOmax = "0"; $RIOsum = 0; $WIOmax = "0";
        $MBmax = "0"; $MBsum = 0; $RMBmax = "0"; $RMBsum = 0; $WMBmax = "0"; $WMBsum = 0;
        $RTmax = "0"; $RTsum = 0; $RRTmax = "0"; $RRTsum = 0; $WRTmax = "0"; $WRTsum = 0;
        $RPmax = "0"; $RPsum = 0; $WPmax = "0"; $WPsum = 0;
        $IOSmax = "0"; $IOSsum = 0; $RSmax = "0"; $RSsum = 0; $WSmax = "0"; $WSsum = 0;
        $BSmax = "0"; $BSsum = 0; $XSTmax = "0"; $XSTsum = 0; $mSTmax = "0"; $MSTsum = 0;
      }

      process {
        
        if ($_."IO (ps)" -gt $IOmax) { $IOmax = $_."IO (ps)"; }  $IOsum += $_."IO (ps)";
        if ($_."Read IO (ps)" -gt $RIOmax) { $RIOmax = $_."Read IO (ps)"; }  $RIOsum += $_."Read IO (ps)";
        if ($_."Write IO (ps)" -gt $WIOmax) { $WIOmax = $_."Write IO (ps)"; }  $WIOsum += $_."Write IO (ps)";
        
        if ($_."MB (ps)" -gt $MBmax) { $MBmax = $_."MB (ps)"; }  $MBsum += $_."MB (ps)";
        if ($_."Read MB (ps)" -gt $RMBmax) { $RMBmax = $_."Read MB (ps)"; }  $RMBsum += $_."Read MB (ps)";
        if ($_."Write MB (ps)" -gt $WMBmax) { $WMBmax = $_."Write MB (ps)"; }  $WMBsum += $_."Write MB (ps)";
        
        if ($_."Response Time (ms)" -gt $RTmax) { $RTmax = $_."Response Time (ms)"; }  $RTsum += $_."Response Time (ms)";
        if ($_."ReadRT(ms)" -gt $RRTmax) { $RRTmax = $_."ReadRT(ms)"; }  $RRTsum += $_."ReadRT(ms)";
        if ($_."WriteRT(ms)" -gt $WRTmax) { $WRTmax = $_."WriteRT(ms)"; }  $WRTsum += $_."WriteRT(ms)";
        
        if ($_."Read %" -gt $RPmax) { $RPmax = $_."Read %"; }  $RPsum += $_."Read %";
        if ($_."Write %" -gt $WPmax) { $WPmax = $_."Write %"; }  $WPsum += $_."Write %";
        
        if ($_."AvgIOSize" -gt $IOSmax) { $IOSmax = $_."AvgIOSize"; }  $IOSsum += $_."AvgIOSize";
        if ($_."AvgReadSize" -gt $RSmax) { $RSmax = $_."AvgReadSize"; }  $RSsum += $_."AvgReadSize";
        if ($_."AvgWriteSize" -gt $WSmax) { $WSmax = $_."AvgWriteSize"; }  $WSsum += $_."AvgWriteSize";
        <#
          if ($_."BlockSize" -gt $BSmax) { $BSmax = $_."BlockSize"; }  $BSsum += $_."BlockSize";
          if ($_."MaxIOServiceTime" -gt $XSTmax) { $XSTmax = $_."MaxIOServiceTime"; }  $XSTsum += $_."MaxIOServiceTime";
          if ($_."MinIOServiceTime" -gt $mSTmax) { $mSTmax = $_."MinIOServiceTime"; }  $mSTsum += $_."MinIOServiceTime";
        #>

      }

      end {

        $Sum = New-Object -typename PSObject;
        
        $Sum | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value $_.timestamp
        $Sum | Add-Member -MemberType NoteProperty -Name "VMAX" -Value $sid4
        $Sum | Add-Member -MemberType NoteProperty -Name "SG" -Value $sgID
        #$va6 = $val.ToString().PadLeft(6,'0');
          
        $IOavg = [Math]::Round(($IOsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "IO Max (ps)" -Value $IOmax
        $Sum | Add-Member -MemberType NoteProperty -Name "IO Avg (ps)" -Value $IOavg
        
        
        $RIOavg = [Math]::Round(($RIOsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "Read IO Max(ps)" -Value $RIOmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Read IO Avg(ps)" -Value $RIOavg
          
        $WIOavg = [Math]::Round(($WIOsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "Write IO Max(ps)" -Value $WIOmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Write IO Avg(ps)" -Value $WIOavg
        
        $MBavg = [Math]::Round(($MBsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "MB Max(ps)" -Value $MBmax
        $Sum | Add-Member -MemberType NoteProperty -Name "MB Avg(ps)" -Value $MBavg
          
        $RMBavg = [Math]::Round(($RMBsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "Read MB Max(ps)" -Value $RMBmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Read MB Avg(ps)" -Value $RMBavg
          
        $WMBavg = [Math]::Round(($WMBsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "Write MB Max(ps)" -Value $WMBmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Write MB Min(ps)" -Value $WMBavg
          
        $RTavg = [Math]::Round(($RTsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "Response Time Max(ms)" -Value $RTmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Response Time Avg(ms)" -Value $RTavg
        
          
        $RRTavg = [Math]::Round(($RTsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "Read RT Max(ms)" -Value $RRTmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Read RT Avg(ms)" -Value $RRTavg
          
        $WRTavg = [Math]::Round(($WRTsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "Write RT Max(ms)" -Value $WRTmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Write RT Avg(ms)" -Value $WRTavg
          
        $RPavg = [Math]::Round(($RPsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "Read Max%" -Value $RPmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Read Avg%" -Value $RPavg
          
        $WPavg = [Math]::Round(($WPsum / $count),1);
        $va8 = "$WPmax / $WPAvg"
        $Sum | Add-Member -MemberType NoteProperty -Name "Write Max%" -Value $WPmax
        $Sum | Add-Member -MemberType NoteProperty -Name "Write Avg%" -Value $WPavg
          
        $IOSavg = [Math]::Round(($IOSsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "AvgIOSize Max" -Value $IOSmax
        $Sum | Add-Member -MemberType NoteProperty -Name "AvgIOSize Avg" -Value $IOSavg
          
        $RSavg = [Math]::Round(($RSsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "AvgReadSize Max" -Value $RSmax
        $Sum | Add-Member -MemberType NoteProperty -Name "AvgReadSize Avg" -Value $RSavg
          
        $WSavg = [Math]::Round(($WSsum / $count),1);
        $Sum | Add-Member -MemberType NoteProperty -Name "AvgWriteSize Max" -Value $WSmax
        $Sum | Add-Member -MemberType NoteProperty -Name "AvgWriteSize Avg" -Value $WSavg
          
        <#		
            $BSavg = [Math]::Round(($BSsum / $count),1);
            $va8 = "$BSmax / $BSAvg"
            $Sum | Add-Member -MemberType NoteProperty -Name "BlockSize" -Value $va8
            
            $XSTavg = [Math]::Round(($XSTsum / $count),1);
            $va8 = "$XSTmax / $XSTAvg"
            $Sum | Add-Member -MemberType NoteProperty -Name "MaxIOServiceTime" -Value $va8
              
            $mSTavg = [Math]::Round(($mSTsum / $count),1);
            $va8 = "$mSTmax / $mSTAvg"
            $Sum | Add-Member -MemberType NoteProperty -Name "MinIOServiceTime" -Value $va8
        #>
          
        if ($csv) {
          $capmet = Get-SG-CapInfo $sgID
          $CapGB, $Vols = $capmet.Split("_");
          
          $va6 = [Math]::Round($CapGB,1)
          $Sum | Add-Member -MemberType NoteProperty -Name "Capacity (gb)" -Value $va6
          
          $va6 = [Math]::Round($Vols,1)
          $Sum | Add-Member -MemberType NoteProperty -Name "Volumes" -Value $va6
        }
        if ($csv) { $Script:SGMetSum += $Sum }
        if ($con) { return $Sum };
      }
    }

    function Submit-StorageGroupsFA {
      param ([Object]$resp, [string]$sidsn, [string]$dirport, [ProgressManager]$pm)
      
      $resp.storageGroupKeyResult.storageGroupInfo[0] | Get-SGKeyInfo $URIserver $sidsn
      
      foreach ($sg in $Script:SGKeys) { # only one entry in array
        $sid = $sg.sid
        $sid4 = $sidsn.Substring(8,4);
        
        $localstart = $sg.localstart; $start = $sg.start
        $localend   = $sg.localend;   $end   = $sg.end
        $uniserver  = $sg.uniserver;
          
        if ($Script:noluv) {
          $Script:noluv = $false;
          if ($con) {
            Write-Host "VMAX: $sid4 on Unisphere Server $uniserver" -ForegroundColor Blue
            Write-Host "  Performance Data Range" -ForegroundColor Yellow
            Write-Host "  	Start: $localstart (UTC:$start)" -ForegroundColor Yellow
            Write-Host "          End: $localend (UTC:$end)" -ForegroundColor Yellow
          } else {
            $title = "$report for $sid4 on $UNIserver_NODOM"
          }
        }
          
        #Load Metrics XML file for request content
          if (!(Test-Path $Global:MEPath)) { Add-MetInfoPath }
        
          $xmlFile = $Global:MEPath + "\" + "SGPerformance.xml"
          #$metFile  = Get-ChildItem -Path $Global:MEPath | Where-Object {$_.PSChildName -eq $xmlFile}
          if (Test-Path $xmlFile) {
            $metXML = new-object "System.Xml.XmlDocument"
            $metXML.Load($xmlFile);
          } else {
            Write-Host "Metrics file not found, $xmlFile - Submit-StorageGroupsFA" -ForegroundColor Red
            break
          }
        #

        [int]$iend = $end;
        $iend -= $secs; # Getting past time of performance
        [string]$start = $iend;
        $start += "000";
        $end += "000";
          
        # Update Metrics XML with current parameter values for this Storage Group.
        $metXML.storageGroupParam.startdate   = $start;
        $metXML.storageGroupParam.enddate     = $end;
        $metXML.storageGroupParam.symmetrixId = $sid;

        ForEach ($mv in $Script:PGViews) {
          $sgId = $mv.Storage_sg
          $metXML.storageGroupParam.storageGroupId  = $sgId;
          #$metXML.Save($metFile);
          
          $userver = $uniserver + $URIport;
          $URI = "https://$userver/univmax/restapi/performance/StorageGroup/metrics"
          $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(4, "Getting Storage Group Metrics for $sgId"))

          try {
            $metResp = Invoke-RestMethod -Method Post -Uri $URI -Headers $Headers -Body $metXML;
          }
          catch {
            Write-Host $_ -ForegroundColor Red
            Write-Host $URI "@ At line 614" -ForegroundColor Red
            return $null
          }
          
          $count = $metResp.iterator.count
          $metResp.iterator.resultList.result | Get-SGMetricsObj $sgId $count $dirport
        }
        
      }

    }

    function Get-FAPortsObj {
      begin {}

      process {
        $Met = New-Object -typename PSObject
        # $_ is System.Xml.XmlElement
        $Met | Add-Member -MemberType NoteProperty -Name "FADir" -Value $_.directorId
        $Met | Add-Member -MemberType NoteProperty -Name "FAPort" -Value $_.portID
        $Script:FAPorts += $Met
      }

      end {}
    }

    function Get-FAMetricsObj {
      param ([string]$fedir, [int]$count)

      begin {[int]$idx = 0;}

      process {
        $idx += 1;
        if ($count -eq 0 -or $idx -eq $count) {
          $Met = New-Object -typename PSObject
          # $_ is System.Xml.XmlElement
          #$_ | Get-Member | Out-Host
          #Read-Host "waiting"
          $ts = $_.timestamp
          $utc = $ts.Substring(0,10);
          $ts = Convert-UTC $utc;
          $Met | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value $ts
          $Met | Add-Member -MemberType NoteProperty -Name "FADir" -Value $fedir
          $percentbusy = [Math]::Round($_.PercentBusy)
          $Met | Add-Member -MemberType NoteProperty -Name "Busy %" -Value $percentbusy
          $iorate = [Math]::Round($_.HostIOs)
          $Met | Add-Member -MemberType NoteProperty -Name "IO (ps)" -Value $iorate
          $readrt = [Math]::Round($_.ReadResponseTime,1);
          $Met | Add-Member -MemberType NoteProperty -Name "Read (ms)" -Value $readrt
          $writert = [Math]::Round($_.WriteResponseTime,1);
          $Met | Add-Member -MemberType NoteProperty -Name "Write (ms)" -Value $readrt
          $mbps = [Math]::Round($_.HostMBs)
          $Met | Add-Member -MemberType NoteProperty -Name "MB (ps)" -Value $mbps
          $qdu = [Math]::Round($_.QueueDepthUtilization)
          $Met | Add-Member -MemberType NoteProperty -Name "QDU" -Value $qdu
          
          $Script:FAMetrics += $Met
        }
      }

      end {}
    }

    function Get-QDCMetricsObj {
      param ([string]$sid4, [string]$fedir, [int]$count)

      begin {[int]$idx = 0;}

      process {
        $idx += 1;
        #if ($count -eq 0 -or $idx -eq $count) {
          $Met = New-Object -typename PSObject
          # $_ is System.Xml.XmlElement
          $ts = $_.timestamp
          $utc = $ts.Substring(0,10);
          $ts = Convert-UTC $utc;
          
          $Met | Add-Member -MemberType NoteProperty -Name "Array" -Value $sid4
          $Met | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value $ts
          $Met | Add-Member -MemberType NoteProperty -Name "FADir" -Value $fedir
          $val = [Math]::Round($_.QueueDepthUtilization,1);
          $Met | Add-Member -MemberType NoteProperty -Name "QDU%" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_9,1);
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-9" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_8,1)
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-8" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_7,1)
            $Met | Add-Member -MemberType NoteProperty -Name "QDC-7" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-6" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_5,1)
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-5" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_4,1)
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-4" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_3,1)
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-3" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_2,1)
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-2" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_1,1)
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-1" -Value $val
          $val = [Math]::Round($_.QUEUE_DEPTH_COUNT_RANGE_0,1)
          $Met | Add-Member -MemberType NoteProperty -Name "QDC-0" -Value $val
          
          $Script:QDCMetrics += $Met
        #}
      }

      end {}
    }

    function Get-SysCallMetricsObj {
      param ([string]$fedir, [int]$count)

      begin {[int]$idx = 0;}

      process {
        $idx += 1;
        if ($count -eq 0 -or $idx -eq $count) {
          $Met = New-Object -typename PSObject
          # $_ is System.Xml.XmlElement
          $ts = $_.timestamp
          $utc = $ts.Substring(0,10);
          $ts = Convert-UTC $utc;
          $Met | Add-Member -MemberType NoteProperty -Name "Time Stamp" -Value $ts
          $Met | Add-Member -MemberType NoteProperty -Name "FA Dir" -Value $fedir
          $syscallcnt = [Math]::Round($_.SyscallCount)
          $Met | Add-Member -MemberType NoteProperty -Name "SysCalls" -Value $syscallcnt
          $syscallavg = [Math]::Round($_.AvgTimePerSyscall,2)
          $Met | Add-Member -MemberType NoteProperty -Name "Avg Time (ms)" -Value $syscallavg
          $syscallps = [Math]::Round($_.SYSCALL_COUNT_PER_SEC,1)
          $Met | Add-Member -MemberType NoteProperty -Name "SysCalls (ps)" -Value $syscallps
          $rdircnt = [Math]::Round($_.SyscallRemoteDirCounts,2);
            $Met | Add-Member -MemberType NoteProperty -Name "RDir Calls" -Value $rdircnt
          $rdirps = [Math]::Round($_.SYSCALL_REMOTE_DIR_COUNT_PER_SEC,2)
          $Met | Add-Member -MemberType NoteProperty -Name "RDir (ps)" -Value $rdirps			
          $rdfcnt = [Math]::Round($_.Syscall_RDF_DirCounts,2);
          $Met | Add-Member -MemberType NoteProperty -Name "RDF Calls" -Value $rdfcnt
          $rdfps = [Math]::Round($_.SYSCALL_RDF_DIR_COUNT_PER_SEC,2)
          $Met | Add-Member -MemberType NoteProperty -Name "RDF (ps)" -Value $rdfps	
          
          $Script:SysCallMetrics += $Met
        }
      }

      end {}
    }

    function Get-SGMetricsObj {
      param ([string]$sgID, [int]$count)

      begin {[int]$idx = 0;}

      process {	
          $idx += 1;
          #if ($count -eq 0 -or $idx -eq $count) { # to limit to specific interval
          $Met = New-Object -typename PSObject
          # $_ is System.Xml.XmlElement
          $ts = $_.timestamp
          $utc = $ts.Substring(0,10);
          $ts = Convert-UTC $utc;
          $Met | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value $ts
          $Met | Add-Member -MemberType NoteProperty -Name "SG" -Value $sgID
          if ($dirport -ne $null) {
            $Met | Add-Member -MemberType NoteProperty -Name "DirPort" -Value $dirport
          }
          #$va6 = $val.ToString().PadLeft(6,'0');
          $va6 = $_.HostIOs; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "IO (ps)" -Value $va6
          $va6 = $_.HostReads; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "Read IO (ps)" -Value $va6
          $va6 = $_.HostWrites; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "Write IO (ps)" -Value $va6
          $va6 = $_.HostMBs; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "MB (ps)" -Value $va6;
          $va6 = $_.HostMBReads; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "Read MB (ps)" -Value $va6
          $va6 = $_.HostMBWritten; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "Write MB (ps)" -Value $va6
          $va6 = $_.ResponseTime; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "Response Time (ms)" -Value $va6
          $va6 = $_.ReadResponseTime; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "ReadRT(ms)" -Value $va6
          $va6 = $_.WriteResponseTime; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "WriteRT(ms)" -Value $va6
          $va6 = $_.PercentRead; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "Read %" -Value $va6
          $va6 = $_.PercentWrite; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "Write %" -Value $va6
          $va6 = $_.AvgIOSize; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "AvgIOSize" -Value $va6
          $va6 = $_.AvgReadSize; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "AvgReadSize" -Value $va6
          $va6 = $_.AvgWriteSize; $va6 = [Math]::Round($va6,1)
          $Met | Add-Member -MemberType NoteProperty -Name "AvgWriteSize" -Value $va6
          <#		
            $va6 = $_.BlockSize; $va6 = [Math]::Round($va6,1)
            $Met | Add-Member -MemberType NoteProperty -Name "BlockSize" -Value $va6
            $va6 = $_.MaxIOServiceTime; $va6 = [Math]::Round($va6,1)
            $Met | Add-Member -MemberType NoteProperty -Name "MaxIOServiceTime" -Value $va6
            $va6 = $_.MinIOServiceTime; $va6 = [Math]::Round($va6,1)
            $Met | Add-Member -MemberType NoteProperty -Name "MinIOServiceTime" -Value $va6
          #>
          
          if ($csv) {
            $capmet = Get-SG-CapInfo $sgID
            $CapGB, $Vols = $capmet.Split("_");
          
            $va6 = [Math]::Round($CapGB,1)
            $Met | Add-Member -MemberType NoteProperty -Name "CapGB" -Value $va6
          
            $va6 = [Math]::Round($Vols,1)
            $Met | Add-Member -MemberType NoteProperty -Name "Volumes" -Value $va6
          }
          
          $Script:SGMetrics += $Met
          #}
      }
      
      end {}
    }

    function Show-ArrayMetrics {
      param ([Object]$resp)
        
      $resp.arrayKeyResult.arrayInfo | Get-ArrayKeyInfo $URIserver
      foreach ($vmax in $Script:ArrayKeys) {
        $sid = $vmax.sid
        $sid4 = $sid.Substring(8,4);
        if ($sidr -eq "0000" -or $sidr -eq $sid4) {
          $Script:noluv = $false;
          $localstart = $vmax.localstart; $start = $vmax.start;
          $localend   = $vmax.localend;   $end   = $vmax.end;
          $uniserver  = $vmax.uniserver;
          
          if ($con -and $report -ne "Summary") {
            Write-Host "VMAX: $sid on Unisphere Server $uniserver" -ForegroundColor Blue
            Write-Host "  Performance Data Range" -ForegroundColor Yellow
            Write-Host "  	Start: $localstart (UTC:$start)" -ForegroundColor Yellow
            Write-Host "          End: $localend (UTC:$end)" -ForegroundColor Yellow
          } elseif ($report -eq "Summary") {
            #Write-Host "  Summary $sid" -ForegroundColor Blue
          } else {
            $title = "$report for $sid4 on $UNIserver_NODOM"
          }
          
          #Load Metrics XML file for request content
            if (!(Test-Path $Global:MEPath)) { Add-MetInfoPath }

            if ($report -match "Summary") {
              $xmlFile = $Global:MEPath + "\" + "ArrayMetrics.xml"
            } else { $xmlFile =  $Global:MEPath + "\" + $report + ".xml";}

            # $metFile  = Get-ChildItem | Where-Object {$_.PSChildName -eq $xmlFile}
          #
          
          if (Test-Path $xmlFile) {
            $metXML = new-object "System.Xml.XmlDocument"
            $metXML.Load($xmlFile);
          } else {
            Write-Host "Metrics file not found, $xmlFile" -ForegroundColor Red
            break
          }
          
          [int]$iend = $end; $iend -= $secs; # Getting past hour of performance
          [string]$newstart = $iend;
          $newstart += "000";
          $end += "000";
          
          # Update Metrics XML with current parameter values.
            $metXML.arrayParam.startdate   = $newstart;
            $metXML.arrayParam.enddate     = $end;
            $metXML.arrayParam.symmetrixId = $sid;
            #$metXML.Save($metFile);
          #

          $userver = $uniserver + $URIport;
          $URI = "https://$userver/univmax/restapi/performance/Array/metrics"
          $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(5, "Getting metrics for $sid"))

          $metResp = Invoke-RestMethod -Method Post -Uri $URI -Headers $Headers -Body $metXML;

          if ($metResp.gettype().name -eq "XmlDocument") {
            if ($con -and $report -ne "Summary") {
              $metResp.iterator.resultList.result | show-metrics | Format-Table -AutoSize
            } elseif ($report -eq "Summary") {
              $metResp.iterator.resultList.result | show-metrics
            } else {
              $metResp.iterator.resultList.result | show-metrics | Out-GridView -Title $title
            }
          } else {
            Write-Host "Metrics data not returned";
          }
        }
      }
    }

    function Show-FAPerformance {
      param ([string]$director)

      $sid4 = $Script:sidsn.Substring(8,4);

      if (!($con)) {
        Write-Host "Generating SG Performance Report VMAX $sid4 on $director ..." -ForegroundColor Green
      }
      $Script:PGViews = @();
      $Script:FAPorts = @();
      $Script:SGMetrics = @();

      # Get a list of portIDs for the director.
      $URI = "https://$userver/univmax/restapi/$Script:prv/symmetrix/$Script:sidsn/director/$director/port?aclx=true&port_status=ON"
      
      [long]$totalTasks = 64;
      $pm = [ProgressManager]::new("Getting list of portIDs for the director, $director", "$URI ", $totalTasks)

      try {
        $resp = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers2
      }
      Catch {
        Write-Host $_ -ForegroundColor Magenta
        Write-Host "URI: $URI" -ForegroundColor Yellow
        return $null
      }

      $success = $resp.listPortResult.success
      $message = $resp.listPortResult.message
      
      if (($success -match "true") -and ($message -ne "No Ports Found")) {
        $resp.listPortResult.symmetrixPortKey | Get-FAPortsObj;
        ForEach ($fap in $Script:FAPorts) {
          $dirport = $director + ":" + $fap.FAPort;
          
          # Get a list of port groups masked to a specific FA
          $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(2, "Getting Port Groups masked to $dirport"))

          $pgresp = Get-FA-SGPorts $dirport;
          $success = $pgresp.listPortGroupResult.success
          $message = $pgresp.listPortGroupResult.message
          if (($success -match "true") -and ($message -ne "No Port Groups Found")) {
            #$prresp | Format-Table -AutoSize

            # Get provisioning groups for each port group
            $pgresp.listPortGroupResult.portGroupId | Get-PGViews $pm;

            # Get Storage Group performance keys.
            $response = Get-Keys-JSON "StorageGroup";

            # Build $Script:SGMetrics PSObject
            Submit-StorageGroupsFA $response $Script:sidsn $dirport $pm;
          }
        }
      } else {
        Write-Host "Unable to obtain a list of portID(s) for $director $message" -ForegroundColor Red
        return $null
      }

      $PSCmdlet.WriteProgress($pm.GetCompletedRecord());
      
      if ($con) {
        $Script:SGMetrics | Format-Table -AutoSize
      } else {
        $grpcount = $Script:PGviews.length
        $title = "Total of ($grpcount) Storage Groups Performance for $sid4 on $URIserver";
        $Script:SGMetrics | Sort-Object TimeStamp | Out-GridView -Title $title
      }

    }

    function Get-FEDirector {
      param ([Object]$resp, [string]$sidsn)

      $Script:FAMetrics = @();
      $Script:QDCMetrics = @();
      $Script:SysCallMetrics = @();

      $FAid = $dir;
      if ($dir -ne "000") { $FAid = "FA-" + $dir.ToUpper() }

      [long]$totalTasks = 64;
      $pm = [ProgressManager]::new("Getting $report Metrics", " ", $totalTasks)
      $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Processing Metric Key info"))

      $resp.feDirectorKeyResult.feDirectorInfo | Get-FEKeyInfo $URIserver $sidsn
      $fekeycnt = $Script:FEKeys.Length;

      foreach ($fe in $Script:FEKeys) {
        $sid = $fe.sid
        $sid4 = $sid.Substring(8,4);
        if ($FAid -eq "000" -or $FAid -eq $fe.fedir) {
        
          $localstart = $fe.localstart; $start = $fe.start
          $localend   = $fe.localend;   $end   = $fe.end
          $uniserver  = $fe.uniserver;  $fedir = $fe.fedir
          
          if ($Script:noluv) {
            $Script:noluv = $false;
            if ($con) {
              Write-Host "VMAX: $sid4 on Unisphere Server $uniserver" -ForegroundColor Blue
              Write-Host "  Performance Data Range" -ForegroundColor Yellow
              Write-Host "  	Start: $localstart (UTC:$start)" -ForegroundColor Yellow
              Write-Host "          End: $localend (UTC:$end)" -ForegroundColor Yellow
            } else {
              $title = "$report for $sid4 on $UNIserver_NODOM"
            }
          }
          
          #Load Metrics XML file for request content
            if (!(Test-Path $Global:MEPath)) { Add-MetInfoPath }

            $xmlFile = $Global:MEPath + "\" + $report + ".xml"
            #$metFile  = Get-ChildItem -Path $Global:MEPath | Where-Object {$_.PSChildName -eq $xmlFile}
            if (Test-Path $xmlFile) {
              $metXML = new-object "System.Xml.XmlDocument"
              $metXML.Load($xmlFile);
            } else {
              Write-Host "Metrics file not found, $xmlFile - Get-FEDirector" -ForegroundColor Red
              break
            }

          #
          
          #if ($FAid -eq "000") { $secs = 600 };
          [int]$iend = $end;
          $iend -= $secs; # Getting past time of performance
          [string]$newstart = $iend;
          $newstart += "000";
          $end += "000";
          
          # Update Metrics XML with current parameter values for this FA Director.
          $metXML.feDirectorParam.startdate   = $newstart;
          $metXML.feDirectorParam.enddate     = $end;
          $metXML.feDirectorParam.symmetrixId = $sid;
          $metXML.feDirectorParam.directorId  = $fedir
          #$metXML.Save($metFile);
          
          $userver = $uniserver + $URIport;
          $URI = "https://$userver/univmax/restapi/performance/FEDirector/metrics"
          $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord($totalTasks, "Getting $report Director $fedir Metrics on $sid"));

          try {
            $metResp = Invoke-RestMethod -Method Post -Uri $URI -Headers $Headers -Body $metXML;
          }
          catch {
            Write-Host $_ -ForegroundColor Red
            Write-Host $URI -ForegroundColor Red
            return $null
          }
          
          # if $FAid -eq "000" then report on last metric data point returned for each FA
          # else report on all metric instances for a specific FA request.
          
          [int]$count = 0;
          if ($FAid -eq "000") { $count = $metResp.iterator.count };
          switch ($report) {
            "FrontEnd" {
              $metResp.iterator.resultList.result | Get-FAMetricsObj $fedir $count
            }
            "QDC-FrontEnd" {
              $metResp.iterator.resultList.result | Get-QDCMetricsObj $sid4 $fedir $count
            }
            "SysCall" {
              $metResp.iterator.resultList.result | Get-SysCallMetricsObj $fedir $count
            }
          }
        }
      }
      
      $PSCmdlet.WriteProgress($pm.GetCompletedRecord());

      switch ($report) {
        "FrontEnd" {
          if ($con) {
            $Script:FAMetrics | Format-Table -AutoSize
          } else {
            # Write-Host "Generating Front End report for $sid4 on $URIserver ..." -ForegroundColor Green;
            $title = "Front End Report for $sid4 on $URIserver";
            $selected_fa = $Script:FAMetrics | Out-GridView -OutputMode Single -Title $title
            if ($selected_fa -ne $null) {
              $FAid = $selected_fa.FADir
              Show-FAPerformance $FAid
            }
          }
        }
        "QDC-FrontEnd" {
          if (($con) -and (!($csv))) {
            $Script:QDCMetrics | Format-Table -AutoSize
          } elseif ($csv) {
            if (!(Test-Path $Global:FAPath)) { New-Item -Path $PWD\$Global:FADir -ItemType Directory | Out-Null; }
            $csvPath = $Global:FAPath + "\" + "QDC-Report.csv"
            $Script:QDCMetrics | Export-Csv -Path $csvPath -NoTypeInformation -Append
            Write-Host "QDC-Report for $sid4 appended to $csvPath" -ForegroundColor Green;
          } else {
            if (!(Test-Path $Global:FAPath)) { New-Item -Path $PWD\$Global:FADir -ItemType Directory | Out-Null; }
            # Write-Host "Generating Queue Depth Count report for $sid4 on $URIserver ..." -ForegroundColor Green;
            $title = "Queue Depth Count Report for $sid4 on $URIserver";
            $Script:QDCMetrics | Out-GridView -Title $title
            Write-Host "Create a QDC Report CSV file for $sid4 (Y or N)?:" -NoNewline -ForegroundColor Yellow
            [string]$createCSV = Read-Host;
            if ($createCSV -match "Y") {
              $csvPath = $Global:FAPath + "\" + "$sid4" + "-" + "QDC-Report" + ".csv"
              $Script:QDCMetrics | Export-Csv -Path $csvPath -NoTypeInformation
              Write-Host "$csvPath created" -ForegroundColor Green
            }
          }
        }
        "SysCall" {
          if ($con) {
            $Script:SysCallMetrics | Format-Table -AutoSize
          } else {
            $Script:SysCallMetrics | Out-GridView -Title $title
          }
        }
      }
    }

    function Get-StorageGroups {
      param ([Object]$resp, [string]$sidsn)

      $Script:SGMetrics = @();
      $sgId = $Script:sg;
      
      if ($sgId -eq "000") {
        $resp.storageGroupKeyResult.storageGroupInfo | Get-SGKeyInfo $URIserver $sidsn
      } else {
        $resp.storageGroupKeyResult.storageGroupInfo[0] | Get-SGKeyInfo $URIserver $sidsn
      }
      [int]$ctr = 0
      foreach ($sg in $Script:SGKeys) {
        $sid = $sg.sid
        $sid4 = $sidsn.Substring(8,4);
        $sgroup = $sg.StorageGroup

        if ($sgId -eq "000" -or $sgId -ne $null) {
        
          $localstart = $sg.localstart; $start = $sg.start
          $localend   = $sg.localend;   $end   = $sg.end
          $uniserver  = $sg.uniserver;
          
          if ($sgId -eq "000") {
            $psgId = $sgroup
            $Script:SGMetrics = @();
            $Script:SGMetSum = @();
          } else {
            $psgId = $sgId
          }
          
          if ($Script:noluv) {
            $Script:noluv = $false;
            if ($con) {
              Write-Host "VMAX: $sid4 on Unisphere Server $uniserver" -ForegroundColor Blue
              Write-Host "  Performance Data Range" -ForegroundColor Yellow
              Write-Host "  	Start: $localstart (UTC:$start)" -ForegroundColor Yellow
              Write-Host "          End: $localend (UTC:$end)" -ForegroundColor Yellow
            } else {
              $title = "$report for $sid4 on $UNIserver_NODOM"
            }
          }
          
          #Load Metrics XML file for request content
            if (!(Test-Path $Global:MEPath)) { Add-MetInfoPath }

            $xmlFile = $Global:MEPath + "\" + $report + ".xml"
            #$metFile  = Get-ChildItem -Path $Global:MEPath | Where-Object {$_.PSChildName -eq $xmlFile}

            if (Test-Path $xmlFile) {
              $metXML = new-object "System.Xml.XmlDocument"
              $metXML.Load($xmlFile);
            } else {
              Write-Host "Metrics file not found, $xmlFile Get-StorageGroups" -ForegroundColor Red
              break
            }
          #
          
          #if ($sgId -eq "000") { $secs = 600 };
          [int]$iend = $end;
          $iend -= $secs; # Getting past time of performance
          [string]$start = $iend;
          $start += "000";
          $end += "000";
          
          # Update Metrics XML with current parameter values for this Storage Group.
            $metXML.storageGroupParam.startdate   = $start;
            $metXML.storageGroupParam.enddate     = $end;
            $metXML.storageGroupParam.symmetrixId = $sid
            $metXML.storageGroupParam.storageGroupId  = $psgId
            #$metXML.Save($metFile);
          #

          $URI = "https://$userver/univmax/restapi/performance/StorageGroup/metrics"
          try {
            $metResp = Invoke-RestMethod -Method Post -Uri $URI -Headers $Headers -Body $metXML;
          }
          catch {
            Write-Host $_ -ForegroundColor Red
            Write-Host $URI "@ At Line 1147" -ForegroundColor Red
            return $null
          }
          
          $count = $metResp.iterator.count
          $metResp.iterator.resultList.result | Get-SGMetricsObj $psgId $count
          
          if (($con) -and (!($csv))) {
            $Script:SGMetrics | Format-Table -AutoSize
          } elseif ($csv) {
            if ($ctr -eq 0) {
              $csvPath = $Global:SGPath + "\" + "SG-Performance-Summary.csv"
              Write-Host "Generating $csvPath Report ..."  -ForegroundColor Green
            }
            $Script:SGMetSum = @();
            $Script:SGMetrics | Get-SGMetrics-Summary $psgId $count $sid4
            $Script:SGMetSum | Export-Csv -Path $csvPath -NoTypeInformation -Append
          } else {
            $title = "Storage Group Performance for $sid4 on $URIserver";
            $Script:SGMetrics | Out-GridView -Title $title

          }
        }
        $ctr++
      }
    }

    function Select-StorageGroup {
      param ([Object]$resp)
      
      $Script:SGInfo = @();
      $sid4 = $Script:sidsn.Substring(8,4);
      $resp.listStorageGroupResult | Get-SGInfo $sid4

    }

    function Convert-ArraysXml {
      begin {$Script:PSArrays = @();}

      process {
        $PSArray = New-Object -typename PSObject
        $PSArray | Add-Member -MemberType NoteProperty -Name "Data Center" -Value $_.DataCenter
        $PSArray | Add-Member -MemberType NoteProperty -Name "ORG" -Value $_.Org
        $PSArray | Add-Member -MemberType NoteProperty -Name "RestAPI" -Value $_.restapi
        $PSArray | Add-Member -MemberType NoteProperty -Name "Array" -Value $_.Name
        $PSArray | Add-Member -MemberType NoteProperty -Name "Sid" -Value $_.sid
        $PSArray | Add-Member -MemberType NoteProperty -Name "Model" -Value $_.Model
        $PSArray | Add-Member -MemberType NoteProperty -Name "Usage" -Value $_.usage
        $PSArray | Add-Member -MemberType NoteProperty -Name "SN" -Value $_.sn
        $Script:PSArrays += $PSArray
      }

      # return an array of storage arrays
      end { $Script:PSArrays }
    }

    function Get-Array-MD {
      param([string]$sid1)

      $AIFile = Get-ChildItem -Path $Global:AIPath |
        Where-Object {$_.PSChildName -like "ArrayInfo*.xml"} |
        Sort-object -property @{Expression={$_.LastWriteTime}; Ascending=$false}; 

      $FileIn = $Global:AIPath + "\" + $AIFile.PSChildName[0];

      $doc = new-object "System.Xml.XmlDocument"
      $doc.Load($FileIn)
      
      [int]$objcnt = 0;
      $URIserver, $sid = $null;
      $doc.SelectNodes("//Array") |
        Where-Object {$_.Sid -match $sid1 -and $_.Org -eq $org} |
        Convert-ArraysXml;
    }

    function Get-Arrays {
      
      begin { }

      process { 
        $ary		= $_;
        $Model	= $ary.Model;

        switch -Wildcard ($Model) {
          "VMAX*" { # Symmetrix arrays
            $Script:ArrayNam	= $ary.Name;
            $Script:ArrayMod	= $ary.Model;
            $URIserver 				= $ary.restapi;
            $UNIserver_NODOM	= $ary.restapi;
            $sid 							= $ary.Sid;
            $sidr 						= $ary.Sid;
            $Script:sidsn 		= $ary.sn;
            $Script:sidmd 		= $ary.Model;
            $URIserver 				+= ".$Script:DomainName";
            $userver   				= $URIserver + $URIport;

            if ($Script:sidmd -match "VMAX3") {
              $Script:prv = "sloprovisioning"
            } else {
              $Script:prv = "provisioning"
            }

            $URI = "https://$userver/univmax/restapi/performance/Array/keys"
            #Write-Host "Get-Arrays $Script:ArrayNam" -ForegroundColor white
            [bool]$noError = $true;

            [long]$totalTasks = 7;
            $pm = [ProgressManager]::new("Processing response from $URI", "Getting Array Metrics", $totalTasks)
            $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Executing Web Request"))
            
            try {
              $response = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers
            }
            Catch {
              Write-Host $_ -ForegroundColor Magenta
              Write-Host "URI: $URI" -ForegroundColor Yellow
              $noError = $false;
              #exit
            }

            if ($noError)	{ Show-ArrayMetrics $response };

          }
          
          "FA-m70*" { # Pure arrays
            $pureCSVFile = "$PWD" + "\" + $Script:org + "-" + $Script:PureMetricsCSV;
            if (Test-Path  $pureCSVFile) {
              $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Processing Pure Storage metrics"))
              $PureRec = Import-CSV -Path  $pureCSVFile |
                Where-Object { $_.Array -eq $ary.Name};
              $Script:SumMetrics += $PureRec;
            }
            
          }
          Default { }
        }

        $PSCmdlet.WriteProgress($pm.GetCompletedRecord());

      }

      end { }

    }

    function Get-Summary {
      $xmlDB = Get-ArrayInfoXML;
      #Write-Progress -Activity "Retrieving array metric data..." -Status "Please wait."

      $pm = [ProgressManager]::new("Processing response from $URI1", "Getting Game Results", $totalTasks)
      $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Executing Web Request"))
      
      if ($dc -ne $null) {
        $xmlDB.SelectNodes("//Array") |
          Where-Object {$_.DataCenter -match $dc -and $_.org -match $Script:org} |
          Get-Arrays
      } else { # this is the default
        $xmlDB.SelectNodes("//Array") |
          Where-Object { $_.org -match $Script:org } |
          Get-Arrays;
      }

      $Script:SumMetrics | Format-Table -AutoSize
      $metCSVfile = "$PWD" + "\" + $Script:org + "-" + $Script:SymmMetricsCSV;
      if (Test-Path $metCSVfile) { Remove-Item -Path $metCSVfile }
      $Script:SumMetrics | Export-CSV -Path $metCSVfile -Delimiter "," -Append -NoTypeInformation
      
      [int]$totalIOPS			= 0;
      [int]$totalRead			= 0;
      [int]$totalWritten	= 0;

      [int]$sz = $Script:SumMetrics.Length - 1;

      for ($i=0; $i -le $sz; $i++) {
        $totalIOPS	 	+= $Script:SumMetrics[$i]."IO (ps)"
        $totalRead		+= $Script:SumMetrics[$i]."Reads (MB)"
        $totalWritten	+= $Script:SumMetrics[$i]."Writes (MB)"			
      }
      if ($totalIOPS -gt $Script:highIOPS) { $Script:highIOPS = $totalIOPS};
      if ($totalIOPS -lt $Script:lowIOPS -or $Script:lowIOPS -eq 0) { $Script:lowIOPS = $totalIOPS};
      if ($totalRead -gt $Script:highRead) { $Script:highRead = $totalRead};
      if ($totalRead -lt $Script:lowRead -or $Script:lowRead -eq 0) { $Script:lowRead = $totalRead};
      if ($totalWritten -gt $Script:highWritten) { $Script:highWritten = $totalWritten};
      if ($totalWritten -lt $Script:lowWritten  -or $Script:lowWritten -eq 0) { $Script:lowWritten = $totalWritten};

      Write-Host "           Total IOPS: $totalIOPS            Reads (MB): $totalRead     Writes (MB): $totalWritten"  -ForegroundColor Green
      #Write-Progress -Activity "Completed" -Completed;

      if ($repeat) {
        $hiLowIOPS = "$Script:highIOPS" + "/" + "$Script:lowIOPS";
        $hiLowRead = "$Script:highRead" + "/" + "$Script:lowRead";
        $hiLowWrit = "$Script:highWritten" + "/" + "$Script:lowWritten";
        Write-Host "           High/Low:   $hiLowIOPS                 $hiLowRead            $hiLowWrit"  -ForegroundColor Yellow
      }
    }

    function Select-Unisphere {
      
      $AIFile = Get-ChildItem -Path $Global:AIPath |
        Where-Object {$_.PSChildName -like "ArrayInfo*.xml"} |
        Sort-object -property @{Expression={$_.LastWriteTime}; Ascending=$false}; 

      $FileIn = $Global:AIPath + "\" + $AIFile.PSChildName[0];

      $doc = new-object "System.Xml.XmlDocument"
      $doc.Load($FileIn)
      
      $title = "Select a RestAPI/Unisphere server & the desired storage arrays for the report";
      [int]$objcnt = 0;
      $URIserver, $sid = $null;
      $doc.SelectNodes("//Array") | Where-Object {$_.Model -match "VMAX"} |
        Convert-ArraysXml |
        Sort-Object "Data Center", Org, RestAPI, Sid |
        Out-GridView -Title $title -OutputMode Multiple |
        ForEach-Object {
          if ($objcnt -eq 0) {
            $URIserver = $_.restapi
            $sid = $_.Sid
            $sn = $_.sn
            $mod = $_.Model
          }
          $objcnt++;
        }
      
      if ($URIserver -eq $null) {
        Write-Host " selection cancelled" -ForegroundColor Red
        Write-Host "Thanks for trying! Bye" -ForegroundColor Blue
        return $null
      }
      
      if ($objcnt -gt 1) { # process all arrays on Unisphere server
        $sid = "0000"
      }
      $selection = $URIserver + "_" + $sid + "_" + $sn + "_" + $mod;
      return $selection
    }

    function Select-Report {

      $reports = @();
      $reports += [pscustomobject]@{Report="ArrayMetrics";
        Description = " Performance metrics for all or a specific Symmetrix on the Unisphere server"}
      $reports += [pscustomobject]@{Report="FrontEnd";
        Description = " Front End director performance metrics for a specific array and all or a specific director port"};
      $reports += [pscustomobject]@{Report="QDC-FrontEnd";
        Description = " Queue Depth Count for Front End director(s) for a specific array and all or a specific director port"};
      $reports += [pscustomobject]@{Report="SysCall";
        Description = " Array SysCall metrics"};
      $reports += [pscustomobject]@{Report="StorageGroup";
        Description = " Table of the Storage Groups and meta data for a symmetrix array"};
      $reports += [pscustomobject]@{Report="Summary";
        Description = "Symmetrix IO Performance Summary"};
      $reports += [pscustomobject]@{Report="SGPerformance";
        Description = " CLI ONLY: Storage Group Performance for named SG or All SGs on FA port"};

      $title = "Select a Symmetrix Performance Report"
      
      $selectA_report = $reports | Out-GridView -Title $title -OutputMode Single;
      
      if ($selectA_report -eq $null) {
        Write-Host " Selection Cancelled" -ForegroundColor Red
        Write-Host "Thanks for trying! Bye" -ForegroundColor Blue
        return "done"
      } else {
        return $selectA_report.report
      }

    }

    function Get-OrgCredentials {
      Param ([string]$borg)

      $xmlDB = Get-ArrayInfoXML;

      if ([string]::IsNullOrEmpty($borg)) { # org value from first record since none specified
        $unique = $xmlDB.SelectNodes("//Array") |
          Where-Object { $_.Model -match "VMAX"} |
          Select-Object -Property Org, username, domainname -Unique;
          $borg = $unique[0].Org
        
      } else {
        $unique = $xmlDB.SelectNodes("//Array") |
          Where-Object { $_.Model -match "VMAX" -and $_.Org -match $borg} |
          Select-Object -Property Org, username, domainname -Unique;
      }

      $Script:DomainName = $unique[0].domainname;

      $credBase = "-" + $borg + "-" + $env:COMPUTERNAME + $credExt;
      $Script:credfilename = $Global:CRPath + "\" + $unique[0].username + $credBase;

      if (!(Test-Path $Script:credfilename)) { # create cache credential
        Write-Host "Unisphere Credentials require for $borg Storage" -ForegroundColor Green
        Export-PSCredential $unique[0].username $credBase
        Start-Sleep 3;
      }

      $cred       = Import-PSCredential $Script:credfilename
      $Script:usr = $cred.UserName;
      $Script:pw  = $cred.GetNetworkCredential().Password;
      $Script:org = $borg;
      $rslt       = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Script:usr,$Script:pw)))

      return $rslt;
    }

  #
  
#

# Exported Functions

  <#
    .SYNOPSIS
      Reports on Symmetrix array performance data by executing
      RESTAPI calls to a specific Unisphere server.
      
    .DESCRIPTION
      Reports symmetrix array metrics. A table of existing arrays
      is presented for selection of the desired array for reporting.

    .PARAMETER URIserver
      Unisphere server name. The <domainname> tag in the XMLDB will be appended.
      Default "select" - A table of arrays will be presented for selection.
      
    .PARAMETER sidr
      Symmetrix 4-digit serial number.
      If not specified will report on all local arrays seen by the Unisphere server.
      
    .PARAMETER secs
      Default display last hour (3600 secs) of metric data points.
      Number of seconds specified limited to 5 digits.
      
    .PARAMETER report
      Default 'select' to present a table of reports for selection.
      
      ArrayMetrics    Displays performance metrics for all or a specific
                      Symmetrix array.
            
      FrontEnd        Displays front end director performance metrics
                      for a specific array and all or specific director.
            
      QDC-FrontEnd    Displays Front End Queue Depth Count metrics
                      for a specific array and all or specific director.
            
      SysCall         Displays front end syscall metrics.
      
      StorageGroup    Displays a list of storage groups on the selected array
                      along with storage group meta data.
            
      SGPerformance   Display Performance metrics for a specified storage group.
                      If the '-csv' option is used, then the metrics will be 
                      summarized for the specified time period and output to
                      a CSV file.

      Summary         Display a summary of the ArrayMetrics report for all
                      arrays or all arrays in a specific data center.
      
    .PARAMETER dir
      For FrontEnd, SysCall, and SGPerformance reports only.
      Specify a specific director value for the report.
      
    .PARAMETER sg
      Name of the Storage Group for Performance report.
      
    .PARAMETER con
      Output to the console rather than Out-Gridview.
      
    .PARAMETER csv
      For SGPerformance report. Output to summary csv file
      in the 'SGInfo' folder.

    .PARAMETER dc
      Specifics a data center name filter to be used with
      the Summary Report.

    .PARAMETER repeat
      Repeats the Summary report every 6 minutes.
      
    .INPUTS
      Each report requires a specific xml file to be present in the
      execution directory. The XMLDB file is named after the report name with
      an extension of .xml.
      
    .INPUTS
      ArrayInfo\ArrayInfo.xml
      Reads the file to present a table for selecting the desired symmetrix array.
      
    .INPUTS
      SGInfo\<sid>-StorageGroups.xml
      
      If the file's last write time is less that 8 hours old,
      it is imported to display the storage group information.
      
    .OUTPUTS
        Output defaults to Out-GridView unless the -con option
        is specified.
      
    .OUTPUTS
      SGInfo\<sid>.StorageGroups.xml
      
      Export of the Storage Group object in xml format.
      
    .OUTPUTS
      SGInfo\SG-Performance-Summary.csv
      
      When the csv option is used with the SGPerformance report.
      
    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01
      
      Displays metrics for all arrays configured on Unisphere server admassan45.

    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01 0700 7200
      
      Displays 2 hours metrics for VMAX 0700.

    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01 0700 -report FrontEnd

      Displays the latest metrics for all FE directors.
    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01 0700 -report FrontEnd -dir 1e

      Displays one hour of metrics for FE director 1E.
    
    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01 0700 -report SysCall
        
      Displays the latest syscall metrics for all FE directors.

    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01 0700 -sg hayesx401-408_sg -csv -secs 86400

      Output the a summary of a SG performance metrics for a specified period of time to a csv file.
      
    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01 0700 -report QDC-FrontEnd
      
      Displays the last hour of Queue Depth Count metrics for all
      directors on 1296 in the Out-Gridview format.

      A prompt is presented to save the report to a CSV file, if desired.

    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01 0700 -report QDC-FrontEnd -dir 15e -secs 7200
      
      Same as prior example but limit output to director 15e and extents
      the reporting window to 2 hours.

    .EXAMPLE
      Get-VeArrayMetrics sanmgmt01 0700 -report QDC-FrontEnd -csv -secs 43200
      
      Output is appended to the CSV file, QDC-Report.csv with QDC metrics for the last 12 hours.
      
      Use the following comand to reopen the CSV in the Out-Gridview.
      
      Import-CSV QDC-Report.csv | Out-GridView
      
      Or use Excel to open the csv file.
      
      All csv files are in the FAInfo folder.
  
    .EXAMPLE
      Get-VeArrayMetrics -report Summary

      Display the last available ArrayMetrics data points for all
      storage arrays in the environment.

      Get-VeArrayMetrics -report Summary -dc Polaris

      Same as the prior example but only for arrays in the
      Polaris data center.

      Get-VeArrayMetrics -report Summary -dc Polaris -repeat

      Same as prior examples, but Summary report is repeated
      every 6 minutes.

    .NOTES
      Author: Craig Dayton
      0.0.2.0  07/05/2017  cadayton: converted to Get-VeSymmMetrics cmdlet in the module, Venom
      0.0.1.5: 11/07/2016  cadayton: Fixed logic to support VMAX3 FrontEnd report.
      0.0.1.4: 11/02/2016  cadayton: Added Queue Depth Count Report with optional csv option
      0.0.1.3: 10/21/2016  cadayton: Added SGPerformance with optional csv option.
      0.0.1.2: 10/16/2016  cadayton: Added StorageGroup report
      0.0.1.1: 09/27/2016  cadayton: Added SysCall report
      0.0.1.0: 09/26/2016  cadayton: Added FrontEnd report

    .LINK
      https://github.com/cadayton/Venom

    .LINK
      http://venom.readthedocs.io

  #>

  function Get-VeSymmMetrics {

    # Get-VeArrayMetrics Params
	    [cmdletbinding()]
        Param (
          [Parameter(Position=0,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [ValidatePattern("^[a-zA-Z0-9]{3,30}")]
            [string]$URIserver = "select",
          [Parameter(Position=1,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [ValidatePattern("^[0-9]{4}$")]
            [string]$sidr = "0000",
          [Parameter(Position=2,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [ValidatePattern("^[0-9]{4,5}$")]
            [int]$secs = 3600,
          [Parameter(Position=3,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [ValidatePattern("^[a-zA-Z0-9]{3,30}")]
            [string]$report = "select",
          [Parameter(Position=4,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [ValidatePattern("^[d-hD-H0-9]{2,3}")]
            [string]$dir = "000",
          [Parameter(Position=5,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [string]$sg,
          [Parameter(Position=6,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [switch]$con,
          [Parameter(Position=7,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [switch]$csv,
          [Parameter(Position=8,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [string]$dc = $null,
          [Parameter(Position=9,
            Mandatory=$false,
            ValueFromPipeline=$true)]
            [string]$org = $null,
          [Parameter(Position=10,
            Mandatory=$False,
            ValueFromPipeline=$True)]
            [bool]$repeat = $true
        )

    #

    $EUP      = Get-OrgCredentials $org;
    $Headers  = @{'Authorization'="Basic $($EUP)";'Content-type'='application/xml';'Accept'='application/xml'}
    $Headers1 = @{'Authorization'="Basic $($EUP)";'Content-type'='application/json';'Accept'='application/xml'}
    $Headers2 = @{'Authorization'="Basic $($EUP)";'Accept'='application/xml'}

    # set requests, to use TLSv1.2 protocol
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
    # tell Windows to ignore self-signed certs
    Set-Ignore-SelfSignedCerts;

    $UNIserver_NODOM    = $URIserver;
    $URIport						= ":8443";
    $userver						= $URIserver + $URIport;
    [bool]$Script:noluv	= $true;
    $Script:sg					= $sg;
    $Script:SumMetrics	= @();

    if ($report -ne "Summary") {
      if ($URIserver -match "select") {
        $selection = Select-Unisphere
        if ([string]::IsNullOrEmpty($selection)) { return }
        $URIserver, $sidr, $Script:sidsn, $Script:sidmd = $selection.Split("_")
        $UNIserver_NODOM = $URIserver;
        $URIserver += ".$Script:DomainName";
        $userver   = $URIserver + $URIport;
      } else {
        $Script:sidsn = Get-Array-SN $sidr;
        Get-Array-MD $sidr | Out-Null
        $Script:sidmd = $Script:PSArrays[0].Model;
      }

      if ($Script:sidmd -match "VMAX3") {
        $Script:prv = "sloprovisioning"
      } else {
        $Script:prv = "provisioning"
      }

      if ($report -match "select") {
        $report = Select-Report
        if ($report -eq "done") { return }
      }
    }

    switch ($report) {
      "ArrayMetrics" {
        $URI = "https://$userver/univmax/restapi/performance/Array/keys"
        [long]$totalTasks = 2;
        $pm = [ProgressManager]::new("Processing response from $URI", "Getting Array Metrics", $totalTasks)
        $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Executing Web Request"))
        $response = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers
      }

      "FrontEnd" {
        $response = Get-Keys-JSON "FEDirector";
      }

      "QDC-FrontEnd" {
        $response = Get-Keys-JSON "FEDirector";
      }

      "SysCall" {
        $response = Get-Keys-JSON "FEDirector";
      }

      "StorageGroup" {
        $sid4 = $Script:sidsn.Substring(8,4);
        [string]$xmlSGFile = $Global:SGPath + "\" + $sid4 + "-StorageGroups.xml"
        [int]$mts = 0;

        if (Test-Path $xmlSGFile) {
          $csvFile = Get-ChildItem $xmlSGFile;
          $cts = $csvFile.LastWriteTime
          $nts = New-TimeSpan -Start (Get-Date) -End $cts
          # Number of minutes since LastWriteTime
          [int]$mts = (($nts.Days * 1440) + ($nts.Hours * 60) + ($nts.Minutes)) * -1;
        }
        
        if (($mts -gt 480) -or ($mts -eq 0)) { # older than 8 hours or doesn't exist
          $URI = "https://$userver/univmax/restapi/$Script:prv/symmetrix/$Script:sidsn/storagegroup"
          [long]$totalTasks = 2;
          $pm = [ProgressManager]::new("Getting Storage Groups on $Script:sidsn", " From $URI", $totalTasks)
          $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Getting Storage Groups on $Script:sidsn"))

          try {
            $response = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers2
          }
          Catch {
            Write-Host $_ -ForegroundColor Magenta
            Write-Host "URI: $URI" -ForegroundColor Yellow
            return $null
          }
        } else {
          $Script:SGinfo = Import-Clixml -Path $xmlSGFile
          $title = "VMAX $sid4 Storage Groups $cts";
          $selected_sg = $Script:SGinfo | Out-GridView -OutputMode Single -Title $title
          if ($selected_sg -ne $null) {
            $response = Get-Keys-JSON "StorageGroup";
            $Script:noluv = $false
            $Script:sg = $selected_sg.StorageGroup;
            $report = "SGPerformance";
            Get-StorageGroups $response $Script:sidsn
          }
          return $null
        }
      }

      "SGPerformance" {
        if ($Script:sg -ne "") {
          $response = Get-Keys-JSON "StorageGroup";
        } elseif ($dir -ne "000") {
          $FAid = $dir;
          $FAid = "FA-" + $dir.ToUpper();
          Show-FAPerformance $FAid
          return $null
        } else {
          Write-Host "SGPerformance report is only available from the CLI" -ForegroundColor Green
          Write-Host "Get-VeSymmMetrics $UNIserver_NODOM $sidr -report SGPerformance -sg <Storage group name>" -ForegroundColor Yellow
          Write-Host "Get-VeSymmMetrics $UNIserver_NODOM $sidr -report SGPerformance -dir <Director ID>" -ForegroundColor Yellow
          Write-Host "Output Options:"
          Write-Host "   -con output to console"
          Write-Host "   -csv output to CSV "
          Write-Host "   default output is Out-Gridview"
          return $null
        }
      }

      "Summary" {
        [int]$Script:highIOPS			= 0;
        [int]$Script:lowIOPS			= 0;
        [int]$Script:highRead			= 0;
        [int]$Script:lowRead			= 0;
        [int]$Script:highWritten	= 0;
        [int]$Script:lowWritten		= 0;
        Get-Summary;

        if ($repeat) {
          $StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
          $StopWatch.Start()
          $ticker = $null;
          try {
            While ($repeat) {
              if ($ticker -eq $null) {
                Write-Host " ";
                Write-Host "Refresh in 6 minutes " -NoNewLine -ForegroundColor Yellow
                Write-Host "  Ctrl-C to exit"
              }
              $ticker = $StopWatch.Elapsed.ToString();
              <#
                $curPos = $host.UI.RawUI.CursorPosition
                $y = $curPos.Y - 1;
                #$curPos.X = 2; 
                $curPos.Y = $y;
                $host.UI.RawUI.CursorPosition = $curPos
              #>
              Start-Sleep -Seconds 10;
              if ($StopWatch.Elapsed.minutes -ge 6) {
                Clear-Host;
                $Script:SumMetrics = @();
                Get-Summary;
                $StopWatch.ReStart();
                $ticker = $null;
              }
            }
          }
          catch { }
          finally {
            #Write-Host "Performing clean up work"
            $StopWatch.Stop();
          }
        }
        return $null
      }

      Default {
        Write-Host "Report logic not defined for $report" -ForegroundColor Red
      }
    }

    if ($response.gettype().name -eq "XmlDocument") {
      # System.Object being piped to a function for processing
      switch ($report) {
        "ArrayMetrics" {
          Show-ArrayMetrics $response
          $PSCmdlet.WriteProgress($pm.GetCompletedRecord());
        }
        "FrontEnd" {
          Get-FEDirector $response $Script:sidsn
        }
        "QDC-FrontEnd" {
          if ($secs -gt "3600") {
            Write-Host "Generating Queue Depth Count report greater than 3600 secs" -ForegroundColor Green
            Write-Host "can take some time to process, so be patience." -ForegroundColor Green
          }
          Get-FEDirector $response $Script:sidsn
        }
        "SysCall" {
          Get-FEDirector $response $Script:sidsn
        }
        "StorageGroup" {
          $Script:noluv = $false
          Select-StorageGroup $response
          $sid4 = $Script:sidsn.Substring(8,4)
          if (!(Test-Path $Global:SGPath)) { New-Item -Path $PWD\$Global:SGDir -ItemType Directory | Out-Null; }
          $xmlSGInfo = $Global:SGPath + "\" + $sid4 + "-StorageGroups.xml"
          $Script:SGInfo | Export-Clixml -Path $xmlSGInfo

          $PSCmdlet.WriteProgress($pm.GetCompletedRecord());

          $td = Get-Date;
          $title = "VMAX $sid4 Storage Groups $td"
          $selected_sg = $Script:SGInfo | Out-GridView -OutputMode Single -Title $title
          if ($selected_sg -ne $null) {
            $response = Get-Keys-JSON "StorageGroup";
            $Script:noluv = $false
            $Script:sg = $selected_sg.StorageGroup;
            $report = "SGPerformance";
            Get-StorageGroups $response $Script:sidsn
          }
          
        }
        "SGPerformance" {
          #$Script:noluv = $false
          Get-StorageGroups $response $Script:sidsn
        }
        Default {
          $Script:noluv = $false
          Write-Host "Report logic not defined for $report" -ForegroundColor Red
        }
      }

      if ($Script:noluv) {
        Write-Host "VMAX $sidr not found on $URIserver" -ForegroundColor Red
      }
    } else {
      Write-Host "XML data not returned from:" -ForegroundColor Red
      Write-Host $URI -ForegroundColor Yellow
    }
  }

#