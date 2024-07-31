using namespace System.Collections
using namespace System.Diagnostics.CodeAnalysis

$esc = [char]27

function Get-ProcessTree {
	<#
	.SYNOPSIS
	Get the process tree.
	.DESCRIPTION
	Get the process tree.
	Display the names, PIDs, number of active threads and window captions (if any) for each process.
	.PARAMETER Service
	Displays names of services hosted in each process.
	.PARAMETER Path
	Display (if available) paths to the executable file of the specific process instead of the process names.
	.PARAMETER CommandLine
	Display (if available) command lines used to start the specific process instead of the process names.
	#>
	[CmdletBinding(DefaultParameterSetName = 'Name')]
	[SuppressMessage('PSReviewUnusedParameter', '')]
	[SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', '')]
	param (
		[switch]$Service,
		[Parameter(ParameterSetName = 'Path')]
		[switch]$Path,
		[Parameter(ParameterSetName = 'CommandLine')]
		[switch]$CommandLine
	)

	$processes = Get-CimInstance Win32_Process | Sort-Object ProcessId

	$pidTable = $processes | Group-Object ProcessId -AsHashTable
	foreach ($proc in $processes) {
		if (isInvaldParentProcess $proc) {
			Add-Member -InputObject $proc -NotePropertyName ParentProcessId -NotePropertyValue ([uint32]0) -Force
		}
	}

	$processGroup = $processes | Group-Object ParentProcessId | Sort-Object Name

	if ($Service) {
		$serviceTable = Get-CimInstance Win32_Service |
			Where-Object ProcessId -NE 0 |
			Sort-Object ProcessId, DisplayName |
			Group-Object ProcessId -AsHashTable
	}

	$nameHeader = $PSCmdlet.ParameterSetName

	foreachCimProcessGroup $processGroup[0].Group 0
}

function isInvaldParentProcess {
	param ($process)

	if (!$pidTable.Contains($process.ParentProcessId)) { return $true }
	if ($process.CreationDate -lt $pidTable[$process.ParentProcessId].CreationDate) { return $true }

	return $false
}

function foreachCimProcessGroup {
	param ($CurrentGroup, [int]$Indentation)

	foreach ($process in $CurrentGroup) {
		$name = if ($Path) { $process.ExecutablePath } elseif ($CommandLine) { $process.CommandLine }
		if (!$name) { $name = $process.ProcessName }

		[pscustomobject][ordered]@{
			'PID' = $process.ProcessId
			'Threads' = $process.ThreadCount
			$nameHeader = "$('  ' * $Indentation)$name"
		}

		$title = (Get-Process -Id $process.ProcessId -ErrorAction Ignore).MainWindowTitle
		if ($title) {
			[pscustomobject]@{ $nameHeader = "$('  ' * ($Indentation + 2))$esc[96mWindowTitle$esc[m: $title" }
		}

		if ($Service -and $serviceTable.Contains($process.ProcessId)) {
			$tab2 = '  ' * ($Indentation + 2)

			$serviceTable[$process.ProcessId] | ForEach-Object {
				[pscustomobject]@{ $nameHeader = "$tab2$esc[93mService$esc[m: $($_.DisplayName)" }
			}
		}

		for ($i = 1; $i -lt $processGroup.Count; $i++) {
			if ($process.ProcessId -eq $processGroup[$i].Name) {
				foreachCimProcessGroup $processGroup[$i].Group ($Indentation + 1)
				break
			}
		}
	}
}
