﻿###########################################################################################################################################################
<#
# .SYNOPSIS
#       Create a new Managed VM.
#
# .DESCRIPTION
#       Create a new Managed VM. If you'd like to modify the defaults, please review & change the code prior to running.
#       https://docs.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-4.4.0
#
# .NOTES
        Version: 0.3.1
#
# .PARAMETER vmName
#       The name of the VM. Windows computer name cannot be more than 15 characters long. Linux computer name cannot be more than 15 characters long.
#       Cannot be entirely numeric. Cannot include a period. Cannot end with a hyphen. Cannot contain the following characters:
#            ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?.
            More info: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftcompute
#
# .PARAMETER VMLocalAdminUser
#       The username you will use on your VM. The following restrictions apply:
#       Windows: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/faq#what-are-the-username-requirements-when-creating-a-vm-
#       Linux: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/faq#what-are-the-username-requirements-when-creating-a-vm-
#
# .PARAMETER VMLocalAdminSecurePassword
#       The password you will use on your VM. The following restrictions apply:
#       Windows: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm-
#       Linux: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/faq#what-are-the-password-requirements-when-creating-a-vm-
#
# .PARAMETER os
#       Windows or Linux.
#
# .EXAMPLE
#       createNewVMs -n name -u Username -os Windows
#>
###########################################################################################################################################################

# Set the Parameters for the script
param (
    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM.")]
    [Alias('n')]
    [string]
    $vmName,
    [Parameter(Mandatory = $true, HelpMessage = "The username you will use on your VM.")]
    [Alias('u')]
    [string]
    $VMLocalAdminUser,
    [Parameter(Mandatory = $true, HelpMessage = "The password you will use on your VM.")]
    [Alias('p')]
    [SecureString]
    $VMLocalAdminSecurePassword,
    [Parameter(Mandatory = $true, HelpMessage = "Windows or Linux.")]
    [Alias('o')]
    [ValidateSet("windows", "linux")]
    [string]
    $os
)

# Declare variables, modify as necessary
$LocationName = "eastus"
$ResourceGroupName = $VMName + "RG"
$VMSize = "Standard_D4s_v3"
$NetworkName = $VMName + "Net"
$NICName = $VMName + "NIC"
$SubnetName = $VMName + "Subnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$PublicIPAddressName = $VMName + "PIP"

# Windows VM config, modify as necessary
# $publisherName = "MicrosoftWindowsServer"
# $offerName = "windowsserver"
# $skuName = "2019-Datacenter"

# Linux VM config, modify as necessary
$publisherName = "RedHat"
$offerName = "RHEL"
$skuName = "7-LVM"

# Get your IP Address to scope remote access to only your IP
$myipaddress = (Invoke-WebRequest https://myexternalip.com/raw).content;

# # Create VM configuration
try {
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
    $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize

    if ($os -eq "windows") {
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
        $nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowRDP -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix $myipaddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
    }
    elseif ($os -eq "linux") {
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $VMName -Credential $Credential
        $nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowSSH -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix $myipaddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
    }

    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -Name "$($VMName)NetworkSecurityGroup" -SecurityRules $nsgRule
    $SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix -NetworkSecurityGroupId $nsg.Id
    $Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
    $PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id -NetworkSecurityGroupId $nsg.Id
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version latest

    # Create VM
    New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose
    $publicIP = Get-AzPublicIpAddress -Name $PIP.name -ResourceGroupName $ResourceGroupName

    # Remotely connect
    "Public IP to connect to: $($publicIP.IpAddress)"
    if ($os -eq "windows") {
        mstsc "/v:$($publicIP.IpAddress)"
    }
    elseif ($os -eq "linux") {
        ssh "$($VMLocalAdminUser)@$($publicIP.IpAddress)"
    }
}
catch {
    throw $_
}
