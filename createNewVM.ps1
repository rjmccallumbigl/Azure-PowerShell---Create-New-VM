###########################################################################################################################################################
<#
# .SYNOPSIS
#       Create a new Managed VM.
#
# .DESCRIPTION
#       Create a new Managed VM. If you'd like to modify the defaults, please review & change the code prior to running.
#       https://docs.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-4.4.0
#
# .NOTES
        Version: 0.5.0
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
#       Windows (w) or Linux (l).
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
    [Parameter(Mandatory = $true, HelpMessage = "Windows or Linux?")]
    [Alias('o')]
    [ValidateSet("windows", "w", "linux", "l")]
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

###################################################################
#
# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage
# Return publishers/offers/skus/versions for this script
# $publishers = Get-AzVMImagePublisher -Location $LocationName | Select-Object PublisherName
# $publishers
#
# Modify as necessary
# $publisherName = "MicrosoftWindowsServer"
# $offers = Get-AzVMImageOffer -Location $LocationName -PublisherName $publisherName | Select-Object Offer
# $offers
#
# Modify as necessary
# $offerName = "WindowsServer"
# $skus = Get-AzVMImageSku -Location $LocationName -PublisherName $publisherName -Offer $offerName | Select-Object Skus
# $skus
#
# Modify as necessary
# $skuName = "2019-Datacenter"
# $images = Get-AzVMImage -Location $LocationName -PublisherName $publisherName -Offer $offerName -Sku $skuName 
# $images
#
###################################################################
#
###################################################################
#
# Example image version for all images, modify as necessary
$version = "latest"

# Example Windows VM config, modify as necessary
# $publisherName = "MicrosoftWindowsServer"
# $offerName = "windowsserver"
# $skuName = "2019-Datacenter"

# Example Windows VM config, modify as necessary
# $publisherName = "MicrosoftWindowsServer"
# $offerName = "windowsserver"
# $skuName = "2022-Datacenter"

# Example Windows VM config, modify as necessary
# $publisherName = "MicrosoftWindowsDesktop"
# $offerName = "windows11preview"
# $skuName = "win11-21h2-pro"

# Example Windows VM config that requires a purchase plan, modify as necessary
# Example: Get-AzVMImage -Location "westus" -PublisherName "microsoft-ads" -Offer "windows-data-science-vm" -Skus "windows2016"
# $version = "20.01.10"
# $publisherName = "microsoft-ads"
# $offerName = "windows-data-science-vm"
# $skuName = "windows2016"

# Example Linux VM config, modify as necessary
# $publisherName = "SUSE"
# $offerName = "SLES-SAP"
# $skuName = "12-SP3"

# Example Linux VM config, modify as necessary
# $publisherName = "RedHat"
# $offerName = "RHEL"
# $skuName = "7-LVM"

Example Linux VM config, modify as necessary
$publisherName = "Oracle"
$offerName = "Oracle-Linux"
$skuName = "77"

# Example Linux VM config, modify as necessary
# $publisherName = "Canonical"
# $offerName = "UbuntuServer"
# $skuName = "19.04"
#
###################################################################

# Get your IP Address to scope remote access to only your IP
$myipaddress = (Invoke-WebRequest https://myexternalip.com/raw).content;

# Create VM configuration
try {
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
    $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize

    if (($os -eq "windows") -or ($os -eq "w")) {
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
        $nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowRDP -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix $myipaddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
    }
    elseif (($os -eq "linux") -or ($os -eq "l")) {
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $VMName -Credential $Credential
        $nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowSSH -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix $myipaddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
    }

    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -Name "$($VMName)NetworkSecurityGroup" -SecurityRules $nsgRule
    $SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix -NetworkSecurityGroupId $nsg.Id
    $Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
    $PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id -NetworkSecurityGroupId $nsg.Id
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version $version

    # Get the Marketplace plan information, if needed    
    $vmImage = Get-AzVMImage -Location $LocationName -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version $version
    if ( ![String]::IsNullOrWhiteSpace($vmImage.PurchasePlan)) {
        
        # Set the Marketplace plan information        
        $VirtualMachine = Set-AzVMPlan -VM $VirtualMachine -Publisher $vmImage.PurchasePlan.Publisher -Product $vmImage.PurchasePlan.Product -Name $vmImage.PurchasePlan.Name
        
        # Check if purchase plan terms have been accepted on this subscription, if not then prompt for confirmation to accept them
        $agreementTerms = Get-AzMarketplaceTerms -Publisher $vmImage.PurchasePlan.Publisher -Product $vmImage.PurchasePlan.Product -Name $vmImage.PurchasePlan.Name
        if ($agreementTerms.Accepted -eq $false) {
            Set-AzMarketplaceTerms -Publisher $vmImage.PurchasePlan.Publisher -Product $vmImage.PurchasePlan.Product -Name $vmImage.PurchasePlan.Name -Terms $agreementTerms -Accept -Confirm
        }
    }
    
    # Create VM
    New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose -ErrorAction Stop
    $publicIP = Get-AzPublicIpAddress -Name $PIP.name -ResourceGroupName $ResourceGroupName

    # Remotely connect after VM is initialized
    "Public IP to connect to: $($publicIP.IpAddress)"
    if (($os -eq "windows") -or ($os -eq "w")) {
        mstsc "/v:$($publicIP.IpAddress)"
    }
    elseif (($os -eq "linux") -or ($os -eq "l")) {
        
        #TODO: Search for Linux based Windows Terminal profiles
        # $wtSettingsLocation = (Get-Item "$Env:LocalAppData\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json") 
        # $wtSettings = Get-Content $wtSettingsLocation -Raw | ConvertFrom-Json

        # $wtLinuxProfiles = $wtSettings.profiles.list | Where-Object {$_.name -like "*suse*" }
        # $ResourceGroupNamePatterns = $names | Where-Object { $_ –ne "cloud-shell-storage-eastus" }
        # $ResourceGroupNamePatterns = $ResourceGroupNamePatterns | Where-Object { $_ –ne "ClassicVMRG" }

        # Attempt with Ubuntu in Windows Terminal first
        try {
            wt -p "Ubuntu-20.04" ssh "$($VMLocalAdminUser)@$($publicIP.IpAddress)"
        }
        catch {
            # If Windows Terminal is not installed, attempt to SSH via PowerShell instead. Can be glitchy
            ssh "$($VMLocalAdminUser)@$($publicIP.IpAddress)"
        }        
    }
}
catch {
    throw $_
}
