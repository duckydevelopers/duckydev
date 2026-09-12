# Ducky Fixer - Windows PowerShell 5.1 / PowerShell 7, Windows 10/11 x86/x64.
# Publish this file as raw text over HTTPS after configuring these values.
& {
    # OPTIONAL TROUBLESHOOTER: leave the URL empty to run only the runtime fixes.
    # To enable: paste your direct .exe link and its SHA256 below.
    # Get the hash with: Get-FileHash .\troubleshooter.exe -Algorithm SHA256
    $Config = @{
        TroubleshooterUrl = '' # Paste link here. Empty = skip troubleshooter.
        TroubleshooterSha256 = '' # Only required when a URL is provided.
        TroubleshooterArguments = ''
    }
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    $work = $null
    $log = $null
    $reboot = $false

    function Write-Ducky([string]$Text) {
        if ($env:WT_SESSION -or $env:TERM -match 'xterm') {
            $esc = [char]27
            $output = for ($i = 0; $i -lt $Text.Length; $i++) {
                $g = [int](225 - 65 * $i / [Math]::Max(1, $Text.Length - 1))
                "$esc[38;2;255;${g};45m$($Text[$i])"
            }
            Write-Host (($output -join '') + "$esc[0m")
        } else { Write-Host $Text -ForegroundColor Yellow }
    }
    function Write-Status([string]$Text) {
        Write-Ducky "  $Text"
        if ($log) { Add-Content -LiteralPath $log -Value "$(Get-Date -Format o) $Text" }
    }
    function Confirm-Fix([string]$Name, [string]$Details) {
        Write-Ducky "  $Name"
        Write-Ducky "  $Details"
        $accepted = (Read-Host "  Run ${Name}? [y/N]").Trim() -match '^(?i:y|yes)$'
        Write-Status "Consent for ${Name}: $accepted"
        return $accepted
    }
    function Get-FixChoice {
        while ($true) {
            Write-Ducky '  GENERAL FIXER'
            Write-Ducky '  1. DirectX + Visual C++ runtimes'
            Write-Ducky '  2. D3DCOMPILER_43.dll missing (DirectX)'
            Write-Ducky '  3. VCRUNTIME / MSVCP missing (Visual C++)'
            Write-Ducky '  4. Blocked or incompatible driver help'
            Write-Ducky '  5. Smart App Control / Defender block help'
            Write-Ducky '  0. Quit'
            $choice = (Read-Host '  Choose [0-5]').Trim()
            switch ($choice) {
                '4' {
                    Write-Ducky '  Note the driver filename in the Windows Security alert.'
                    Write-Ducky '  Get a compatible update from Windows Update or the device/app vendor.'
                    Write-Ducky '  If none is available, contact the vendor before using that driver.'
                    Write-Ducky '  No driver or security settings were changed.'
                }
                '5' {
                    Write-Ducky '  Read the block notification and note the file and detection name.'
                    Write-Ducky '  Obtain an updated, signed release from the official app publisher.'
                    Write-Ducky '  Ask the publisher to investigate a suspected incorrect detection.'
                    Write-Ducky '  No app or security settings were changed.'
                }
                { $_ -in @('0', '1', '2', '3') } { return $choice }
                default { Write-Ducky '  Enter a number from 0 to 5.' }
            }
        }
    }
    function Get-Package([string]$Url, [string]$Name, [string]$Sha256 = '') {
        if (([uri]$Url).Scheme -ne 'https') { throw 'Download URLs must use HTTPS.' }
        $path = Join-Path $work $Name
        Write-Status "Downloading $Name..."
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $path -TimeoutSec 300
        if ($Sha256) {
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $Sha256) {
                throw "Checksum mismatch: $Name"
            }
        } else {
            $signature = Get-AuthenticodeSignature -LiteralPath $path
            if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') {
                throw "Microsoft signature verification failed: $Name"
            }
        }
        return $path
    }
    function Invoke-Package([string]$Path, [string]$Arguments, [int[]]$SuccessCodes = @(0, 3010)) {
        $start = @{ FilePath = $Path; Wait = $true; PassThru = $true }
        if ($Arguments) { $start.ArgumentList = $Arguments }
        $process = Start-Process @start
        Write-Status "$([IO.Path]::GetFileName($Path)): exit code $($process.ExitCode)"
        if ($process.ExitCode -notin $SuccessCodes) { throw "Installer failed with exit code $($process.ExitCode)." }
        if ($process.ExitCode -eq 3010) { Set-Variable -Name reboot -Value $true -Scope 1 }
    }
    function Test-LegacyDirectX {
        # A presence heuristic, not a complete runtime integrity check.
        $folders = @((Join-Path $env:WINDIR 'System32'))
        if ([Environment]::Is64BitOperatingSystem) { $folders += Join-Path $env:WINDIR 'SysWOW64' }
        foreach ($folder in $folders) {
            foreach ($dll in @('d3dx9_43.dll', 'd3dx10_43.dll', 'd3dx11_43.dll', 'D3DCompiler_43.dll', 'xinput1_3.dll', 'XAudio2_7.dll')) {
                if (-not (Test-Path -LiteralPath (Join-Path $folder $dll))) { return $false }
            }
        }
        return $true
    }

    try {
        @'

       __
     <(o )___     D U C K Y   F I X E R
      ( ._> /    ---------------------
       `---'     A little duck. A fresh start.

'@ -split "`n" | ForEach-Object { Write-Ducky $_ }
        if ($env:OS -ne 'Windows_NT') { throw 'Ducky Fixer requires Windows.' }
        if ([Environment]::OSVersion.Version.Build -lt 10240) { throw 'Windows 10 or newer is required.' }
        if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { throw 'This build supports x86/x64 Windows only.' }
        if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) { throw 'Open 64-bit PowerShell and run the command again.' }
        $choice = Get-FixChoice
        if ($choice -eq '0') { return }
        $Config.TroubleshooterUrl = $Config.TroubleshooterUrl.Trim()
        $Config.TroubleshooterSha256 = $Config.TroubleshooterSha256.Trim()
        if ($Config.TroubleshooterUrl) {
            if ($Config.TroubleshooterSha256 -notmatch '^[a-fA-F0-9]{64}$') {
                throw 'A troubleshooter URL is set. Add its SHA256 at the top, or leave the URL blank to skip it.'
            }
            if (([uri]$Config.TroubleshooterUrl).Scheme -ne 'https') { throw 'The troubleshooter URL must use HTTPS.' }
        }
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Open PowerShell using Run as administrator, then run the command again.'
        }
        Write-Ducky '  You will be asked before each selected fix runs.'
        Write-Ducky '  Keep antivirus enabled. If it blocks a file, stop and review the alert.'
        Write-Ducky '  Downloads and system installations require your consent.'
        if ($Config.TroubleshooterUrl) {
            Write-Ducky "  Runs this troubleshooter first: $($Config.TroubleshooterUrl)"
        } else {
            Write-Ducky '  Troubleshooter: not configured (skipped).'
        }
        if ((Read-Host '  Continue? [y/N]').Trim() -notmatch '^(?i:y|yes)$') {
            Write-Ducky '  Cancelled. No downloads or installations were started.'
            return
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $work = Join-Path ([IO.Path]::GetTempPath()) ('DuckyFixer-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        $logDirectory = Join-Path $env:LOCALAPPDATA 'DuckyFixer\Logs'
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        $log = Join-Path $logDirectory ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N') + '.log')
        Write-Status "General Fixer selection: $choice; session consent: True"
        if ($Config.TroubleshooterUrl) {
            if (Confirm-Fix 'optional troubleshooter' "Downloads and runs $($Config.TroubleshooterUrl) as administrator. Its changes depend on that program.") {
                Write-Status 'Starting troubleshooter. Close it when finished to continue.'
                $exe = Get-Package $Config.TroubleshooterUrl 'troubleshooter.exe' $Config.TroubleshooterSha256
                Invoke-Package $exe $Config.TroubleshooterArguments
            } else { Write-Status 'Troubleshooter skipped.' }
        } else {
            Write-Status 'No troubleshooter configured. Skipping.'
        }

        if ($choice -in @('1', '2')) {
            if (Confirm-Fix 'DirectX runtime fix' 'Installs Microsoft legacy DirectX components if needed. These components cannot be uninstalled; existing installs are retained if a later step fails.') {
                Write-Status 'Checking legacy DirectX runtime files...'
                if ((Test-LegacyDirectX) -and $choice -ne '2') {
                    Write-Status 'Common legacy DirectX files are present; skipping installation.'
                } else {
                    try {
                        $exe = Get-Package 'https://download.microsoft.com/download/1/7/1/1718ccc4-6315-4d8e-9543-8e28a4e18c4c/dxwebsetup.exe' 'dxwebsetup.exe'
                        Invoke-Package $exe '/Q'
                        if (-not (Test-LegacyDirectX)) { throw 'Runtime files are still missing.' }
                    } catch {
                        Write-Status "Web setup did not complete: $($_.Exception.Message) Using offline DirectX package."
                        $exe = Get-Package 'https://download.microsoft.com/download/8/4/a/84a35bf1-dafe-4ae8-82af-ad2ae20b6b14/directx_Jun2010_redist.exe' 'directx-redist.exe'
                        $extract = Join-Path $work 'DirectX'
                        New-Item -ItemType Directory -Path $extract | Out-Null
                        Invoke-Package $exe ('/Q /T:"{0}"' -f $extract)
                        $setup = Join-Path $extract 'DXSETUP.exe'
                        $signature = Get-AuthenticodeSignature -LiteralPath $setup
                        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') { throw 'Invalid DirectX setup signature.' }
                        Invoke-Package $setup '/silent'
                        if (-not (Test-LegacyDirectX)) { throw 'DirectX runtime files remain missing after offline setup.' }
                    }
                    Write-Status 'DirectX setup completed. Save your work, restart Windows, then try the affected app again.'
                }
            } else { Write-Status 'DirectX fix skipped.' }
        }

        if ($choice -in @('1', '3')) {
            if (Confirm-Fix 'Visual C++ runtime fix' 'Installs Microsoft Visual C++ 2005-v14 packages, including unsupported legacy versions. A restart may be needed. Completed installs are retained if a later step fails.') {
                Write-Status 'Visual C++ runtimes all-in-one installation...'
                $packages = @(
                    @{ Version = '2005'; Url = 'https://download.microsoft.com/download/8/b/4/8b42259f-5d70-43f4-ac2e-4b208fd8d66a/vcredist_{0}.EXE'; Args = '/q /r:n' }
                    @{ Version = '2008'; Url = 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_{0}.exe'; Args = '/q /norestart' }
                    @{ Version = '2010'; Url = 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_{0}.exe'; Args = '/q /norestart' }
                    @{ Version = '2012'; Url = 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_{0}.exe'; Args = '/install /quiet /norestart' }
                    @{ Version = '2013'; Url = 'https://aka.ms/highdpimfc2013{0}enu'; Args = '/install /quiet /norestart' }
                    @{ Version = 'v14'; Url = 'https://aka.ms/vc14/vc_redist.{0}.exe'; Args = '/install /quiet /norestart' }
                )
                $architectures = @('x86')
                if ([Environment]::Is64BitOperatingSystem) { $architectures += 'x64' }
                foreach ($package in $packages) {
                    foreach ($architecture in $architectures) {
                        $name = "vc-$($package.Version)-$architecture.exe"
                        $exe = Get-Package ($package.Url -f $architecture) $name
                        # 1638 / 0x80070666 mean another/newer version is already installed.
                        Invoke-Package $exe $package.Args @(0, 3010, 1638, -2147023258)
                    }
                }
                Write-Status 'Visual C++ setup completed. Try the affected app again after any required restart.'
            } else { Write-Status 'Visual C++ fix skipped.' }
        }
        Write-Status 'Session finished. See the log for completed and skipped steps.'
        if ($reboot) { Write-Status 'A restart is required. Restart Windows when convenient.' }
    } catch {
        Write-Status "Stopped: $($_.Exception.Message)"
        throw
    } finally {
        if ($log) { Write-Ducky "  Log: $log" }
        if ($work -and (Test-Path -LiteralPath $work)) {
            $resolved = [IO.Path]::GetFullPath($work)
            $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
            if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved) -match '^DuckyFixer-[a-f0-9]{32}$') {
                Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
