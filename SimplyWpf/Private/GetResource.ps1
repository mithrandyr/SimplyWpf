
function GetResource {
    param([parameter(Mandatory, Position=1)][string]$ResourceName)

    if($script:wpfdata.ResourceKeys.ContainsKey($ResourceName)) {
        $index = $script:wpfdata.ResourceKeys[$ResourceName]
        $script:wpfdata.ResourceObject[$index]
    }
    else { throw "Invalid resource '$resourceName', does not exist." }
}