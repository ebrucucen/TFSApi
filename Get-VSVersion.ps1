function Get-VSVersions{
param ([PSCredential]$credential, 
[psobject]$buildservers,
[string]$VS2015VersionKey)

$buildservers.BuildServerNames | % {Invoke-Command -ComputerName ($_+'.'+$($buildservers.domain)) -ScriptBlock {param($p1,$p2) write-output " $p1"
  (Get-ItemProperty $p2).version} -ArgumentList $_,$VS2015VersionKey  -Credential $Credential}

$env:computername
 (Get-ItemProperty $VS2015VersionKey ).version
}

function Get-MyCredentials{
    param([string]$encryptedCredentialFile)

    if (!(Test-Path -Path $encryptedCredentialFile))
    {
        Create-Credentials $encryptedCredentialFile
    }
    $Credential= Import-Clixml $encryptedCredentialFile
    return $Credential
}

function Create-Credentials {
param( 
#   [string]$username="$($env:USERNAME)@$tdenvdomain",
    [string]$encryptedCredentialFile)

    [string]$message="Enter your credentials" 
   
#   [PSCredential]$cred =Get-Credential $username -Message $message 
    [PSCredential]$cred =Get-Credential -Message $message 
    $cred | Export-Clixml $encryptedCredentialFile

}
#Steps:
#1.get-credentials [first from file, if not prompt]
#get-buildserverlist
#get-vsversion
function Get-BuildList{
param([string] $domainName="mydomain.com")
    $buildserverlist=new-object PSObject -property @{
        BuildServerNames= @("bld-01", "bld-02", "bld-03")
        Domain=$domainName}

    return $buildserverlist
}

$encryptedCredentialFile="c:\mycredentials.xml" 

$BuildServers=Get-BuildList
[PSCredential]$MyCredential=Get-MyCredentials $encryptedCredentialFile
$VS2015VersionKey= 'HKLM:\SOFTWARE\Microsoft\DevDiv\vc\Servicing\14.0\IDE.x64'
Get-VSVersions $MyCredential $BuildServers $VS2015VersionKey
