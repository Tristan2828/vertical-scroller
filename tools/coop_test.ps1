# Opens a host and a client window side by side on this PC, for trying co-op by hand.
# Click a window to give it the keyboard (or use one gamepad per window).
#
# Usage:  pwsh tools/coop_test.ps1 [-Screen 1] [-Port 7812] [-Autopilot]
#   -Screen      which monitor (on the owner's PC, 1 is the landscape 4K one)
#   -Autopilot   both ships fly and shoot by themselves (and the lobby starts itself)
# Set $env:GODOT to override the Godot executable path (the GUI build here).

param(
	[int]$Screen = 1,
	[int]$Port = 7812,
	[switch]$Autopilot
)

$godot = if ($env:GODOT) { $env:GODOT } else { "C:\Code Tools\Godot\Godot_v4.7.2-stable_win64.exe" }
$project = Split-Path -Parent $PSScriptRoot
$common = @("--local-only", "--port=$Port", "--window=1440x810")
if ($Autopilot) { $common += "--autopilot" }

Start-Process -FilePath $godot -ArgumentList (@("--path", "`"$project`"", "--screen", "$Screen", "--", "--host", "--window-at=200,200") + $common)
Start-Sleep -Seconds 1
Start-Process -FilePath $godot -ArgumentList (@("--path", "`"$project`"", "--screen", "$Screen", "--", "--join=127.0.0.1", "--window-at=1700,1000") + $common)
Write-Host "Started a host (left) and a client (right). In the lobby: client presses Ready, host presses Start."
