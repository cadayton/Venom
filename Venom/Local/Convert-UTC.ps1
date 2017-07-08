function Convert-UTC {
  Param (
    [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$True)]
      [string]$ctime,
      [switch]$gmt
  )
  
  Begin {
      Write-Verbose "Converting UTC time"
      #define universal starting time
      [datetime]$utc = "1/1/1970"

      #test for Daylight Saving Time
      Write-Verbose "Checking DaylightSavingTime"
      $dst = Get-Ciminstance -ClassName Win32_Computersystem -filter "DaylightInEffect = 'True'"

  }

  Process {
      Write-Verbose "Processing $ctime"
      #add the ctime value which should be the number of
      #seconds since 1/1/1970.
      $gmtTime = $utc.AddSeconds($ctime)

      if ($gmt) {
        #display default time which should be GMT if
        #user used -GMT parameter
        Write-verbose "GMT"
        return $gmtTime
      } else {
        #otherwise convert to the local time zone
        Write-Verbose "Converting to $gmtTime to local time zone"

        #get time zone information from WMI
        $tz = Get-CimInstance -ClassName Win32_TimeZone

        #the bias is the number of minutes offset from GMT
        Write-Verbose "Timezone offset = $($tz.Bias)"
        #Add the necessary number of minutes to convert
        #to the local time.
        $local = $gmtTime.AddMinutes($tz.bias)
        if ($dst) {
            Write-Verbose "DST in effect with bias = $($tz.daylightbias)"
            return $local.AddMinutes(-($tz.DaylightBias))
        } else {
            #write the local time
            return $local
        }
      }
  }

  End {
      Write-Verbose "Convert-UTC completed"
  }
}