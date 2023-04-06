if ($args.count -gt 4) {[string]$APIUsername = $args[4],$args[0] -join "\"}else{[string]$APIUsername = $args[0]}

[securestring]$APIPassword =  ConvertTo-SecureString $args[1] -AsPlainText -Force
$Username = $args[2]
$FolderName = $args[3]

### User Configuration Items ###

$SecretServerURL = "https://server/url"         #Your Secret Server URL   
$PFolderBaseID = 0                              #FolderID for Base Folder
$FolderOwnerUsers = @("Manager1","Manager2")    #Usernames as shown on secret server users
$FolderOwnerGroups =  @("ManagementGroup")      #Groupnames as shown on secret server groups
$AllowedTemplateIDs = @()                       #comma separated list of alllowed template ids
#$logFile = "c:\temp\ss-EnhancedPersonalFolders.log"  #uncomment this line to enable logging to specified file

### End User Config Items ### 
$reqPermissions = "Administer Folders","View Folders","View Groups","View Roles","View Secret Policy","View Secret Templates","View Users"

if ($null -ne $logfile){(get-date).ToString() + ":`t" + $args[0,2,3] | Add-Content -path $logFile}
try {
    $Session = New-TssSession -SecretServer $SecretServerURL -Credential (New-Object System.Management.Automation.PSCredential ($APIUsername, $APIPassword))
    if ($null -ne $logfile){(get-date).ToString() + ":`t" + "Connected to " + $session.secretserver | Add-Content -path $logFile}
    [array]$missingPermissions = (Compare-Object -ReferenceObject (Show-TssCurrentUser -TssSession $session).Permissions.name -DifferenceObject $reqPermissions | Where-Object {$_.sideindicator -eq "=>"}).inputobject
    if ($missingPermissions.Count) { throw "API Account missing Role Permisions: " + ($missingPermissions -join "/")}
    $existingFolder = Search-TssFolder -TssSession $Session -ParentFolderId $PFolderBaseID -SearchText $FolderName
    if ($null -eq $existingFolder) {
        $newFolder = New-TssFolder -TssSession $Session -FolderName $FolderName -ParentFolderId $PFolderBaseID -InheritPermissions:$false
        foreach ($OwnerUserName in $FolderOwnerUsers){Add-TssFolderPermission -TssSession $Session -FolderId $newFolder.id -UserName $OwnerUserName -FolderRole "owner" -SecretRole "owner" | Out-Null}
        foreach ($GroupName in $FolderOwnerGroups){Add-TssFolderPermission -TssSession $Session -FolderId $newFolder.id -Group $GroupName -FolderRole "owner" -SecretRole "owner" | Out-Null}
        Add-TssFolderPermission -TssSession $Session -FolderId $newFolder.id -Username $username -FolderRole "add secret" -SecretRole "edit" | Out-Null
        if ($AllowedTemplateIDs.count -gt 0){set-TssFolder -TssSession $Session -Id $newFolder.id -AllowedTemplate $AllowedTemplateIDs}
    }else{Write-Verbose ("Folder Exists:" + $existingFolder.FolderId)}
}Catch{if ($null -ne $logFile){(get-date).ToString() + ":`t" + $_ | Add-Content -path $logFile}else{write-error $_}}

