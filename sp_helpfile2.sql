USE [master];
GO

IF NOT EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_helpfile2'))
BEGIN;
	EXEC('CREATE PROCEDURE sp_helpfile2 AS SELECT ''Procedure Stub''');
END;
GO

ALTER PROCEDURE sp_helpfile2
AS
/*
---
Description:    Returns information about database files in the current database

Parameters:		none

Output:
 - Similar information to sp_helpfile.  Extra columns such as amount of space in the file that is used.
...
*/
BEGIN
	/* Turn off row counting */
	SET NOCOUNT ON;

	/* Reture the data */
	SELECT
		file_id
		,type_desc															AS FileType
		,state_desc															AS FileState
		,name																AS LogicalName
		,CAST(size / 128.0 AS DECIMAL(10, 2))								AS SizeMB
		,CASE is_percent_growth
			WHEN 0 THEN CAST(CAST(growth / 128.0 AS DECIMAL(10, 2)) AS NVARCHAR(20)) + ' MB'
			WHEN 1 THEN CAST(growth AS NVARCHAR(20)) + ' %'
		END																	AS Growth
		,CAST(IIF(max_size < 0, NULL, max_size / 128.0) AS DECIMAL(10, 2))	AS MaxSizeMB
		,CAST(FILEPROPERTY(name, 'SpaceUsed') / 128.0 AS DECIMAL(10, 2))	AS UsedMB
		,CAST((CAST(FILEPROPERTY(name, 'SpaceUsed') / 128.0 AS DECIMAL(10, 2))) * 100 / CAST(size / 128.0 AS DECIMAL(10, 2)) AS DECIMAL(10, 2))	AS UsedPct
		,physical_name
		,is_read_only
		,is_media_read_only
		,is_sparse
	FROM
		sys.database_files
END;
GO

EXEC sys.sp_MS_marksystemobject 'sp_helpfile2'
GO