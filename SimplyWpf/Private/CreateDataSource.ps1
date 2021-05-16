
Function CreateDataSource {
    param([parameter(Mandatory, Position=1)][string]$DataSourceName 
        , [parameter(Mandatory, Position=2, ParameterSetName="col")][string]$CollectionType
    )
    $value = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
    [System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($value, $value.SyncRoot)
    $script:wpfdata.DataSources.$DataSourceName = $value
}