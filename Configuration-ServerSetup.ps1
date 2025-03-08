Configuration ServerSetup
{
    param (
        [string]$TimeZone = "Eastern Standard Time",
        [string]$StaticIP = "172.16.0.20",
        [string]$SubnetMask = "255.255.0.0",
        [string]$DefaultGateway = "172.16.0.1",
        [string]$DNSServer = "127.0.0.1",
        [string]$ComputerName = "PSP-DC2"
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost
    {
        # Disable IPv6
	Registry DisableIPv6
        {
            Ensure      = "Present"
            Key         = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
            ValueName   = "DisabledComponents"
            ValueType   = "Dword"
            ValueData   = 0xFF  # Disables all IPv6 components
        }

	# Set Time Zone
        Script SetTimeZone
        {
            GetScript = { @{} }
            SetScript = { tzutil.exe /s $using:TimeZone }
            TestScript = { (Get-TimeZone).Id -eq $using:TimeZone }
        }

        # Network Configuration
        Script SetNetworkConfig
        {
            GetScript = { @{} }
            SetScript = {
                $Adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
                New-NetIPAddress -InterfaceAlias $Adapter.Name -IPAddress $using:StaticIP -PrefixLength 16 -DefaultGateway $using:DefaultGateway
                Set-DnsClientServerAddress -InterfaceAlias $Adapter.Name -ServerAddresses $using:DNSServer
            }
            TestScript = {
                $Adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
                $CurrentIP = Get-NetIPAddress -InterfaceAlias $Adapter.Name | Where-Object { $_.AddressFamily -eq 'IPv4' }
                return $CurrentIP.IPAddress -eq $using:StaticIP
            }
        }

        # Disable Server Manager Auto Start
        Script DisableServerManager
        {
            GetScript = { @{} }
            SetScript = { Get-ScheduledTask -TaskName "ServerManager" | Disable-ScheduledTask }
            TestScript = { (Get-ScheduledTask -TaskName "ServerManager").State -eq "Disabled" }
        }

        # Change Computer Name
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        Script RenameComputer
        {
            GetScript = { @{} }
            SetScript = { Rename-Computer -NewName $using:ComputerName -Force }
            TestScript = { (Get-ComputerInfo).CsName -eq $using:ComputerName }
        }

        # Disable Internet Explorer ESC
        Registry DisableIEESCAdmin
        {
            Ensure = "Present"
            Key = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
            ValueName = "IsInstalled"
            ValueType = "Dword"
            ValueData = 0
        }

        Registry DisableIEESCUser
        {
            Ensure = "Present"
            Key = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
            ValueName = "IsInstalled"
            ValueType = "Dword"
            ValueData = 0
        }
    }
}

# Generate MOF file
ServerSetup -OutputPath "C:\DSC_Network"

# Apply the configuration
Start-DscConfiguration -Path "C:\DSC_Network" -Wait -Force -Verbose


