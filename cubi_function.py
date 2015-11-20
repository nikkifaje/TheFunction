

def query_function(lens = 'NULL', output = 'NULL'):

    """Returns standardized data for or from SQL."""

    try:
        print('Begin')
        file_location = r'C:\Python34\VEnvs\MSSQL\pymssql\Function\TheFunction.sql'
        file = open(file_location).readlines()
        #print(file)
        
        sql_function_head = '''

            USE [EfficiencyDev]
            GO
            SET ANSI_NULLS ON
            GO

            SET QUOTED_IDENTIFIER ON
            GO

            CREATE FUNCTION [dbo].[ufn_ArrowheadCU_Members_ALPHA] (
	        @Lens VARCHAR(50) = 'Init'
	        ,@StartDate DATE = NULL
	        ,@EndDate DATE = NULL
            )

            RETURNS TABLE

            AS

            RETURN (
        '''

        results_head = '''
            DECLARE
            SET
            DECLARE
            SET
        '''

        variables_dictionary = {}
        for line in file:
            word_list = line.split()
            strip_items_dictionary = {'(':'', ')':'', ',':''}
            for word in word_list:
                if '@' in word:
                    word_alter = word
                    for strip_item in strip_items_dictionary:
                        if strip_item in word_alter:
                            word_alter = word_alter.replace(strip_item, strip_items_dictionary[strip_item])
                        else:
                            continue
                    variables_dictionary[word_alter] = None
        print(variables_dictionary)
        
        if output.upper() == 'GETRESULTS':
            pass

        if output.upper() == 'GETQUERY':
            pass

        if output.upper() == 'GETFUNCTION':
            pass

    
    except Exception as ex:
        raise

    finally:
        pass


if __name__ == '__main__':
    query_function()
