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