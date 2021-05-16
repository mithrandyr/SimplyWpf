Add-Type -AssemblyName PresentationFramework, PresentationCore, System.Windows.Presentation

foreach($f in (Get-ChildItem "$PSScriptRoot\Private\*.ps1")) {
    . $f.FullName
}

foreach($f in (Get-ChildItem "$PSScriptRoot\Public\*.ps1")) {
    . $f.FullName
    Export-ModuleMember -Function $f.BaseName
}