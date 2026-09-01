# Security Policy

## Supported versions

Until the project publishes versioned releases, only the current `main` branch
is supported. Security fixes are not backported to older commits or downstream
forks.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting for this repository when it is
available. Do not open a public issue with exploit details, credentials,
location data, logs, screenshots, or session state. If private reporting is not
available, open a minimal issue asking the maintainer to establish a private
contact channel; include no sensitive technical details in that issue.

Please provide:

- the affected commit and component;
- the security impact and required preconditions;
- minimal, sanitized reproduction steps; and
- any proposed mitigation or patch.

Particularly relevant reports include lock-screen or authentication bypasses,
unsafe command construction, privilege-boundary mistakes, credential or private
state exposure, and unsafe handling of remote content. Test only on systems and
accounts you own or are authorized to assess.

The maintainer will coordinate validation, remediation, and disclosure as
availability permits. No response-time or remediation-time guarantee is
currently offered. Vulnerabilities in an upstream dependency should also be
reported to that upstream; please notify this project when its defaults or
integration make the issue reachable here.
