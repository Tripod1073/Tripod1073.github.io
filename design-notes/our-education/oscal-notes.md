# OSCAL Notes from webinars
## Introduction

### Beginner OSCAL: [OSCAL Foundation Webinar: A Beginner's Guide to OSCAL](https://youtu.be/jqoLyE8P66A?si=eQdCmc\_Lzpx8-0U8)

- Define Security Control: 13:50
  - Include technical and non-technical elements (training, physical, etc.)
- Packaging Controls: 16:48
  - Discussed what is provided and how it is presented.
- OSCAL purpose, standardization, and machine readability: 17:48
- OSCAL Assessment: 18:45
  - Automation purpose: 20:20
- Machine Readable Language: 21:20
-  Brief Technical Review: 23:30
- Use case: 27:00
- Q&A: 31:30


### OSCAL Layers: [OSCAL Foundation Webinar: Diving Into the OSCAL Layers](https://youtu.be/WxFH3lPBZUE?si=HvKIWsYKHGnj_dit)

- Layers and Models: 4:50
  - Controls Layer
    - Catalog Model
    - Profile Model
  - Implementation Layer
    - System Security Plan Model
    - Component Model
  - Assessment Layer
    - POA&M Model
    - Assessment Results Model
    - Assessment Plan Model

- Control Layer: 6:05
  - Original Workflow (pre-OSCAL): 8:08
  - OSCAL catalog model: 9:30
    - The regulatory body publishes the Catalog.
    - Includes the non-automation-friendly information, with additional metadata from the publisher.
  - OSCAL Profile: 11:44
    - Includes the subset and parameter values, can be a combination of multiple catalogs (which is normally done in risk frameworks)
- Implementation Layer: 13:56
  - System Security Plan: 15:08
  - Components: 15:30
  - Manual workflow example: 16:55
  - OSCAL implementation method: 18:30
  - OSCAL System Security Plan: 20:20
  - OSCAL Component Definitions: 21:06

- Assessment Layer: 22:30
  - Original Workflow: 24:26
  - OSCAL Models: 24:50
  - Assessment Plan: 25:37
  - Assessment Results: 26:38
  - POA&M (Plan of Actions and Milestones): 26:16

- Summary and Panel: 29:20

### OSCAL Implementation: [Implementing OSCAL: A Technical Deep Dive into the OSCAL Data Format](https://youtu.be/tOFvl_j1lB0?si=2_BWb8mAQl5dCkF9)

- Technical background basics & definitions: 3:33
  - "Data format": 4:15
  - "Document": 4:37
  - "Schema": 4:55
  - Document type: 6:56
- OSCAL schema files: 8:31
  - Metaschema file for using multiple schemas: 10:41
  - "Ground Truth" (true specification): 11:21
  - Constraints: 12:41
  - Recommendations: 13:40
- Implementing OSCAL (3 capabilities): 14:19
  - Produce documents for an external entity: 16:33
  - Consume documents from an external entity: 17:36
  - Use documents internally: 18:29
    - **Determine approach:** 20:26
      - Native Processing: 21:12
      - Transform at edges: 22:18
- Parsing and generation tips: 23:29
- Integration with existing systems: 29:45
- AI use and errors: 30:30
- conclusion: 33:30
- Panel Discussion (others' experiences): 34:00

