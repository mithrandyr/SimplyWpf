function Invoke-WpfApplication {
    [cmdletBinding(DefaultParameterSetName="obj")]
    param([parameter(Mandatory, ParameterSetName="obj")][string]$XAML
        , [parameter(Mandatory, ParameterSetName="path")][Alias("FullName", "Path")][string]$PathToXAML
        , [string]$WindowTitle = "Show-WPFApplication"
        , [parameter(Mandatory)][scriptblock]$Handlers
        , [parameter()][scriptblock]$Functions
        , [parameter()][string[]]$Modules
        , [switch]$NoCleanup)

    if($PSCmdlet.ParameterSetName -eq "path") { $XAML = Get-Content -Raw -Path $PathToXAML }
    $script:wpfData = [PSCustomObject]@{
        Controls = GenerateWPFControls -Xaml $XAML -CreateVariables
        Functions = @{}
        Modules = @()
        Jobs = @()
        Errors = @()
        ResourceKeys = [hashtable]::Synchronized(@{})
        ResourceObject = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
        DataSources = [hashtable]::Synchronized(@{})
    }
    [System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($wpfData.ResourceObject, $wpfData.ResourceObject.SyncRoot)
    
    #New-Variable -Name Resources -Value $Script:wpfControls["Resources"]
    # -- create timer to clean up wpfJobs that are finished.

    try {
        #loading modules
        foreach ($m in $Modules) { 
            if($m -like "*.psd1" -or $m -like "*.psm1") { $m = [string](Resolve-Path $m) }
            $script:wpfData.Modules += $m
            #$script:wpfData.Modules += Import-Module -Name $m -PassThru
        }
        
        #Functions loaded
        $codeModule = New-Module -Name SharedCode -ScriptBlock $Functions
        $codeModule.ExportedFunctions.Values |
            Where-Object source -NotIn $codeModule.NestedModules.Name |
            ForEach-Object { $script:wpfData.Functions[$_.Name] = $_.Definition }
        $codeModule | Remove-Module
        Remove-Variable codeModule

        $wpfData.Functions.GetEnumerator().foreach({New-Item -Path Function: -Name $_.Key -Value $_.Value -Force}) | Out-Null

        #Process Handler Actions
        Invoke-Expression -Command $Handlers.ToString()

        $window.Title = $WindowTitle
        $window.ShowDialog() | Out-Null
    }
    finally {
        #Job cleanup
        if(-not $NoCleanup) { $script:wpfData.Jobs | Remove-Job -Force }
    }
}