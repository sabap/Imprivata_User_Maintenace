# Imprivata_User_Maintenace
Auto-remove inactive users from Imprivata (PowerShell)

This script will automatically purge users from Imprivata (Active Directory Security Group) based on a set duration of inactivity (Last Log On date).  Once setup, this script will completely automate this user maintenace as well as send email reports of the deleted users, license count etc, when the script is executed.

Prerequisites:
1. User account for Imprivata maintenance in Active Directory
2. Network share with permissions, granting the Imprivata maintenance user R/W access. (Example:  \\MyServer\Imprivata\Reports\Inactive\Exports )
3. Server or Workstation that can be used for running scheduled tasks and has the ActiveDirectoy PowerShell module installed.
    Go here to get the module:   https://blogs.technet.microsoft.com/ashleymcglone/2016/02/26/install-the-active-directory-powershell-module-on-windows-10/
4. Imprivata MUST be set to syncronize users based on an Active Directory Security Group (Example: "imprivata_users"  (CN=imprivata_users,OU=Groups,DC=ourcompany,DC=local))
   (If your environment is set to Synchronize based on OU, this script will not work!)
   
SETUP

IMPRIVATA CONSOLE - Auto-Report Creation
Log on to your Imprivata admin console
Goto Reports > Add New Report > User Details
Specify a name for the report (Example: Inactivity Maintenance)
Filter Users by "state" / "enabled"
Click "Save and Export >>"
On the right-hand side, there is a box labled "File Server Configuration"
 -Protocol = Network Share
 -Server = server name (no double backslashes and no FQDN.  Just the server's name [example:  MyServer])
 -Username = Imprivata maintenance user in AD
 -Password = Password for the maintenance user
 -Domain = Your domain name (Example: ourcompany.local)
On the same page, set the frequency to daily or weekly and select a time (example:  Daily  @  12:00 AM)
set the save location, which should be a share on the server that you named in the config box.
Location should be in the following format:  \Imprivata\Reports\Inactive\Exports
Select the Imprivata Site that you want to run the report against.
Click save.
You should be able to manually run the report and see the .CSV file that gets placed in your network share.  If you do not, you most likely have a permissions error or a syntax error
If you see the file, you are ready for the next step.

IMPRIVATA CONSOLE - Auto-Sync setup
Goto Users > Synchronize
Select a domain and click next
Scroll down to the bootom where the headding "Automate the synchronization process" is located.
Check "Automate Synchronization?"
As a safeguard, I like to check "Do not Synchronize if Users are to be Deleted?" and set "Only if the number of users to be deleted exceeds" to 20 or 30.
Select "Every day" from the drop-down menu and select a time that is approximately 1 hour after the above report is scheduled to run (Example: 1:00 AM)
Click Save.
 
ACTIVE DIRECTORY
Create a security group that will contain users which will receive the report emails from the script.
Example: SCRIPTSendMail_Imprivata  (CN=SCRIPTSendMail_Imprivata,OU=Groups,DC=ourcompany,DC=local)
Add your admins (recipients) to this group.
 
POWERSHELL SCRIPT 
Copy the PowerShell script to your share (Example: \\MyServer\Imprivata\Reports\Inactive)   
Edit lines 2 - 12 of the script to suit your environment.
 -$ImprivataLicences = 1772 # This is the toal number of Imprivata Licenses that you have.
 -$InactivityTime = 42 # Amount of DAYS since last logon. Any account LAST LOGON DATE greater than this number will be removed.
 -$AdSecurityGroup = "imprivata_users" # ActiveDirectory Security group in which the Imprivata users are assigned.
 -$ExcludedUsers = "impsrvacct,epicimprivata" # This is a list of users that you want to Exclude from being removed. These are generally managers or service accounts.
 -$EmailFromAddress = "Imprivata.Maintenance@ourcompany.org" # This is the FROM address that will appear in the email.
 -$EmailGroup = "SCRIPTSendMail_Imprivata" # This is the AD Security group to wich the members will be sent the report. # This is the AD Security group to wich the members will be sent the report.
 -$EmailSubject = "Imprivata User Maintenance - REMOVED ACCOUNTS" # This is the email SUBJECT.
 -$EmailSMTPServer = "ourcompany-org.mail.protection.outlook.com"  # This is the SMTP relay server for the email function.
 -$ScriptDir = "\\MyServer\Imprivata\Reports\Inactive" # This is the root directory in which the script resides.
 -$ImpCSVDir = "$ScriptDir\Exports" # This is the directory to which Imprivata exports the CSV reports. THIS IS CONFIGURED IN IMPRIVATA.
 -$LogDir = "$ScriptDir\Logs" # This is the log directory

These are all the changes you need to make.
If you feel comfortable changing the HTML email portion at the bottom, do so to suit your needs.

SCHEDULED TASK CONFIGURATION
Schedule a task on a Windows Server or Workstation with PowerShell.
(NOTE: This machine needs the ActiveDirectory PowerShell module, as noted in prerequisite #3, above)
Run the task as a user that has R/W permissions on the network share direcories and "Domain Admin" permissions.
Based on the previously configured Imprivata report, The CSV file was being created at 12:00 AM
Create a Scheduled task that runs daily (or weekly, depening of your Imprivata report). Schedule it for 12:30AM
The action should be:  C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
The command line argument should be:  -File \\MyServer\Imprivata\Reports\Inactive\Imprivata_User_Maintenance.ps1

You are now done!
You can test the script by manually running the scheduled task.  You should receive an email (if you are in the recipient security group).

TROUBLESHOOTING
If you are not recieving an email after manually running the scheduled task or if the task indicates a failure, you can open the script in the PowerShell ISE and run it from there.
That will give you any error codes that may arise.

COMMON ERRORS
SMTP relay server misconfiguration.
Network share permissions.
Run-As user is not a "Domain Admin".
The "activedirectory" PowerShell module is not installed on the task server.


 
 
