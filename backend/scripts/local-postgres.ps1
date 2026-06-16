param(
  [ValidateSet('start', 'stop')]
  [string]$Action = 'start'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $repoRoot '.local-postgres'
$dataDir = Join-Path $runtimeRoot 'data'
$logFile = Join-Path $runtimeRoot 'postgres.log'
$port = 55432
$pgBin = $env:PG_BIN

if (-not $pgBin) {
  $pgBin = 'C:\Program Files\PostgreSQL\18\bin'
}

$initdb = Join-Path $pgBin 'initdb.exe'
$pgCtl = Join-Path $pgBin 'pg_ctl.exe'
$psql = Join-Path $pgBin 'psql.exe'
$createdb = Join-Path $pgBin 'createdb.exe'

if (-not (Test-Path $runtimeRoot)) {
  New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
}

if ($Action -eq 'start') {
  if (-not (Test-Path (Join-Path $dataDir 'PG_VERSION'))) {
    & $initdb -D $dataDir -A trust -U postgres -E UTF8 | Out-Null
  }

  if (-not (Test-Path $logFile)) {
    New-Item -ItemType File -Force -Path $logFile | Out-Null
  }

  & $pgCtl -D $dataDir status | Out-Null
  if ($LASTEXITCODE -ne 0) {
    & $pgCtl -D $dataDir -l $logFile -o "-p $port" start | Out-Null
  }

  $dbExists = & $psql -h 127.0.0.1 -p $port -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='alisho_library';"
  if (($dbExists | Out-String).Trim() -ne '1') {
    & $createdb -h 127.0.0.1 -p $port -U postgres alisho_library | Out-Null
  }

  Write-Output "Local PostgreSQL started on 127.0.0.1:$port"
  exit 0
}

if (Test-Path (Join-Path $dataDir 'PG_VERSION')) {
  & $pgCtl -D $dataDir stop | Out-Null
  Write-Output "Local PostgreSQL stopped"
}
