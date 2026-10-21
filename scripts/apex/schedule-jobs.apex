// Schedules the recurring jobs. Run once per org:
//   sf apex run --file scripts/apex/schedule-jobs.apex --target-org <alias>

// Daily 06:00: reminder emails 1 month and 1 day before a lease ends.
LeaseExpiryNotificationJob.scheduleDaily();

// Hourly: geocodes properties that stayed "Pending" (large data loads, failed callouts retried by resetting the status).
System.schedule('Geocode pending properties', '0 0 * * * ?', new PropertyGeocodeBatch());
