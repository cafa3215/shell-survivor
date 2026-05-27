$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

Set-Location $rootDir
python "tools/advance_project.py" run-auto
python "tools/advance_project.py" validate-auto

