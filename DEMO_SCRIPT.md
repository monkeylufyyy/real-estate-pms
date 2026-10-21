# Demo recording script (about 8 minutes)

Record the browser window with any screen recorder (Windows: **Win + G** Game Bar, or OBS). Speak while you click. Seed data and images are already in the org.

Before you start: open the **Real Estate PMS** app from the App Launcher. Change the email of tenant *Arjun Mehta* to an address you can open, so the PDF email can be shown arriving.

## 1. Properties list (1 min)
1. Open the **Properties** tab. Point out the 25-per-page paging, the count and the image cards.
2. Filter by price (for example 30,000 to 70,000), then clear it.
3. Filter by Availability = Available and Furnishing = Furnished.
4. Enter **Nearby distance = 15 km**, click **Use my location** (allow the browser prompt) or type latitude 13.0827 and longitude 80.2707 for Chennai, then **Apply filters**. Show the "km away" labels and the sort by distance.

## 2. Create a property (1.5 min)
1. Click **New Property**. Fill the fields.
2. Click **Save property** with no image. Show the "At least one property image is required" message.
3. Add one or two photos and save. Show the success toast.
4. On the record page show the gallery, the **map with the geocoded marker** and the geocode status.

## 3. Tenant assignment and task (1 min)
1. Open a property that is Available, set **Tenant** and save.
2. Show the status changed to Occupied and the new open task **Generate lease agreement** in the activity panel.
3. Open **Tenants** and show the list view, including a tenant with two properties.

## 4. Lease agreement, PDF and email (2 min)
1. Open **Lease Agreements**, create a lease for the property from step 3. Show the task is now completed.
2. Try a second lease with overlapping dates and show the error.
3. On the lease record click **Download PDF** and open the file.
4. Click **Send PDF to Tenant**, confirm, and show the email arriving with the attachment and the "Last sent" time.

## 5. Vendors and maintenance requests (1 min)
1. Create a Maintenance Request without choosing a vendor. Show the vendor was filled in automatically.
2. Create two more and show they spread across vendors, then open **Vendors** and show their requests.

## 6. Dashboard (1 min)
Open **Dashboards**, **Real Estate Dashboard**, click **Refresh**. Show the occupancy gauge, requests by status and leases expiring in 30 days.

## 7. Automation and tests (30 sec)
- Setup, Scheduled Jobs: show **Lease Expiry Notifications** (daily) and **Geocode pending properties** (hourly).
- Setup, Apex Test Execution, Run All: show 77 passing tests. Developer Console, Tests, Overall Code Coverage for per-class coverage.
