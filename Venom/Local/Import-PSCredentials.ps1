function Import-PSCredential {
  param ( $Path = "credentials.enc.xml" )

  $import = Import-Clixml $Path

  if ( !$import.UserName -or !$import.EncryptedPassword ) {
    Throw "Input is not a valid ExportedPSCredential object, exiting."
  }

  $Username = $import.Username
  $SecurePass = $import.EncryptedPassword | ConvertTo-SecureString
  $Credential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass
  return $Credential
}