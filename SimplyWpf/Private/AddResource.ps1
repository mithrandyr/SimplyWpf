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