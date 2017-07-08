function Export-PSCredential {
  param ( $Credential = (Get-Credential), $Path = "credentials.enc.xml" )

  # Look at the object type of the $Credential parameter to determine how to handle it
  switch ( $Credential.GetType().Name ) {
    # It is a credential, so continue
    PSCredential		{ continue }
    # It is a string, so use that as the username and prompt for the password
    String				{ $Credential = Get-Credential -credential $Credential }
    # In all other caess, throw an error and exit
    default				{ Throw "You must specify a credential object to export to disk." }
  }

  $export = "" | Select-Object Username, EncryptedPassword
  $export.PSObject.TypeNames.Insert(0,'ExportedPSCredential')
  $export.Username = $Credential.Username
  $export.EncryptedPassword = $Credential.Password | ConvertFrom-SecureString
  if (!(Test-Path $Global:CRDir)) {
    New-Item $Global:CRDir -ItemType Directory
  }
  $Script:credfilename = $Global:CRPath + "\" + $Credential.Username + $Path;
  $export | Export-Clixml $Script:credfilename;
  Write-Host -foregroundcolor Yellow "Created:$Script:credfilename"

}