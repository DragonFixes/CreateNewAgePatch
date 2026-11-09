#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the Create New Age Patch mod jar.

.DESCRIPTION
    Compiles src\main\java with javac against the Forge, Mixin, ASM and
    log4j jars from a Forge/Mohist 1.20.1 server's libraries folder, adds
    src\main\resources and the MixinConfigs manifest entry, and writes
    build\createnewagepatch-<version>.jar. No Gradle is involved; the mod needs
    no Minecraft classes at compile time.

.PARAMETER LibrariesDir
    A 1.20.1 Forge or Mohist server's "libraries" folder. Defaults to the
    Com (SRV) (T) test server under {USERPROFILE}\curseforge.

.PARAMETER Version
    Version written into mods.toml and the jar name. Defaults to the value in
    gradle.properties-style file "version.txt" beside this script.

.PARAMETER Jdk
    JDK home containing bin\javac.exe and bin\jar.exe. Defaults to JAVA_HOME,
    then the javac on PATH.

.PARAMETER CopyTo
    Optional mods folder to copy the built jar into.

.EXAMPLE
    .\build.ps1

.EXAMPLE
    .\build.ps1 -CopyTo "$env:USERPROFILE\curseforge\minecraft\Instances\Com (SRV) (T)\mods"

.EXAMPLE
    .\build.ps1 -LibrariesDir D:\servers\pack\libraries -Version 1.0.1
#>
[CmdletBinding()]
param(
    [string]$LibrariesDir = (Join-Path $env:USERPROFILE 'curseforge\minecraft\Instances\Com (SRV) (T)\libraries'),
    [string]$Version,
    [string]$Jdk,
    [string]$CopyTo
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

try {
    if (-not $Version) { $Version = (Get-Content (Join-Path $root 'version.txt') -TotalCount 1).Trim() }

    if (-not $Jdk) {
        if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\javac.exe'))) { $Jdk = $env:JAVA_HOME }
        else {
            # The javac on PATH may be a launcher shim (Oracle's javapath), so ask
            # the JVM for its real home instead of walking up from the shim.
            $props = & java -XshowSettings:properties -version 2>&1 | Out-String
            if ($props -match 'java\.home = (.+)') { $Jdk = $Matches[1].Trim() }
        }
    }
    $javac = Join-Path $Jdk 'bin\javac.exe'
    $jarExe = Join-Path $Jdk 'bin\jar.exe'
    if (-not (Test-Path $javac)) { throw "javac not found under $Jdk" }

    if (-not (Test-Path $LibrariesDir)) { throw "Libraries folder not found: $LibrariesDir" }
    $patterns = 'javafmllanguage-1.20.1-*.jar', 'fmlcore-1.20.1-*.jar', 'mixin-0.8*.jar',
                'asm-9*.jar', 'asm-tree-9*.jar', 'log4j-api-2*.jar'
    $cp = foreach ($p in $patterns) {
        $hit = Get-ChildItem $LibrariesDir -Recurse -Filter $p | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $hit) { throw "Missing library matching $p in $LibrariesDir" }
        $hit.FullName
    }

    $build = Join-Path $root 'build'
    $classes = Join-Path $build 'classes'
    if (Test-Path $build) { Remove-Item $build -Recurse -Force }   # regenerable output
    New-Item -ItemType Directory -Force $classes | Out-Null

    $sources = Get-ChildItem (Join-Path $root 'src\main\java') -Recurse -Filter *.java | ForEach-Object FullName
    # -proc:none: the Mixin jar ships an annotation processor for refmaps; this
    # mod targets classes by name and needs no refmap.
    & $javac --release 17 -encoding UTF-8 -nowarn -proc:none -cp ($cp -join ';') -d $classes @sources
    if ($LASTEXITCODE -ne 0) { throw "javac failed ($LASTEXITCODE)" }

    Copy-Item (Join-Path $root 'src\main\resources\*') $classes -Recurse -Force
    $toml = Join-Path $classes 'META-INF\mods.toml'
    (Get-Content $toml -Raw).Replace('${version}', $Version) | Set-Content $toml -NoNewline -Encoding UTF8

    $manifest = Join-Path $build 'MANIFEST.MF'
    @(
        'Manifest-Version: 1.0'
        'MixinConfigs: createnewagepatch.mixins.json'
        "Implementation-Title: createnewagepatch"
        "Implementation-Version: $Version"
        ''
    ) -join "`r`n" | Set-Content $manifest -NoNewline -Encoding ASCII

    $out = Join-Path $build "createnewagepatch-$Version.jar"
    & $jarExe --create --file $out --manifest $manifest -C $classes .
    if ($LASTEXITCODE -ne 0) { throw "jar failed ($LASTEXITCODE)" }
    Write-Host "Built $out"

    if ($CopyTo) {
        Copy-Item $out $CopyTo -Force
        Write-Host "Copied to $CopyTo"
    }
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
