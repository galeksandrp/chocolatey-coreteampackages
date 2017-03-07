. "$env:ChocolateyInstall\helpers\functions\Install-ChocolateyInstallPackage.ps1"
$installPackageFunc = Get-Item Function:\Install-ChocolateyInstallPackage | ? { $_.Parameters.ContainsKey('file64') }
if ($installPackageFunc) {
  return
}

Write-Debug "Loading Install-ChocolateyInstallPackage override"
Rename-Item Function:Install-ChocolateyInstallPackage Install-ChocolateyInstallPackageOriginal

<#
.SYNOPSIS
Simple wrapper to support easier selection of 32bit and 64bit install file.
**NOTE:** Administrative Access Required.
.DESCRIPTION
This will select the appropriate installer depending on the system environment
and the user passed arguments.
.PARAMETER PackageName
The name of the package - while this is an arbitrary value, it's
recommended that it matches the package id.
.PARAMETER FileType
This is the extension of the file. This can be 'exe', 'msi', or 'msu'.
.PARAMETER SilentArgs
OPTIONAL - These are the parameters to pass to the native installer,
including any arguments to make the installer silent/unattended.
.PARAMETER File
Full file path to the native 32bit installer to run.
OPTIONAL when File64 have been set.
.PARAMETER File64
Full file path to the native 64bit installer to run.
OPTIONAL when File have been set.
.PARAMETER ValidExitCodes
Array of exit codes indicating success. Defaults to `@(0)`.
.PARAMETER UseOnlyPackageSilentArguments
Do not allow choco to privde/merge additional silent arguments and
only use the ones available with the package. Available in 0.9.10+.
.PARAMETER IgnoredArguments
Allows splatting with argumnets that do not apply. Do not use directly.
.EXAMPLE
$packageName= 'bob'
$toolsDir   = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$fileLocation = Join-Path $toolsDir '32BIT_INSTALLER_EMBEDDED_IN_PACKAGE'
$fileLocation64 = Join-Path $toolsDir '64BIT_INSTALLER_EMBEDDED_IN_PACKAGE'

$packageArgs = @{
  packageName   = $packageName
  fileType      = 'msi'
  file          = $fileLocation
  file64        = $fileLocation64
  silentArgs    = "/qn /norestart"
  validExitCodes= @(0, 3010, 1641)
  softwareName  =
}

Install-ChocolateyInstallPackageEx @packageArgs
#>
function Install-ChocolateyInstallPackage {
  param(
    [parameter(Mandatory=$true, Position=0)][string] $packageName,
    [parameter(Mandatory=$false, Position=1)]
    [alias("installerType","installType")][string] $fileType = 'exe',
    [parameter(Mandatory=$false, Position=2)][string[]] $silentArgs = '',
    [alias("fileFullPath")][parameter(Mandatory=$false, Position=3)][string] $file,
    [alias("fileFullPath64")][Parameter(Mandatory=$false, Position=4)][string] $file64,
    [parameter(Mandatory=$false)] $validExitCodes = @(0),
    [parameter(Mandatory=$false)]
    [alias("useOnlyPackageSilentArgs")][switch] $useOnlyPackageSilentArguments = $false,
    [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
  )
  $bitnessMessage = ''
  $fileFullPath = $file
  if ((Get-ProcessorBits 32) -or $env:ChocolateyForceX86 -eq 'true') {
    if (!$file) { throw "32-bit installation is not supported for $packageName" }
    if ($file64) { $bitnessMessage = '32-bit ' }
  } elseif( $file64) {
    $fileFullPath = $file64
    $bitnessMessage = '64-bit '
  }

  if ($fileFullPath -eq '' -or $fileFullPath -eq $null) {
    throw "Package parameters incorrect, either File or File64 must be specified."
  }

  Write-Host "Installing $bitnessMessage$packageName..."

  $packageArgs = @{
    packageName    = $packageName
    fileType       = $fileType
    silentArgs     = $silentArgs
    file           = $fileFullPath
    validExitCodes = $validExitCodes
    useOnlyPackageSilentArgs = $useOnlyPackageSilentArguments
    ignoredArguments = $ignoredArguments
  }

  Install-ChocolateyInstallPackageOriginal @packageArgs
}

# We need to force the export of Install-ChocolateyInstall function
Export-ModuleMember -Function Install-ChocolateyInstallPackage
