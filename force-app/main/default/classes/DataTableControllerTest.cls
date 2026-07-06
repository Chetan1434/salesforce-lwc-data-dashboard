@isTest
private class DataTableControllerTest {

    @testSetup
    static void setup() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 25; i++) {
            accounts.add(new Account(
                Name           = 'Test Account ' + i,
                Industry       = 'Technology',
                Phone          = '415-555-' + String.valueOf(i).leftPad(4, '0'),
                AnnualRevenue  = 100000 + (i * 1000),
                Rating         = 'Warm'
            ));
        }
        insert accounts;
    }

    @isTest
    static void testGetAccountsDefaultParams() {
        Test.startTest();
        DataTableController.TableResponse response =
            DataTableController.getAccounts(null, null, null);
        Test.stopTest();

        System.assertEquals(25, response.totalRecords,
            'Total record count should match inserted records');
        System.assertEquals(10, response.records.size(),
            'Default page size should return 10 records');
    }

    @isTest
    static void testGetAccountsWithSearch() {
        Test.startTest();
        DataTableController.TableResponse response =
            DataTableController.getAccounts('Test Account 1', 10, 1);
        Test.stopTest();

        System.assert(response.totalRecords > 0,
            'Should find accounts matching the search key');
        for (Account acc : response.records) {
            System.assert(acc.Name.contains('Test Account 1'),
                'All returned records should match the search term');
        }
    }

    @isTest
    static void testGetAccountsPagination() {
        Test.startTest();
        DataTableController.TableResponse page1 = DataTableController.getAccounts('', 10, 1);
        DataTableController.TableResponse page2 = DataTableController.getAccounts('', 10, 2);
        DataTableController.TableResponse page3 = DataTableController.getAccounts('', 10, 3);
        Test.stopTest();

        System.assertEquals(10, page1.records.size(), 'Page 1 should have 10 records');
        System.assertEquals(10, page2.records.size(), 'Page 2 should have 10 records');
        System.assertEquals(5, page3.records.size(), 'Page 3 should have the remaining 5 records');
        System.assert(page1.records[0].Id != page2.records[0].Id,
            'Different pages should return different records');
    }

    @isTest
    static void testGetAccountsNoResults() {
        Test.startTest();
        DataTableController.TableResponse response =
            DataTableController.getAccounts('NoSuchAccountXYZ', 10, 1);
        Test.stopTest();

        System.assertEquals(0, response.totalRecords, 'No records should match');
        System.assertEquals(0, response.records.size(), 'Records list should be empty');
    }

    @isTest
    static void testUpdateAccountsSuccess() {
        List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 5];
        for (Account acc : accounts) {
            acc.Industry = 'Finance';
        }

        Test.startTest();
        DataTableController.updateAccounts(accounts);
        Test.stopTest();

        List<Account> updated = [SELECT Id, Industry FROM Account WHERE Id IN :accounts];
        for (Account acc : updated) {
            System.assertEquals('Finance', acc.Industry, 'Industry should be updated');
        }
    }

    @isTest
    static void testUpdateAccountsFailure() {
        // Malformed / non-existent Id forces a DML failure so we exercise
        // the AuraHandledException branch in updateAccounts.
        Account fakeAccount = new Account(
            Id   = '001000000000000AAA',
            Name = 'Fake Account'
        );

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            DataTableController.updateAccounts(new List<Account>{ fakeAccount });
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown,
            'An exception should be thrown when updating an invalid record');
    }
}
