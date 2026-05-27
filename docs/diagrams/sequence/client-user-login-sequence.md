# Client user login sequence
Note: the client provides their own IdP. MFA is required, but must be configured by the client's IdP.

```mermaid

sequenceDiagram
  autonumber

  actor User as Client User
  participant Browser
  participant CF as CloudFront
  participant WAF as AWS WAF
  participant ALB as ALB (Perimeter VPC)
  participant App as Ingress service (Perimeter VPC)
  participant IdP as Customer SSO IdP
  participant STS as AWS STS
  participant TGW as Transit Gateway
  participant C_ALB as Client ALB (internal)
  participant C_App as Client App (ECS Fargate)

  Note over App,IdP: MFA enforcement is contractual + technical.<br>We require MFA evidence in SAML or OIDC.<br>If evidence is missing or not acceptable, we deny access.<br>We do not control the MFA mechanism, only the requirement and validation.

  User->>Browser: Navigate to application URL
  Browser->>CF: HTTPS request
  CF->>WAF: Inspect request
  WAF-->>CF: Allow
  CF->>ALB: Forward to origin
  ALB->>App: Route request

  App-->>Browser: Redirect to IdP login<br>Provide MFA requirement and allow both SAML and OIDC
  Browser->>IdP: Authenticate
  IdP-->>Browser: MFA challenge (required)
  User->>Browser: Complete MFA
  Browser->>IdP: Submit MFA response

  alt User returns with SAML response
    IdP-->>Browser: SAMLResponse (signed)
    Browser->>App: POST SAMLResponse to ACS endpoint
    App->>App: Validate SAML signature, issuer, audience, time bounds
    App->>App: Validate MFA evidence<br>(AuthnContextClassRef or required MFA attribute)
  else User returns with OIDC authorization code
    IdP-->>Browser: Redirect with authorization code
    Browser->>App: GET callback with code
    App->>IdP: Exchange code for tokens
    IdP-->>App: ID token + access token (signed)
    App->>App: Validate token signature, issuer, audience, nonce, exp
    App->>App: Validate MFA evidence<br>(acr and or amr claims)
  end

  alt MFA evidence acceptable
    App->>STS: Exchange federation for AWS identity context<br>(optional, if using AWS-side authZ)
    STS-->>App: Temporary credentials or session context
    App-->>Browser: Set app session (cookie/token)
  else MFA evidence missing or unacceptable
    App-->>Browser: Deny access (MFA required)<br>Force re-auth with MFA requirement
  end

  Browser->>CF: HTTPS request to protected resource
  CF->>WAF: Inspect request
  WAF-->>CF: Allow
  CF->>ALB: Forward
  ALB->>App: Route request with session

  App->>TGW: Send private request to client account
  TGW->>C_ALB: Deliver to client internal ALB
  C_ALB->>C_App: Route to ECS service
  C_App-->>Browser: Response (via same path back)

```

How this “ensures MFA” in a defensible way

You can’t force the client’s MFA method, but you can require proof that MFA happened.

In practice, that means the app only accepts SSO responses that contain MFA evidence.

Concrete implementation guidance

SAML
- Require the assertion to include an MFA-authn signal, typically in the AuthnContextClassRef value (IdP-specific), or in a specific attribute your integration contract requires.
- Reject assertions without that value.

OIDC
- Require an MFA indicator in claims, typically acr or amr (depends on IdP).
- Reject tokens that do not include the required acr/amr value.


