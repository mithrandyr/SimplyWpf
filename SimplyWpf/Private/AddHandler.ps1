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