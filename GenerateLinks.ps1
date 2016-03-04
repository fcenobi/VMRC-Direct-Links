<#
.SYNOPSIS

.DESCRIPTION
Creates an HTML file with direct VMRC links for VMware VMs located in vCenter.  It is meant to provide the ability to console to a VM when vCenter is offline during maintenance.

.PARAMETER
-vcenter
    The target vcenter to connect to
-datacenter
    The target datacenter to work/search within
-cluster
    The cluster in which to deploy the cloned templates
-vmFolder
    [Optional] The folder path to the VMs you want to create VMRC links.  If not defined will provide links for all VMs in the defined Cluster
-credPath
    The path to the VICredentialStore file that contains the necessary credentials to connect to vCenter and each ESXi host directly
-outFile
    The file path to where you want the output stored

.EXAMPLE
GenerateLinks -vcenter yourvcenterserver.domain.local -datacenter 'Datacenter Name' -cluster 'Cluster String' -vmFolder 'Servers\Windows 2003' -credPath 'c:\temp\mycredentails.xml' -outFile 'c:\temp\vmrclinks.html'
#>

############# GLOBALS ##############
param(
    # Vcenter containing the VMs you're interested in
    [String]$vcenter = "",
    # Datacenter Filter
    [String]$datacenter="",
    # Cluster Filter
    [String]$cluster="",
    # Folder path containing VMs you want to create direct VMRC links for
    #$vmFolder="NetLok\Custom VPN's"
    [String]$vmFolder=$null,
    # Credential File Path
    [String]$credPath = "",
    # Output File
    $outFile = ""
)
############# END GLOBALS ##########

# Check if VMware PowerCLI is loaded
if((Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null)
{
    # Since not loaded, try loading it
	Add-PSSnapin VMware.VimAutomation.Core
    if((Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null){
        Write-Host "ERROR: Unable to load VMware PowerCLI"
        Break
    }
}

# Resolve folder path to Folder Object based on the path
function Get-FolderFromPath
{
    param(
        [String] $Path
    )
    $chunks = $Path.Split('\')
    $root = Get-View -VIObject (Get-Folder -Name $chunks[0])
    if (-not $?){return}
 
    $chunks[1..$chunks.Count] | % {
        $chunk = $_
        $child = $root.ChildEntity | ? {$_.Type -eq 'Folder'} | ? { (Get-Folder -id ("{0}-{1}" -f ($_.Type, $_.Value))).Name -eq $chunk}
        if ($child -eq $null) { throw "Folder '$chunk' not found"}
        $root = Get-View -VIObject (Get-Folder -Id ("{0}-{1}" -f ($child.Type, $child.Value)))
        if (-not $?){return}
    }
    return (Get-Folder -Id ("{0}-{1}" -f ($root.MoRef.Type, $root.MoRef.Value)))
}

# Get the credential from the file
$credential = Get-VICredentialStoreItem -Host $vcenter -File $credPath

# Connect to vCenter
Connect-VIServer -Server $vcenter -User $credential.User -Password $credential.Password

# Load all the VMs from the vmFolder if defined or all VMs from the cluster
if($vmFolder.Length -gt 0){
	$folder = Get-FolderFromPath($vmFolder)
	if($folder -eq $null){
	    Write-Host "ERROR: $vmFolder Path NOT FOUND!  Halting."
	    Break
	}else{
		$vms = Get-VM -Location $folder | Select Id,Name,Description,VMHost
	}
}else{
	$vms = Get-VM -Location (Get-Datacenter -Name $datacenter) | Select Id,Name,Description,VMHost
}

# Check if there were any VMs found
if($vms.Count -eq 0){
    Write-Host "ERROR: No VMs found in $datacenter"
    Break
}

# Get all the hosts in the cluster
$hosts = Get-Cluster -Name $cluster | Get-VMHost

# Disconnect from vCenter
Disconnect-VIServer -Server $vcenter -Confirm:$false

# Empty array to store the vm objects
$outVMs = @()

# Connect to each host and search for VMs that are in the list of VMs from the Folder or Datacenter
ForEach($esxihost in $hosts){
    
    # Get the credential from the file
    $credential = Get-VICredentialStoreItem -Host $esxihost.Name -File $credPath

    Try{
    	# Connect to the ESXi Host using the retrieved credentials
		$conn = Connect-VIServer -Server $esxihost.Name -User $credential.User -Password $credential.Password
        if($conn.IsConnected){
            Write-Host "Connected to: $conn.Name"

            # Get all VMs on the ESXi Host
            $hostVMs = Get-VM -Location $esxihost.Name | Select Id,Name,VMHost

            # Check each VM on the host to see if it matches a VM pulled from the cluster or folder path
            ForEach($hostVM in $hostVMs){
                if(($vms.Name).Contains($hostVM.Name)){            
            
                    # Get the MoID from the Id string
                    $moid = (([String]$hostVM.Id).Split('-'))[1]
                    # Generate the VMRC link in HTML with the VM name as the Text
                    $link="<a href='vmrc://@$($hostVM.VMHost)/?moid=$($moid)'>$($hostVM.Name)</a>"
                    # Pull the description of the VM
                    $vmDesc=($vms | Where-Object -Property Name -eq -Value $hostVM.Name).Description

                    # Build a new objec with all the information
                    $obj = New-Object System.Object            
                    $obj | Add-Member -MemberType NoteProperty -Name VMRCLink -Value $link
                    $obj | Add-Member -MemberType NoteProperty -Name Description -Value $vmDesc
            
                    # Add the object to the array of VMs w/ VMRC links
                    $outVMs += $obj
                }
            }

            # Disconnect from the ESXi Host
            Disconnect-VIServer $esxihost.Name -Confirm:$false
        }else{
            Write-Host "Connection Failed For: $esxihost"
        }
    }Catch{
      $err = $_.Exception.Message
      Write-Host $err 
    }    
}

# If there is at least 1 VM to output generate the output file
if($outVMs.Count -gt 0){
    # Generate an HTML table of the VMs w/ VMRC links
    $outHTML = $outVMs | ConvertTo-Html

    # To get valid <a href> links in the out put we need to interpret convert the &lt; and &gt; in the out HTML back to < and >
    # then output it to a file
    Add-Type -AssemblyName System.Web
    [System.Web.HttpUtility]::HtmlDecode($outHTML) | Out-File $outFile
}else{
    Write-Host "INFO: No VMs to output"
}