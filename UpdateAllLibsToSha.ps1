<#
.SYNOPSIS
    Updates the libgit2 submodule to the specified commit and updates libgit2_hash.txt and NativeBinaries.props with the new hash value.
.PARAMETER libgit2sha
    Desired libgit2 version. This is run through `git rev-parse`, so branch names are okay too.
.PARAMETER libssh2sha
    Desired libssh2 version. This is run through `git rev-parse`, so branch names are okay too.
.PARAMETER zlibsha
    Desired zlib version. This is run through `git rev-parse`, so branch names are okay too.
#>

Param(
    [string]$libgit2sha = 'HEAD',
    [string]$libssh2sha = 'HEAD',
    [string]$zlibsha = 'HEAD'
)

Set-StrictMode -Version Latest

$self = Split-Path -Leaf $MyInvocation.MyCommand.Path
$projectDirectory = Split-Path $MyInvocation.MyCommand.Path
$libgit2Directory = Join-Path $projectDirectory "libgit2"
$libssh2Directory = Join-Path $projectDirectory "libssh2"
$zlibDirectory = Join-Path $projectDirectory "zlib"

function Invoke-Command([scriptblock]$Command, [switch]$Fatal, [switch]$Quiet) {
    $output = ""
    if ($Quiet) {
        $output = & $Command 2>&1
    } else {
        & $Command
    }

    if (!$Fatal) {
        return
    }

    $exitCode = 0
    if ($LastExitCode -ne 0) {
        $exitCode = $LastExitCode
    } elseif (!$?) {
        $exitCode = 1
    } else {
        return
    }

    $error = "``$Command`` failed"
    if ($output) {
        Write-Host -ForegroundColor yellow $output
        $error += ". See output above."
    }
    Throw $error
}

function Find-Git {
    $git = @(Get-Command git)[0] 2>$null
    if ($git) {
        $git = $git.Definition
        Write-Host -ForegroundColor Gray "Using git: $git"
        & $git --version | write-host -ForegroundColor Gray
        return $git
    }
    throw "Error: Can't find git"
}

function Update-Lib($git, $lib, $directory, [ref]$sha) {
    Push-Location $directory

    Write-Output "$lib -> Fetching..."
    Invoke-Command -Quiet { & $git fetch }

    Write-Output "$lib -> Verifying $($sha.value)..."
    $sha.value = & $git rev-parse $sha.value
    if ($LASTEXITCODE -ne 0) {
        write-host -foregroundcolor red "Error: invalid SHA. USAGE: $self <SHA>"
        popd
        break
    }

    Write-Output "$lib -> Checking out $($sha.value)..."
    Invoke-Command -Quiet -Fatal { & $git checkout $sha.value }

    Pop-Location
}

Push-Location $libgit2Directory

& {
    trap {
        Pop-Location
        break
    }

    $git = Find-Git

    
    Update-Lib $git "libgit2" $libgit2Directory ([ref]$libgit2sha)
    Update-Lib $git "libssh2" $libssh2Directory ([ref]$libssh2sha)
    Update-Lib $git "zlib" $zlibDirectory ([ref]$zlibsha)

    # Write-Output "Fetching..."
    # Invoke-Command -Quiet { & $git fetch }

    # Write-Output "Verifying $sha..."
    # $sha = & $git rev-parse $sha
    # if ($LASTEXITCODE -ne 0) {
    #     write-host -foregroundcolor red "Error: invalid SHA. USAGE: $self <SHA>"
    #     Pop-Location
    #     break
    # }

    # Write-Output "Checking out $sha..."
    # Invoke-Command -Quiet -Fatal { & $git checkout $sha }

    # Pop-Location

    # $binaryFilename = "git2-" + $sha.Substring(0,7)
    $libgit2binaryFilename = "git2-ssh-net-" + $libgit2sha.Substring(0,7)
    $libssh2binaryFilename = "libssh2-" + $libssh2sha.Substring(0,7)
    $zlibbinaryFilename = "zlib-" + $zlibsha.Substring(0,7)

    Set-Content -Encoding ASCII (Join-Path $projectDirectory "nuget.package\libgit2\libgit2_hash.txt") $libgit2sha
    Set-Content -Encoding ASCII (Join-Path $projectDirectory "nuget.package\libgit2\libssh2_hash.txt") $libssh2sha
    Set-Content -Encoding ASCII (Join-Path $projectDirectory "nuget.package\libgit2\zlib_hash.txt") $zlibsha

    Copy-Item -Path (Join-Path $libgit2Directory "COPYING") -Destination (Join-Path $projectDirectory "nuget.package\libgit2\libgit2.license.txt")

    $buildProperties = @"
<Project>
  <PropertyGroup>
    <libgit2_propsfile>`$(MSBuildThisFileFullPath)</libgit2_propsfile>
    <libgit2_hash>$libgit2sha</libgit2_hash>
    <libgit2_filename>$libgit2binaryFilename</libgit2_filename>
  </PropertyGroup>
</Project>
"@

    Set-Content -Encoding UTF8 (Join-Path $projectDirectory "nuget.package\build\LibGit2Sharp-ssh-net.NativeBinaries.props") $buildProperties

    $net46BuildProperties = @"
<Project>
  <PropertyGroup>
    <libgit2_propsfile>`$(MSBuildThisFileFullPath)</libgit2_propsfile>
    <libgit2_hash>$libgit2sha</libgit2_hash>
    <libgit2_filename>$libgit2binaryFilename</libgit2_filename>
  </PropertyGroup>
  <ItemGroup>
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\runtimes\win-x86\native\*" TargetPath="lib\win32\x86\%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" />
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\runtimes\win-x64\native\*" TargetPath="lib\win32\x64\%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" />
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\runtimes\win-arm64\native\*" TargetPath="lib\win32\arm64\%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" />
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\runtimes\**\*`" Exclude="`$(MSBuildThisFileDirectory)\..\..\runtimes\win-*\**\*" TargetPath="lib\%(RecursiveDir)..\%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" />
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\libgit2\LibGit2Sharp.dll.config" TargetPath="LibGit2Sharp.dll.config" CopyToOutputDirectory="PreserveNewest" />
  </ItemGroup>
</Project>
"@

    Set-Content -Encoding UTF8 (Join-Path $projectDirectory "nuget.package\build\net46\LibGit2Sharp-ssh-net.NativeBinaries.props") $net46BuildProperties

    $netBuildProperties = @"
<Project>
  <PropertyGroup>
    <libgit2_propsfile>`$(MSBuildThisFileFullPath)</libgit2_propsfile>
    <libgit2_hash>$libgit2sha</libgit2_hash>
    <libgit2_filename>$libgit2binaryFilename</libgit2_filename>
  </PropertyGroup>
  <ItemGroup>
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\runtimes\win-x86\native\*.dll" TargetPath="lib\win32\x86\%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" />
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\runtimes\win-x64\native\*.dll" TargetPath="lib\win32\x64\%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" />
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\runtimes\win-arm64\native\*" TargetPath="lib\win32\arm64\%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" />
    <ContentWithTargetPath Include="`$(MSBuildThisFileDirectory)\..\..\runtimes\**\*`" Exclude="`$(MSBuildThisFileDirectory)\..\..\runtimes\win-*\**\*" TargetPath="lib\%(RecursiveDir)..\%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" />
  </ItemGroup>
</Project>
"@
    Set-Content -Encoding UTF8 (Join-Path $projectDirectory "nuget.package\build\net6.0\LibGit2Sharp-ssh-net.NativeBinaries.props") $netBuildProperties
    Set-Content -Encoding UTF8 (Join-Path $projectDirectory "nuget.package\build\net7.0\LibGit2Sharp-ssh-net.NativeBinaries.props") $netBuildProperties
    Set-Content -Encoding UTF8 (Join-Path $projectDirectory "nuget.package\build\net8.0\LibGit2Sharp-ssh-net.NativeBinaries.props") $netBuildProperties

    $dllConfig = @"
<configuration>
    <dllmap os="linux" cpu="x86-64" wordsize="64" dll="$libgit2binaryFilename" target="lib/linux-x64/lib$libgit2binaryFilename.so" />
    <dllmap os="linux" cpu="arm" wordsize="32" dll="$libgit2binaryFilename" target="lib/linux-arm/lib$libgit2binaryFilename.so" />
    <dllmap os="linux" cpu="armv8" wordsize="64" dll="$libgit2binaryFilename" target="lib/linux-arm64/lib$libgit2binaryFilename.so" />
    <dllmap os="linux-musl" cpu="x86-64" wordsize="64" dll="$libgit2binaryFilename" target="lib/linux-musl-x64/lib$libgit2binaryFilename.so" />
    <dllmap os="linux-musl" cpu="armv8" wordsize="64" dll="$libgit2binaryFilename" target="lib/linux-musl-arm64/lib$libgit2binaryFilename.so" />
    <dllmap os="osx" cpu="x86-64" wordsize="64" dll="$libgit2binaryFilename" target="lib/osx-x64/lib$libgit2binaryFilename.dylib" />
    <dllmap os="osx" cpu="armv8" wordsize="64" dll="$libgit2binaryFilename" target="lib/osx-arm64/lib$libgit2binaryFilename.dylib" />
</configuration>
"@

    Set-Content -Encoding UTF8 (Join-Path $projectDirectory "nuget.package\libgit2\LibGit2Sharp.dll.config") $dllConfig

    Write-Output "Done!"
}
exit
