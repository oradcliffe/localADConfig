configuration sharedDirConfig
{ 
   param 
   () 
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xSMBShare, cNtfsAccessControl

    Node localhost
    {

    $publicDirPath = "$env:SystemDrive\shares\Public"
    $rootDirPath = "$env:SystemDrive\shares"
    $RootOUs = ('IT', 'Marketing', 'Accounting')
    $itGroupName = 'G_IT'
    $groupNamePrefix = 'G_'

        LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyAndAutoCorrect'            
            RebootNodeIfNeeded = $true
        }

        File publicDir
        {
            Type = 'Directory'
            Ensure = 'Present'
            DestinationPath = $publicDirPath
        }

        foreach ($RootOU in $RootOUs) {
            File "groupDir_$RootOU"
            {
                Type = 'Directory'
                Ensure = 'Present'
                DestinationPath = "$rootDirPath\$RootOU"
            }
        }

        cNtfsPermissionEntry publicDir_FullControl
        {
            Ensure = 'Present'
            Path = $publicDirPath
            Principal = $itGroupName
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = 'FullControl'
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]publicDir'
        }

        cNtfsPermissionEntry publicDir_Modify
        {
            Ensure = 'Present'
            Path = $publicDirPath
            Principal = 'Domain Users'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = 'Modify'
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]publicDir'
        }

        foreach ($RootOU in $RootOUs) {
            if ($RootOU -eq 'IT'){
                cNtfsPermissionEntry "groupDir_$RootOU"
                    {
                        Ensure = 'Present'
                        Path = "$rootDirPath\$RootOU"
                        Principal = $itGroupName
                        AccessControlInformation = @(
                            cNtfsAccessControlInformation
                            {
                                AccessControlType = 'Allow'
                                FileSystemRights = 'FullControl'
                                Inheritance = 'ThisFolderSubfoldersAndFiles'
                                NoPropagateInherit = $false
                            }
                        )
                        DependsOn = "[File]groupDir_$RootOU"
                    }
            }
            else {
                cNtfsPermissionEntry "groupDir_Modify_$RootOU"
                    {
                        Ensure = 'Present'
                        Path = "$rootDirPath\$RootOU"
                        Principal = "$groupNamePrefix$RootOU"
                        AccessControlInformation = @(
                            cNtfsAccessControlInformation
                            {
                                AccessControlType = 'Allow'
                                FileSystemRights = 'Modify'
                                Inheritance = 'ThisFolderSubfoldersAndFiles'
                                NoPropagateInherit = $false
                            }
                        )
                        DependsOn = "[File]groupDir_$RootOU"
                    }
                cNtfsPermissionEntry "groupDir_fullControl_$RootOU"
                    {
                        Ensure = 'Present'
                        Path = "$rootDirPath\$RootOU"
                        Principal = "$itGroupName"
                        AccessControlInformation = @(
                            cNtfsAccessControlInformation
                            {
                                AccessControlType = 'Allow'
                                FileSystemRights = 'FullControl'
                                Inheritance = 'ThisFolderSubfoldersAndFiles'
                                NoPropagateInherit = $false
                            }
                        )
                        DependsOn = "[File]groupDir_$RootOU"
                    }
            }
        }

        xSmbShare Public
        {
            Ensure = 'Present'
            Name   = 'Public'
            Path = $publicDirPath  
            FullAccess = "$domainName\$itGroupName"
            ChangeAccess = "$domainName\Domain Users"
            Description = "This is a public share"
            DependsOn = '[File]publicDir'
        }

        foreach ($RootOU in $RootOUs) {
            if ($RootOU -eq 'IT'){
                    xSmbShare "private_$RootOU"
                {
                    Ensure = 'Present'
                    Name   = "$RootOU"
                    Path = "$rootDirPath\$RootOU"  
                    FullAccess = "$domainName\$itGroupName"
                    Description = "This is a private share for $RootOU"
                    DependsOn = "[File]groupDir_$RootOU"
                }
            }
            else {
                xSmbShare "private_$RootOU"
                {
                    Ensure = 'Present'
                    Name   = "$RootOU"
                    Path = "$rootDirPath\$RootOU"  
                    FullAccess = "$domainName\$itGroupName"
                    ChangeAccess = "$domainName\$groupNamePrefix$RootOU"
                    Description = "This is a private share for $RootOU"
                    DependsOn = "[File]groupDir_$RootOU"
                }
            }
        }

        WindowsFeature DFSNamespace
        {
            Name = 'FS-DFS-Namespace'
            Ensure = 'Present'
        }

        WindowsFeature DFSReplication
        {
            Name = 'FS-DFS-Replication'
            Ensure = 'Present'
        }

        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = 'Present'
            Name = 'RSAT-DFS-Mgmt-Con'
        }
    }
}