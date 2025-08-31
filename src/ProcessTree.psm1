using namespace System.Diagnostics.CodeAnalysis

$esc = [char]27
if ($Host.Name -eq 'Windows PowerShell ISE Host') {
	# ISEはエスケープシーケンスをサポートしていない
	$cyan = ''
	$brightYellow = ''
	$reset = ''
} elseif ($PSStyle) {
	$cyan = $PSStyle.Foreground.Cyan
	$brightYellow = $PSStyle.Foreground.BrightYellow
	$reset = $PSStyle.Reset
} else {
	$cyan = "$esc[96m"
	$brightYellow = "$esc[93m"
	$reset = "$esc[m"
}

$isWin11OrLater = [Environment]::OSVersion.Version -ge '10.0.22000'

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
	if ($isWin11OrLater) { $cpuTable = getCpuUsageTable }

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

function getCpuUsageTable {
	$table = @{}
	$cpuCount = [System.Environment]::ProcessorCount

	(Get-Counter '\Process V2(*)\% Processor Time' -ErrorAction Ignore).CounterSamples |
		Where-Object InstanceName -NE _total |
		ForEach-Object {
			$processId = [uint32]($_.InstanceName -replace '^.+:(\d+)$', '$1')
			$table[$processId] = ($_.CookedValue / $cpuCount).ToString('0.00').PadLeft(8)
		}

	return $table
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

		$processTable = [ordered]@{ 'ProcessId' = $process.ProcessId }
		if ($isWin11OrLater) {
			$processTable['CpuUsage'] = `
				if ($cpuTable.Contains($process.ProcessId)) { $cpuTable[$process.ProcessId] } else { 'N/A' }
		}
		$processTable['Threads'] = $process.ThreadCount
		$processTable[$nameHeader] = "$('  ' * $Indentation)$name"
		[pscustomobject]$processTable

		$title = (Get-Process -Id $process.ProcessId -ErrorAction Ignore).MainWindowTitle
		if ($title) {
			[pscustomobject]@{ $nameHeader = "$('  ' * ($Indentation + 2))${cyan}WindowTitle${reset}: $title" }
		}

		if ($Service -and $serviceTable.Contains($process.ProcessId)) {
			$tab2 = '  ' * ($Indentation + 2)

			$serviceTable[$process.ProcessId] | ForEach-Object {
				[pscustomobject]@{ $nameHeader = "$tab2${brightYellow}Service${reset}: $($_.DisplayName)" }
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
