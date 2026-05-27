# CMMC SaaS Product Design
# Criteria
## GRC Documentation
### System Security Plan (SSP)
1. Guide the user through documentation generation
   - Organizational information
   - System information
   - Authorization information (if applicable)
   - System owner
   - Review schedule
     - SSP is annual
     - Policies are three years
     - Procedures are annual
2. Show the user what parameters must be set by the organization
   - Help text for what the parameter means
   - Recommended best practices or minimums set by CMMC
3. Determine the necessary functions for the system based on CMMC
   - Define the approach to the system (servers, VMs, containers, etc.)
   - Define components by function based on the approach
   - Prompt the user for engaged services
   - Compare engaged services to necessary components
   - Identify missing components
4. Prompt for the organization’s intended configuration of components
   - Validate against CMMC (items 2 & 3)
   - Generate a “fix list”
5. Prompt for human-performed processes
   - List of necessary processes by framework
   - Prompt for existing processes
   - Determine process gap
   - Outline requirements for new processes (defined by the framework)
6. Generate system description
   - Test if the description addresses functions and components
   - This could potentially be by an LLM with the product providing the guardrails (to be determined)
7. Generate SSP
8. Generate appendices (incomplete list)
9. Generate policies by control domain
   - The collection of requirements based on the framework
   - May be added to by subsequent additional frameworks
   - Somehow keyed to requirements
10. Generate procedures by control domain
    - The collection of component configurations
    - The collection of processes
  
### Contingency Plan
1. Guide the user through document generation
   - Organizational information
   - System information
   - Executive approval
   - Plan owner
   - Test schedule and permitted types of tests (test against SSP)
2. Identify critical systems based on SSP data, the minimum necessary to keep the system running
3. Prompt for organizational RPO
4. Prompt for organizational RTO
5. Identify components that cannot meet RPO and RTO
6. Prompt for response roles
   - Include a checklist, traditional roles are reduced by cloud services
   - Identify the responsible party for each role by title or team
7. Pull requirements from SSP related to contingency response
8. Test submitted values against SSP variables
   - Identify failures
9. Allow the organization to override with their own plan
   - Enumerate SSP requirements related to contingency response
   - This could potentially be by an LLM with the product providing the guardrails (to be determined)
10. Generate the plan document
  
### Incident Response Plan
Use the contingency plan function for now, replacing critical systems with SIEM, RPO and RTO with MTD, and other incident-related metrics.
  
## System Configuration

### System connections
1. Enumerate components
2. Use components to determine services
3. Identify the service providers by components and services
4. Define the roles necessary for reading and writing configurations to components and services
5. Generate JSON for system accounts
6. Guidance for how to create system accounts
7. Prompt for API access tokens or other credentialing methods
8. Test connections

### System Deployment
1. Set configurations based on the SSP variables
2. Test configurations continuously
3. Trigger alerts for out-of-compliance configurations
4. Revert changes to specified values
### System Audit
1. Generate a component inventory at least monthly
  - Includes services and software
2. Call out component inventory

# Topics to complete

## Organization-defined parameters specified by CMMC
### 03.01: Access Control
03.01.01.f.02:	Disable system accounts when the accounts have been inactive for [organization-defined time period]\
03.01.01.g.01:	Notify account managers and designated personnel or roles within [organization-defined time period] when accounts are no longer required.\
03.01.01.g.02:	Notify account managers and designated personnel or roles within [organization-defined time period] when users are terminated or transferred.\
03.01.01.g.03:	Notify account managers and designated personnel or roles within [organization-defined time period] when  system usage or the need-to-know changes for an individual.\
03.01.01.h:	Require that users log out of the system after [organization-defined time period] of expected inactivity or when [organization-defined circumstances].\
03.01.05.b: Authorize access to [organization-defined security functions] and [organization-defined security-relevant information].\
03.01.05.c:	Review the privileges assigned to roles or classes of users [Assignment: organization-defined frequency] to validate the need for such privileges.\
03.01.06.a:	Restrict privileged accounts on the system to [organization-defined personnel or roles].\
03.01.08.a:	Enforce a limit of [organization-defined number] consecutive invalid logon attempts by a user during a [organization-defined time period].\
03.01.08.b:	Automatically [Selection (one or more): lock the account or node for an [organization-defined time period]; lock the account or node until released by an administrator; delay next logon prompt; notify system administrator; take other action] when the maximum number of unsuccessful attempts is exceeded.\
03.01.10.a:	Prevent access to the system by [Selection (one or more): initiating a device lock after [organization-defined time period] of inactivity; requiring the user to initiate a device lock before leaving the system unattended].\
03.01.11:	Terminate a user session automatically after [organization-defined conditions or trigger events requiring session disconnect].\
03.01.20.b:	Establish the following security requirements to be satisfied on external systems prior to allowing use of or access to those systems by authorized individuals: [organization-defined security requirements].

### 03.02: Awareness and Training
03.02.01.a.01:	Provide security literacy training to system users as part of initial training for new users and [organization-defined frequency] thereafter.\
03.02.01.a.02:	Provide security literacy training to system users when required by system changes or following [organization-defined events].\
03.02.01.b:	Update security literacy training content [organization-defined frequency] and following [organization-defined events].\
03.02.02.a.01:	Provide role-based security training to organizational personnel before authorizing access to the system or CUI, before performing assigned duties, and [organization-defined frequency] thereafter.\
03.02.02.a.02:	Provide role-based security training to organizational personnel when required by system changes or following [organization-defined events].\
03.02.02.b:	Update role-based training content [organization-defined frequency] and following [Assignment: organization-defined events].

### 03.03:	Audit and Accountability
03.03.01.a:	Specify the following event types selected for logging within the system: [organization-defined event types].\
03.03.01.b:	Review and update the event types selected for logging [organization-defined frequency].\
03.03.04.a:	Alert organizational personnel or roles within [organization-defined time period] in the event of an audit logging process failure.\
03.03.04.b:	Take the following additional actions: [organization-defined additional actions].\
03.03.05.a:	Review and analyze system audit records [organization-defined frequency] for indications and the potential impact of inappropriate or unusual activity.\
03.03.07.b:	Record time stamps for audit records that meet [organization-defined granularity of time measurement] and that use Coordinated Universal Time (UTC), have a fixed local time offset from UTC, or include the local time offset as part of the time stamp.

### 03.04:	Configuration Management
03.04.01.b:	Review and update the baseline configuration of the system [organization-defined frequency] and when system components are installed or modified.\
03.04.02.a:	Establish, document, and implement the following configuration settings for the system that reflect the most restrictive mode consistent with operational requirements: [organization-defined configuration settings].\
03.04.06.b:	Prohibit or restrict use of the following functions, ports, protocols, connections, and services: [organization-defined functions, ports, protocols, connections, and services].\
03.04.06.c:	Review the system [organization-defined frequency] to identify unnecessary or nonsecure functions, ports, protocols, connections, and services.\
03.04.08.c:	Review and update the list of authorized software programs [organization-defined frequency].\
03.04.10.b:	Review and update the system component inventory [organization-defined frequency].\
03.04.12.a:	Issue systems or system components with the following configurations to individuals traveling to high-risk locations: [organization-defined system configurations].\
03.04.12.b:	Apply the following security requirements to the systems or components when the individuals return from travel: [organization-defined security requirements].

### 03.05:	Identification and Authentication
03.05.01.b:	Re-authenticate users when [organization-defined circumstances or situations requiring re-authentication].\
03.05.02:	Uniquely identify and authenticate [Assignment: organization-defined devices or types of devices] before establishing a system connection.\
04.05.05.c:	Prevent the reuse of identifiers for [organization-defined time period].\
03.05.05.d:	Manage individual identifiers by uniquely identifying each individual as [Assignment: organization-defined characteristic identifying individual status].\
03.05.07.a:	Maintain a list of commonly-used, expected, or compromised passwords, and update the list [organization-defined frequency] and when organizational passwords are suspected to have been compromised.\
03.05.07.f:	Enforce the following composition and complexity rules for passwords: [organization-defined composition and complexity rules].\
03.05.12.e:	Change or refresh authenticators [organization-defined frequency] or when the following events occur: [organization-defined events].

### 03.06:	Incident Response
03.06.02.b:	Report suspected incidents to the organizational incident response capability within [organization-defined time period].\
03.06.02.c:	Report incident information to [organization-defined authorities].\
03.06.03:	Test the effectiveness of the incident response capability [organization-defined frequency].\
03.06.04.a.01:	Provide incident response training to system users consistent with assigned roles and responsibilities within [organization-defined time period] of assuming an incident response role or responsibility or acquiring system access.\
03.06.04.a.03:	Provide incident response training to system users consistent with assigned roles and responsibilities [organization-defined frequency] thereafter.\
03.06.04.b:	Review and update incident response training content [organization-defined frequency] and following [organization-defined events].

### 03.07:	Maintenance (n/a)

### 03.08:	Media Protection
03.08.07.a:	Restrict or prohibit the use of [organization-defined types of system media].

### 03.09:	Personnel Security
03.09.01.b:	Rescreen individuals in accordance with [organization-defined conditions requiring rescreening].\
03.09.02.a.01:	When individual employment is terminated, disable system access within [Assignment: organization-defined time period].

### 03.10:	Physical Access Authorizations
03.10.01.c:	Review the facility access list [Assignment: organization-defined frequency].\
03.10.02.b:	Review physical access logs [organization-defined frequency] and upon occurrence of [organization-defined events or potential indications of events].\
03.10.06.b:	Employ the following security requirements at alternate work sites: [organization-defined security requirements].

### 03.11:	Risk Assessment
03.11.01.b:	Update risk assessments [organization-defined frequency].\
03.11.02.a:	Monitor and scan the system for vulnerabilities [organization-defined frequency] and when new vulnerabilities affecting the system are identified.\
03.11.02.b:	Remediate system vulnerabilities within [organization-defined response times].\
03.11.02.c:	Update system vulnerabilities to be scanned [organization-defined frequency] and when new vulnerabilities are identified and reported.

### 03.12:	Security Assessment and Monitoring
03.12.01:	Assess the security requirements for the system and its environment of operation [Assignment: organization-defined frequency] to determine if the requirements have been satisfied.\
03.12.05.a:	Approve and manage the exchange of CUI between the system and other systems using [Selection (one or more): interconnection security agreements; information exchange security agreements; memoranda of understanding or agreement; service-level agreements; user agreements; non-disclosure agreements; other types of agreements].\
03.12.05.c:	Review and update the exchange agreements [Assignment: organization-defined frequency].

### 03.13:	System and Communication Protection
03.13.09:	Terminate the network connection associated with a communications session at the end of the session or after [organization-defined time period] of inactivity.\
03.13.10:	Establish and manage cryptographic keys in the system in accordance with the following key management requirements: [organization-defined requirements for key generation, distribution, storage, access, and destruction].\
03.13.11:	Implement the following types of cryptography to protect the confidentiality of CUI: [organization-defined types of cryptography].\
03.13.12.a:	Prohibit the remote activation of collaborative computing devices and applications with the following exceptions: [organization-defined exceptions where remote activation is to be allowed].

### 03.14:	System and Information Integrity
03.14.01.b:	Install security-relevant software and firmware updates within [organization-defined time period] of the release of the updates.\
03.14.02.c.01:	Configure malicious code protection mechanisms to perform scans of the system [organization-defined frequency] and real-time scans of files from external sources at endpoints or system entry and exit points as the files are downloaded, opened, or executed.

### 03.15:	Planning
03.15.01.b:	Review and update policies and procedures [organization-defined frequency].\
03.15.02.b:	Review and update the system security plan [organization-defined frequency].\
03.15.03.d:	Review and update the rules of behavior [organization-defined frequency].

### 03.16: System and Services Acquisition
03.16.01:	Apply the following systems security engineering principles to the development or modification of the system and system components: [organization-defined systems security engineering principles].\
03.16.03.a:	Require the providers of external system services used for the processing, storage, or transmission of CUI to comply with the following security requirements: [organization-defined security requirements].

### 03.17:	Supply Chain Risk Management Plan
03.17.01.b:	Review and update the supply chain risk management plan [organization-defined frequency].\
03.17.03.b:	Enforce the following security requirements to protect against supply chain risks to the system, system components, or system services and to limit the harm or consequences from supply chain-related events: [organization-defined security requirements].

# Parameters necessary for documentation that CMMC does not specify
## Organizational/Product Management:
- Organizational Name
- Organizational Short Name, if any
- System Name
- System Short Name or Acronym, if any
- Document preparer:
  - Company Representative Responsible for this plan
  - Company Name
  - Address 1
  - Address 2
  - City, State, Zip
  - Email Address
  - Phone Number
- Documentation History (to be system-generated)
  - Date
  - Comments
  - Version
  - Author
- Information System Categorization (per NIST SP 800-60 and FIPS 199)
  - Low, moderate, or high; calculated by security objectives below
- Information Types (defined by NIST SP 800-60, Volumes I and II, rev 1, which is the same as the Federal Enterprise Architecture (FEA) Consolidated Reference Model)
  - Information Type (multiple entries)
  - Confidentiality
  - Integrity
  - Availability
- Security Objectives (determined by high watermark for all information types)
  - Confidentiality (calculated)
  - Integrity (calculated)
  - Availability (calculated)
- E-Auth Determination (if all questions are “yes,” then E-Auth is required)
  [ ] Does the system require authentication via the Internet?
  [ ] Is data being transmitted over the Internet via browsers?
  [ ] Do users connect to the system over the Internet?
- E-Auth Assurance Level Summary
  - E-Auth level number
  - Date approved
- Information System Owner
  - Name
  - Title
  - Organization
  - Address
  - Phone Number
  - Email Address
- Authorizing Official
  - Name
  - Title
  - Organization
  - Address
  - Phone Number
  - Email Address
- Other Designated Contacts (can be many)
  - Name
  - Title
  - Organization
  - Address
  - Phone Number
  - Email Address
- Assignment of Security Responsibility (ISSO)
  - Name
  - Title
  - Organization
  - Address
  - Phone Number
  - Email Address
  
  ## Product Details
- System Operational Status Table
  - Operational, Under Development, Major Modification, Other (Explain)
- Information System Type
  - General Support System (GSS), Major Application (MA), Subsystem
- Systems Providing Controls to (provided by outside the system boundary) Table
  - Providing System Name
  - Providing System Owner
  - Providing System ATO Date
    - Common or Hybrid controls
- System Receiving Controls from (provided by outside the system boundary) Table
  - Receiving System Name
  - Receiving System Owner
  - Receiving System ATO Date
    - Common or Hybrid controls
- General System Description
  - A general description of the system, including its function and purpose.
- Information System Locations Table
  - Primary
    - Address if owned
    - Provider and address if physical
    - Provider and cloud regions if Cloud
  - Secondary
    - Address if owned
    - Provider and address if physical
    - Provider and cloud regions if Cloud
- Information System Components and Boundaries Table
  - System Assets
    - Asset Type
    - Description of Function or Services Provided
- Types of Users Table
  - User Roles and Privileges (external users are “not applicable” for “Sensitivity Level,” administrators are grouped by role; normally align with RBAC group names)
    - Role
    - Internal or External
    - Human or non-human
    - Sensitivity Level
    - Authorized Privileges and Functions Performed
- Network Architecture (will be an image file, hopefully a vector image, but PDFs are common)
  - Network diagram
- Asset Inventory (due to size, will be an attachment, a combined inventory with software)
  - IP Address/Hostname (unique ID)
  - Make
  - Model and Firmware
  - Location
  - Components that Use this Device
- Software Inventory (due to size, will be an attachment, a combined inventory with assets)
  - IP Address/Hostname (unique ID)
  - Function
  - Version
  - Patch Level
  - Virtual (Yes/No)
- Data Flow (will be an image file, hopefully a vector image, but PDFs are common)
  - Data flow diagram
- Ports, Protocols, and Services Table (may be combined with encryption table)
  - Ports (T or U) ((TCP or UDP))
  - Protocols
  - Services
  - Purpose
  - Used By (list components)
- System Interconnections Table
  - System Name
  - Organization
  - Types of System (GSS, MA, Subsystem)
  - Agreement Types (ISA, MOU) ((Interconnection Security Agreement or Memorandum of Understanding))
  - Date of Agreement
  - FIPS 199 Security Category of System
  - A&A Status of System 
  - Name and Title of AO
- Connection Details of Interconnected Systems (found in ISA or MOU)
  - System Name
  - Organization
  - Point of Contact and Phone Number
  - Connection Security (IPSec, VPN, SSL, Certificates, Secure File Transfer, etc.)
  - Data Direction (incoming, outgoing, or both)
  - Information Being Transmitted
  - Ports of Circuit #

# Appendices
- Appendix A – Acronyms, Terms, and Definitions
- Appendix B – References
  - Applicable Standards and Guidance
  - Applicable Federal Laws
  - Applicable NIST Publications
- Appendix C – Hosted Subsystems (if applicable)
  - Table
    - Subsystem Name
    - Subsystem Purpose/Description
    - Program Manager/System Owner
    - Associated Exhibit 53 ID# (if applicable)
- Appendix D – Combined Inventory (see asset and software inventories above)
- Appendix E – Contingency Plan (combination of BCP and DRP)
- Appendix F – Incident Response Plan
- Appendix G – Plan of Action and Milestones (POA/M)

# Configuration Items
03.01 Access Control
   - User accounts
      - Account types: privileged and non-privileged, internal and external
      - Role-Based Access Control definitions
         - Permissions assignments
         - Permission grouping
         - Permission functions, R/W or R/O
      - Human users by type
      - System accounts by function
         - Permissions
         - Authorized devices
      - Automated management processes
         - Expiration by time
         - Expiration by inactivity
      - Password hashing
      - Log out automations
   - Login functions
      - Unsuccessful logon attempt configurations for lock-out
      - Inactivity device lock - obscure content
      - Session termination
         - Expiration by time
         - Expiration by inactivity
      - Log out automations
   - Remote Access
      - Connection encryption
      - Connection authorization (device or account)
      - Connection authentication
      - Connection access points
      - Permitted accounts
   - Wireless access
      - Connection encryption
      - Connection authorization (device or account) 
      - Connection authentication
      - Connection access points
      - Permitted accounts/devices
   - Mobile Devices
      - Connection encryption
      - Connection authorization (device or account) 
      - Connection authentication
      - Connection access points
      - Permitted accounts/devices
   - External Systems
      - Connection encryption
      - Connection authorization (device or account) 
      - Connection authentication
      - Connection access points
      - Permitted accounts/devices that permit external system connections
   - Portable Storage Devices
      - Device encryption
      - Connection authorization - device
      - Connection authorization - user 
      - Connection authentication
      - Connection access points
      - Permitted accounts/devices that support portable storage devices
   - Publicly Accessible Content
      - Flags for components permitted to host publicly accessible content

03.02 Awareness and Training
   - API connection to LMS to pull:
      - User list with start and end dates (as applicable)
      - User completion records
      - Last content update by module/course
      - User assignment by role (if possible)
   - _May be entirely outside the system_

03.03 Audit and Accountability
   - Event Logging
     - Inventory of event types
   - Audit Record Content
     - Sample log(s) showing contents for each event type (if they have different formats)
   - Audit Record Generation
     - Pull live samples from designated dates
     - Pull the oldest log samples to show retention age
   - Response to Audit Logging Process Failures
     - Pull alert configuration for processing failures
     - Pull configuration for system logging restart
   - Reporting
     - Pull organization log reports on a schedule
     - Alert personnel to report collection
   - Time Stamps
     - Pull component timestamp configuration (UTC, offset, local)
     - Pull time sync configuration (origin server)
   - Protection of Audit Information
     - Pull account types able to write/modify on-disk log records
     - Pull account types able to write/modify in application log records
     - Pull account types able to start/restart/terminate/disable logging services

03.04 Configuration Management
   - Baseline Configuration
      - Support IaC deployment for all virtual components
      - Pull changelog list (date/time) for all IaC components
      - Support the configuration management tool for all hardware components
   - Change Control
      - Deploy modifications through the system
         - Restrict modification privileges to identified users or groups
         - Record timestamp for changes, with timestamp and implementor
      - Change approvals
         - Only approved changes can be deployed
         - Restrict approval privileges to identified users or groups
         - Require change approvals within the system, with timestamps and identification of the approver
      - Least Functionality
         - Firewalls and virtual firewalls (security groups) default to closed ports
         - Specified ports opened
         - Pull report of open ports
      - Software Restriction
         - Pull reports of installed software
         - Install software from the authorized repo
      - Component inventory 
         - See Other – Asset inventory
      - Information Location
         - Asset inventory to identify all CUI components

03.05 Identification and Authentication
   - Device to Device
      - Identify all devices by type, device, or type/device
      - Each device is assigned a unique ID
      - Each device-to-device connection requires authentication and encryption 
   - Multifactor Authentication
      - All privileged and non-privileged accounts require MFA
      - Specific to user accounts
      - Replay-resistant authentication mechanisms
      - Password Management
         - Use a management mechanism that permits restriction to commonly-used, expected, or compromised passwords (restricted list)
      - The mechanism must permit updating the list when specified and when organizational passwords are suspected to be compromised
      - Password transmission by encrypted channels
      - Password storage in cryptographically protected channels
      - Require a new password upon first use after account recovery
      - Enforce organizationally defined password rules
      - Obscure feedback when entering a password
   - Authenticator Management
      - Establish initial authenticator content
      - Change authenticators at first use

03.06 Incident Monitoring, Reporting, and Response Assistance
   - Pull reports from the incident response ticketing system
      - Ticketing system to identify IR tickets by flag
      - System can pull a list of IR ticket IDs with date and status open/closed
      - System can pull ticket history for requested tickets
   - Pull reports from the incident response ticketing system for tests
      - Ticketing system to identify IR test tickets by flag
      - System can pull a list of IR testIDs with date and status open/closed
      - System can pull test history for requested test IDs
   - Pull IR training results from LMS
      - Identify IR training modules
      - Pull assigned personnel
      - Pull assigned personnel completion dates

03.07 Maintenance
   -Pull reports from the ticketing system of device management
      - Ticketing system to identify device management activities
      - Track CUI assets specifically
         - Data management
   - Pull reports from the ticketing system of nonlocal maintenance
      - Ticketing system to identify nonlocal maintenance activities
      - Configure remote access to require MFA and replay resistance
      - Configure remote access to terminate session and network connections when complete
   - Maintenance Personnel
      - Integrate with account management to list authorized maintenance personnel by groups
      - Integrate with account management to list personnel authorized to escort and supervise non-authorized persons for maintenance (device provider service staff)

03.08 Media Protection
   -Identify all components with CUI data
   - Integrate with account management to list users authorized to access CUI
   - Pull reports from the ticketing system to track system sanitization of CUI before release of media control
   - Pull reports from the ticketing system to track media transport
   - System Backup
      - Configure backup systems to apply encryption

03.09 Personnel Security
   - Pull reports from the HR system of personnel screening by name and date
   - Pull reports from the HR system for personnel termination or reassignment/transfer
      - Pull reports from the account management ticketing system for personnel account actions related to termination or reassignment/transfer
      - Report cross-reference of activities between the systems

03.10 Physical Protection
   - Pull reports from the physical access management system of personnel with authorized access (where the system resides) by name and dates
   - Pull tickets for issuing authorization and removing authorization on a schedule
   - Pull reports for physical access activities on a schedule

03.11 Risk Assessment
   - Prompt for risk assessment performance and track results
   - Pull reports from the vulnerability management tool for scans
      - Test for schedule
      - Identify remediation deadlines (may be in ticketing system)
      - Configure the tool to autoupdate vulnerability definitions before running a scan
   - Pull reports from the ticketing system of responses to security assessments, monitoring, and audits.
      - Ticketing system to identify response tickets

03.12 Security Assessment and Monitoring
   - Track continuous monitoring activities
      - Scheduled tasks
      - Completion of scheduled tasks
      - Evidence of scheduled tasks
      - Identify personnel who completed and approved scheduled tasks
      - Permit ad hoc tasks
   - Track updates of information exchange agreements

03.13 System and Communications Protection
   - Pull subnetwork IDs from the system
   - Apply deny by default, allow by exception for all network communications
      - Pull allowed rules
   - Implement encryption for all CUI during transfer and storage
   - Enforce network disconnections at the end of the session or after a defined period of inactivity
   - Identify the cryptographic key management tool
      - Pull configuration of permitted encryption types
   - Identify collaborative computing devices and applications
      - Deny by default
      - Permit by allow-list
      - Pull the allow-list
      - Configure conferencing software/device to post notifications of reporting and microphone use
   - Identify mobile code
      - Pull reports from the ticketing system of mobile code approvals

03.14 System and Information Integrity
   - Pull malicious code protection information
      - Identify tool for protection at entry/exit points
      - Identify tool for components
      - Schedule malicious code updates and show updates with new releases
      - Scan the system on an identified schedule and in real-time for files from external sources
      - Configure malicious code tools to block, quarantine, or otherwise mitigate malicious code
   - Track system security alerts, advisories, and directives from external sources
   - Generate and disseminate alerts, advisories, and directives as needed

03.15 Planning
   - Integrate policies and procedures
   - Generate System Security Plan
   - Generate Rules of Behavior

03.16 Security Engineering Principles
   - Track programmatic changes to flag updating of diagrams
   - Track EOL for system components
   - Generate security requirements for external system services

03.17 Supply Chain Risk Management
   - Generate Supply Chain Risk Management Plan
   - Track changes to plan, prompt for scheduled reviews

# Other – Design Draft
## Asset Inventory
   - System collects data from cloud providers and data center devices
      - CSP provides API endpoints
      - Datacenters vary, backlog this
         - If DC has network and system device management tools, query those
         - If DC doesn’t may need to scan and query devices
         - If DC hosts private clouds, use cloud APIs
   - System establishes configuration baselines through controls above
   - System posts configuration to cloud services and data center devices
      - CSP provides endpoints to configure services and virtual components
      - Datacenters vary, backlog this
         - If DC has network and system device management tools, post to those
         - If DC doesn’t, post to hardware
         - If DC hosts private clouds, use cloud APIs
   - System queries components on a schedule, compares the existing configuration to the baseline
   - System alerts personnel and provides an on-demand report function
   - System can optionally restore to baseline configurations

## Software Inventory
   - System collects data from running software as available, may require only collecting version and patch level if software doesn’t provide an API function
   - System establishes software configuration baselines through controls above
   - System posts configuration to software as available, may not be possible
   - System queries software on a schedule, compares the existing configuration to the baseline
   - System alerts personnel and provides an on-demand report function
   - System can optionally restore to baseline configurations

