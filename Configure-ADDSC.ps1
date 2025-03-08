Configuration InstallADDS
{
    param (
        [string]$DomainName = "starklabs.com",
        [string]$SafeModePassword = "p@ssw0rd",
	[string]$Netbios = "STARK",
	[string]$ForestMode = "WinThreshold",
	[string]$DomainMode = "WinThreshold"
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost
    {
        # Install AD DS Feature
        WindowsFeature ADDSInstall
        {
            Name   = "AD-Domain-Services"
            Ensure = "Present"
        }

        # Promote to Domain Controller
        Script PromoteToDC
        {
            GetScript = { @{} }
            SetScript = {
                Install-ADDSForest -DomainName $using:DomainName -SafeModeAdministratorPassword (ConvertTo-SecureString $using:SafeModePassword -AsPlainText -Force) -DomainNetbiosName $using:Netbios -ForestMode $using:ForestMode -DomainMode $using:DomainMode -Force
            }
            TestScript = { (Get-WindowsFeature -Name AD-Domain-Services).Installed }
        }
    }
}

# Apply the DSC Configuration
InstallADDS -OutputPath "C:\DSC_ADDS"
Start-DscConfiguration -Path "C:\DSC_ADDS" -Wait -Force -Verbose

