# https://docs.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-4.4.0

$VMLocalAdminUser = "rymccall"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "Type Your Password Here!" -AsPlainText -Force
$LocationName = "eastus"
$ResourceGroupName = "WS2019SQLVM_RG"
$ComputerName = "WS2019SQLVM"
$VMName = "WS2019SQLVM"
$VMSize = "Standard_D2_v3"

$NetworkName = "WS2019SQLVMNet"
$NICName = "WS2019SQLVMNIC"
$SubnetName = "WS2019SQLVMSubnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"


New-AzResourceGroup -Name $ResourceGroupName
$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
# $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id
$PublicIPAddressName = "WS2019SQLVMPIP"
$PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
#     # ($locName="eastus") + " " + ($pubName="MicrosoftSQLServer") + " " + ($offerName="SQL2016SP2-WS2019") + " " +($skuname="standard")
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftSQLServer' -Offer 'SQL2016SP2-WS2019' -Skus 'standard' -Version latest

New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose
