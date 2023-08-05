function Get-ProcessTree {
	<#
	.SYNOPSIS
	Get the process tree.
	.DESCRIPTION
	Get the process tree.
	Display the names, PIDs and window captions (if any) for each process.
	#>
	[CmdletBinding()]
	[OutputType([string[]])]
	param ()

	if ($PSVersionTable['PSVersion'].Major -le 5 -or $IsWindows) { return getCimProcessTree }

	$processGroup = Get-Process | Sort-Object Id | Group-Object -Property @{ Expression = { $_.Parent.Id } }
	return foreachProcessGroup $processGroup[0].Group 0
}

function getCimProcessTree {
	[OutputType([string[]])]
	param ()

	$processes = Get-CimInstance Win32_Process | Sort-Object ProcessId
	$processGroup = $processes | Group-Object ParentProcessId | Sort-Object Name

	$rootProcesses = @($processGroup[0].Group)
	$processIds = $processes | Select-Object -ExpandProperty ProcessId
	for ($i = 0; $i -lt $processGroup.Count; $i++) {
		if ($processGroup[$i].Name -notin $processIds) {
			$rootProcesses += $processGroup[$i].Group
			$processGroup[$i] = $null
		}
	}

	foreachCimProcessGroup ($rootProcesses | Sort-Object ProcessId) 0
}

function foreachCimProcessGroup {
	[OutputType([string[]])]
	param ($CurrentGroup, [int]$Indent)

	foreach ($process in $CurrentGroup) {
		$title = (Get-Process -Id $process.ProcessId -ErrorAction Ignore).MainWindowTitle
		"$('  ' * $Indent)$($process.ProcessName) ($($process.ProcessId)) $title"

		for ($i = 1; $i -lt $processGroup.Count; $i++) {
			if ($null -eq $processGroup[$i]) { continue }

			if ($process.ProcessId -eq $processGroup[$i].Name) {
				foreachCimProcessGroup $processGroup[$i].Group ($Indent + 1)
				break
			}
		}
	}
}

function foreachProcessGroup {
	[OutputType([string[]])]
	param ($CurrentGroup, [int]$Indent)

	foreach ($process in $CurrentGroup) {
		"$('  ' * $Indent)$($process.ProcessName) ($($process.Id)) $($process.MainWindowTitle)"

		for ($i = 1; $i -lt $processGroup.Count; $i++) {
			if ($process.Id -eq $processGroup[$i].Name) {
				foreachProcessGroup $processGroup[$i].Group ($Indent + 1)
				break
			}
		}
	}
}
