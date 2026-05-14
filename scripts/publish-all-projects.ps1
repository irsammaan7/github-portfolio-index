#Requires -Version 5.1
<#
.SYNOPSIS
  Create missing GitHub repos (irsammaan7) and push each local project.
  Uses: git -C "<dir>" (avoids Push-Location + PATH edge cases).
#>
$ErrorActionPreference = 'Stop'
$User = 'irsammaan7'
$Base = "C:\Users\Irsam Maan\OneDrive\Desktop\University"
$GitExe = "C:\Program Files\Git\mingw64\bin\git.exe"

function Invoke-Git {
  param([string]$Dir, [string[]]$GitArgs)
  & $GitExe -C $Dir @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "git $($GitArgs -join ' ') failed (exit $LASTEXITCODE) in $Dir"
  }
}

function Get-GitHubToken {
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
  $p.StartInfo.FileName = $GitExe
  $p.StartInfo.Arguments = "credential fill"
  $p.StartInfo.RedirectStandardInput = $true
  $p.StartInfo.RedirectStandardOutput = $true
  $p.StartInfo.RedirectStandardError = $true
  $p.StartInfo.UseShellExecute = $false
  $p.StartInfo.WorkingDirectory = $Base
  [void]$p.Start()
  $p.StandardInput.Write("protocol=https`nhost=github.com`n`n")
  $p.StandardInput.Close()
  $out = $p.StandardOutput.ReadToEnd()
  $null = $p.WaitForExit()
  if ($p.ExitCode -ne 0) { throw "git credential fill failed: $out" }
  $line = ($out -split "`r?`n" | Where-Object { $_ -match '^password=' } | Select-Object -First 1)
  if (-not $line) { throw "No GitHub token from credential helper." }
  return ($line -replace '^password=','')
}

function Test-RepoExists([string]$Repo) {
  try {
    $r = Invoke-WebRequest -Uri "https://github.com/$User/$Repo" -Method Head -MaximumRedirection 0 -UseBasicParsing -TimeoutSec 15
    return ($r.StatusCode -eq 200)
  } catch {
    return $false
  }
}

function Get-RepoDescription([string]$ProjectDir, [string]$Repo) {
  $n = Join-Path $ProjectDir 'GITHUB_REPO_NOTES.txt'
  if (-not (Test-Path $n)) { return $Repo }
  $t = Get-Content -Raw -Path $n
  if ($t -match '(?ms)Suggested GitHub description:\s*\r?\n\s*(.+?)\s*\r?\n') { return $Matches[1].Trim() }
  return $Repo
}

function New-GitHubRepo([string]$Token, [string]$Repo, [string]$Description) {
  $headers = @{
    Authorization = "Bearer $Token"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
  }
  $body = (@{
      name = $Repo
      description = ($Description.Substring(0, [Math]::Min(350, $Description.Length)))
      private = $false
      auto_init = $false
    } | ConvertTo-Json)
  try {
    Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Method Post -Headers $headers -Body $body -ContentType 'application/json; charset=utf-8'
    return $true
  } catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code -eq 422) {
      Write-Host "  (create 422: repo may already exist) $Repo"
      return $false
    }
    throw
  }
}

$projects = @(
  @{ Rel = 'FYP'; Repo = 'fortilm-fyp' }
  @{ Rel = '7th Semester\Applied ML\i227435_A03\cicids2017-intrusion-detection'; Repo = 'cicids2017-intrusion-detection' }
  @{ Rel = '7th Semester\SSD\Assignment 3\owasp-api-vuln-lab-assignment-03'; Repo = 'owasp-api-security-lab' }
  @{ Rel = '8th Semester\Blockchain\Blockchain Project'; Repo = 'chainpoll-blockchain-dapp' }
  @{ Rel = '6th  semester\Infosec\i227435_7441_7427_Project\Code_i22_7441_7427_7435'; Repo = 'shamir-secret-sharing' }
  @{ Rel = '6th  semester\Ethical\22i_7435_Packet_Sniffer'; Repo = 'packet-sniffer-scapy' }
  @{ Rel = '7th Semester\SSD\Labtask9'; Repo = 'flask-ssd-crud-lab' }
  @{ Rel = '5th Semester\Database\DB_PROJECT'; Repo = 'aspnet-student-db-crud' }
  @{ Rel = '7th Semester\OS'; Repo = 'os-concurrency-neural-pipeline' }
  @{ Rel = '8th Semester\PDC'; Repo = 'pdc-parallel-computing' }
  @{ Rel = '5th Semester\Computer Networks'; Repo = 'computer-networks-labs' }
  @{ Rel = '5th Semester\Cyber 2'; Repo = 'cyber-2-packet-tracer' }
  @{ Rel = '6th  semester\VA&RE'; Repo = 'vare-coursework' }
  @{ Rel = '7th Semester\Information Assurance\Info Project'; Repo = 'information-assurance-policy-pack' }
  @{ Rel = '6th  semester\AI'; Repo = 'ai-course-labs' }
  @{ Rel = '4th Semester\Data Structures'; Repo = 'data-structures-coursework' }
  @{ Rel = '4th Semester\Web Programming'; Repo = 'web-programming-coursework' }
  @{ Rel = '5th Semester\Algo'; Repo = 'algorithms-coursework' }
  @{ Rel = '3rd semester\Programming Fundamentals Coding'; Repo = 'programming-fundamentals-cpp' }
  @{ Rel = '3rd semester\Object Oriented Programming'; Repo = 'oop-semester-3' }
  @{ Rel = '4th Semester\Object Oriented Programming'; Repo = 'oop-semester-4' }
  @{ Rel = '4th Semester\COAL'; Repo = 'coal-assembly-labs' }
  @{ Rel = '3rd semester\DLD'; Repo = 'dld-proteus-labs' }
  @{ Rel = '3rd semester\FSE'; Repo = 'fse-coursework' }
  @{ Rel = '4th Semester\TBW'; Repo = 'tbw-coursework' }
  @{ Rel = '4th Semester\Marketing'; Repo = 'marketing-coursework' }
  @{ Rel = '8th Semester\Entre'; Repo = 'entrepreneurship-coursework' }
  @{ Rel = '8th Semester\PPIT'; Repo = 'ppit-coursework' }
)

Write-Host "Getting GitHub token..."
$token = Get-GitHubToken

foreach ($item in $projects) {
  $repo = $item.Repo
  $dir = Join-Path $Base $item.Rel
  Write-Host "`n=== $repo ==="
  if (-not (Test-Path $dir)) {
    Write-Warning "Missing folder: $dir"
    continue
  }
  if (-not (Test-Path (Join-Path $dir '.git'))) {
    Write-Warning "Not a git repo: $dir"
    continue
  }

  $desc = Get-RepoDescription $dir $repo
  $exists = Test-RepoExists $repo
  if (-not $exists) {
    Write-Host "Creating GitHub repo $repo ..."
    [void](New-GitHubRepo $token $repo $desc)
    Start-Sleep -Milliseconds 500
  } else {
    Write-Host "Repo exists on GitHub: $repo"
  }

  $url = "https://github.com/$User/$repo.git"
  $oldEa = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'
  & $GitExe -C $dir remote get-url origin 2>$null | Out-Null
  $hasOrigin = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $oldEa
  if ($hasOrigin) {
    Invoke-Git $dir @('remote', 'set-url', 'origin', $url)
  } else {
    Invoke-Git $dir @('remote', 'add', 'origin', $url)
  }

  $branch = (& $GitExe -C $dir branch --show-current 2>$null).Trim()
  if (-not $branch) { $branch = 'main' }
  Write-Host "Pushing branch $branch ..."
  try {
    Invoke-Git $dir @('push', '-u', 'origin', $branch)
    Write-Host "OK: https://github.com/$User/$repo"
  } catch {
    Write-Warning "Push failed for ${repo}: $_"
    Write-Host "  Retry later or run: git -C `"$dir`" push -u origin $branch"
  }
}

Write-Host "`nDone. https://github.com/${User}?tab=repositories"
