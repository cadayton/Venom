function Get-JSON-RequestBody {
  param([string]$sidsn)
  
$SymmID = @"
{
"symmetrixId" : "$sidsn"
}
"@;
  return $SymmID;
}