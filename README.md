# Real Estate Property Management System

A Salesforce (Lightning Experience) application for managing properties, tenants, lease agreements, vendors and maintenance requests, with a dashboard for occupancy, expiring leases and maintenance workload.

Built with Apex, Lightning Web Components, Salesforce metadata (objects, reports, dashboard) and [jsPDF](https://github.com/parallax/jsPDF) for PDF generation.

## Data model

| Object | Purpose | Key fields |
| --- | --- | --- |
| `Property__c` | A rentable property | Address, City, State, Postal Code, Country, Type, Furnishing Status, Status, Rent, Description, Tenant, Geolocation, Image Count |
| `Tenant__c` | A tenant (can rent many properties) | Name, Phone Number, Email |
| `Lease_Agreement__c` | A lease for exactly one property | Property, Tenant, Terms, Agreed Monthly Rent, Start Date, End Date |
| `Vendor__c` | A maintenance service provider | Name, Phone Number, Email, Active |
| `Maintenance_Request__c` | A maintenance job | Property, Vendor, Status (Open / In progress / Completed / Cancelled), Description |

Images are Salesforce Files attached to the property, so a property can have any number of them.

## Requirement coverage

| Requirement | Where it lives |
| --- | --- |
| Property fields, required rules | Field metadata, validation rules, custom create form |
| List view with server-side pagination (25 per page) | `propertyList` LWC and `PropertySearchController` (SOQL `LIMIT` / `OFFSET`, separate `COUNT()` query) |
| Filters: price, availability, furnishing, nearby distance | Same component. Nearby uses SOQL `DISTANCE()` against the geolocation field and the browser's location (or manual latitude / longitude) |
| Create property, images required, cannot save without one | `propertyCreate` LWC overrides the standard **New** action. `PropertyService.createProperty` saves the property and its images in one transaction and rolls back on any failure |
| Geocode the address and show a map | `GeocodingService` (OpenStreetMap Nominatim) runs from a Queueable after save. `propertyMap` LWC renders it with `lightning-map` on the record page |
| Tenants list | `All Tenants` list view and tab. A tenant can be assigned to many properties |
| Task to generate the lease when a property is assigned | `PropertyTriggerHandler` and `PropertyAssignmentService`. Assigning a tenant also marks an available property as Occupied. Creating the lease completes the task |
| Lease list and create | Standard list view and tab for `Lease_Agreement__c` |
| Download PDF and send PDF to tenant | `leaseActions` LWC on the lease record page. `leasePdfBuilder` builds the PDF with jsPDF (static resource `jspdf`). `LeaseAgreementController.sendLeasePdf` emails it and keeps a copy on the record |
| Email 1 month and 1 day before lease end | `LeaseExpiryNotificationJob` (Batchable and Schedulable, daily). Flags on the lease make each email go out once |
| Vendors | `Vendor__c` with list view and tab |
| Auto-assign maintenance request to least-loaded vendor | `MaintenanceRequestTrigger` and `VendorAssignmentService` |
| Dashboard: leases expiring in 30 days, requests by status, occupancy rate | `Real Estate Dashboard` in the `Real Estate Dashboards` folder, built on three reports |
| Bulk data | Bulkified triggers (no SOQL or DML in loops), batch geocoding, one `sendEmail` call per batch, indexed filters, paged queries |
| Unit tests, 80%+ coverage | 77 Apex tests, see below |

## Behaviour worth knowing

- **Assigning a tenant** to an available property sets it to Occupied and creates a "Generate lease agreement" task due in 7 days for the property owner.
- **Overlapping leases** on the same property are rejected.
- **Vendor workload** is the number of that vendor's requests that are Open or In progress. Ties go to the vendor whose name sorts first. Only active vendors are considered. A request that already has a vendor keeps it.
- **Reminder emails**: the one-month email goes out once a lease ends within a month. The one-day email goes out when it ends tomorrow or today. A lease that is created late (for example 10 days from its end) receives only the final reminder.
- **Pagination limit**: Salesforce caps SOQL `OFFSET` at 2,000 rows, so 81 pages can be browsed. The UI tells the user to narrow the filters beyond that.
- **Geocoding** uses the free Nominatim service (no API key, light usage only). Inserts of up to 100 properties geocode immediately. Larger loads stay `Pending` and `PropertyGeocodeBatch` processes them.
- **Developer Edition orgs** allow only 15 single emails per day, which affects the PDF and reminder emails there. Production orgs allow far more. Reminders that cannot be sent are retried on the next daily run.
- **Image uploads on create** are resized in the browser and capped at about 3 MB per save. More images can be added from the property page with no such cap.

## Deploy

Prerequisites: Salesforce CLI and an authenticated org.

```bash
sf org login web --alias real-estate
sf project deploy start --source-dir force-app --target-org real-estate
sf org assign permset --name Real_Estate_PMS_Admin --target-org real-estate
```

Optional demo data and background jobs:

```bash
sf apex run --file scripts/apex/seed-demo-data.apex --target-org real-estate
powershell -File scripts/attach-demo-images.ps1 -TargetOrg real-estate
sf apex run --file scripts/apex/schedule-jobs.apex --target-org real-estate
```

Open the **Real Estate PMS** app from the App Launcher. The **Properties** tab is the paginated list. Dashboards are in the Dashboards tab.

Note: Salesforce refuses to deploy Apex classes that have scheduled jobs pending. Delete the two scheduled jobs (Setup, Scheduled Jobs) before redeploying Apex, then run `schedule-jobs.apex` again.

## Tests

```bash
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 20 --target-org real-estate
```

77 tests, all passing. Coverage of the application classes and triggers is between 86% and 100% each. The test classes cover:

- tenant assignment, task creation, bulk updates of 200 records and geocoding
- image rules (required, type, size, rollback) and image counts
- pagination, every filter, distance sorting and filter validation
- lease overlap, validation rules, task completion and PDF email
- reminder emails (month, day, never twice, bulk, scheduling)
- vendor assignment (least workload, ties, inactive vendors, bulk, explicit vendor)

Tests that exercise user-mode security run as a standard user holding only the `Real_Estate_PMS_Admin` permission set.

## Project layout

```
force-app/main/default
  objects/            custom objects, fields, validation rules, list views
  classes/            Apex services, controllers, batch / queueable jobs, tests
  triggers/           PropertyTrigger, LeaseAgreementTrigger, MaintenanceRequestTrigger, ContentDocumentLinkTrigger
  lwc/                propertyList, propertyCreate, propertyMap, propertyGallery, leaseActions, leasePdfBuilder
  aura/               propertyNewOverride (hosts the create form as the New action override)
  staticresources/    jspdf (jsPDF 2.5.1)
  flexipages/         Property and Lease record pages
  reports/, dashboards/   dashboard and its reports
  permissionsets/     Real_Estate_PMS_Admin
scripts/              seed data, job scheduling, demo images
```
