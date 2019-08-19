# Written by: Matt Elsberry - 08/07/2019
$ImprivataLicences = 1000 # This is the toal number of Imprivata Licenses that you have.
$InactivityTime = 42 # Amount of DAYS since last logon. Any account LAST LOGON DATE greater than this number will be removed.
$UnenrolledDaysLimit = 42 # Amount of DAYS that the account remains UNENROLLED greater than this number will be removed.
$AdSecurityGroup = "imprivata_users" # ActiveDirectory Security group in which the Imprivata users are assigned.
$ExcludedUsers = "impmaintacct,headhoncho" # This is a list of users that you want to Exclude from being removed. These are generally managers or service accounts.
$EmailFromAddress = "Imprivata.Maintenance@ourcompany.org" # This is the FROM address that will appear in the email.
$EmailGroup = "SCRIPTSendMail_Imprivata" # This is the AD Security group to wich the members will be sent the report.
$EmailSubject = "Imprivata User Maintenance - REMOVED ACCOUNTS" # This is the email SUBJECT.
$EmailSMTPServer = "ourcompany-org.mail.protection.outlook.com"  # This is the SMTP server for the email function.
$ScriptDir = "\\MyServer\Imprivata\Reports\Inactive" # This is the root directory in which the script resides.
$ImpCSVDir = "$ScriptDir\Exports" # This is the directory to which Imprivata exports the CSV reports. THIS IS CONFIGURED IN IMPRIVATA.
$GenericAcctDesc = "Generic Account" # Line text from AD description field that indicates a Generic account

# --------- DO NOT CHANGE ANYTHING BELOW THIS LINE ------------------

New-Item -ItemType Directory -Force -Path "$ScriptDir\Logs"
New-Item -ItemType Directory -Force -Path "$ScriptDir\UnenrolledCheck" # For Unenrolled user handling and tracking
$Unenrolled = "$ScriptDir\UnenrolledCheck" # For Unenrolled user handling and tracking
$RunningList = "$Unenrolled\RunningList.csv" # For Unenrolled user handling and tracking
$RunningListTEMP = "$Unenrolled\RunningListTEMP.csv" # For Unenrolled user handling and tracking
$LogDir = "$ScriptDir\Logs" # This is the log directory
$DoThisOne = "" # This forces the variable to clear. DO NOT CHANGE
$EmailRecipients = (Get-ADGroupMember $EmailGroup | Get-ADUser -Properties EmailAddress | Select-Object -Expand EmailAddress)
Set-Location -Path $ImpCSVDir
dir | Export-Csv $LogDir\CSVFiles.csv
$Exports = import-csv "$LogDir\CSVFiles.csv"
$OutFile = "$LogDir\log.txt"
$EmailFile = "$LogDir\Imprivata_User_Maint_Email.csv"
$UnenrolledFile = "$Unenrolled\Unenrolled.csv" # For Unenrolled user handling and tracking
$EmailHeader = "Username, First Name, Last Name, Last Logon Date"
$UnenrolledHeader = "user, First Name, Last Name" # For Unenrolled user handling and tracking
$RunningListHeader = "user, First Name, Last Name, UnenrolledDays" # For Unenrolled user handling and tracking
$Date = Get-Date
$ExcludedUserCount = 0
$UserCount = 0
$UnenrolledCount = 0
$GenericCount = 0

$RunningListPathTest1 = Test-Path  $RunningList
    If ($RunningListPathTest1 -eq $False)
        {Add-Content -Path $RunningList -Value $RunningListHeader}
$RunningListPathTest2 = Test-Path  $RunningListTEMP
    If ($RunningListPathTest2 -eq $False)
        {Add-Content -Path $RunningListTEMP -Value $RunningListHeader}

if (Test-Path  $EmailFile)
    {Remove-Item -Path $EmailFile}
	
if (Test-Path  $UnenrolledFile)  # For Unenrolled user handling and tracking
    {Remove-Item -Path $UnenrolledFile}

Add-Content -Path $EmailFile -Value $EmailHeader
Add-Content -Path $UnenrolledFile -Value $UnenrolledHeader # For Unenrolled user handling and tracking
$RemovedUserCount = 0

foreach ($Export in $Exports) 
{
$ExecutedFile = $Export.Name

if ($ExecutedFile -ne "Logs")
    {
    $GetFile = Get-Content $OutFile | Select-String $ExecutedFile -SimpleMatch
    if ($GetFile -eq $null)   
	    {
	    $Status = "Has been executed on $Date"
	    Write-Host "$ExecutedFile is fresh meat and is about to get pruned"
        $OutData = $ExecutedFile + ", " + $Status
        Add-Content -Path $OutFile -Value $OutData
        
        $DoThisOne = $ExecutedFile
	    }
	    Else 
	    {	    
	    Write-Host "$ExecutedFile Has already been executed and can be deleted."
	    }
    }
}

if ($DoThisOne -ne "")
    {
    Write-Host "Let's start removing these users from Imprivata..."
    $users = import-csv $ImpCSVDir\$DoThisOne
        Foreach ($user in $users)
        {
		$UserCount = $UserCount + 1
        if ($ExcludedUsers.Split(",") -eq $user.user)
            {
			$ExcludedUserCount = $ExcludedUserCount + 1
            }
        ELSE
            {
			if ($user."User Last Logged On" -eq "N/A")
                {                
				$UnenrolledOutData = $user.user + "," + $user."First Name" + "," + $user."Last Name" # For Unenrolled user handling and tracking
                Add-Content -Path $UnenrolledFile -Value $UnenrolledOutData # - This generates the list of Unenrolled users that will be used later.
				$UnenrolledCount = $UnenrolledCount + 1 # For Unenrolled user handling and tracking
                }
            ELSE
                {
                $a,$b,$c,$d,$e,$f = $user."User Last Logged On".split(" ")
                $LastLogonDate = $a + " " + $b + " " + $c
                If ((get-date).AddDays(-$InactivityTime) -gt $LastLogonDate)
                    {  
				    #Write-Host Removing $user.User
                    Remove-adgroupmember -identity $AdSecurityGroup -members $user.user -Confirm:$false
					$RemovedUserCount = $RemovedUserCount + 1
					$EmailOutData = $user.user + "," + $user."First Name" + "," + $user."Last Name" + "," + $LastLogonDate
					Add-Content -Path $EmailFile -Value $EmailOutData					
                    }
                }
            }
        }
	Remove-Item $ImpCSVDir\$DoThisOne
    }
# ---- Start Dealing with Unenrolled users --
$UnenrolledUsers = import-csv $UnenrolledFile # Unenrolled users that were picked up during this scan
	Foreach ($UnenrolledUser in $UnenrolledUsers)
    {
    $GenericUser = Get-AdUser $UnenrolledUser.user -Properties Description | Select Description
    $GenericUser = $GenericUser -replace ".*=" -replace '[{@}]'
    IF ($GenericUser -eq $GenericAcctDesc)
        {$GenericCount = $GenericCount + 1
        $UnenrolledUserFound = "no"
        }
    ELSE
        {
    $UnenrolledUserFound = "no"
	$UnenrolledRunningLists = import-csv $RunningList
    ForEach ($UnenrolledRunningList in $UnenrolledRunningLists)
        {
		If ($UnenrolledUser.user -eq $UnenrolledRunningList.user)
			{
            IF ([int]$UnenrolledRunningList.UnenrolledDays -ge $UnenrolledDaysLimit)
				{
				#Write-Host Removing Unenrolled user $UnenrolledRunningList.user
				Remove-adgroupmember -identity $AdSecurityGroup -members $UnenrolledRunningList.user -Confirm:$false
				$RemovedUserCount = $RemovedUserCount + 1
				$EmailOutDataUnenrolled = $UnenrolledRunningList.user + "," + $UnenrolledRunningList."First Name" + "," + $UnenrolledRunningList."Last Name" + "," + "Unenrolled for " + $UnenrolledRunningList.UnenrolledDays + " days"
				Add-Content -Path $EmailFile -Value $EmailOutDataUnenrolled
				}
            [int]$UnenrolledDays = $UnenrolledRunningList.UnenrolledDays                    
            $UnenrolledUserFound = "yes"
            [int]$UnenrolledDays = [int]$UnenrolledDays + 1
            $UnenrolledListOutda = $UnenrolledRunningList.user + "," + $UnenrolledRunningList."First Name" + "," + $UnenrolledRunningList."Last Name" + "," + [int]$UnenrolledDays				    
			Add-Content -Path $RunningListTEMP -Value $UnenrolledListOutda
            }
        }
        If ($UnenrolledUserFound -eq "no")
            {            
            [int]$UnenrolledDays = 1
            $UnenrolledListOutda = $UnenrolledUser.user + "," + $UnenrolledUser."First Name" + "," + $UnenrolledUser."Last Name" + "," + [int]$UnenrolledDays			
			Add-Content -Path $RunningListTEMP -Value $UnenrolledListOutda            
            }
        }
    }

$UnenrolledCount = $UnenrolledCount - $GenericCount
    
# ---- End Unenrolled users --

$RemainingLicenses = $ImprivataLicences - $UserCount
$UnenrollInactivity = $UnenrolledDaysLimit / 7
$UnenrollWeeks = [math]::floor($UnenrollInactivity)
$UserInactivity = $InactivityTime / 7
$InactivityWeeks = [math]::floor($UserInactivity)

$DeletionInfo = Import-Csv -Path $EmailFile | ConvertTo-Html -Fragment
$mailBody = 
@"
Hello I.T. Folks,</br>
For your records, here is a list of users that have been Auto-removed from Imprivata due to inactivity greater than <b>$InactivityWeeks</b> weeks OR failure to enroll their badge within <b>$UnenrollWeeks</b> weeks.</br>
A CSV file has been attached containing these removed Users.</br>
You currently have (<b>$RemainingLicenses</b>) licenses remaining of your total ($ImprivataLicences).</br>
</br>
Total users removed = <font color="red"><b>$RemovedUserCount</b></font></br>
</br>
$DeletionInfo</br>
</br>
There were ($ExcludedUserCount) users excluded from this removal.</br>
These uses are: <i>$ExcludedUsers</i></br>
<hr>
There are currently (<b>$UnenrolledCount</b>) Users that are Unenrolled and are being tracked by the script.</br>
There are (<b>$GenericCount</b>) Unenrolled Generic Accounts that are <b>NOT</b> being tracked.
Best Regards,</br>
<i>Script written by: Matt Elsberry</i></br>
This script was executed from <b>$env:computername</b> by <b>$env:UserName</b></br>
"@

Send-MailMessage -Body $mailBody -BodyAsHtml `
-From $EmailFromAddress -To $EmailRecipients `
-Subject $EmailSubject -Encoding $([System.Text.Encoding]::UTF8) `
-SmtpServer $EmailSMTPServer `
-Attachment $EmailFile
Remove-Item $EmailFile
Remove-Item -Path $RunningList
Remove-Item -Path $UnenrolledFile
Rename-Item -Path $RunningListTEMP -NewName $RunningList
