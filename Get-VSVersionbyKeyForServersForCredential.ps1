function Get-VSVersions{
[CmdletBing()]
param ([PSCredential]$credential, 
[psobject]$buildservers,
[string]$VS2015VersionKey)
BEGIN{}
PROCESS{
$buildobjectList =@()
$buildservers.BuildServerNames | % {$buildobject= Invoke-Command -ComputerName ($_+'.'+$($buildservers.domain)) -ScriptBlock {param($p1,$p2) 
  $version=(Get-ItemProperty $p2).version ; 
    $req= [net.Webrequest]::Create("http://google.com")
    $res=try{if(($req.getresponse()).statuscode -eq "OK"){ "Internet Connection on"} }catch{"No connection"}
    $psversion= $PSVersionTable.PSVersion.ToString()
    new-object -TypeName PSObject -Property @{Name=$p1;VSVersion=$version;Internet=$res;PSVersion=$PSVersion}
} -ArgumentList $_,$VS2015VersionKey  -Credential $Credential;
    $buildobjectout= new-object -TypeName PSObject -Property @{Name=$($buildobject.Name);VSVersion= $($buildobject.VSVersion);Internet=$($buildobject.Internet);PSVersion=$($buildobject.PSVersion)}
        $buildobjectList+=$buildobjectout

}}
 

$mycomputer=$env:computername
$myvsversion= (Get-ItemProperty $VS2015VersionKey ).version
$mypsversion= $PSVersionTable.PSVersion.ToString()
$wc = [System.Net.WebClient]::new()
$wc.UseDefaultCredentials=$true
$wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

$myreq= [net.Webrequest]::Create("http://google.com")    
$myconn=try{if(($myreq.getresponse()).statuscode -eq "OK"){ "Internet Connection on"} }catch{"No connection"}
$myMachine= New-Object -TypeName PSObject -Property @{Name=$mycomputer;VSVersion=$myvsversion;Internet=$myconn;PSVersion=$mypsversion}
$buildobjectList+=$myMachine
END{
 $buildobjectList | Select Name, VSVersion, Internet, PSVersion| Format-Table -AutoSize

Write-Output ""
Write-Output "Checked internet connection by creating httprequest to http://google.com"
Write-Output "Checked VS Version by checking registry key $VS2015VersionKey"

Write-Output "[$(Get-Date -Format 'dd/MM/yyyy hh:mm')] Script: $($MyInvocation.ScriptName)"
}
}

function Get-MyCredentials{
    param([string]$encryptedCredentialFile)

    if(Test-Path -Path $encryptedCredentialFile)
    {
 
       if( Test-CredentialsByFile $EncryptedCredentialfile){}
       else { $encryptedCredentialFile= Create-Credentials $encryptedCredentialFile}
    }
    else
    {
    $encryptedCredentialFile= Create-Credentials $encryptedCredentialFile
    }
    $Credential= Import-Clixml $encryptedCredentialFile

    return $Credential
}
function Test-CredentialsByFile {
    [OutputType([Bool])] 
    
    param ([string]$EncryptedCredentialfile)
       $Credential= Import-Clixml $encryptedCredentialFile
        $domain= $Credential.UserName.split("@")[1]
       return Test-CredentailsByCredential $Credential $domain
}

function Test-CredentailsByCredential {
    [OutputType([Bool])] 
    
    param ([Parameter( 
                Mandatory = $true, 
                ValueFromPipeLine = $true, 
                ValueFromPipelineByPropertyName = $true 
            )] 
            [Alias( 
                'PSCredential' 
            )]
            [ValidateNotNull()] 
            [System.Management.Automation.PSCredential] 
            [System.Management.Automation.Credential()] 
            $Credential = [System.Management.Automation.PSCredential]::Empty, 
 
            [Parameter(Mandatory = $true)] 
            [ValidateNotNull()] 
            [String]
            $Domain
    )
Begin { 
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.AccountManagement") 
        $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $Domain) 
    } 
 
    Process { 
        $networkCredetial = $Credential.GetNetworkCredential() 
        return $principalContext.ValidateCredentials($networkCredetial.UserName, $networkCredetial.Password) 
    } 
 
    End { 
        $principalContext.Dispose() 
    } 
}

function Create-Credentials {
param( 
    [string]$encryptedCredentialFile)
   
    [string]$username="$($env:USERNAME)@$($global:testdomainname)"
    [string]$message="Enter your TEST credentials" 
    
    [PSCredential]$cred =Get-Credential $username -Message $message 
    $cred | Export-Clixml $encryptedCredentialFile
    if (Test-CredentialsByFile $encryptedCredentialFile ){
       return $encryptedCredentialFile}
    else{
        Write-Error "Credentials validation failed. Check if your account is not locked out."
        return "Your account could be locked out"
    }
}
#test-mycredentialsfile
#get-credentials
#get-buildserverlist
#get-vsversion
function Get-BuildList{
    $buildserverlist=new-object PSObject -property @{
        BuildServerNames= @("bld-01", "bld-02", "bld-03")
        Domain=$global:testdomainName}
    return $buildserverlist
}

$datetimestamp =Get-Date -Format 'ddMMyyyy_hhmm'
#$encryptedCredentialFile="c:\temp\mycredentials$datetimestamp.xml" 
$encryptedCredentialFile="c:\temp\my_tdenv_credentials.xml" 
[string] $global:testdomainName="mydomain.com")

$BuildServers=Get-BuildList
[PSCredential]$MyCredential=Get-MyCredentials $encryptedCredentialFile
$VS2015VersionKey= 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\DevDiv\vc\Servicing\14.0\IDE.Core'
Get-VSVersions $MyCredential $BuildServers $VS2015VersionKey
