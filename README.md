# Expense Claim App for Salesforce

An open-source Salesforce application for submitting, reviewing, and managing expense claims.

The project is being developed as a **Salesforce second-generation managed package (2GP)** using Salesforce DX, GitHub, and automated CI/CD workflows.

> **Project status:** Early development.  
> The package is not yet ready for production use.

## Overview

The goal of the Expense Claim App is to provide Salesforce customers with a reusable and configurable expense-management solution that can be installed as a managed package.

The application is intended to support use cases such as:

- Employee and volunteer expense claims
- Mileage reimbursements
- Reimbursement of purchases and other expenses
- Receipt and supporting-document uploads
- Configurable expense categories and reimbursement rules
- Approval processes
- Expense review and administration
- Reporting and auditability

The design principle is to keep organisation-specific policies configurable while keeping the underlying application reusable.

## Technology

The project uses:

- Salesforce DX
- Second-Generation Managed Packaging (2GP)
- Salesforce CLI (`sf`)
- Lightning Web Components
- Apex
- Salesforce Flow
- Custom Metadata Types
- Permission Sets
- GitHub
- GitHub Actions
- Salesforce Code Analyzer

CumulusCI may also be used for project automation as the development lifecycle becomes more complex.

## Repository Structure

```text
expense-claim-app/
│
├── .github/
│   └── workflows/          GitHub Actions workflows
│
├── config/
│   └── project-scratch-def.json
│                          Scratch-org configuration
│
├── docs/                  Architecture and project documentation
│
├── force-app/
│   └── main/
│       └── default/       Salesforce package metadata
│
├── scripts/               Development and setup scripts
│
├── .forceignore
├── .gitignore
├── LICENSE
├── README.md
└── sfdx-project.json
```

The contents of `force-app` form the Salesforce application source and will ultimately be included in the managed package.

## Development Model

Development follows a source-driven workflow.

```text
Feature branch
      │
      ▼
Pull Request
      │
      ├── Static analysis
      ├── Automated tests
      └── Salesforce validation
      │
      ▼
     main
      │
      ▼
2GP package version
      │
      ▼
Installation testing
      │
      ▼
Released package
```

The `main` branch represents the current accepted source.

Changes should normally be made in short-lived branches such as:

```text
feature/expense-object
feature/mileage-calculation
fix/duplicate-claim
docs/architecture
```

and merged through Pull Requests.

## Prerequisites

For local development you need:

- Git
- Salesforce CLI
- VS Code
- Salesforce Extension Pack for VS Code
- Access to a Salesforce Dev Hub
- Permission to create scratch orgs

Verify the main tools with:

```bash
git --version
sf --version
```

## Clone the Repository

Using SSH:

```bash
git clone git@github.com:cmlcs/expense-claim-app.git
cd expense-claim-app
```

## Authenticate Your Dev Hub

Authenticate the Salesforce org that acts as your Dev Hub:

```bash
sf org login web \
  --alias DevHub \
  --set-default-dev-hub
```

Verify the connection:

```bash
sf org display --target-org DevHub
```

## Create a Development Scratch Org

Create a scratch org using the configuration stored in this repository:

```bash
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias ExpenseDev \
  --set-default \
  --duration-days 7
```

Open the org:

```bash
sf org open --target-org ExpenseDev
```

## Deploy the Source

Deploy the current application source:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org ExpenseDev
```

As the project evolves, setup scripts and automation may replace some of these manual steps.

## Run Tests

Apex tests can be run with:

```bash
sf apex run test \
  --test-level RunLocalTests \
  --target-org ExpenseDev \
  --wait 20
```

Lightning Web Component tests and additional quality checks will be added as those components are introduced.

## Static Analysis

The project uses Salesforce Code Analyzer as part of its quality checks.

Run it locally with:

```bash
sf code-analyzer run \
  --workspace force-app \
  --severity-threshold 3
```

The same analysis is intended to run automatically for Pull Requests through GitHub Actions.

## Managed Package

The project is intended to be distributed as a **Salesforce second-generation managed package (2GP)**.

The managed-package lifecycle will be:

```text
Source in GitHub
      ↓
Managed 2GP beta
      ↓
Install in clean test org
      ↓
Automated and manual validation
      ↓
Promote tested package version
      ↓
Released managed package
```

The Salesforce namespace, package ID, installation instructions, and release information will be added once the initial managed package has been created.

## Configuration Philosophy

Organisation-specific expense policies should be configurable wherever practical rather than hard-coded.

Examples include:

- Expense categories
- Mileage rates
- Reimbursement limits
- Approval thresholds
- Enabled expense types
- Business rules

Custom Metadata Types and other Salesforce configuration mechanisms will be preferred where appropriate.

## Contributing

Contributions are welcome.

For now, use the following workflow:

```bash
git checkout main
git pull

git checkout -b feature/my-change

# make your changes

git add .
git commit -m "feat: describe the change"
git push -u origin feature/my-change
```

Then create a Pull Request into `main`.

More detailed contribution guidelines will be added to `CONTRIBUTING.md` as the project matures.

## Documentation

Project documentation will live under:

```text
docs/
├── architecture/
├── configuration/
└── contributing/
```

Architecture decisions that materially affect the package should be documented alongside the source.

## Roadmap

Initial development will focus on establishing the technical foundation before implementing the full expense-management functionality.

Current priorities include establishing the Dev Hub and namespace, creating the first managed 2GP package, validating scratch-org development, creating the CI/CD pipeline, and proving package installation in a clean Salesforce org.

Feature development will follow once the packaging and deployment lifecycle is working reliably.

## Security

Do not commit Salesforce credentials, SFDX authentication URLs, private keys, access tokens, or other secrets to this repository.

Secrets required by CI/CD should be stored using GitHub Actions secrets or another appropriate secret-management mechanism.

## License

This project is licensed under the **Apache License 2.0**.

See [LICENSE](LICENSE) for details.