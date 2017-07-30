# Using
  using module .\Progress.psm1
#

# Module Declarations

	$FEHeader = @("Host","Date","Time","Zone","Initiator-WWN","Target","Target-WWN","IOps","Relative-IO");
	$Script:PureMetricsCSV	= "PureMetrics.csv";

#

# Non-Exported Functions

	. $PSScriptRoot\Local\Get-ArrayInfoXML.ps1
	. $PSScriptRoot\Local\Export-PSCredentials.ps1
  . $PSScriptRoot\Local\Import-PSCredentials.ps1

	# Utility Functions

		function Convert-Ztime {
			param (
				#expected format:2016-10-30T00:19:32Z
				[Parameter(Position=0,
					Mandatory=$True,
					ValueFromPipeline=$True)]
					[ValidatePattern("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z")]
					[string]$zulustr
				)
			
			$t1 = $zulustr.Replace("-","");
			$t2 = $t1.Replace("T","");
			$t1 = $t2.Replace(":","");
			$t2 = $t1.Replace("Z","");

			$localtime = [DateTime]::ParseExact($t2,"yyyyMMddHHmmss",$null,"AssumeUniversal")

			return $localtime;
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
      $Script:org = $borg;

		}

		function Get-InitiatorCount {
			begin { [int]$objcnt = 0; $Script:InitCnt = 0;}
			process { $objcnt++ }
			end { $Script:InitCnt = $objcnt }
		}

		filter isNumeric() {
				return $_ -is [byte]  -or $_ -is [int16]  -or $_ -is [int32]  -or $_ -is [int64]  `
					-or $_ -is [sbyte] -or $_ -is [uint16] -or $_ -is [uint32] -or $_ -is [uint64] `
					-or $_ -is [float] -or $_ -is [double] -or $_ -is [decimal]
		}

	#

	# Report Functions

		function Get-SGMetrics-Summary {
			param ([string]$sgID, [int]$count, [string]$sid4)
			begin { $tsmax = "0";
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

		function Show-IOMetrics {
			begin {}

			process {
				$Met = New-Object -typename PSObject

				if ($report -match "Summary") {
					$Met | Add-Member -MemberType NoteProperty -Name "Array" -Value $Script:ArrayNam;
					$Met | Add-Member -MemberType NoteProperty -Name "Model" -Value $Script:ArrayMod;
				}

				$ztime = $_.time
				$ltime = Convert-Ztime $ztime;
				$Met | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value $ltime
				
				$wps = $_.writes_per_sec;
				$rps = $_.reads_per_sec;
				$iorate = $wps + $rps;
				$Met | Add-Member -MemberType NoteProperty -Name "IO (ps)" -Value $iorate
				#$readrt = [Math]::Round($_.RESPONSE_TIME_READ,1);
				$Met | Add-Member -MemberType NoteProperty -Name "Read (ps)" -Value $rps
				#$writert = [Math]::Round($_.RESPONSE_TIME_WRITE,1);
				$Met | Add-Member -MemberType NoteProperty -Name "Write (ps)" -Value $wps
				
				$Met | Add-Member -MemberType NoteProperty -Name "Read (us)" -Value $_.usec_per_read_op
				#$writert = [Math]::Round($_.RESPONSE_TIME_WRITE,1);
				$Met | Add-Member -MemberType NoteProperty -Name "Write (us)" -Value $_.usec_per_write_op
				if ($report -ne "Summary") {
					$Met | Add-Member -MemberType NoteProperty -Name "QDepth" -Value $_.queue_depth
				}
				$readmbps = $_.output_per_sec / (1024 * 1024);
				$readmb = [Math]::Round($readmbps);
				$Met | Add-Member -MemberType NoteProperty -Name "Reads (MB)" -Value $readmb
				$writembps = $_.input_per_sec / (1024 * 1024);
				$writemb = [Math]::Round($writembps);
				$Met | Add-Member -MemberType NoteProperty -Name "Writes (MB)" -Value $writemb;
					
				$Script:IOMetrics += $Met
			}

			end {
				if ($report -ne "Summary") {
					if ($con) {
						Write-Host "IO Metrics for $pureName" -ForegroundColor Yellow
						$Script:IOMetrics | Format-Table -AutoSize
					} else {
						$title = "IO Metrics for $pureName"
						$Script:IOMetrics | Out-GridView -Title $title
					}
				}
			}
		}

		function Get-PureIOMetrics {
			begin { $PureMetrics = @();}
			process {
				$PureMet = New-Object -typename PSObject

				$PureMet | Add-Member -MemberType NoteProperty -Name "Array" -Value $Script:ArrayNam;
				$PureMet | Add-Member -MemberType NoteProperty -Name "Model" -Value $Script:ArrayMod;

				$ztime = $_.time
				$ltime = Convert-Ztime $ztime;
				$PureMet | Add-Member -MemberType NoteProperty -Name "Time Stamp" -Value $ltime
				
				$wps = $_.writes_per_sec;
				$rps = $_.reads_per_sec;
				$iorate = $wps + $rps;
				$PureMet | Add-Member -MemberType NoteProperty -Name "IO (ps)" -Value $iorate
				$rms = $_.usec_per_read_op / 1000;
				$readrt = [Math]::Round($rms,1);
				$PureMet | Add-Member -MemberType NoteProperty -Name "Read RT (ms)" -Value $readrt;
				$wms = $_.usec_per_write_op / 1000;
				$writert = [Math]::Round($wms,1);
				$PureMet | Add-Member -MemberType NoteProperty -Name "Write RT (ms)" -Value $writert

				$readmbps = $_.output_per_sec / (1024 * 1024);
				$readmb = [Math]::Round($readmbps);
				$PureMet | Add-Member -MemberType NoteProperty -Name "Reads (MB)" -Value $readmb
				$writembps = $_.input_per_sec / (1024 * 1024);
				$writemb = [Math]::Round($writembps);
				$PureMet | Add-Member -MemberType NoteProperty -Name "Writes (MB)" -Value $writemb;

				$readpct1 = ($rps/$iorate) * 100;
				$readpct2 = [Math]::Round($readpct1);
				$PureMet | Add-Member -MemberType NoteProperty -Name "READ %" -Value $readpct2
				$PureMet | Add-Member -MemberType NoteProperty -Name "HIT %" -Value "N/A"
					
				$PureMetrics += $PureMet

			}
			end { $Script:SumMetrics += $PureMetrics[$PureMetrics.Length - 1]; }
		}

		function Show-HGMetrics {
			param ([string]$hosttype)
			
			begin {}

			process {
				$Met = New-Object -typename PSObject

				$ztime = $_.time
				$ltime = Convert-Ztime $ztime;
				$Met | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value $ltime
				$Met | Add-Member -MemberType NoteProperty -Name "Host" -Value $_.name
				if ($hosttype -match "Group") {
					$Met | Add-Member -MemberType NoteProperty -Name "HG" -Value "Y"
				} else {
					$Met | Add-Member -MemberType NoteProperty -Name "HG" -Value "N"
				}
				
				$wps = $_.writes_per_sec;
				$rps = $_.reads_per_sec;
				$iorate = $wps + $rps;
				$Met | Add-Member -MemberType NoteProperty -Name "IO (ps)" -Value $iorate
					$Met | Add-Member -MemberType NoteProperty -Name "Read (ps)" -Value $rps
				$Met | Add-Member -MemberType NoteProperty -Name "Write (ps)" -Value $wps
				
				$Met | Add-Member -MemberType NoteProperty -Name "Read (us)" -Value $_.usec_per_read_op
				$Met | Add-Member -MemberType NoteProperty -Name "Write (us)" -Value $_.usec_per_write_op
				$Met | Add-Member -MemberType NoteProperty -Name "Input (ps)" -Value $_.input_per_sec
				$Met | Add-Member -MemberType NoteProperty -Name "Output (ps)" -Value $_.output_per_sec
					
				$Script:HGMetrics += $Met
			}

			end {
				if ($hosttype -match "Host") {
					if ($con) {
						Write-Host "Host & Host Group Metrics for $pureName" -ForegroundColor Yellow
						$Script:HGMetrics |
							Sort-Object Timestamp, "IO (ps)" |
							Format-Table -AutoSize
					} else {
						$title = "Host & Host Group Metrics for $pureName"
						$Script:HGMetrics |
							Sort-Object Timestamp, "IO (ps)" -Descending |
							Out-GridView -Title $title
					}
				}
			}
		}

		function Get-PureArrayIP {
			param([string]$arrayName)

			$doc = Get-ArrayInfoXML;
			
			$doc.SelectNodes("//Array") | Where-Object {$_.Name -match $arrayName} |
				Get-PureXMLObj;
			[string]$ip = $Script:PSArrays[0].ArrayIP;
			$Script:usr = $Script:PSArrays[0].UserName;
			$Script:org  = $Script:PSArrays[0].Org;
			$ipx = $ip.Trim();
			return $ipx;

		}

		function Get-FrontEndObj {
			param ([string]$feStr)
			
				$feStr | Set-Content gpm.txt
				
				# remove header
				$a = (get-content gpm.txt)
					$a = $a[1..($a.count - 1)]
				
				# replace spaces with comma
				$a | ForEach-Object {$_.Trim() -replace "\s+",","} | set-content gpm.csv
				$a1 = (get-content gpm.csv)
				
				# generate valid CSV file
				$a1 | ForEach-Object { # generate valid CSV file
					$b = $_;
					if ($b.Length -gt 2) {
						$c = $_.SubString(0,1)
						if ($c -match '^[0-9]') { # Append needed commas
							$newline = ",,,," + $b + ","
							$newline | Add-Content gpm1.csv
						} else {
							$newline = $b.Trim() -replace ",-","";
							$newline += ","
							$newline | Add-Content gpm1.csv
						}
					}
				}
				
				$feObj = Import-CSV gpm1.csv -Header $FEHeader
				$feObj | ForEach-Object { # Add hostname to entries w/o
					$nm = $_.Host
					if ($_.Host -ne "") {
						$hostnm = $_.Host;
					} else {
						$_.Host = $hostnm
					}
				}
				
				#Remove temp files
				Remove-Item gpm.txt
				Remove-Item gpm.csv
				Remove-Item gpm1.csv
				
				return $feObj

		}

		function Get-PureXMLObj {

			begin {$Script:PSArrays = @();}

			process {
				$PSArray = New-Object -typename PSObject
				$PSArray | Add-Member -MemberType NoteProperty -Name "Org" -Value $_.Org
				$PSArray | Add-Member -MemberType NoteProperty -Name "Data Center" -Value $_.DataCenter
				$PSArray | Add-Member -MemberType NoteProperty -Name "Array" -Value $_.Name
				$PSArray | Add-Member -MemberType NoteProperty -Name "ArrayIP" -Value $_.remote
				$PSArray | Add-Member -MemberType NoteProperty -Name "Model" -Value $_.Model
				$PSArray | Add-Member -MemberType NoteProperty -Name "Usage" -Value $_.usage
				$PSArray | Add-Member -MemberType NoteProperty -Name "UserName" -Value $_.username
				$Script:PSArrays += $PSArray
			}

			# return an array of PureSystem arrays
			end { $Script:PSArrays }
		}

		function Set-PureArray {
			param ([string]$ip, [string]$borg, [string]$account)
			
			# Get or Set Credentials $account
			Set-Credentials $borg $account
			
			try {
				$Script:pure = New-PfaArray -EndPoint $ip -Credentials $Script:cred -IgnoreCertificateError
			}
			catch {
				Write-Host $_ -ForegroundColor "Red"
				Write-Host "New-PfaArray -EndPoint $ip failed";
				return $null
			}

		}

		function Select-PureArray {
		
			$doc = Get-ArrayInfoXML;
			
			$title = "Select a PureSystem array for the report";
			[int]$objcnt = 0;
			$doc.SelectNodes("//Array") | Where-Object {$_.Class -match "Pure"} | Get-PureXMLObj |
				Sort-Object Org, "Data Center", Name |
				Out-GridView -Title $title -OutputMode Single |
				ForEach-Object {
					if ($objcnt -eq 0) {
						$arrayName = $_.Array
						$arrayIP = $_.ArrayIP
						$arrayOrg = $_.Org
						$arrayAcct = $_.UserName
					}
					$objcnt++;
				}
			
			if ($arrayName -eq $null) {
				Write-Host " selection cancelled" -ForegroundColor Red
				Write-Host "Thanks for trying! Bye" -ForegroundColor Blue
				return $null
			}

			Set-PureArray $arrayIP $arrayOrg $arrayAcct
			
			return $arrayName
		}

		function Select-Report {

			$reports = @();
			$reports += [pscustomobject]@{Report="ArrayMetrics";
				Description = " Performance metrics for PureSystem $pureName"}
			$reports += [pscustomobject]@{Report="FrontEnd";
				Description = " Front End port performance metrics PureSystem $pureName"};
			$reports += [pscustomobject]@{Report="StorageGroup";
				Description = " Performance metrics for Hosts and Host Groups"};
			$reports += [pscustomobject]@{Report="Summary";
				Description = " IO Performance Summary of all Pure Storage arrays"};
				
			$title = "Select a PureSystem Performance Report"
			
			$selectA_report = $reports | Out-GridView -Title $title -OutputMode Single;
			
			if ($selectA_report -eq $null) {
				Write-Host " Selection Cancelled" -ForegroundColor Red
				Write-Host "Thanks for trying! Bye" -ForegroundColor Blue
				return "Cancel"
			} else {
				return $selectA_report.report
			}

		}

		function Get-Arrays {
			param ([ProgressManager]$pm)
			
			begin { }

			process { 
				$Script:ArrayNam	= $_.Name;
				$Script:ArrayMod	= $_.Model;
				$Script:org			  = $_.Org;
				$Script:usr				= $_.username;
				$aryIP 						= $_.Remote;

				$PSCmdlet.WriteProgress($pm.GetCurrentProgressRecord(2, "Getting Pure credential Info"))
				Set-PureArray $aryIP $Script:org $Script:usr

				$PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(3, "Pure Metric data for $Script:ArrayNam"))
				$Script:IOMetrics = @();
				if ($reports -eq "Summary") {
					Get-PfaArrayIOMetrics -array $Script:pure -timerange "1h" |
						Show-IOMetrics;
					$Script:SumMetrics += $Script:IOMetrics[$Script:IOMetrics.Length - 1];
				} else {
					Get-PfaArrayIOMetrics -array $Script:pure -timerange "1h" |
						Get-PureIOMetrics;
				}
			}

			end { }

		}

		function Get-Summary {
			[long]$totalTasks = 3;
      $pm = [ProgressManager]::new("Retrieving Pure metric data...", " ", $totalTasks)
      $PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Gathering Pure array Info form the XMLDB"))
			
			$xmlDB = Get-ArrayInfoXML;
			
			if ([string]::IsNullOrEmpty($org)) {
				$xmlDB.SelectNodes("//Array") | Where-Object {$_.Class -match "Pure"} | Get-Arrays $pm
			} else {
				$xmlDB.SelectNodes("//Array") | Where-Object {$_.Class -match "Pure" -and $_.org -match $org} | Get-Arrays $pm
			}

			$PSCmdlet.WriteProgress($pm.GetCompletedRecord());

			$Script:SumMetrics | Format-Table -AutoSize
			$metCSVfile = "$PWD" + "\" + $Script:org + "-" + $Script:PureMetricsCSV;
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

			Write-Host "           Total IOPS: $totalIOPS     Reads (MB): $totalRead     Writes (MB): $totalWritten"  -ForegroundColor Green

		}

	#

#

# Exported Functions

	<#
		.SYNOPSIS
			Reports on PureSystem array performance data by executing
			RESTAPI calls from the Pure Storage PowerShell SDK 
			to a specific PureArray.
			
		.DESCRIPTION
			Reports PureSystem array metrics. A table of existing arrays
			is presented for selection of the desired array for reporting.

		.PARAMETER pureNAME
			PureSystem array name.
			Default "select" - A table of arrays will be presented for selection.
			
		.PARAMETER timeRange
			One of the following values: 1h,3h,24h,7d,30d,90d,1y
			Default: 1h
			By default 1 hour of data samples will be presented.
			
		.PARAMETER report
			Default 'select' to present a table of reports for selection.
			
			ArrayMetrics - Displays performance metrics for PureSystem array.
						
			FrontEnd     - Displays front end port IO Balance metrics
										for a PureSystem array.
			
			StorageGroup - Displays a list of Hosts and Groups along with performance
							metrics of each from a PursSystem array.
						
			Summary - Displays summarized view of IO Performance metrics and the display
								is updated every 6 minutes.
			
		.PARAMETER sg
			Name of the Host or Host Group for the Performance report.
			
		.PARAMETER con
			Output to the console rather than Out-Gridview.
			
		.PARAMETER csv
			For SGPerformance report. Output to summary csv file
			in the 'SGInfo' folder. (NOT IMPLEMENTED)

		.PARAMETER repeat
			For the Summary report. The report will be repeated every 6 minutes.
			
		.INPUTS
			ArrayInfo\ArrayInfo.xml
			Reads the file to present a table for selecting the desired PureSystem array.
			
		.INPUTS
			\pureuser-emc.xml
			
			Contains encrypted credentials for the pureuser account.
			If the file is not present, there will be prompt for the
			credentials and the file will be regenerated.
			
			The file can only be decrypted on system it was created on.
			
		.OUTPUTS
				Output defaults to Out-GridView unless the -con option
				is specified.
			
		.OUTPUTS
				\pureuser.enc.xml
			
			Pureuser encrypted credentials.
			
		.EXAMPLE
			Get-VePureMetrics
			
			Input parameters are provided though a series of Out-Gridview selections.

		.EXAMPLE
			Get-VePureMetrics bowpur002 -report FrontEnd

			Displays the FrontEnd report for bowpur002.
		.EXAMPLE
			Get-Pure-Metrics bowpur002 -report ArrayMetrics

			Displays one hour of array metrics for bowpur002.

		.EXAMPLE
			Get-Pure-Metrics bowpur002 -report StorageGroups

			Display Hosts & Host Groups metrics.
		
		.EXAMPLE
			Get-Pure-Metrics -report Summary

			Displays a summary of the ArrayMetrics report for all Pure Storage arrays.f

		  The display is updated every 6 minutes with new metrics values.

		.NOTES

			Requires Installation of PureSystem PowerShell module.	
			Execute the following to install PureStorage PowerShell module.
			Install-Module -Name PureStoragePowerShellSDK.
			
			Author: Craig Dayton
			0.0.2.0  07/10/2017 : cadayton : Converted to cmdlet exported from the PureMetrics module.
			Updated: 03/31/2017  Added a summary report.
			Updated: 01/05/2017  Cached credential file now machine specific.
			Updated: 11/15/2016  FrontEnd Report modified to count initiators & CSV output.
			Updated: 11/01/2016  Input validations added.
			Updated: 10/31/2016  Initial release

    .LINK
      https://github.com/cadayton/Venom

    .LINK
      http://venom.readthedocs.io

	#>

	Function Get-VePureMetrics {
		# Get-VePureMetrics Params
			[cmdletbinding()]
				Param (        
					[Parameter(Position=0,
						Mandatory=$False,
						ValueFromPipeline=$True)]
						#	[ValidatePattern("^[a-zA-Z0-9]{8}")]
					[string]$pureName = "select",
						# expected choices: 1h, 3h, 24h, 7d, 30d, 90d, 1y
					[Parameter(Position=1,
						Mandatory=$False,
						ValueFromPipeline=$True)]
						[ValidatePattern("^[1h,3h,24h,7d,30d,90d,1y]{2,3}$")]
					[string]$timeRange = "1h",
					[Parameter(Position=2,
						Mandatory=$False,
						ValueFromPipeline=$True)]
						[ValidatePattern("^[a-zA-Z0-9]{3,30}")]
					[string]$report = "select",
					[Parameter(Position=3,
						Mandatory=$False,
						ValueFromPipeline=$True)]
					[string]$sg,
					[Parameter(Position=5,
						Mandatory=$False,
						ValueFromPipeline=$True)]
					[switch]$con,
					[Parameter(Position=6,
						Mandatory=$False,
						ValueFromPipeline=$True)]
					[switch]$csv,
					[Parameter(Position=7,
						Mandatory=$False,
						ValueFromPipeline=$True)]
					[bool]$repeat =$true,
					[Parameter(Position=8,
						Mandatory=$False,
						ValueFromPipeline=$True)]
					[string]$org = $null
				)
				
		#

		Write-Host "Get-VePureMetrics version 0.0.2.0" -ForegroundColor Green

		if ($pureName -match "select" -and $report -ne "Summary" -and $report -ne "Summary1") {
			$pureName = Select-PureArray;
			if ([String]::IsNullOrEmpty($pureName)) {$report = "Cancel"}
		} elseif ($report -ne "Summary" -and $report -ne "Summary1") { # Verify array exists
			[string]$pureIP = Get-PureArrayIP $pureName;
			$pureIP=$pureIP.Trim();
			if ([string]::IsNullOrEmpty($pureIP)) {
				Write-Host "PureSystem $pureName does not exist in the XMLDB" -ForegroundColor Red
				Write-Host "The XMLDB may need to be updated" -ForegroundColor Yellow
				$report = "Cancel"
			} else {
				Set-PureArray $pureIP $Script:org $Script:usr
			}
		}

		if ($report -match "select") {
			$report = Select-Report
		}

		switch -Wildcard ($report) {
			"ArrayMetrics" {
				$Script:IOMetrics = @();
				Write-Host "Generating array metrics report for $pureName ..." -ForegroundColor Green
				Get-PfaArrayIOMetrics -array $Script:pure -timerange $timeRange |
					Show-IOMetrics
			}
			"Summary*" {
				$Script:SumMetrics = @();
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
				return $null;
			}
			"FrontEnd" {
				[long]$totalTasks = 3;
      	$pm = [ProgressManager]::new("Generating Front End report for $pureName ...", " ", $totalTasks)
      	
				$PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(1, "Gathering $pureName Info from the XMLDB"))
			  [string]$pureIP = Get-PureArrayIP $pureName;
				$pureIP=$pureIP.Trim();

				$PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(2, "Requesting metric data from $pureName @ $pureIP"))
				
				try {
					$fe = New-PfaCLICommand -EndPoint $pureIP -Credentials $Script:cred -CommandText "purehost monitor --balance"
				}
				catch {
					Write-Host $_ -ForegroundColor "Red"
					$PSCmdlet.WriteProgress($pm.GetCompletedRecord());
					return $null
				}
				
				$feObj = Get-FrontEndObj $fe;
				$title = "Front End Report for PureSystem, $pureName";
				if ($con) {
					Write-Host $title -ForegroundColor Yellow
					$PSCmdlet.WriteProgress($pm.GetCompletedRecord());
					$feObj | Format-Table -AutoSize;
				} elseif ($csv) {
					if (!(Test-Path $Global:FAPath)) { New-Item -Path $PWD\$Global:FADir -ItemType Directory | Out-Null; }
					$PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(2, "Creating CSV file"))			
					$csvPath = "$Global:FAInfo" + $Script:org + "-" + $pureName + "-Report.csv"
					$feObj | Export-Csv -Path $csvPath -NoTypeInformation
					$feObj | Sort-Object -property Initiator-WWN -unique | Get-InitiatorCount
					$PSCmdlet.WriteProgress($pm.GetCompletedRecord());
					Write-Host "Front-Report for $pureName with $Script:InitCnt Initiators saved to $csvPath" -ForegroundColor Green;
				} else {
					$PSCmdlet.WriteProgress( $pm.GetCurrentProgressRecord(3, "Generating report output & counting initiators"))
					$feObj | Sort-Object -property Initiator-WWN -unique | Get-InitiatorCount
					Write-Host "$pureName has $Script:InitCnt Initiators" -ForegroundColor Green
					$PSCmdlet.WriteProgress($pm.GetCompletedRecord());
					$feObj | Out-GridView -Title $title;
				}
			}
			"StorageGroup" {
				$Script:HGMetrics = @();
				Write-Host "Generating Host & Host Group metric report for $pureName ..." -ForegroundColor Green
				Get-PfaAllHostGroupIOMetrics -array $Script:pure |
					Show-HGMetrics "Group"
				Get-PfaAllHostIOMetrics -array $Script:pure |
					Show-HGMetrics "Host"
			}
			"Cancel" {			}
			Default {
				Write-Host "Report logic not defined for $report" -ForegroundColor Red
			}
		}

	}

#