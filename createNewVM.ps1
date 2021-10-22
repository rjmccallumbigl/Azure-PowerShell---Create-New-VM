###########################################################################################################################################################
<#
# .SYNOPSIS
#       Create a new Managed Azure VM.
#
# .DESCRIPTION
#       Create a new Azure VM with a Managed Disk. If you'd like to modify the defaults, please review & change the code prior to running.
#       https://docs.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-4.4.0
#
# .NOTES
        Version: 0.7.2
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
# .PARAMETER image
#       (Set 1) Image string in the format of "Publisher|Offer|Plan|Version", accepts | or :
#
# .PARAMETER PublisherName
#       (Set 2) Publisher of your preferred image
# .PARAMETER offerName
#       (Set 2) Offer of your preferred image
# .PARAMETER skuName
#       (Set 2) SKU of your preferred image
# .PARAMETER version
#       (Set 2) Version of your preferred image [Optional]
#
# .EXAMPLE
#       .\createNewVM.ps1 -n name -u Username -i "MicrosoftWindowsServer|WindowsServer|2019-Datacenter"
# .EXAMPLE
#       .\createNewVM.ps1 -image "RedHat:rhel:7-lvm"
# .EXAMPLE
#       .\createNewVM.ps1 -publisherName "SUSE" -offerName "SLES-SAP" -skuName "12-SP3" -VMLocalAdminUser rymccall -vmName susetestvm
# .EXAMPLE
#       $publisherName = "Oracle"
#       $offerName = "Oracle-Linux"
#       $skuName = "77"
#       .\createNewVM.ps1 -publisherName $publisherName -offerName $offerName -skuName $skuName -VMLocalAdminUser "rymccall" -vmName "oracletestvm"
# .EXAMPLE
#       $LocationName = "eastus"
#       $publishers = Get-AzVMImagePublisher -Location $LocationName | Select-Object PublisherName
#       $publisherName = ($publishers | Where-Object { $_ -like "*Canonical*"})[0].publishername
#       $offers = Get-AzVMImageOffer -Location $LocationName -PublisherName $publisherName | Select-Object Offer
#       $offerName = ($offers | Where-Object { $_ -like "*UbuntuServer*"})[0].Offer
#       $skus = Get-AzVMImageSku -Location $LocationName -PublisherName $publisherName -Offer $offerName | Select-Object Skus
#       $skuName = ($skus | Where-Object { $_ -like "*19.*"})[0].skus
#       .\createNewVM.ps1 -publisherName $publisherName -offerName $offerName -skuName $skuName -VMLocalAdminUser "rymccall" -vmName "ubuntutestvm"
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
    [Parameter(Mandatory = $true, HelpMessage = "Image (Set 1)", ParameterSetName = "imageSet")]
    [Alias('i')]
    [ValidateScript({ 
        ($_ -like "*|*|*" -or $_ -like "*:*:*" )
        })]
    [string]
    $image,
    [Parameter(Mandatory = $true, HelpMessage = "Publisher (Set 2)", ParameterSetName = "notImageSet")]    
    [string]
    $publisherName,
    [Parameter(Mandatory = $true, HelpMessage = "Offer (Set 2)", ParameterSetName = "notImageSet")]    
    [string]
    $offerName,
    [Parameter(Mandatory = $true, HelpMessage = "SKU (Set 2)", ParameterSetName = "notImageSet")]    
    [string]
    $skuName,
    [Parameter(Mandatory = $false, HelpMessage = "Version (Set 2)", ParameterSetName = "notImageSet")]    
    [string]
    $version
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
# Return publishers/offers/skus/versions for this script  
# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage
# 
# $LocationName = "eastus"
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

# Example image version for all images, modify as necessary
if ([String]::IsNullOrWhiteSpace($version)) {
    $version = "latest"
}

# Use image string if variable passed in
if ($image) {
    $splitImage = $image -split { $_ -eq "|" -or $_ -eq ":" }
    $publisherName = $splitImage[0]
    $offerName = $splitImage[1]
    $skuName = $splitImage[2]
    if ($splitImage[3]) { 
        $version = $splitImage[3] 
    }
}

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

# Example Linux VM config, modify as necessary
# $publisherName = "Oracle"
# $offerName = "Oracle-Linux"
# $skuName = "77"

# Example Linux VM config, modify as necessary
# $publisherName = "Canonical"
# $offerName = "UbuntuServer"
# $skuName = "19.04"

###################################################################

# Get your IP Address to scope remote access to only your IP
$myipaddress = (Invoke-WebRequest https://myexternalip.com/raw).content;

# Create VM configuration
try {
    # Get the Marketplace image information
    if ($version -eq "latest") {
        $vmLatestImage = (Get-AzVMImage -Location $LocationName -PublisherName $publisherName -Offer $offerName -Skus $skuName -ErrorAction Stop)[-1]
        $vmImage = Get-AzVMImage -Location $LocationName -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version $vmLatestImage.Version -ErrorAction Stop
    }
    else {
        $vmImage = Get-AzVMImage -Location $LocationName -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version $version -ErrorAction Stop
    }

    $os = $vmImage.OSDiskImage.OperatingSystem
    
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName -ErrorAction Stop
    $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -ErrorAction Stop

    if ($os -eq "windows") {
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate -ErrorAction Stop
        $nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowRDP -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix $myipaddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow -ErrorAction Stop
    }
    elseif ($os -eq "linux") {
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $VMName -Credential $Credential -ErrorAction Stop
        $nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowSSH -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix $myipaddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow -ErrorAction Stop
    }

    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -Name "$($VMName)NetworkSecurityGroup" -SecurityRules $nsgRule -ErrorAction Stop
    $SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop
    $Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet -ErrorAction Stop
    $PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic -ErrorAction Stop
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id -ErrorAction Stop
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version $version -ErrorAction Stop
    
    # Check if this image requires Purchase Plan information to be filled out
    if ( ![String]::IsNullOrWhiteSpace($vmImage.PurchasePlan)) {

        # Set the Marketplace plan information
        $VirtualMachine = Set-AzVMPlan -VM $VirtualMachine -Publisher $vmImage.PurchasePlan.Publisher -Product $vmImage.PurchasePlan.Product -Name $vmImage.PurchasePlan.Name -ErrorAction Stop

        # Check if purchase plan terms have been accepted on this subscription, if not then prompt for confirmation to accept them
        $agreementTerms = Get-AzMarketplaceTerms -Publisher $vmImage.PurchasePlan.Publisher -Product $vmImage.PurchasePlan.Product -Name $vmImage.PurchasePlan.Name -ErrorAction Stop
        if ($agreementTerms.Accepted -eq $false) {
            Set-AzMarketplaceTerms -Publisher $vmImage.PurchasePlan.Publisher -Product $vmImage.PurchasePlan.Product -Name $vmImage.PurchasePlan.Name -Terms $agreementTerms -Accept -Confirm -ErrorAction Stop
        }
    }

    # Create VM
    New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose -ErrorAction Stop
    $publicIP = Get-AzPublicIpAddress -Name $PIP.name -ResourceGroupName $ResourceGroupName -ErrorAction Stop

    # Remotely connect after VM is initialized
    "Public IP to connect to: $($publicIP.IpAddress)"
    if (($os -eq "windows") -or ($os -eq "w")) {
        mstsc "/v:$($publicIP.IpAddress)"
    }
    elseif (($os -eq "linux") -or ($os -eq "l")) {

        # Attempt with Linux profiles in Windows Terminal first if installed
        try {
            $wtSettingsLocation = (Get-Item "$Env:LocalAppData\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json" -ErrorAction Stop)
            $wtSettingsRaw = Get-Content $wtSettingsLocation -Raw
            $wtSettings = $wtSettingsRaw | ConvertFrom-Json
            $wtProfiles = $wtSettings.profiles.list

            # Some WSL options that may be installed in your WSL (modify as necessary)
            $wtLinuxOptions = @("ubuntu", "suse", "debian")
            ForEach ( $wtProfile in $wtProfiles) {
                ForEach ( $wtLinuxOption in $wtLinuxOptions) {
                    if ($wtProfile.name -like "*$($wtLinuxOption)*" ) {
                        wt -p $wtProfile.name ssh "$($VMLocalAdminUser)@$($publicIP.IpAddress)"
                        return
                    }
                }
            }
        }
        catch {
            try {
                # If Windows Terminal is not installed, attempt to SSH via Putty instead
                putty -ssh "$($VMLocalAdminUser)@$($publicIP.IpAddress)"
                return
            }
            catch {
                # If Windows Terminal and Putty are not installed, attempt to SSH via PowerShell instead. Can be glitchy
                ssh "$($VMLocalAdminUser)@$($publicIP.IpAddress)"
            }
        }
    }
}
catch {
    throw $_
}

