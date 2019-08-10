# Written by: Matt Elsberry - 08/07/2019
$ImprivataLicences = 1772 # This is the toal number of Imprivata Licenses that you have.
$InactivityTime = 42 # Amount of DAYS since last logon. Any account LAST LOGON DATE greater than this number will be removed.
$AdSecurityGroup = "imprivata_users" # ActiveDirectory Security group in which the Imprivata users are assigned.
$ExcludedUsers = "impsrvacct,epicimprivata" # This is a list of users that you want to Exclude from being removed. These are generally managers or service accounts.
$EmailFromAddress = "Imprivata.Maintenance@ourcompany.org" # This is the FROM address that will appear in the email.
$EmailGroup = "SCRIPTSendMail_Imprivata" # This is the AD Security group to wich the members will be sent the report. # This is the AD Security group to wich the members will be sent the report.
$EmailSubject = "Imprivata User Maintenance - REMOVED ACCOUNTS" # This is the email SUBJECT.
$EmailSMTPServer = "ourcompany-org.mail.protection.outlook.com"  # This is the SMTP relay server for the email function.
$ScriptDir = "\\MyServer\Imprivata\Reports\Inactive" # This is the root directory in which the script resides.
$ImpCSVDir = "$ScriptDir\Exports" # This is the directory to which Imprivata exports the CSV reports. THIS IS CONFIGURED IN IMPRIVATA.
$LogDir = "$ScriptDir\Logs" # This is the log directory

# --------- DO NOT CHANGE ANYTHING BELOW THIS LINE -----------------

$DoThisOne = "" # This forces the variable to clear. DO NOT CHANGE
$EmailRecipients = (Get-ADGroupMember $EmailGroup | Get-ADUser -Properties EmailAddress | Select-Object -Expand EmailAddress)
Set-Location -Path $ImpCSVDir
dir | Export-Csv $LogDir\CSVFiles.csv
$Exports = import-csv "$LogDir\CSVFiles.csv"
$OutFile = "$LogDir\log.txt"
$EmailFile = "$LogDir\Imprivata_User_Maint_Email.csv"
$EmailHeader = "Username, First Name, Last Name, Last Logon Date"
$Date = Get-Date
$ExcludedUserCount = 0
$UserCount = 0

if (Test-Path  $EmailFile)
    {Remove-Item -Path $EmailFile}

Add-Content -Path $EmailFile -Value $EmailHeader
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
                }
            ELSE
                {
                $a,$b,$c,$d,$e,$f = $user."User Last Logged On".split(" ")
                $LastLogonDate = $a + " " + $b + " " + $c
                If ((get-date).AddDays(-$InactivityTime) -gt $LastLogonDate)
                    {  
				    Write-Host Removing $user.User
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

$RemainingLicenses = $ImprivataLicences - $UserCount
$InactivityWeeks = $InactivityTime / 7
$DeletionInfo = Import-Csv -Path $EmailFile | ConvertTo-Html -Fragment
$mailBody = 
@"
Hello I.T. Folks,</br>
For your records, here is a list of users that have been Auto-removed from Imprivata due to inactivity greater than <b>$InactivityWeeks</b> weeks.</br>
A CSV file has been attached containing these removed Users.</br>
You currently have (<b>$RemainingLicenses</b>) licenses remaining of your total ($ImprivataLicences).</br>
</br>
Total users removed = <font color="red"><b>$RemovedUserCount</b></font></br>
</br>
$DeletionInfo</br>
</br>
There were ($ExcludedUserCount) users excluded from this removal.</br>
These uses are: <i>$ExcludedUsers</i></br>
Best Regards,</br>
This script was executed from <b>$env:computername</b> by <b>$env:UserName</b></br>
<i>Script written by: Matt Elsberry</i></br>
"@

Send-MailMessage -Body $mailBody -BodyAsHtml `
-From $EmailFromAddress -To $EmailRecipients `
-Subject $EmailSubject -Encoding $([System.Text.Encoding]::UTF8) `
-SmtpServer $EmailSMTPServer `
-Attachment $EmailFile
Remove-Item $EmailFile
