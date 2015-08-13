# VMRC-Direct-Links
Creates an HTML file with direct VMRC links for VMware VMs located in vCenter.  It is meant to provide the ability to console to a VM when vCenter is offline during maintenance.

**Tested With**
- Powershell 4
- PowerCLI 6.0

**Configuration**
Create a VICredentialStore with credentials for your vcenter server and credentials for every ESXi server in the cluster.

**PowerCLI commands to create the VICredentialStore file.**

Passwords are hashed but are reversable.  Rights to the file are restricted to the user who creates the file
```
New-VICredentialStoreItem -Host <vcenter_name> -User <user_name> -Password <password> -File 'c:\Path\To\Credential\File.xml'
New-VICredentialStoreItem -Host <esxi_server_01> -User <user_name> -Password <password> -File 'c:\Path\To\Credential\File.xml'
New-VICredentialStoreItem -Host <esxi_server_02> -User <user_name> -Password <password> -File 'c:\Path\To\Credential\File.xml'
New-VICredentialStoreItem -Host <esxi_server_XX> -User <user_name> -Password <password> -File 'c:\Path\To\Credential\File.xml'
```

**Parameters**
```
PARAMETER
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
```

#####EXAMPLE
```
./GenerateLinks.ps1 -vcenter yourvcenterserver.domain.local -datacenter 'Datacenter Name' -cluster 'Cluster String' -vmFolder 'Servers\Windows 2003' -credPath 'c:\temp\mycredentails.xml' -outFile 'c:\temp\vmrclinks.html'
```
