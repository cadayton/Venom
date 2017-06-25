function Set-Ignore-SelfSignedCerts {

$TD = @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy
{
public bool CheckValidationResult(
ServicePoint srvPoint, X509Certificate certificate,
WebRequest request, int certificateProblem)
{
return true;
}
}
"@

	try {
		Write-Verbose "Adding TrustAllCertsPolicy type."
		Add-Type -TypeDefinition $TD
		Write-Verbose "TrustAllCertsPolicy type added."
	}
	catch {
		Write-Host $_ -ForegroundColor "Red"
	}
	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}