/**
 * @description Backend controller for the LWC Data Table Dashboard.
 * Handles paginated, searchable reads and bulk inline-edit saves on Account.
 */
public with sharing class DataTableController {

    /**
     * Wrapper so the LWC gets both the page of records AND the total
     * record count (needed to calculate total pages) in a single round trip.
     */
    public class TableResponse {
        @AuraEnabled public List<Account> records;
        @AuraEnabled public Integer totalRecords;
    }

    /**
     * @description Returns one page of Accounts matching an optional search key.
     * @param searchKey   Free-text match against Account.Name (nullable)
     * @param pageSize    Records per page (defaults to 10)
     * @param pageNumber  1-based page number (defaults to 1)
     */
    @AuraEnabled(cacheable=true)
    public static TableResponse getAccounts(String searchKey, Integer pageSize, Integer pageNumber) {
        TableResponse response = new TableResponse();

        try {
            pageSize   = (pageSize   == null || pageSize   <= 0) ? 10 : pageSize;
            pageNumber = (pageNumber == null || pageNumber <= 0) ? 1  : pageNumber;
            Integer offsetVal = (pageNumber - 1) * pageSize;

            String likeKey = '%' + String.escapeSingleQuotes(
                String.isBlank(searchKey) ? '' : searchKey
            ) + '%';

            response.totalRecords = Database.countQuery(
                'SELECT COUNT() FROM Account WHERE Name LIKE :likeKey'
            );

            response.records = Database.query(
                'SELECT Id, Name, Industry, Phone, AnnualRevenue, Rating ' +
                'FROM Account ' +
                'WHERE Name LIKE :likeKey ' +
                'ORDER BY Name ASC ' +
                'LIMIT :pageSize OFFSET :offsetVal'
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching accounts: ' + e.getMessage());
        }

        return response;
    }

    /**
     * @description Saves inline-edited rows from lightning-datatable.
     * Not cacheable — this is a DML operation, called imperatively from the LWC.
     */
    @AuraEnabled
    public static void updateAccounts(List<Account> accounts) {
        try {
            List<Database.SaveResult> results = Database.update(accounts, false);
            List<String> errorMessages = new List<String>();

            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        errorMessages.add(err.getMessage());
                    }
                }
            }

            if (!errorMessages.isEmpty()) {
                throw new AuraHandledException('Update failed: ' + String.join(errorMessages, '; '));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error updating accounts: ' + e.getMessage());
        }
    }
}
