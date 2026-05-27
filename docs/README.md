# spo-infra 
Infrastructure repo for SpecifierOnline

## Links for Amy
[Writing and formatting in GitHub](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/quickstart-for-writing-on-github)

[Introduction to Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)

[Project for SpecifierOnline](https://github.com/users/Tripod1073/projects/1)

## Links for Kent
[Use AWS tools for the configuration management backend.](https://aws.amazon.com/blogs/publicsector/prepare-for-fedramp-20x-with-aws-automation-and-validation/)
- I stumbled across this blog post that may be a useful roadmap for configuration elements of the system.

## Document Guidance
The files in *Documents* will mostly be related to guidance for both the design and use of SpecifierOnline. Amy will get the most benefit in the long run, but Kent will need the ones that address design concepts and overviews.

The files in *Design References* and *Diagrams* will be related to system architecture and guidance for development and other technical resources. Kent will get the most benefit, but Amy should use the ***OSCAL Notes.md*** file watch the videos that explain OSCAL (the first and second).

# Repository Structure
```
.github/
    Github actions and workflows

architecture/
    System design and logging architecture documentation

cloudformation/
    YAML for CloudFormation templates

compliance/
    Control mappings and compliance documentation

design-notes/
    Early design exploration and research notes

diagrams/
    Architecture, data flow, and process sequence diagrams

docker/
    Docker related deployment

evidence/
    Configuration exports used to verify logging controls

infrastructure/
    Terraform and deployment artifacts implementing the architecture
 
oscal/
    Machine-readable compliance artifacts

procedures/
    Operational task instructions

tools/
    Tools to write OSCAL
```
