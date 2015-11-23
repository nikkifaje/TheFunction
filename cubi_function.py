import re


def query_function(lens = 'NULL', output = 'NULL'):

    """Returns standardized data for or from SQL."""

    try:
        print('Begin')
        file_location = r'C:\Python34\VirtualEnvs\CUBITest\TheFunction\ACUFunction.sql'
        read_file_string = open(file_location).read()
       
        
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

        strip_items_dictionary = {'(':'', ')':'', ',':''}

        
        #Capture all definitions that need to be declared in sql function
        read_file_list = read_file_string.split('\n')
        variables_dictionary = {}
        for line in read_file_list:
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


        #Build output sql query for relevant lens paramters to optimize final query
        #execution. Read through eac set of LEFT OUTER JOINS and build requested
        #select statement accoring to string format parameter
        sql_output_list = read_file_string.split(':BEGINOUTPUT')
        sql_left_join_list = sql_output_list[1].split('LEFT OUTER JOIN')
        for left_join_group in sql_left_join_list[0:5]:
            #print(repr(left_join_group))
            words_list = re.split(r' |\n*', left_join_group)
            #print(repr(word))
            #for word in left_join_group.re.split(r'\s*', word):
            for word in words_list:
                if "'%:" in word:
                    print(repr(word))
            #print('LEFT OUTER JOIN '+join_group)
            
        
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
