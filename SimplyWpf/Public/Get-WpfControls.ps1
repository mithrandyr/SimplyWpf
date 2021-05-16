function Get-WpfControls {
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