@{
	ModuleVersion = '2.0.0'
	GUID = 'e66c3c53-cd0b-4368-aff8-2fd99f54355c'
	Author = 'BaldCat'
	Copyright = '(c) 2023 BaldCat. All rights reserved.'
	Description = 'This module writes the process tree.'
	PowerShellVersion = '5.1'
	CompatiblePSEditions = @('Core', 'Desktop')
	RootModule = 'ProcessTree.psm1'
	FunctionsToExport = @('Get-ProcessTree')
	CmdletsToExport = @()
	AliasesToExport = @()
	PrivateData = @{
		PSData = @{
			ProjectUri = 'https://github.com/baldcat18/ProcessTree'
			Tags = @('Process', 'Tree', 'Windows')
		}
	}
}
