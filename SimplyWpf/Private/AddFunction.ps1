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