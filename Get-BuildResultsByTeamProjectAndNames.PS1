#!/usr/bin/env powershell
#requires -Version 2.0
function Get-Builds {    
  <#
      .SYNOPSIS
      For the Write-BuildReport function we need to pass an object collection contains details of the build. 

      .DESCRIPTION
      Creates the psobject collection for the builds provided by Get-BuildNames function.
      .EXAMPLE

      Get-AllBuildNames 

      .NOTES
      Place additional notes here.

      .LINK
      URLs to related sites
      The first link is opened by Get-Help -Online Get-AllBuildNames

      .OUTPUTS
      A PSObject collection for build details.
  #> 
  param(  
    [Parameter(Mandatory,HelpMessage='Add help message for user')]
    [ValidateNotNullOrEmpty()]
    [string]$tfsUrl,
    [Parameter(Mandatory,HelpMessage='Add help message for user')]
    [ValidateNotNullOrEmpty()]
    [PSObject[]]$BuildList,
    [Parameter(Mandatory,HelpMessage='Add help message for user')]
    [int]$hours
  )
  BEGIN{
    #Load required assemblies: 
    Add-Type -AssemblyName Microsoft.TeamFoundation.Client
    Add-Type -AssemblyName Microsoft.TeamFoundation.Build.Client
    Add-Type -AssemblyName Microsoft.TeamFoundation.Build.Common
    Add-Type -AssemblyName Microsoft.TeamFoundation.VersionControl.Client
  }
  PROCESS{
    $Tfs = [Microsoft.TeamFoundation.Client.TeamFoundationServerFactory]::GetServer($tfsUrl)
    $VersionControlServer = $Tfs.GetService('Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer')
    $BuildControlServer = $Tfs.GetService('Microsoft.TeamFoundation.Build.Client.IBuildServer')
    $BuildStatusFilter=@( 'InProgress', 'Succeeded', 'Failed', 'PartiallySucceeded', 'Stopped')

    foreach ($build in $BuildList){
    
      $TeamProject= $build.TeamProject
        
      foreach( $buildDefinitionName in $build.BuildNames){
        $spec=$BuildControlServer.CreateBuildDetailSpec($TeamProject,$BuildDefinitionName)
        $spec.InformationTypes=$null
            
        $MatchingBuilds = $BuildControlServer.QueryBuilds($Spec)
            
      $Builds =($MatchingBuilds.Builds) |Where-Object (Status -in $BuildStatusFilter -and (StartTime -gt ((get-date).addhours($hours))) }
      if ($Builds -eq $null) {
      $Builds=($MatchingBuilds.Builds) |Where-Object (Status -in $BuildStatusFilter) | Sort-Object -Property StartTime -Descending |Select-Object -First 1}
            
      $Builds| Sort-Object  -Property StartTime -Descending | ForEach-Object { 
        if($PSItem -ne $null){
          $errorMessage=''    
          if (!($PSItem.status -in ( 'Succeeded', 'InProgress' ))){
            $details=$BuildControlServer.GetAllBuildDetails($PSItem.Uri)
            $errorMessage= if($PSItem.TestStatus -eq 'Failed'){
              #Todo: can link the trx files...

              ("<a href='http://reportserver/{0}/{1}/TestReport.xml'>Tests failed. Check the test results</a>" -f $teamproject, $PSItem.BuildNumber)
            }
            else{
              ([Microsoft.TeamFoundation.Build.Client.InformationNodeConverters]::GetBuildErrors($details)).Message |Out-String | ForEach-Object{
                if (!( $PSItem -eq $null)){
                $PSItem.substring(0, (155, $PSItem.length | Measure-Object -Minimum).Minimum)}
              }
            } 
            $obj=@()
            $obj = New-Object -TypeName psobject -Property @{
              TeamProject=$TeamProject
              Name =$PSItem.BuildDefinition.Name
              BuildNumber=("<a href='{0}'> {1} </a>" -f $PSItem.LogLocation, $PSItem.BuildNumber)
              Status=$PSItem.Status
              FinishTime=$PSItem.FinishTime
              ErrorMessage=$ErrorMessage.Trim()
            }
            $script:objects+=$obj
          }
        }
      }
    }
  }
  END{}
}


function Get-AllBuildNames{
  <#
      .SYNOPSIS
      We need a list of the builds to query and report on. 
      Ideally fed from another service

      .DESCRIPTION
      Get the name list of builds which will then go and query tfs builds 
      For now it is a hardcoded list.
      .EXAMPLE

      Get-AllBuildNames 

      .NOTES
      Place additional notes here.

      .LINK
      URLs to related sites
      The first link is opened by Get-Help -Online Get-AllBuildNames

      .OUTPUTS
      A PSObject with an array of strings contains build names
  #>  
  $build=New-Object -TypeName psobject -Property @{
    TeamProject='abc'
    BuildNames=@('build1', 'build2', 'build3', 'build4', 'build5', 'build6','build7')}
  $BuildList+=$build
  return $BuildList
}


function Write-BuildReport {
<#
    .SYNOPSIS
    Creates an html report for TFS build names
    
    .DESCRIPTION
    Writes a report of the latest build result in the last x number of hours...

    .EXAMPLE
    Define 2 parameters:
    1.TFS Url to connect
    $tfsUrl= "http://tfs.com:8080/tfs"
    2.Get the Number of hours to check build start time
    $hours=6
    3. The path of the report:
    $reportPath="c:\buildsreports\"
    Write-BuildReport -tfsUrl $tfsUrl -Hours $hours -reportPath $reportPath

    .NOTES
    Place additional notes here.


    .OUTPUTS
    List of output types produced by this function.
#>
  param(
    [Parameter(Mandatory,HelpMessage='Add help message for user')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({(Invoke-WebRequest -Uri ('{0}' -f $PSItem)).StatusCode -eq 200})]
    [string]$tfsUrl,
    [Parameter(Mandatory,HelpMessage='Add help message for user')]
    [int]$hours,
    [Parameter(Mandatory,HelpMessage='Add help message for user')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path -Path $PSItem -PathType Container})]
  [string[]]$reportPath)
 
  BEGIN{

    [PSObject[]]$script:objects= @()

    $fileName= Join-Path -Path $reportPath -ChildPath ((get-date -format 'yyMMddhhmm') + '.htm') 
    [PSObject[]]$BuildList=@()
    
    Get-AllBuildNames |  Get-Builds -tfsUrl $tfsUrl -BuildList $BuildList -Hours $Hours
   
    $css= '<style>
      BODY{background-color:white; margin-left: 20px; font-family: calibri;}
      TABLE{margin-left: 40px; border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;width: 100pc}
      TH{border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:#58ACFA}
      TD{border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:#FAFAFA}
      UL {margin-left:70;margin-top:0;margin-bottom:10;}
      LI UL {margin-left:20;margin-bottom:10}
      .failed {color:red;}
      .passed {color:green;}
    </style>'

   
    Write-Verbose -Message ('HTML report will be saved {0}' -f $fileName) 
  }

    Process{ 

      $Content= $script:objects |  Select-Object -Property TeamProject, Name, BuildNumber, Status, FinishTime, ErrorMessage |`
      ConvertTo-Html -Fragment -As Table -PreContent "<h2>Builds</h2>" | Out-String

      $Report=ConvertTo-Html -Title 'TFS Builds ' -Head "<h1>Builds</h1><br>This report was ran: $(Get-Date)" -Body ('{0}' -f $Content)
    
    }

    End{ 
      Add-Type -AssemblyName System.Web
      [System.Web.HttpUtility]::HtmlDecode($Report) | Out-File -FilePath $fileName

      Invoke-Expression -Command $FileName  
    } 
  }

