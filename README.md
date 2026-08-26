# SFPro

This repository is to start my SF journey and gracefully update all the day to day things which I handle and projects I accomplished.

1. Successfully implemented Agentforce SDR and generated prompt templates
2. Implemented the Sales coach
3. Participated in the release cycle and identified various bugs and created known issues which came part of the SF release.
4. Will be highlighting all the known issues I have created as part of Spring 25.
5. Developed prompt template agents using Flows. This will help in auto translating a filed from a different language to english in another field
6. Implmeneted the ECI functionality with SDR where it will automatically track all the mails coming to and fro of a lead and land them in activity.

## Salesforce Metadata Sync

This repository now includes the connected Salesforce org's custom Apex source, synced directly from the org and laid out as a standard SFDX project (`force-app/main/default/...`, `sfdx-project.json`):

- **438 Apex classes** (`force-app/main/default/classes`)
- **66 Apex triggers** (`force-app/main/default/triggers`)

Only custom, non-managed-package code was pulled — records where `NamespacePrefix = null`. The org also has thousands of Apex classes/triggers belonging to installed managed packages (FSL, Maps, Marketing Cloud `et4ae5`, Pardot `pi`, `sfsp`, and others); those were intentionally excluded since their source isn't meaningfully readable/editable outside the package anyway.

**Known gap: Lightning Web Components (LWC) are not included.** The connected app backing this sync only has standard REST API access to the org, not Tooling API or Metadata API access, and LWC bundle source (`LightningComponentBundle`) can only be retrieved through those APIs. Retrieving LWC source in a future sync will require enabling Tooling API scope on the connection, or pulling the metadata via SFDX/Metadata API (e.g. `sf project retrieve start`) instead of SOQL.
