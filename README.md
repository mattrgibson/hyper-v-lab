First, we're going to prep our host machine for WinRM so that we can execute remote PowerShell on the Hyper-V VM without needing to open it through the console (this is after a manual install of the OS, which maybe I'll figure out how to automate later).

## Configure WinRM

Run the following in an elevated PowerShell prompt.

```powershell
Get-Service WinRM | Start-Service
```

Then, we need to add our future virtual machine to our trusted hosts. Replace the IP variable with the IP you intend to assign the future VM.

```powershell
Get-Item WSMan:\localhost\Client\TrustedHosts
$VMIP = "172.16.0.10"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $VMIP -Force
```
## Install Hyper-V

Next, you'll want to install Hyper-V. Run the following from an elevated PowerShell:

``` powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

## Create the virtual network

I have the code stored in a [GitHub Gist]([Create-HyperVNAT.ps1](https://gist.github.com/mattrgibson/7b0927f0cd20247ec2bb473e620a8aaa)), but copying here:

``` powershell
New-VMSwitch -SwitchName "Lab" -SwitchType Internal
$netAdapter = Get-NetAdapter | Where-Object{$_.Name -like "*Lab*"}
New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 16 -InterfaceIndex $netAdapter.ifIndex
New-NetNat -Name HyperVNAT -InternalIPInterfaceAddressPrefix 172.16.0.0/16
```

## Download an ISO

For the purposes of this note, I installed Window Server 2019 Standard. Check the [[ISO Keys]] document for the product key.

Download from [Visual Studio Benefits]([Downloads & Keys - Visual Studio Subscriptions](https://my.visualstudio.com/Downloads/Featured?mkt=en-us))

## Create the Hyper-V virtual machine

Open an elevated PowerShell. Edit the variables at the top of the script [here]([New Lab VM in Hyper-V](https://gist.github.com/mattrgibson/8a2d68a4ad541c225d5750692ff241a4)). Run the following:

``` powershell
.\New-LabVM.ps1
```

At this point, you have to open the VM through Hyper-V RDP and install through GUI like a n00b. Haven't figured out to automate this part yet.
## Apply PowerShell DSC to virtual machine

Download the DSC file from [here]([Config-LabVM.ps1](https://gist.github.com/mattrgibson/de7bb85e39826b383ac514c5d7b98fd3)). Then replace the param variables appropriately.

Like a boss, we're going to apply DSC to this machine without evening opening it up in RDP. Straight terminal son.

```powershell
$pass = ConvertTo-SecureString "p@ssw0rd" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ("Administrator", $pass)

# Copy the DSC PowerShell to the virtual machine
$VM = "VMname"
$Session = New-PSSession -VMName $VM -Credential $Credential
Copy-Item -Path "$env:USERPROFILE\Downloads\Configuration-ServerSetup.ps1" -Destination "C:\DSC_ServerSetup.ps1" -ToSession $Session
Copy-Item -Path "$env:USERPROFILE\Downloads\Configuration-RDPSetup.ps1" -Destination "C:\DSC_RDPSetup.ps1" -ToSession $Session

# Invoke the DSC
Enter-PSSession $Session
cd c:\
.\DSC_ServerSetup.ps1

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name NetworkingDsc -Force
.\DSC_RDPSetup.ps1

# Restart the machine
Restart-Computer
```

## Apply Windows Updates

Run this on each VM you created

```powershell
$VM = "VMname"
$Session = New-PSSession -VMName $VM -Credential $Credential
Enter-PSSession $Session

Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck
Import-Module PSWindowsUpdate
Get-WindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot
```

## Install Active Directory

Download the file from [here]([Quick script to setup AD in lab](https://gist.github.com/mattrgibson/3ae05914f16bfe96c1ac5267c2dea336)) and change the variables. Then copy it to the VM and run it.

```powershell
$Session = New-PSSession -VMName $VM -Credential $Credential
Copy-Item -Path "$env:USERPROFILE\Downloads\Configure-AD.ps1" -Destination "C:\Configure-AD.ps1" -ToSession $Session

# Invoke the DSC
Enter-PSSession $Session
cd c:\
.\Configure-AD.ps1

# Restart the machine
Restart-Computer
```

After you install Active Directory, you need update your `$Credential` variable to use the NETBIOS name (e.g., NETBIOS\Administrator)

Also, you need to disable IPv6 on the machine. This script disables it system wide (all adapters), which is fine by me in a lab. Run this in a PSSession on the VM.

Last, you're going to want to update your ServerSetup DSC to use the correct DNS (change it from 8.8.8.8 to 127.0.0.1)

```powershell
# Disable IPv6 on all interfaces
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0xFF -PropertyType DWord -Force

# Restart the system to apply changes
Restart-Computer -Force
```

After it's done rebooting, create a new PSSession to it and run `Get-ADDomain`. If it returns an object with the expected values, you're all set.
