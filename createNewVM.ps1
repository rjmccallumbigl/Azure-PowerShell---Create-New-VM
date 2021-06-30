###########################################################################################################################################################
<#
# .SYNOPSIS
#       Create a new Managed VM.
#
# .DESCRIPTION
#       Create a new Managed VM. If you'd like to modify the defaults, please review & change the code prior to running.
#       https://docs.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-4.4.0
#
# .PARAMETER vmName
#       The name of the VM. Windows computer name cannot be more than 15 characters long, be entirely numeric, or contain the following characters:
#            ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?.
#
# .PARAMETER VMLocalAdminUser
#       The username you will use on your VM.
#
# .PARAMETER VMLocalAdminSecurePassword
#       The password you will use on your VM.
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
$publisherName = "MicrosoftWindowsServer"
$offerName = "windowsserver"
$skuName = "2019-Datacenter"

# Linux VM config, modify as necessary
# $publisherName = "canonical"
# $offerName = "0001-com-ubuntu-server-focal"
# $skuName = "20_04-lts-gen2"

# Get your IP Address to scope remote access to only your IP
$myipaddress = (Invoke-WebRequest https://myexternalip.com/raw).content;

# # Create VM configuration
try {
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
    $SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
    $Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
    $PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic    
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
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id -NetworkSecurityGroupId $nsg.Id
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version latest

    # Create VM
    New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose
}
catch {
    throw $_
}
