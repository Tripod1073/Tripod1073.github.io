# Basic pricing considerations
This is a random collection of ideas and information for consideration.

## SLAs v SLOs
Should we consider SLAs or SLOs in our contracts? These are only applicable to high-availability environments, and because our system should not be considered "mission-critical," HA is typically out of scope. 
- SLA: Service level agreements
  - Missing an SLA means providing a credit to the customer
  - Very common in data center services
- SLO: Service level objectives
  - No financial impact for missing, just issue a mea-culpa
  - Not common, only a goodwill gesture
- Uptime considerations:

| Availability %  | Downtime per year | Downtime per quarter  | Downtime per month  | Downtime per week  | Downtime per day (24 hours)  |
|:---|---:|---:|---:|---:|---:|
| 99% ("two nines")  | 3.65 days  | 21.9 hours  | 7.31 hours  | 1.68 hours  | 14.40 minutes  |
| 99.9% ("three nines")  | 8.77 hours  | 2.19 hours  | 43.83 minutes  | 10.08 minutes  | 1.44 minutes  |
| 99.99% ("four nines")  | 52.60 minutes  | 13.15 minutes  | 4.38 minutes  | 1.01 minutes  | 8.64 seconds  |
| 99.999% ("five nines")  | 5.26 minutes  | 1.31 minutes  | 26.30 seconds  | 6.05 seconds  | 864.00 milliseconds  |

## Functions
What is core to the product? Can we separate into different services?

### Core service
Operations: 
1. Get customer information and make it consumable or presented to the customer
2. Get configuration requirements from providers
    - Framework requirements published by authorities (FedRAMP, CIS, PCI DSS, etc.) (may be published in OSCAL
    - Specific configurations for services (AWS config packs, others?)
3. Create diff between 1 & 2

### Documentation Service
Use core information to generate 
1. Get machine readable requirements per framework in OSCAL
2. Convert core information as OSCAL
3. Convert core diff into OSCAL or perform diff after OSCAL
    - Present in human-friendly format
    - Have machine readable presentation in background
4. Generate SSP
5. Generate policies/procedures/processes

### Audit service
1. Gather evidence
    - Present core service information (1 and 3) as audit-friendly artifacts
    - Present audit trail of evidence gathering
    - Validate evidence results by providing raw data
    - Provide credential information (redacted) to show proper access to the system
2. Align evidence with requirements per the core and documentation services
3. Allow export to auditor tools
