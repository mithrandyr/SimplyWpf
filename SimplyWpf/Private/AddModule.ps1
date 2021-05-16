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