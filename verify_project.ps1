param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ArgsRemaining
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $root "verify_project.py"

# Pass through user args without deprecated defaults.
python $script @ArgsRemaining
exit $LASTEXITCODE

