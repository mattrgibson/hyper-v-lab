Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

$HashArguments = @{
    DomainName          = "starklab.com"
    DomainNetbiosName   = "STARK"
    ForestMode          = "WinThreshold"
    DomainMode          = "WinThreshold"
}
Install-ADDSForest @HashArguments -InstallDns -SafeModeAdministratorPassword (ConvertTo-SecureString "Comet14841" -AsPlainText -Force) -NoRebootOnCompletion -Confirm:$false
