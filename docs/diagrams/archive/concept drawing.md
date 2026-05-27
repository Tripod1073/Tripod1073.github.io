# System Architectural Diagrams

## Design Only

### Segmentation Diagram
The icons in the AB (authorization boundary) only identify **_subnets_**, not devices. Subnetting is core to secure architectural development for compliance.
```mermaid
architecture-beta
   
   group boundary(cloud)[Authorization Boundary]
   group sysBoundary(cloud)[System Service Boundary] in boundary
   group custBoundary(cloud)[Customer System Boundary] in boundary

   junction sysJunct in sysBoundary
   junction custJunct in custBoundary
   junction public

   service sysExit(cloud)[Exit Gateway] in sysBoundary
   service sysProd(server)[Compute Subnet] in sysBoundary
   service sysDB(disk)[Datastore Subnet] in sysBoundary

   sysExit:L -- R:sysJunct
   sysProd:R -- L:sysJunct
   sysDB:T -- B:sysJunct

   service custExit(cloud)[Customer Exit Gateway] in custBoundary
   service custProd(server)[Customer Compute Subnet] in custBoundary
   service custDB(database)[Customer Datastore Subnet] in custBoundary

   custProd:R -- L:custJunct
   custDB:T -- B:custJunct
   custExit:L -- R:custJunct

   service authProv(internet)[Identity and Authentication Provider]

   service sysEntry(cloud)[Entrance Gateway] in boundary
   
   junction boundJunctTL in boundary
   junction boundJunctTR in boundary

   sysEntry:R -- L:boundJunctTR
   sysEntry:L -- R:boundJunctTL
   boundJunctTL:B -- T:sysJunct
   boundJunctTR:B -- T:custJunct

   authProv:L -- R:public
   github:R -- L:public
   sysEntry:T -- B:public

   service custSystem(cloud)[Customer System]

   custSystem:T -- R:custExit

   service github(cloud)[System Repos]
   service iam(server)[AWS IAM] in boundary
   service transit_gw(internet)[Transit Gateway] in boundary

```
