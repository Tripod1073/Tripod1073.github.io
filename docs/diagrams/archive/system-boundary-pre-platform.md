# System Boundary

```mermaid
flowchart LR

subgraph WORKLOAD["Workload Accounts"]
    WA1[Workload Account A]
    WA2[Workload Account B]
    WAN[Additional Workload Accounts]
end

subgraph SECURITY["Security Account"]
    SEC_BUCKET[Central Security Log Archive]
    SEC_MON[Security Monitoring and Investigation]
    SEC_KMS[KMS Keys]
end

subgraph LOCAL["Workload-Local Log Storage"]
    APP_A[App Log Bucket A]
    APP_B[App Log Bucket B]
    APP_N[App Log Bucket N]
end

WA1 -->|Security Telemetry| SEC_BUCKET
WA2 -->|Security Telemetry| SEC_BUCKET
WAN -->|Security Telemetry| SEC_BUCKET

WA1 -->|Application Logs Stay Local| APP_A
WA2 -->|Application Logs Stay Local| APP_B
WAN -->|Application Logs Stay Local| APP_N

SEC_BUCKET --> SEC_MON
SEC_KMS --> SEC_BUCKET
