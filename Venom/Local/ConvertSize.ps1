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