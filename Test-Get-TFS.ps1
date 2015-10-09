function Test-TFS2010{
    param (
    [string]$GetTFSScriptFullName =$(Throw 'Script Location is required'),
    [string]$tfsUrl= $(Throw 'Tfs url is required')
    )

    & $GetTFSScriptFullName
    $tfs10= Get-Tfs2010 $tfsUrl
    
    if ($tfs10){
       return $true
    }
    else{
       return $false
    }
}
#Put values to be tested:
#scriptname is the name of location, assumed the same folder as this script
$scriptName= Join-Path -Path $PSScriptRoot "Get-TFS.ps1" 
$tfsUrl="http://tfs:8080/tfs/defaultcollection"

Test-TFS2010 $scriptName $tfsUrl