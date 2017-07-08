function Get-ArrayInfoXML {

  $AIFile = Get-ChildItem -Path $AIPath |
    Where-Object {$_.PSChildName -like "ArrayInfo*.xml"} |
    Sort-object -property @{Expression={$_.LastWriteTime}; Ascending=$false}; 

  $FileIn = $AIPath + "\" + $AIFile.PSChildName[0];
  $doc = new-object "System.Xml.XmlDocument"
  $doc.Load($FileIn)

  return $doc

}