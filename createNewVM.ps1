###########################################################################################################################################################
<#
# .SYNOPSIS
#       Create a new Managed VM.
#
# .DESCRIPTION
#       Create a new Managed VM.
#       https://docs.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-4.4.0
#
# .PARAMETER vmName
#       The name of the VM.
#
# .PARAMETER VMLocalAdminUser
#       The username you will use on your VM.
#
# .PARAMETER VMLocalAdminSecurePassword
#       The password you will use on your VM.
#
# .EXAMPLE
#       createNewVMs -n name -u Username -p Password!234
#>
###########################################################################################################################################################

#Set the Parameters for the script
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
    $VMLocalAdminSecurePassword
)

# Declare variables, modify as necessary
$LocationName = "eastus"
$publisherName = "MicrosoftWindowsServer"
$offerName = "windowsserver"
$skuName = "2019-Datacenter"
$ResourceGroupName = $VMName + "RG"
$VMSize = "Standard_D2_v3"
$NetworkName = $VMName + "Net"
$NICName = $VMName + "NIC"
$SubnetName = $VMName + "Subnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$PublicIPAddressName = $VMName + "PIP"

# Create resources
New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
$PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id
$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)

# Create VM configuration
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version latest

New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose
