/**
 * Lease agreement rules:
 *  - a property cannot have two leases whose date ranges overlap
 *  - creating a lease completes the open "Generate lease agreement" task of that property
 */
public with sharing class LeaseAgreementTriggerHandler {
    public static void beforeSave(List<Lease_Agreement__c> newList, Map<Id, Lease_Agreement__c> oldMap) {
        preventOverlappingLeases(newList);
    }

    public static void afterInsert(List<Lease_Agreement__c> newList) {
        completeGenerationTasks(newList);
    }

    private static void preventOverlappingLeases(List<Lease_Agreement__c> leases) {
        Set<Id> propertyIds = new Set<Id>();
        Set<Id> ownIds = new Set<Id>();
        Date earliestStart;
        Date latestEnd;

        for (Lease_Agreement__c lease : leases) {
            if (lease.Id != null) {
                ownIds.add(lease.Id);
            }
            if (lease.Property__c == null || lease.Start_Date__c == null || lease.End_Date__c == null) {
                continue;
            }
            propertyIds.add(lease.Property__c);
            if (earliestStart == null || lease.Start_Date__c < earliestStart) {
                earliestStart = lease.Start_Date__c;
            }
            if (latestEnd == null || lease.End_Date__c > latestEnd) {
                latestEnd = lease.End_Date__c;
            }
        }
        if (propertyIds.isEmpty()) {
            return;
        }

        Map<Id, List<Lease_Agreement__c>> existingByProperty = new Map<Id, List<Lease_Agreement__c>>();
        for (Lease_Agreement__c existing : [
            SELECT Id, Name, Property__c, Start_Date__c, End_Date__c
            FROM Lease_Agreement__c
            WHERE
                Property__c IN :propertyIds
                AND Start_Date__c <= :latestEnd
                AND End_Date__c >= :earliestStart
                AND Id NOT IN :ownIds
        ]) {
            if (!existingByProperty.containsKey(existing.Property__c)) {
                existingByProperty.put(existing.Property__c, new List<Lease_Agreement__c>());
            }
            existingByProperty.get(existing.Property__c).add(existing);
        }

        // Records of the same transaction are checked against each other as well.
        Map<Id, List<Lease_Agreement__c>> acceptedByProperty = new Map<Id, List<Lease_Agreement__c>>();
        for (Lease_Agreement__c lease : leases) {
            if (lease.Property__c == null || lease.Start_Date__c == null || lease.End_Date__c == null) {
                continue;
            }
            List<Lease_Agreement__c> others = new List<Lease_Agreement__c>();
            if (existingByProperty.containsKey(lease.Property__c)) {
                others.addAll(existingByProperty.get(lease.Property__c));
            }
            if (acceptedByProperty.containsKey(lease.Property__c)) {
                others.addAll(acceptedByProperty.get(lease.Property__c));
            }

            Lease_Agreement__c clash = firstOverlap(lease, others);
            if (clash != null) {
                String label = clash.Name == null ? 'another lease in this batch' : clash.Name;
                lease.addError('This property already has a lease (' + label + ') that overlaps the selected dates.');
            } else {
                if (!acceptedByProperty.containsKey(lease.Property__c)) {
                    acceptedByProperty.put(lease.Property__c, new List<Lease_Agreement__c>());
                }
                acceptedByProperty.get(lease.Property__c).add(lease);
            }
        }
    }

    private static Lease_Agreement__c firstOverlap(Lease_Agreement__c lease, List<Lease_Agreement__c> others) {
        for (Lease_Agreement__c other : others) {
            if (lease.Start_Date__c <= other.End_Date__c && lease.End_Date__c >= other.Start_Date__c) {
                return other;
            }
        }
        return null;
    }

    private static void completeGenerationTasks(List<Lease_Agreement__c> leases) {
        Set<Id> propertyIds = new Set<Id>();
        for (Lease_Agreement__c lease : leases) {
            if (lease.Property__c != null) {
                propertyIds.add(lease.Property__c);
            }
        }
        if (propertyIds.isEmpty()) {
            return;
        }
        String subjectPattern = PropertyAssignmentService.TASK_SUBJECT_PREFIX + '%';
        List<Task> openTasks = [
            SELECT Id
            FROM Task
            WHERE WhatId IN :propertyIds AND IsClosed = FALSE AND Subject LIKE :subjectPattern
        ];
        for (Task t : openTasks) {
            t.Status = 'Completed';
        }
        if (!openTasks.isEmpty()) {
            update openTasks;
        }
    }
}
