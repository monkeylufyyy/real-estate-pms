// Demo data for the Real Estate PMS: run with
//   sf apex run --file scripts/apex/seed-demo-data.apex --target-org <alias>
// Properties are geocoded automatically after the save (OpenStreetMap Nominatim).
// Images are attached separately (see scripts/attach-demo-images.ps1) because properties
// created through the UI must have images; this script creates records directly.

if ([SELECT COUNT() FROM Property__c] > 0) {
    System.debug(LoggingLevel.WARN, 'Properties already exist, seed skipped.');
    return;
}

Date today = Date.today();

// ---- Tenants ----
List<Tenant__c> tenants = new List<Tenant__c>{
    new Tenant__c(Name = 'Arjun Mehta', Phone__c = '9840011111', Email__c = 'arjun.mehta@example.com'),
    new Tenant__c(Name = 'Priya Nair', Phone__c = '9840022222', Email__c = 'priya.nair@example.com'),
    new Tenant__c(Name = 'Rahul Verma', Phone__c = '9840033333', Email__c = 'rahul.verma@example.com'),
    new Tenant__c(Name = 'Sneha Iyer', Phone__c = '9840044444', Email__c = 'sneha.iyer@example.com'),
    new Tenant__c(Name = 'Karthik Raja', Phone__c = '9840055555', Email__c = 'karthik.raja@example.com')
};
insert tenants;

// ---- Vendors ----
insert new List<Vendor__c>{
    new Vendor__c(Name = 'Chennai Plumbing Works', Phone__c = '9444000001', Email__c = 'plumbing@example.com'),
    new Vendor__c(Name = 'Spark Electricals', Phone__c = '9444000002', Email__c = 'electric@example.com'),
    new Vendor__c(Name = 'CoolAir HVAC Services', Phone__c = '9444000003', Email__c = 'hvac@example.com'),
    new Vendor__c(Name = 'FixIt Carpentry', Phone__c = '9444000004', Email__c = 'carpentry@example.com')
};

// ---- Properties ----
List<Property__c> props = new List<Property__c>{
    new Property__c(Name = 'Marina Residency', Address__c = 'Kamarajar Salai', City__c = 'Chennai', State__c = 'Tamil Nadu', Postal_Code__c = '600005', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Furnished', Status__c = 'Available', Rent__c = 45000, Description__c = '3 BHK apartment a short walk from Marina Beach.'),
    new Property__c(Name = 'Adyar Heights', Address__c = 'Besant Avenue, Adyar', City__c = 'Chennai', State__c = 'Tamil Nadu', Postal_Code__c = '600020', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Semi-Furnished', Status__c = 'Available', Rent__c = 32000, Description__c = '2 BHK near the Adyar river with covered parking.'),
    new Property__c(Name = 'T Nagar Studio', Address__c = 'Usman Road, T Nagar', City__c = 'Chennai', State__c = 'Tamil Nadu', Postal_Code__c = '600017', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Unfurnished', Status__c = 'Available', Rent__c = 18000, Description__c = 'Compact studio in the heart of the shopping district.'),
    new Property__c(Name = 'Anna Nagar Duplex', Address__c = '2nd Avenue, Anna Nagar', City__c = 'Chennai', State__c = 'Tamil Nadu', Postal_Code__c = '600040', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Furnished', Status__c = 'Available', Rent__c = 58000, Description__c = '4 BHK duplex with terrace garden.'),
    new Property__c(Name = 'Velachery Flat', Address__c = 'Velachery Main Road', City__c = 'Chennai', State__c = 'Tamil Nadu', Postal_Code__c = '600042', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Semi-Furnished', Status__c = 'Available', Rent__c = 24000, Description__c = '2 BHK close to the IT corridor and metro.'),
    new Property__c(Name = 'Indiranagar Loft', Address__c = '100 Feet Road, Indiranagar', City__c = 'Bengaluru', State__c = 'Karnataka', Postal_Code__c = '560038', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Furnished', Status__c = 'Available', Rent__c = 65000, Description__c = 'Modern loft with exposed brick and a rooftop deck.'),
    new Property__c(Name = 'Koramangala Villa', Address__c = '80 Feet Road, Koramangala', City__c = 'Bengaluru', State__c = 'Karnataka', Postal_Code__c = '560034', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Unfurnished', Status__c = 'Available', Rent__c = 95000, Description__c = 'Independent 4 BHK villa with private garden.'),
    new Property__c(Name = 'MG Road Office', Address__c = 'MG Road', City__c = 'Bengaluru', State__c = 'Karnataka', Postal_Code__c = '560001', Country__c = 'India', Type__c = 'Commercial', Furnishing_Status__c = 'Semi-Furnished', Status__c = 'Available', Rent__c = 120000, Description__c = 'Grade A office floor, 3,000 sq ft, fully air conditioned.'),
    new Property__c(Name = 'Bandra Sea View', Address__c = 'Linking Road, Bandra West', City__c = 'Mumbai', State__c = 'Maharashtra', Postal_Code__c = '400050', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Furnished', Status__c = 'Available', Rent__c = 110000, Description__c = 'Sea-facing 2 BHK in a prime Bandra location.'),
    new Property__c(Name = 'Powai Lakeside', Address__c = 'Hiranandani Gardens, Powai', City__c = 'Mumbai', State__c = 'Maharashtra', Postal_Code__c = '400076', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Semi-Furnished', Status__c = 'Available', Rent__c = 72000, Description__c = '3 BHK overlooking Powai Lake with clubhouse access.'),
    new Property__c(Name = 'Banjara Hills Residency', Address__c = 'Road No 12, Banjara Hills', City__c = 'Hyderabad', State__c = 'Telangana', Postal_Code__c = '500034', Country__c = 'India', Type__c = 'Residential', Furnishing_Status__c = 'Furnished', Status__c = 'Available', Rent__c = 52000, Description__c = 'Spacious 3 BHK in a gated community.'),
    new Property__c(Name = 'Hitech City Tower', Address__c = 'Madhapur', City__c = 'Hyderabad', State__c = 'Telangana', Postal_Code__c = '500081', Country__c = 'India', Type__c = 'Commercial', Furnishing_Status__c = 'Unfurnished', Status__c = 'Available', Rent__c = 150000, Description__c = 'Large office floor in the Hitech City business district.')
};
insert props;

// ---- Assign tenants (marks the property Occupied and creates the lease task) ----
Map<String, Property__c> byName = new Map<String, Property__c>();
for (Property__c p : props) {
    byName.put(p.Name, p);
}
byName.get('Marina Residency').Tenant__c = tenants[0].Id;
byName.get('Indiranagar Loft').Tenant__c = tenants[1].Id;
byName.get('Bandra Sea View').Tenant__c = tenants[2].Id;
byName.get('Banjara Hills Residency').Tenant__c = tenants[3].Id;
byName.get('Anna Nagar Duplex').Tenant__c = tenants[4].Id;
byName.get('MG Road Office').Tenant__c = tenants[0].Id; // one tenant renting two properties
update props;

// ---- Leases (the last two properties stay "assigned, lease task still open") ----
List<Lease_Agreement__c> leases = new List<Lease_Agreement__c>{
    new Lease_Agreement__c(Property__c = byName.get('Marina Residency').Id, Tenant__c = tenants[0].Id, Start_Date__c = today.addMonths(-11), End_Date__c = today.addDays(12), Agreed_Monthly_Rent__c = 45000, Terms__c = 'Eleven month lease. Rent due by the 5th of each month. Two months security deposit. No subletting. Maintenance up to INR 2,000 per month is borne by the tenant.'),
    new Lease_Agreement__c(Property__c = byName.get('Indiranagar Loft').Id, Tenant__c = tenants[1].Id, Start_Date__c = today.addMonths(-10), End_Date__c = today.addDays(21), Agreed_Monthly_Rent__c = 65000, Terms__c = 'Eleven month lease. Rent due by the 1st of each month. Three months security deposit. Pets allowed with written approval.'),
    new Lease_Agreement__c(Property__c = byName.get('Bandra Sea View').Id, Tenant__c = tenants[2].Id, Start_Date__c = today.addMonths(-6), End_Date__c = today.addMonths(5), Agreed_Monthly_Rent__c = 108000, Terms__c = 'Eleven month lease. Rent due by the 7th of each month. Society charges paid by the landlord.'),
    new Lease_Agreement__c(Property__c = byName.get('Banjara Hills Residency').Id, Tenant__c = tenants[3].Id, Start_Date__c = today.addMonths(-3), End_Date__c = today.addMonths(8), Agreed_Monthly_Rent__c = 52000, Terms__c = 'Eleven month lease. Rent due by the 5th of each month. One month notice required before vacating.')
};
insert leases;

// ---- Maintenance requests (auto-assigned to the least loaded vendor) ----
List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>();
String[] issues = new List<String>{ 'Kitchen tap leaking', 'Air conditioner not cooling', 'Power socket sparking in bedroom', 'Wardrobe door hinge broken', 'Water heater not working', 'Ceiling fan noisy', 'Bathroom drain blocked', 'Balcony door will not lock' };
String[] statuses = new List<String>{ 'Open', 'Open', 'In progress', 'In progress', 'Completed', 'Open', 'Cancelled', 'Completed' };
List<Property__c> occupied = new List<Property__c>{ byName.get('Marina Residency'), byName.get('Indiranagar Loft'), byName.get('Bandra Sea View'), byName.get('Banjara Hills Residency') };
for (Integer i = 0; i < issues.size(); i++) {
    requests.add(new Maintenance_Request__c(Property__c = occupied[Math.mod(i, occupied.size())].Id, Status__c = statuses[i], Description__c = issues[i]));
}
insert requests;

System.debug('Seeded ' + tenants.size() + ' tenants, ' + props.size() + ' properties, ' + leases.size() + ' leases, ' + requests.size() + ' maintenance requests.');
