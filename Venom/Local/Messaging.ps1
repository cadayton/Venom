# Messaging Functions 
  function Send-SMS {
      param ($subject)
      
      $email = New-Object System.Net.Mail.MailMessage		
        ($smsnum,$fname) = $Script:eSms.Split("#")
        $email.Subject = $subject;
        $email.From = $Script:eFrom;
        $email.To.Add($smsnum)
        #$email.Body = " "; #$msg;
        $client = New-Object System.Net.Mail.SmtpClient $Script:smtphost
        $client.UseDefaultCredentials = $true
        $client.Send($email)		
  }

  function Send-Email {
    param ([string]$subject, [string]$msg, [switch]$sms)

    if ($sms) {
      Send-SMS $subject;
    }
    
    $email = New-Object System.Net.Mail.MailMessage
      
    $attlog	= New-Object System.Net.Mail.Attachment($Script:logName)
    $email.Attachments.Add($attlog)
    #$attPDF			= New-Object System.Net.Mail.Attachment($Global:pdfName)
    #$email.Attachments.Add($attPDF)
    $email.Body     = $msg;
    $email.From     = $Script:eFrom;
    $email.Subject	= $subject;
    $email.To.Add($Script:eTo);
    #$email.Cc.Add($Global:emailaddr);
    
    $client = New-Object System.Net.Mail.SmtpClient $Script:smtphost
    $client.UseDefaultCredentials = $true
    $client.Send($email)
  }
    
  function Remove-OldLogs {
    $numOfDays = 7;  # remove log files older that 7 days.
    $currentDate = Get-Date
    $LastWrite = $currentDate.AddDays(-$numOfDays)
    $Files = Get-ChildItem -Path $PWD -Filter "$MyName*.log" |
      Where-Object {$_.LastWriteTime -le "$LastWrite"}
    foreach ($File in $Files) {
      #write-host "Deleting file $File" -foregroundcolor "Red";
      Write-Log "Deleting file: $File - $env:USERNAME";
      Remove-Item $File | out-null
    }
  }
  function Write-LogHdr {
  
    $msg = "Executing " + $MyName + " on host " + $env:COMPUTERNAME;
    Write-Log $msg;
    Write-Log "****** Execution Info ********";
    Write-Log "  Execution path: $PWD";
    Write-Log "      Running as: $env:USERNAME";
    Write-Log "        Log File: $Script:logname";
    Write-Log " "
    Remove-OldLogs;
  }
  function Write-Log {
    param($msg)
  
    $logext         = get-date -format "yyyyMMdd";
    $Script:logname = "$PWD" + "\" + "$MyName" + "_" + "$logext" + ".log";
    $timestamp      = get-date -format "MM/dd/yy HH:mm:ss";
    $logrec1        = "$timestamp : ";
    $logrec1        += $msg;

    if (!(Test-Path $Script:logname)) { # file does not exist
      New-Item $Script:logname -type file | Out-Null
      Write-LogHdr;
    }

    Add-Content $Script:logname $logrec1

  }

  function Get-Checksum {
    param($crypto_provider)

    if ($crypto_provider -eq $null) {
      $crypto_provider = new-object 'System.Security.Cryptography.MD5CryptoServiceProvider';
    }

    $m1 = (get-module SSSAR).Version.Major;
    $n2 = (get-module SSSAR).Version.Minor;
    $b3 = (get-module SSSAR).Version.Minor;
    $vdir = $m1 + "." + $n2 + "." + $b3;
    $MyModPath = "$PSScriptRoot\$vdir";
    if (Test-Path $MyModPath) { } else { $MyModPath = $PSScriptRoot }
    $psm = Get-ChildItem -Path $MyModPath -Filter .\SSSAR.psm1
    $chk = Get-ChildItem -Path $MyModPath -Filter .\Checksum
    $MyFile = "$PWD\pureuser-$env:COMPUTERNAME.enc.xml"
		
    $file_info = Get-Item $psm.VersionInfo.FileName
    trap { ;	continue }
    $stream = $file_info.OpenRead();
    if ($? -eq $false) {
      return $null;
    }

    $bytes		= $crypto_provider.ComputeHash($stream);
    $checksum	= '';
    foreach ($byte in $bytes) {
      $checksum	+= $byte.ToString('x2');
    }

    $stream.close() | out-null;

    $baseChkSum = (Get-Content $chk.VersionInfo.FileName)[0];
    $Script:smtpHost = (Get-Content $chk.VersionInfo.FileName)[1];
    $Script:eFrom = (Get-Content $chk.VersionInfo.FileName)[2];
    $Script:eTo = (Get-Content $chk.VersionInfo.FileName)[3];
    $Script:eSms = (Get-Content $chk.VersionInfo.FileName)[4];
    $Script:Account = (Get-Content $chk.VersionInfo.FileName)[5];

    if (($checksum -ne $baseChkSum) -and (Test-Path $MyFile)) {
      $info = "$env:COMPUTERNAME SSSAR code change detected cached credentials removed - $env:USERNAME";
      Write-Log $info
      Send-Email "$env:COMPUTERNAME SSSAR code change detected" $info -sms
      Remove-Item $MyFile
    }

    return $checksum;
  }

  function Import-RequiredModule {
    param([string]$modName, [string]$modVersion)

    # Check if required module is loaded

    if ($modVersion -ne $null) { # Check if module is available to import and then import it.
      $mod = Get-Module -ListAvailable | Where-Object {$_.Name -eq $modName -and $_.Version -eq $modVersion}
    } else {
      $mod = Get-Module -ListAvailable | Where-Object {$_.Name -eq $modName}
    }

    if ($mod -ne $null) { # Import Module
      return $mod
    } else {
      $mod = "$modName $modVersion is not available to Import"
      return $mod
    }

  }
  
#