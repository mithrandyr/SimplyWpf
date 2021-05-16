function Background {
    [CmdletBinding()]
    param([parameter(Mandatory, Position=1)][scriptblock]$Action
            , [parameter(ValueFromRemainingArguments)][Object[]]$ArgumentList)

    [string[]]$paramBlock = $Action.Ast.ParamBlock.Parameters.foreach({ ($_.Extent.Text -split "`n") -join "" })
    $paramBlock += '[PSObject]$this'
    $paramBlock += '[PSObject]$wpfData'
    
    $ArgumentList += $this
    $ArgumentList += $script:wpfData

    $sbString = "Param({0})`n" -f ($paramBlock -join ", ")
    $sbString += '$ErrorAction = "Stop"' + "`n"
    $sbString += "`n" + 'Write-Verbose "Entering Background for $this"' + "`n"
    $sbString += '$wpfData.Modules.foreach({Import-Module $_ -Force})' + "`n"
    $sbString += '$wpfData.Functions.GetEnumerator().foreach({New-Item -Path Function: -Name $_.Key -Value $_.Value -Force})'
    $sbString += "`ntry { `n`t"
    $sbString += ($Action.Ast.EndBlock.Statements.Extent.Text -join "`n`t")
    $sbString += @'
}
catch {
    $wpfData.Errors += [PSCustomObject]@{DateTime = (Get-Date); Control = $this.Name; Area = "Background"; Exception = $_.Exception.ToString(); ScriptStackTrace = $_.ScriptStackTrace; FullyQualifiedErrorId = $_.FullyQualifiedErrorId}
    UI {
        $message = $_.exception.ToString()
        if($this.Content -is [string]) { $label = $this.Content }
        else { $label = $this.Name}
        $caption = "ERROR (Background Process) : $label [{0}]" -f $this.GetType().Name
        [System.Windows.MessageBox]::Show($message, $caption)
    }
}
'@
    $sb = [scriptblock]::Create($sbString)

    $uiSB = {
        function UI {
            param([parameter(Mandatory, Position=1)][scriptblock]$Action)

            #$wpfData.Jobs +=
            # https://geekeefy.wordpress.com/2017/06/07/powershell-tokenization-and-abstract-syntax-tree/
            # https://mikefrobbins.com/2019/02/21/powershell-tokenizer-more-accurate-than-ast-in-certain-scenarios/
<#            Start-ThreadJob -Name "Show-WPFApplication-UI" -ScriptBlock {
                
                $this = $using:this
                $action = ($using:Action).GetNewClosure()
                Write-Host "this: $action"

                Write-Host ("d: {0}" -f $this.dispatcher)
                [System.Windows.Threading.DispatcherExtensions]::Invoke($this.Dispatcher, {write-host "Test"})
                [System.Windows.Threading.DispatcherExtensions]::Invoke($this.Dispatcher, $action)
                
                    $sbString = @'
        $this = $this
        $wpfData.Controls.GetEnumerator().foreach({New-Variable -Name $_.Key -Value $_.Value})
        $wpfData.Functions.GetEnumerator().foreach({New-Item -Path Function: -Name $_.Key -Value $_.Value -Force})
'@ 
                $sbString += "`n{0}" -f $Action.ToString()
                
                $sb = [scriptblock]::Create($sbString).GetNewClosure()
                [System.Windows.Threading.DispatcherExtensions]::Invoke($this.Dispatcher, $using:Action)
            } -StreamingHost $Host
#>

            $sbString = @'
    $this = $this
    $wpfData.Controls.GetEnumerator().foreach({New-Variable -Name $_.Key -Value $_.Value})
    $wpfData.Functions.GetEnumerator().foreach({New-Item -Path Function: -Name $_.Key -Value $_.Value -Force})
'@ 
            $sbString += "`n{0}" -f $Action.ToString()
            
            $sb = [scriptblock]::Create($sbString).GetNewClosure()
            
            [System.Windows.Threading.DispatcherExtensions]::Invoke($this.Dispatcher, $sb)
        }
    }

    $init = [scriptblock]::Create($uiSB.ToString() + "`nfunction GetResource {" + (Get-Command GetResource).Definition + "}`nfunction SetResource {"  + (Get-Command SetResource).Definition + "}")
    $script:wpfData.Jobs += Start-ThreadJob -Name "Show-WPFApplication" -Scriptblock $sb -ArgumentList $ArgumentList -StreamingHost $Host -InitializationScript $init
}