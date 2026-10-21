/**
 * Small helper so every @AuraEnabled method surfaces a readable message to the UI.
 */
public with sharing class AuraErrors {
    public static AuraHandledException build(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    public static String messageOf(Exception e) {
        if (e instanceof DmlException && ((DmlException) e).getNumDml() > 0) {
            return ((DmlException) e).getDmlMessage(0);
        }
        return e.getMessage();
    }
}
