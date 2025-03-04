https://guides.hakedev.com/wiki/proxmox/windows-11-clone

```
C:\Windows\System32\Sysprep\sysprep.exe /audit

Disable-BitLocker -MountPoint "C:"
Get-BitLockerVolume -MountPoint "C:"

Get-AppxPackage -AllUsers Microsoft.OneDriveSync | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ 'Microsoft.OneDriveSync' | Remove-AppxProvisionedPackage -Online

Get-AppxPackage -AllUsers *CoPilot* | Remove-AppxPackage -AllUsers 
Get-AppxProvisionedPackage -Online | where-object {$_.PackageName -like "*Copilot*"} | Remove-AppxProvisionedPackage -Online 
```