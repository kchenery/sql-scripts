CREATE PROCEDURE [dbo].[sp_trust_foreignkeys]
	@ObjectName NVARCHAR(300)
AS
/*
---
Description:    Finds foreign keys on @ObjectName that are not trusted and runs ALTER TABLE...WITH CHECK CHECK
				accoss them.

Parameters:
 - ObjectName:	Name of the table to act on

Output:
 - Informational messages about progress
...
*/
BEGIN;
	DECLARE @SQL            NVARCHAR(MAX);
	DECLARE @TableName      NVARCHAR(MAX);
	DECLARE @ForeignKeyName NVARCHAR(MAX);
	DECLARE @CurrentDate    NVARCHAR(23);

	DECLARE ForeignKeyFixes CURSOR LOCAL FAST_FORWARD
	FOR
	SELECT
		'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + QUOTENAME(OBJECT_NAME(parent_object_id)) + ' WITH CHECK CHECK CONSTRAINT ' + QUOTENAME(name)
		,QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + QUOTENAME(OBJECT_NAME(parent_object_id))
		,QUOTENAME(name)
	FROM
		sys.foreign_keys
	WHERE
		is_not_trusted = 1
	AND (
			parent_object_id = OBJECT_ID(@ObjectName)
		 OR @ObjectName IS NULL
		 )

	OPEN ForeignKeyFixes
	FETCH NEXT FROM ForeignKeyFixes INTO @SQL, @TableName, @ForeignKeyName

	WHILE @@FETCH_STATUS = 0
	BEGIN;

		SELECT @CurrentDate = CONVERT(NVARCHAR(30), SYSUTCDATETIME(), 121);
		BEGIN TRY;
			PRINT @CurrentDate + ' - Trusting: ' + @ForeignKeyName + ' on ' + @TableName

			EXEC sp_executesql @SQL
		END TRY
		BEGIN CATCH;
			PRINT 'Error was caught and suppressed';
		END CATCH;

		FETCH NEXT FROM ForeignKeyFixes INTO @SQL, @TableName, @ForeignKeyName
	END;

	CLOSE ForeignKeyFixes;
	DEALLOCATE ForeignKeyFixes;
END;