if ($args.Length -lt 2 ) {
	"usage ./CreateWebService.ps1 sitePrefix environment [sitePostfix=intern] [websitesRoot=C:\\inetpub\\wwwroot] [port=80] [forceDelete=false] [createScanningFolders=false]"
    return  
}



[string] $sitePrefix = $args[0]
[string] $environment = $args[1]
[string] $sitePostfix = "intern"
[string] $websitesRoot = "C:\\inetpub\\wwwroot"
[bool] $forceDelete = $false
[int] $port = 80
[bool] $createScanningFolders = $false

if ($args.Length -gt 2 ) {
    $sitePostfix = $args[2]
}
if ($args.Length -gt 3 ) {
    $websitesRoot = $args[3]
}
if ($args.Length -gt 4) {
    $port = [System.Convert]::ToInt32($args[4])
}
if ($args.Length -gt 5) {
    $forceDelete = [System.Convert]::ToBoolean($args[5])
}
if ($args.Length -gt 6) {
    $createScanningFolders = [System.Convert]::ToBoolean($args[6])
}

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
	return [ADSI]("IIS://localhost/w3svc/AppPools/ASP.NET v4.0" )
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
	$permission = $userAccount, $right,"Allow"
	$right = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
	$acl.AddAccessRule($right)
	Set-Acl -AclObject $acl -Path $directory
}

function CreateSubDirectory($parent, $directorName) {
    $fullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($parent, $directorName))    
    mkdir $fullPath
}

function WriteMessage([string]$message) {
    $color = (Get-Host).UI.RawUI.ForegroundColor
    (Get-Host).UI.RawUI.ForegroundColor="Green"
    Write-Host $message
    (Get-Host).UI.RawUI.ForegroundColor=$color
}

function CreateWebService ($webServiceName, $appPoolName, $directoryPath, $port ) {
  $integrated=0
  
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
    if ($forceDelete -eq $false) {
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

  SetAccessRights $scanningPath $appName "Modify"
  SetAccessRights $processingPath $appName "Modify"
  SetAccessRights $processingPath $appName "Delete"
  SetAccessRights $processingPath $appName "DeleteSubDirectoriesAndFiles"
  
  return $true
}

# Check system requirements
if ((Test-Admin) -eq $false) {
  Write-Error "This script requires admin rights!"
  return
}

if ((get-module -name WebAdministration -erroraction silentlycontinue) -eq $false) {
    Write-Error "The Powershell module for WebAdministration is not installed! Please check your IIS installation!"
}

if ((IsAspNet4Installed) -eq $null) {
  Write-Error ".NET4.0 is not installed or not registered in IIS! Please check your Installation!"
  return
}

# Add system modules to access the WebAdministration modules
Get-Module -ListAvailable | Where-Object {$_.Path -like "$PSHOME*"} | Import-Module

# Built appName and directoryNames
$appName = $sitePrefix + "-" + $environment + "-sp.check24." + $sitePostfix
$webServicePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($websitesRoot, $appName))
$appPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($webServicePath, "Application"))
$logPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($webServicePath, "Logs"))

# check if Website already exists and exit the script when forceDelete == false
if (ExistsWebSite($appName)) {
  if ($forceDelete -eq $false) {
    Write-Warning "The webService '$appName' already exists!"
    return
  }
  else {
    Remove-Website -Name $appName
    Remove-WebAppPool -Name $appName
  }
}

WriteMessage
WriteMessage "Create WebService '$appName' on '$appPath'"

if (([System.IO.Directory]::Exists($webServicePath) -eq $true))
{
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

SetAccessRights $appPath $appName "Modify"
SetAccessRights $logPath $appName "Modify"

if ($createScanningFolders -eq $true) {
	CreateScanningDirectoriesAndSetAccessRights $webServicePath
}

WriteMessage
WriteMessage "WebService '$appName' was successful created!"