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
