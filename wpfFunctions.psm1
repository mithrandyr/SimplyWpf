<#
TODO consider moving this into its own true module: SimplyWPF
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, System.Windows.Presentation
function GenerateWPFControls {
    [cmdletBinding()]
    param([parameter(Mandatory)][string]$Xaml
        , [switch]$CreateVariables)

    $xamlObj = [xml]($Xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace 'x:Class=".*?"','' -replace 'd:DesignHeight="\d*?"','' -replace 'd:DesignWidth="\d*?"','')
    $wpf = @{}

    $wpf.Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xamlObj -ErrorAction Stop))
    
    foreach($n in $xamlObj.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")) {
        $wpf[$n.Name] = $wpf.window.FindName($n.Name)
    }
    
    if($CreateVariables) {
        foreach($k in $wpf.Keys) {
            New-Variable -Scope 1 -Name $k -Value $wpf.$k | Out-Null
        }
    }
    $wpf | Write-Output
}

function AddHandler{
    [CmdletBinding()]
    param([parameter(Mandatory, Position=1)][object]$Control
        , [Parameter(Position=2)][string]$EventName = "Click"
        , [parameter(Mandatory, Position=3)][scriptblock]$Action)

    $handlerTemplate = @"
    param(`$this, `$eventArgs)
    `$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop

    try {
        $action
    }
    catch {
        `$script:wpfData.Errors += [PSCustomObject]@{DateTime = (Get-Date); Control = `$this.Name; Area = "EventHandler"; Exception = `$_.Exception.ToString(); ScriptStackTrace = `$_.ScriptStackTrace; FullyQualifiedErrorId = `$_.FullyQualifiedErrorId}
        `$message = `$_.exception.ToString()
        if(`$this.Content -is [string]) { `$label = `$this.Content }
        else { `$label = `$this.Name}
        `$caption = "ERROR (EventHandler) : `$label [{0}]" -f `$this.GetType().Name
        [System.Windows.MessageBox]::Show(`$message, `$caption)
    }
"@

    $Type = $Control.GetType()
    if ($EventName.StartsWith("On_")) { $EventName = $EventName.Substring(3) }
    
    $Event = $Type.GetEvent($EventName, [Reflection.BindingFlags]"IgnoreCase, Public, Instance")
    if(-not $Event) { Write-Error "Handler $EventName does not exist on $Control." }
    else {
        $handler = ([scriptblock]::Create($handlerTemplate.ToString())) -as $Event.EventHandlerType
        try{
            if($handler -is [System.Windows.RoutedEventHandler] -and $Type::"${EventName}Event" ) {
                $Control.AddHandler( $Type::"${EventName}Event", $handler )
            } else {
                if ($Control.Resources) {
                    
                    if (-not $Control.Resources.EventHandlers) {
                        $Control.Resources.EventHandlers = @{}
                    }
                    $Control.Resources.EventHandlers."On_$EventName" = $handler
                }
                $event.AddEventHandler($Control, $handler)
            }
        }
        catch { Write-Error "Not able to add eventHandler to $control for event $EventName." }
    }
}

function Background {
    [CmdletBinding()]
    param([parameter(Mandatory, Position=1)][scriptblock]$Action
            , [parameter(ValueFromRemainingArguments)][Object[]]$ArgumentList)

    [string[]]$paramBlock = $Action.Ast.ParamBlock.Parameters.foreach({ ($_.Extent.Text -split "`n") -join "" })
    $paramBlock += '[PSObject]$this'
    $paramBlock += '[PSObject]$wpfData'
    
    $ArgumentList += $this
    $ArgumentList += $script:wpfData

    $sbString = "Param({0})`n" -f ($paramBlock -join ", ")
    $sbString += '$ErrorAction = "Stop"' + "`n"
    $sbString += "`n" + 'Write-Verbose "Entering Background for $this"' + "`n"
    $sbString += '$wpfData.Modules.foreach({Import-Module $_ -Force})' + "`n"
    $sbString += '$wpfData.Functions.GetEnumerator().foreach({New-Item -Path Function: -Name $_.Key -Value $_.Value -Force})'
    $sbString += "`ntry { `n`t"
    $sbString += ($Action.Ast.EndBlock.Statements.Extent.Text -join "`n`t")
    $sbString += @'
}
catch {
    $wpfData.Errors += [PSCustomObject]@{DateTime = (Get-Date); Control = $this.Name; Area = "Background"; Exception = $_.Exception.ToString(); ScriptStackTrace = $_.ScriptStackTrace; FullyQualifiedErrorId = $_.FullyQualifiedErrorId}
    UI {
        $message = $_.exception.ToString()
        if($this.Content -is [string]) { $label = $this.Content }
        else { $label = $this.Name}
        $caption = "ERROR (Background Process) : $label [{0}]" -f $this.GetType().Name
        [System.Windows.MessageBox]::Show($message, $caption)
    }
}
'@
    $sb = [scriptblock]::Create($sbString)

    $uiSB = {
        function UI {
            param([parameter(Mandatory, Position=1)][scriptblock]$Action)

            #$wpfData.Jobs +=
            # https://geekeefy.wordpress.com/2017/06/07/powershell-tokenization-and-abstract-syntax-tree/
            # https://mikefrobbins.com/2019/02/21/powershell-tokenizer-more-accurate-than-ast-in-certain-scenarios/
<#            Start-ThreadJob -Name "Show-WPFApplication-UI" -ScriptBlock {
                
                $this = $using:this
                $action = ($using:Action).GetNewClosure()
                Write-Host "this: $action"

                Write-Host ("d: {0}" -f $this.dispatcher)
                [System.Windows.Threading.DispatcherExtensions]::Invoke($this.Dispatcher, {write-host "Test"})
                [System.Windows.Threading.DispatcherExtensions]::Invoke($this.Dispatcher, $action)
                
                    $sbString = @'
        $this = $this
        $wpfData.Controls.GetEnumerator().foreach({New-Variable -Name $_.Key -Value $_.Value})
        $wpfData.Functions.GetEnumerator().foreach({New-Item -Path Function: -Name $_.Key -Value $_.Value -Force})
'@ 
                $sbString += "`n{0}" -f $Action.ToString()
                
                $sb = [scriptblock]::Create($sbString).GetNewClosure()
                [System.Windows.Threading.DispatcherExtensions]::Invoke($this.Dispatcher, $using:Action)
            } -StreamingHost $Host
#>

            $sbString = @'
    $this = $this
    $wpfData.Controls.GetEnumerator().foreach({New-Variable -Name $_.Key -Value $_.Value})
    $wpfData.Functions.GetEnumerator().foreach({New-Item -Path Function: -Name $_.Key -Value $_.Value -Force})
'@ 
            $sbString += "`n{0}" -f $Action.ToString()
            
            $sb = [scriptblock]::Create($sbString).GetNewClosure()
            
            [System.Windows.Threading.DispatcherExtensions]::Invoke($this.Dispatcher, $sb)
        }
    }

    $init = [scriptblock]::Create($uiSB.ToString() + "`nfunction GetResource {" + (Get-Command GetResource).Definition + "}`nfunction SetResource {"  + (Get-Command SetResource).Definition + "}")
    $script:wpfData.Jobs += Start-ThreadJob -Name "Show-WPFApplication" -Scriptblock $sb -ArgumentList $ArgumentList -StreamingHost $Host -InitializationScript $init
}

function AddResource {
    [cmdletBinding()]
    param([parameter(Mandatory, Position=1)][string]$ResourceName 
            , [parameter(Mandatory, Position=2)]$Value
            , [parameter(Position=3)][scriptblock]$Binding
        )
    
    $result = [PSCustomObject]@{
        wpfType = "RESOURCE"
        resourceType = "SCALAR"
        resourceName = $resourceName
        binds = @()
    }
    if($value -and $value.GetType().IsArray) { $result.ResourceType = "ARRAY" }
    if($Binding) { $result.Binds += &$Binding }
    $result
}

function AddBind {
    [cmdletBinding(DefaultParameterSetName="obj")]
    param([parameter(Mandatory, Position=1)][object]$Control
        , [parameter(Mandatory, Position=2, ParameterSetName="obj")][string]$ResourceName
        , [parameter(Mandatory, Position=2, ParameterSetName="col")][string]$DataSourceName
        , [parameter(Mandatory, Position=3)][string]$PropertyName
    )
    [PSCustomObject]@{
        wpfType = "BIND"
        bindControl = $Control
        bindProperty = $PropertyName
        bindResource = $ResourceName
    }
}

function AddFunction {
    [cmdletBinding()]
    param([parameter(Mandatory, Position=1)][string]$FunctionName
            , [parameter(Mandatory, Position=2)][scriptblock]$ScriptBlock
        )
    [PSCustomObject]@{
        wpfType = "FUNCTION"
        functionName = $FunctionName
        functionAction = $ScriptBlock
    }
}
function AddModule {
    [cmdletBinding()]
    param([parameter(Mandatory, Position=1)][string]$FunctionName
            , [parameter(Position=2)][scriptblock]$ScriptBlock
        )
    [PSCustomObject]@{
        wpfType = "MODULE"
        moduleName = $FunctionName
        functionAction = $ScriptBlock
    }
}

Function CreateDataSource {
    param([parameter(Mandatory, Position=1)][string]$DataSourceName 
        , [parameter(Mandatory, Position=2, ParameterSetName="col")][string]$CollectionType
    )
    $value = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
    [System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($value, $value.SyncRoot)
    $script:wpfdata.DataSources.$DataSourceName = $value
}

function SetResource {
    param([parameter(Mandatory, Position=1)][string]$ResourceName 
        , [parameter(Mandatory, Position=2)][string]$Value
    )

    $index = $script:wpfdata.ResourceKeys[$ResourceName]        
    if($index -ge 0) { $script:wpfdata.ResourceObject[$index] = $value }
    else {
        $index = $script:wpfdata.ResourceObject.Count
        $script:wpfdata.ResourceKeys[$ResourceName] = $index
        $script:wpfdata.ResourceObject.Add($Value)
    } 
}

function GetResource {
    param([parameter(Mandatory, Position=1)][string]$ResourceName)

    if($script:wpfdata.ResourceKeys.ContainsKey($ResourceName)) {
        $index = $script:wpfdata.ResourceKeys[$ResourceName]
        $script:wpfdata.ResourceObject[$index]
    }
    else { throw "Invalid resource '$resourceName', does not exist." }
}

function Bind {
    [cmdletBinding(DefaultParameterSetName="obj")]
    param([parameter(Mandatory, Position=1)][object]$Control
        , [parameter(Mandatory, Position=2, ParameterSetName="obj")][string]$ResourceName
        , [parameter(Mandatory, Position=2, ParameterSetName="col")][string]$DataSourceName
        , [parameter(Mandatory, Position=3)][string]$PropertyName
    )

    if($PSCmdlet.ParameterSetName -eq "obj") {
        if(-not $Script:wpfdata.ResourceKeys.ContainsKey($ResourceName)) { throw "Invalid ResourceName '$ResourceName' for Bind to use." }
        $binding = [System.Windows.Data.Binding]::new()
        $binding.Path = "[{0}]" -f $Script:wpfdata.ResourceKeys[$ResourceName]
        $binding.Mode = [System.Windows.Data.BindingMode]::OneWay
        $binding.Source = $Script:wpfdata.ResourceObJect
        $prop = Invoke-Expression ("[{0}]::{1}Property" -f $Control.GetType().FullName, $PropertyName)
        [void][System.Windows.Data.BindingOperations]::SetBinding($Control, $prop, $Binding)
    }
    else {
        if(-not $Script:wpfdata.DataSources.ContainsKey($DataSourceName)) { throw "Invalid DataSourceName '$DataSourceName' for Bind to use." }
        $binding = [System.Windows.Data.Binding]::new()
        $binding.Mode = [System.Windows.Data.BindingMode]::OneWay
        $binding.Source = $Script:wpfdata.DataSources.$DataSourceName
        $prop = Invoke-Expression ("[{0}]::{1}Property" -f $Control.GetType().FullName, $PropertyName)
        [void][System.Windows.Data.BindingOperations]::SetBinding($Control, $prop, $Binding)
    }
}

function Show-WPFApplication {
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