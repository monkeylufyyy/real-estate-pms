/**
 * Automatically assigns new maintenance requests to the active vendor with the least workload.
 * Workload = number of that vendor's requests that are Open or In progress.
 * Requests created in the same transaction are counted as they are assigned, so a bulk insert
 * spreads evenly instead of piling onto one vendor. Ties are broken by vendor name.
 */
public with sharing class VendorAssignmentService {
    public static final Set<String> ACTIVE_STATUSES = new Set<String>{ 'Open', 'In progress' };

    public static void assignVendors(List<Maintenance_Request__c> requests) {
        List<Maintenance_Request__c> unassigned = new List<Maintenance_Request__c>();
        Map<Id, Integer> inBatch = new Map<Id, Integer>();

        for (Maintenance_Request__c request : requests) {
            if (request.Vendor__c == null) {
                unassigned.add(request);
            } else if (isActive(request)) {
                increment(inBatch, request.Vendor__c);
            }
        }
        if (unassigned.isEmpty()) {
            return;
        }

        List<Vendor__c> vendors = [SELECT Id FROM Vendor__c WHERE Is_Active__c = TRUE ORDER BY Name ASC, Id ASC];
        if (vendors.isEmpty()) {
            return;
        }

        Map<Id, Integer> workload = loadWorkload(vendors);
        for (Id vendorId : inBatch.keySet()) {
            if (workload.containsKey(vendorId)) {
                workload.put(vendorId, workload.get(vendorId) + inBatch.get(vendorId));
            }
        }

        for (Maintenance_Request__c request : unassigned) {
            Id best = leastLoaded(vendors, workload);
            request.Vendor__c = best;
            if (isActive(request)) {
                increment(workload, best);
            }
        }
    }

    private static Map<Id, Integer> loadWorkload(List<Vendor__c> vendors) {
        Map<Id, Integer> workload = new Map<Id, Integer>();
        for (Vendor__c vendor : vendors) {
            workload.put(vendor.Id, 0);
        }
        for (AggregateResult row : [
            SELECT Vendor__c vendorId, COUNT(Id) total
            FROM Maintenance_Request__c
            WHERE Vendor__c IN :workload.keySet() AND Status__c IN :ACTIVE_STATUSES
            GROUP BY Vendor__c
        ]) {
            workload.put((Id) row.get('vendorId'), (Integer) row.get('total'));
        }
        return workload;
    }

    private static Id leastLoaded(List<Vendor__c> vendors, Map<Id, Integer> workload) {
        Id best;
        Integer bestLoad;
        for (Vendor__c vendor : vendors) {
            Integer load = workload.get(vendor.Id);
            if (best == null || load < bestLoad) {
                best = vendor.Id;
                bestLoad = load;
            }
        }
        return best;
    }

    private static Boolean isActive(Maintenance_Request__c request) {
        return request.Status__c == null || ACTIVE_STATUSES.contains(request.Status__c);
    }

    private static void increment(Map<Id, Integer> counts, Id key) {
        counts.put(key, (counts.containsKey(key) ? counts.get(key) : 0) + 1);
    }
}
