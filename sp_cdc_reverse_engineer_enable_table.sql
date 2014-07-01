USE [master];
GO
IF NOT EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_cdc_reverse_engineer_enable_table'))
BEGIN;
	EXEC('CREATE PROCEDURE dbo.sp_cdc_reverse_engineer_enable_table AS SELECT ''ProcedureStub'' AS Stub;');
END;
GO

ALTER PROCEDURE dbo.sp_cdc_reverse_engineer_enable_table
	@ObjectName	NVARCHAR(128) = NULL
AS
/*
---
Description:	Reverse engineers sys.sp_cdc_enable_table commands from the data in
				the cdc meta data tables.

Parameters:
  - ObjectName:		Optional parameter for a single object. If NULL then all objects are returned

Output:			Outputs statements that can be used to create cdc on tables.
...
*/
BEGIN;
	/* Turn off row counting */
	SET NOCOUNT ON;

	/* Check the object supplied exists */
	IF OBJECT_ID(@ObjectName) IS NULL AND @ObjectName IS NOT NULL 
	BEGIN;
		DECLARE @ErrorMessage NVARCHAR(1000);
		SET @ErrorMessage = 'No object named ' + @ErrorMessage + ' found';

		THROW 50000, @ErrorMessage, 1;
		RETURN;
	END;

	/* Generate and display sys.sp_cdc_enable_table commands */
	WITH ReverseEngineerCDC AS (
		SELECT
			OBJECT_SCHEMA_NAME(ct.source_object_id)		AS source_schema
			,OBJECT_NAME(ct.source_object_id)              AS source_name
			,ct.supports_net_changes
			,ct.role_name
			,ct.index_name
			,STUFF((
				SELECT ', ' + QUOTENAME(cc.column_name)
				FROM cdc.captured_columns AS cc
				WHERE cc.object_id = ct.object_id
				ORDER BY cc.column_ordinal
				FOR XML PATH(''), TYPE
			).value('.', 'VARCHAR(MAX)'), 1, 2, '')
										AS captured_column_list
			,ct.[filegroup_name]
			,ct.partition_switch							AS allow_partition_switch
		FROM
			cdc.change_tables AS ct
		WHERE
			ct.source_object_id = OBJECT_ID(@ObjectName)
		OR	@ObjectName IS NULL
	)
	SELECT
		'EXEC sys.sp_cdc_enable_table
			@source_schema = ''' + source_schema + '''
			,@source_name = ''' + source_name + '''
			,@supports_net_changes = ' + LTRIM(STR(supports_net_changes)) + '
			,@role_name = ' + ISNULL('''' + role_name + '''', 'NULL') + '
			,@index_name = ''' + index_name + '''
			,@captured_column_list = ''' + captured_column_list + '''
			,@filegroup_name = ' + ISNULL('''' + filegroup_name + '''', 'NULL') + '
			,@allow_partition_switch = ' + LTRIM(STR(allow_partition_switch)) + '
	GO

	'
	FROM
		ReverseEngineerCDC
	ORDER BY
		source_schema
		,source_name;
END;
GO

EXEC sys.sp_MS_marksystemobject 'dbo.sp_cdc_reverse_engineer_enable_table'
GO