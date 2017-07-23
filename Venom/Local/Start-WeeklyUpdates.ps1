  #########################################################################
  #                                                                       #
	# Example of how to orchestrate some of the Venom cmdlets together      #
	#                                                                       #
	# Change the parameter values to match your XMLDB records.              #
  #                                                                       #
  #########################################################################
  
  function Start-WeeklyUpdates {

    function Get-XMLDB {
      $File1Path = Get-ChildItem -Path C:\bin\ps\ArrayInfo |
        Where-Object {$_.PSChildName -like "ArrayInfo*.xml"} |
        Sort-object -property @{Expression={$_.LastWriteTime}; Ascending=$false};

      $FileIn = $File1Path.FullName[0]

      if ((Test-Path $FileIn)) { # input file exist?
        $doc = new-object "System.Xml.XmlDocument"
        $doc.Load($FileIn)
        return $doc;
      } else {
        Write-Host "$FileIn not found in $File1Path" -ForegroundColor Red
        return $null
      }

    }
		
		$xmlDB = Get-XMLDB;

		# Fabric update processing
			$xmlDB.SelectNodes("//Fabric") |
				Where-Object {$_.DataCenter -eq "Snake" -and $_.Org -eq "Mojo"} |
				Select-Object -Property fabric |
				ForEach-Object {
					$fab = $_.fabric;
					$logFile = "$PWD\$fab.log";
					Write-Host "Generating Device-Alias cmd files for $fab" -ForegroundColor Green
					Write-Host "  See log $logFile for the ouput" -ForegroundColor Green
					Set-VeDeviceAlias -FabricName $fab *> $logFile

					Write-Host "Applying Device-Alias cmd files for $fab" -ForegroundColor Green
					Set-VeDeviceAlias -FabricName $fab -apply *>> $logFile

					Write-Host "Updating flogi csv files for $fab" -ForegroundColor Green					
					Update-VeFlogi -FabricName $fab -Org EIT *>> $logFile
				}
		#
		
		# Symm update processing
			$logFile = "$PWD\Snake-SymmLogin.log";
			Write-Host " "
			Write-Host "Updating Symm Login entries for Snake see log $logFile"  -ForegroundColor Green		
			$xmlDB.SelectNodes("//Array") |
				Where-Object { $_.Model -match "VMAX" -and $_.DataCenter -eq "Snake" -and $_.Org -eq "Mojo"} |
				Select-Object -Property sid |
				ForEach-Object {
					Write-Host "  Setting Symm Aliases for $_.sid" -ForegroundColor Magenta
					Set-VeSymmLogin -sid $_.sid *> $logFile

					Write-Host "  Updating Current Login csv file for $_.sid" -ForegroundColor Magenta					
					Set-VeSymmLogin -sid $_.sid -SetLogin *>> $logFile
				}
		#

	}
