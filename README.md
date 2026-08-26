# SFPro

This repository is to start my SF journey and gracefully update all the day to day things which I handle and projects I accomplished.

1. Successfully implemented Agentforce SDR and generated prompt templates
2. Implemented the Sales coach
3. Participated in the release cycle and identified various bugs and created known issues which came part of the SF release.
4. Will be highlighting all the known issues I have created as part of Spring 25.
5. Developed prompt template agents using Flows. This will help in auto translating a filed from a different language to english in another field
6. Implmeneted the ECI functionality with SDR where it will automatically track all the mails coming to and fro of a lead and land them in activity.

## Salesforce → Claude → GitHub Sync

This repo is connected to a live Salesforce org through Claude, which pulls metadata out of the org and pushes it here as real, version-controlled source. Here's what's been done so far and how it works.

### How it works

1. **Salesforce connection** — Claude has an MCP connection to the org (`Salesforce_Connector`) that runs SOQL queries against the standard REST API (`soqlQuery`, `getObjectSchema`, etc.). A second connection (`Salesforce Tooling API`) exists but is reference-only — it returns metadata *schema* documentation (field definitions, valid values), not live query results, so it can't retrieve actual org data.
2. **Claude Code** reads the org's metadata records, reconstructs them as proper SFDX source files (`.cls`/`.trigger` + their `-meta.xml` companions), and commits them to this repo on the `claude/salesforce-github-sync-x04508` branch.
3. **GitHub** — commits are pushed to that branch, tracked via [PR #2](https://github.com/Vamshi-Rammadugu/SFPro/pull/2). Future syncs push new commits to the same branch/PR rather than opening new ones.

### What's included

Laid out as a standard SFDX project (`sfdx-project.json`, `force-app/main/default/...`):

- **438 Apex classes** — `force-app/main/default/classes`
- **66 Apex triggers** — `force-app/main/default/triggers`

Only custom, non-managed-package code was pulled — records where `NamespacePrefix = null`. The org also has thousands of Apex classes/triggers belonging to installed managed packages (FSL, Maps, Marketing Cloud `et4ae5`, Pardot `pi`, `sfsp`, and others); those were intentionally excluded since their source isn't meaningfully readable/editable outside the package anyway (managed package bodies come back as unreadable generated stubs).

### Known gap: Lightning Web Components

**LWC source is not included yet.** Retrieving `LightningComponentBundle` records requires live Tooling/Metadata API access. The `Salesforce_Connector` connection only has standard REST API access (it explicitly rejects `LightningComponentBundle` as an invalid query type), and the `Salesforce Tooling API` connection, despite the name, only exposes schema/reference documentation — it has no `query`/`retrieve` action that can execute against the live org. Closing this gap needs one of:

- A connector with a genuine Tooling API *query/execute* action (not just reference docs), or
- Local SFDX CLI access (`sf project retrieve start -m LightningComponentBundle`) against an authenticated org, with the results committed here.

### Status

- ✅ Apex classes + triggers synced and pushed
- ⬜ LWC components — blocked on Tooling/Metadata API access (see above)
