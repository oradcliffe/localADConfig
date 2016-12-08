configuration ADconfig
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds
    ) 
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
        $RootOUs = ('IT', 'Marketing', 'Accounting')
        $ChildOUs = ('Users', 'Computers', 'Groups')
        $Userdata = (Import-Csv -Delimiter ',' -LiteralPath C:\Users\Administrator\Desktop\users.csv)

        LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyAndAutoCorrect'            
            RebootNodeIfNeeded = $true            
        }

        xADRecycleBin RecycleBin
        {
           EnterpriseAdministratorCredential = $DomainCreds
           ForestFQDN = $DomainName
        }

                ### OUs ###
        $DomainRoot = "DC=$($DomainName -replace '\.',',DC=')"
        $DependsOn_OU = @()

        ForEach ($RootOU in $RootOUs) {

            xADOrganizationalUnit "OU_$RootOU"
            {
                Name = $RootOU
                Path = $DomainRoot
                ProtectedFromAccidentalDeletion = $true
                Description = "OU for $RootOU"
                Credential = $DomainCreds
                Ensure = 'Present'
                DependsOn = '[xADRecycleBin]RecycleBin'
            }

            ForEach ($ChildOU in $ChildOUs) {
                
                xADOrganizationalUnit "OU_$($RootOU)_$ChildOU"
                {
                    Name = $ChildOU
                    Path = "OU=$RootOU,$DomainRoot"
                    ProtectedFromAccidentalDeletion = $true
                    Credential = $DomainCreds
                    Ensure = 'Present'
                    DependsOn = "[xADOrganizationalUnit]OU_$RootOU"
                }

                $DependsOn_OU += "[xADOrganizationalUnit]OU_$($RootOU)_$ChildOU"
            }

        }


        ### USERS ###
        $DependsOn_User = @()
        ForEach ($User in $Userdata) {

            xADUser "NewADUser_$($User.UserName)"
            {
                DomainName = $DomainName
                Ensure = 'Present'
                UserName = $User.UserName
                UserPrincipalName = $User.UPN
                GivenName = $User.Givenname
                Surname = $User.Surname
                JobTitle = $User.Title
                Path = "OU=Users,OU=$($User.Dept),$DomainRoot"
                Enabled = $true
                Password = New-Object -TypeName PSCredential -ArgumentList 'JustPassword', (ConvertTo-SecureString -String $User.Password -AsPlainText -Force)
                DependsOn = $DependsOn_OU
            }
            $DependsOn_User += "[xADUser]NewADUser_$($User.UserName)"
        }


        ### GROUPS ###
        ForEach ($RootOU in $RootOUs) {
            xADGroup "NewADGroup_$RootOU"
            {
                GroupName = "G_$RootOU"
                GroupScope = 'Global'
                Description = "Global group for $RootOU"
                Category = 'Security'
                Members = ($Users | Where-Object {$_.Dept -eq $RootOU}).UserName
                Path = "OU=Groups,OU=$RootOU,$DomainRoot"
                Ensure = 'Present'
                DependsOn = $DependsOn_User
            }
        }

         ###Add IT to Domain Admins###
        
        xADGroup addIT
        {
            GroupName = 'Domain Admins'
            MembersToInclude = 'G_IT'
            Ensure = 'Present'
        }
   }
}

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}