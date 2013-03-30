## =====================================================================
## Title       : Create-WebService
## Description : Creates a webService on the local computer
## Author      : Jan Baer
## Date        : 3/30/2012
## Input       : Create-WebService [-SitePrefix <String>] [-Environment <String>] [[-SitePostfix] <string>] [[-WebsitesRoot] <string>] [[-Port] <int>] [[-ForceDelete] <switch> [[-CreateScanningFolder] <switch>]]
##                     
## Output      : 
## Usage       : Create-WebService -SitePrefix scan -Environment dev -ForceDelete -CreateScanningFolder
##
## Notes       :
## Tag         : iis, deployment
## Change log  :
## =====================================================================
Param (
  [Parameter(Mandatory=$true, Position=0)]
  [string]$SitePrefix,
  [Parameter(Mandatory=$true, Position=1)]
  [string]$Environment,
  [string]$SitePostfix = "intern",
  [string]$WebsitesRoot = "C:\\inetpub\\wwwroot",
  [int]$Port = 80,
  [switch]$ForceDelete,
  [switch]$CreateScanningFolder
)

function Test-Admin { 
   $currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() ) 
   if ($currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )) 
   { 
      return $true 
   } 
   else 
   { 
      return $false 
   } 
}

function IsAspNet4Installed {
	$items = Get-ChildItem IIS:\AppPools | where {$_.Name -like ".NET v4.*" }
	return ($items.Count -ne 0)
}

function ExistsWebSite($webSiteName) {
	$website = Get-WebSite -Name $webSiteName | where {$_.name -eq $appName}
	
	if ($website -eq $null) {
		return $false
	}
	
	return $true
}

function SetAccessRights($directory, $userName, $right) {
	$acl = Get-Acl -Path $directory
	$userAccount = New-Object System.Security.Principal.NTAccount("IIS AppPool", $userName) 
	$permission = $userAccount, $right, "ContainerInherit,ObjectInherit", "None", "Allow"
	$right = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
  if ($right -eq "FullControl") {
    $acl.SetAccessRule($right)      
  }
	else {
    $acl.AddAccessRule($right)
  }
	Set-Acl -AclObject $acl -Path $directory
}

function CreateSubDirectory($parent, $directorName) {
    $fullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($parent, $directorName))    
    mkdir $fullPath
}

function CreateWebService($webServiceName, $appPoolName, $directoryPath, $Port) {
  $integrated = 0
  New-WebAppPool -Name $appPoolName
  Set-ItemProperty IIS:AppPools\$appPoolName managedRuntimeVersion v4.0
  Set-ItemProperty IIS:AppPools\$appPoolName managedPipelineMode $integrated

  New-Website -Name $webServiceName -PhysicalPath $directoryPath -ApplicationPool $appPoolName
  Remove-WebBinding -Name $webServiceName
  New-WebBinding -Name $webServiceName -IPAddress "*" -Port $port -HostHeader $webServiceName
}

function CreateScanningDirectoriesAndSetAccessRights($parentDirectory) {
  $scanningPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($parentDirectory, "Scanning"))
  $processingPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scanningPath, "Processing"))
  
  if (([System.IO.Directory]::Exists($scanningPath) -eq $true))
  {
    if ($ForceDelete -eq $false) {
        return $false
    }
    else {
        rm $scanningPath -Force -Recurse
    }
  }
  
  mkDir $scanningPath
  CreateSubDirectory $scanningPath "PackageFolder"
  CreateSubDirectory $scanningPath "Processing"
  CreateSubDirectory $scanningPath "Archive"
  CreateSubDirectory $scanningPath "NoAssigment"

  return $true
}

# Check system requirements
if ((Test-Admin) -eq $false) {
  Write-Host "This script requires admin rights!" -f Red
  return
}

if ((get-module -name WebAdministration -erroraction silentlycontinue) -eq $false) {
    Write-Host "The Powershell module for WebAdministration is not installed! Please check your IIS installation!" -f Red
	return
}

Import-Module -Name WebAdministration

if ((IsAspNet4Installed) -eq $null) {
  Write-Host ".NET4.0 is not installed or not registered in IIS! Please check your Installation!" -f Red
  return
}

# Built appName and directoryNames
$appName = $SitePrefix + "-" + $Environment + "-sp.check24." + $SitePostfix
$webServicePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($WebsitesRoot, $appName))
$appPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($webServicePath, "Application"))
$logPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($webServicePath, "Logs"))

# check if Website already exists and exit the script when ForceDelete == false
if (ExistsWebSite($appName)) {
  if ($ForceDelete -eq $false) {
    Write-Warning "The webService '$appName' already exists!"
    return
  }
  else {
    Remove-Website -Name $appName
    Remove-WebAppPool -Name $appName
  }
}

Write-Host
Write-Host "Create WebService '$appName' on '$appPath'" -ForegroundColor Green

if (([System.IO.Directory]::Exists($webServicePath) -eq $true)) {
    if ($forceDelete -eq $false) {
        Write-Warning "The directory $webServicePath already exists!"
        return $false
    }
    else {
        rm $webServicePath -Force -Recurse
  }
}

mkdir $webServicePath
mkdir $appPath
mkdir $logPath

CreateWebService $appName $appName $appPath $port

SetAccessRights $webServicePath $appName "FullControl"

if ($CreateScanningFolder -eq $true) {
  CreateScanningDirectoriesAndSetAccessRights $webServicePath
}


Write-Host
Write-Host "WebService '$appName' was successful created!" -ForegroundColor Green


