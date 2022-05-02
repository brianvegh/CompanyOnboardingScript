PowerShell script suite that automates company new user and new client onboarding across Microsoft Active Directory, Sharepoint, Office365 and Teams as well as 3CX VoIP Phone Service and DUO Multi-Factor Authentication Platform. This code and supporting and associated files have been redacted to eliminate disbursement of client-specific information. As such, coupled with the fact that these tools were designed to work within a specific environment, these publicly available scripts will require adaptation to be utilized in a Windows Active Directory environment
-----
- I have two small features to implement for the New User script 
  - add new user to CodeTwo group automatically based on domain
    - *nonessential, currently requires manual addition to group*
  - refractor Teams integration script to read from same input file used to create user
    - *nonessential, currently requires manual entry per user*
-----

The New User script currently performs the following:

1. Batch Generate New Users from a csv file (template provided). **Fully adds new users to Active Directory, and O365 via AD Sync**
1. Creates ,rdp file
1. Creates a List Entry in Employee Tracker on COMPANY Teams Channel with user's info and attaches the .rdp file.

The New User script currently requires human interaction for 

- 3CX
  - PRE SCRIPT-
    - create user
    - assign DID and extension
    - add phone to user group Copy DID and extension to script template csv.
  - POST SCRIPT-
    - add user to Microsoft Teams 'User Sync' and 'Calendar Sync' 
    - Run 'Teams-3CX\_Connecter.ps1 to finalize (activates teams-3cx enterprise)
        - *.ps1 in same directory on Domain Controller; currently prompts for each user's information via console entry; includes input validation on phone number format*
- O365
  - DURING SCRIPT-
    - Assign licenses
    - Add to CodeTwo mail security group based on user domain
    - Add user to explicitly requested groups
- Duo
  - DURING SCRIPT-
    - Perform Duo Sync
	    - *REDACTED

Instructions appear throughout the script in the console listing the above human-interaction steps, in order of requirement.

The New Client script is complete. Supports batch client generation. After selecting an appropriate Client Name (punctuation free name that is acceptable as the Client Email Address), tech need generate a newClient.csv file from the template provided. Each row is one client. The script then performs the following:

- Creates Client Organizational Unit
- Nests a Client Security Group within respective OU
- Creates private O365 Group and Team; links AD security group to O365 group/team, Adds PERSON and ADMIN as owners
  - Per ITADMIN's latest IT Ops addendum, we are not required to create SharePoint Sites on COMPANY WEBSITE and reorganize the links- they are transitioning to Teams for new clients going forward

