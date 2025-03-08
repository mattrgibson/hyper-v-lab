Configuration RDPSetup
{
    param (
        [string]$TimeZone = "Eastern Standard Time",
        [string]$StaticIP = "172.16.0.20",
        [string]$SubnetMask = "255.255.0.0",
        [string]$DefaultGateway = "172.16.0.1",
        [string]$DNSServer = "8.8.8.8",
        [string]$ComputerName = "PSP-DC2"
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName NetworkingDsc

    Node localhost
    {

        # Enable Remote Desktop
        Registry EnableRDP
        {
            Ensure = "Present"
            Key = "HKLM:\System\CurrentControlSet\Control\Terminal Server"
            ValueName = "fDenyTSConnections"
            ValueType = "Dword"
            ValueData = 0
        }

        # Enable RDP Firewall Rule
        Firewall EnableRDPFirewallRule
        {
            Name        = 'RemoteDesktop-UserMode-In-TCP'
            DisplayName = 'Remote Desktop - User Mode (TCP-In)'
            Action      = 'Allow'
            Direction   = 'Inbound'
            Enabled     = 'True'
            Profile     = 'Any'  # Applies to all profiles: Domain, Private, and Public
            Ensure      = 'Present'
        }
    }
}

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name NetworkingDsc -Force

# Generate MOF file
RDPSetup -OutputPath "C:\DSC_RDPSetup"

# Apply the configuration
Start-DscConfiguration -Path "C:\DSC_RDPSetup" -Wait -Force -Verbose


