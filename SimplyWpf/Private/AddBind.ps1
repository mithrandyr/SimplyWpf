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