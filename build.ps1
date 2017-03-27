param(
   [switch]
   $Publish,

   [string]
   $NuGetApiKey
)

#$preview = "-alpha-1"
$gv = "3.5.4"
$vt = @{
   "Storage.Net.Microsoft.Azure.DataLake.Store.csproj" = "1.0.0-alpha-1";
   "Storage.Net.Amazon.Aws" = "3.5.4";
   "Storage.Net.Microsoft.Azure" = "3.5.4";
}

$Copyright = "Copyright (c) 2015-2017 by Ivan Gavryliuk"
$PackageIconUrl = "http://i.isolineltd.com/nuget/storage.png"
$PackageProjectUrl = "https://github.com/aloneguid/storage"
$RepositoryUrl = "https://github.com/aloneguid/storage"
$Authors = "Ivan Gavryliuk (@aloneguid)"
$PackageLicenseUrl = "https://github.com/aloneguid/storage/blob/master/LICENSE"
$RepositoryType = "GitHub"

$SlnPath = "src\storage.sln"

function Set-VstsBuildNumber($BuildNumber)
{
   Write-Verbose -Verbose "##vso[build.updatebuildnumber]$BuildNumber"
}

function Update-ProjectVersion($File)
{
   $v = $vt.($File.Name)
   if($v -eq $null) { $v = $gv }

   $xml = [xml](Get-Content $File.FullName)

   if($xml.Project.PropertyGroup.Count -eq $null)
   {
      $pg = $xml.Project.PropertyGroup
   }
   else
   {
      $pg = $xml.Project.PropertyGroup[0]
   }

   $fv = "{0}.{1}.{2}.0" -f $parts[0], $parts[1], $parts[2]
   $av = "{0}.0.0.0" -f $parts[0]
   $pv = $v

   $pg.Version = $pv
   $pg.FileVersion = $fv
   $pg.AssemblyVersion = $av

   Write-Host "$($File.Name) => fv: $fv, av: $av, pkg: $pv"

   $pg.Copyright = $Copyright
   $pg.PackageIconUrl = $PackageIconUrl
   $pg.PackageProjectUrl = $PackageProjectUrl
   $pg.RepositoryUrl = $RepositoryUrl
   $pg.Authors = $Authors
   $pg.PackageLicenseUrl = $PackageLicenseUrl
   $pg.RepositoryType = $RepositoryType

   $xml.Save($File.FullName)
}

function Exec($Command)
{
   Invoke-Expression $Command
   if($LASTEXITCODE -ne 0)
   {
      Write-Error "command failed (error code: $LASTEXITCODE)"
      exit 1
   }
}

# General validation
if($Publish -and (-not $NuGetApiKey))
{
   Write-Error "Please specify nuget key to publish"por
   exit 1
}

# Update versioning information
Get-ChildItem *.csproj -Recurse | Where-Object {-not($_.Name -like "*test*")} | % {
   Update-ProjectVersion $_
}
Set-VstsBuildNumber $Version

# Restore packages
Exec "dotnet restore $SlnPath"

# Build solution
Get-ChildItem *.nupkg -Recurse | Remove-Item -Verbose
Exec "dotnet build $SlnPath -c release"

# Run the tests
#Exec "dotnet test test\LogMagic.Test\LogMagic.Test.csproj"

# publish the nugets
if($Publish.IsPresent)
{
   Write-Host "publishing nugets..."

   Get-ChildItem *.nupkg -Recurse | % {
      $path = $_.FullName
      Write-Host "publishing from $path"

      Exec "nuget push $path -Source https://www.nuget.org/api/v2/package -ApiKey $NuGetApiKey"
   }
}

Write-Host "build succeeded."