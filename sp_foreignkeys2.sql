USE [master]
GO

IF NOT EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_foreignkeys2'))
BEGIN;
	EXEC('CREATE PROCEDURE sp_foreignkeys2 AS SELECT ''ProcedureStub'' AS Stub;');
END;
GO

ALTER PROCEDURE sp_foreignkeys2
@ObjectName	NVARCHAR(300) = NULL
AS
/*
---
Description:    Returns information about foreign key relationships.

Parameters:
 - ObjectName:  Name of the object you want foreign key details of.  Omitting this value
				will return data for all foreign keys in the database.

Output:
 - Similar information to sp_helpindex.  Extra columns are Include list and any filter information.
...
*/
BEGIN;
	SET NOCOUNT ON;

	SELECT
		OBJECT_SCHEMA_NAME(fk.parent_object_id)		AS ChildSchema
		,OBJECT_NAME(fk.parent_object_id)			AS ChildObject
		,fk.name									AS ForeignKey
		,(SELECT(
			STUFF((	SELECT ', ' + c.name
					FROM
						sys.foreign_key_columns AS fkc
						INNER JOIN sys.columns AS c	ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
					WHERE
						fkc.constraint_object_id = fk.object_id
					ORDER BY
						fkc.constraint_column_id
					FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)')
					,1 ,2, '')
					)
				) AS ChildColumns
		,'References'									AS Direction
		,OBJECT_SCHEMA_NAME(fk.referenced_object_id)	AS ParentSchemaName
		,OBJECT_NAME(fk.referenced_object_id)			AS ParentObjectName
		,(SELECT(
			STUFF((	SELECT ', ' + c.name
					FROM
						sys.foreign_key_columns AS fkc
						INNER JOIN sys.columns AS c	ON fkc.referenced_object_id = c.object_id AND fkc.referenced_column_id = c.column_id
					WHERE
						fkc.constraint_object_id = fk.object_id
					ORDER BY
						fkc.constraint_column_id
					FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)')
					,1 ,2, '')
					)
				) AS ParentColumns
		,fk.is_disabled			AS IsDisabled
		,fk.is_not_trusted		AS IsNotTrusted
		,fk.delete_referential_action_desc	AS OnDeleteAction
		,fk.update_referential_action_desc	AS OnUpdateAction
	FROM
		sys.foreign_keys AS fk
	WHERE
		fk.parent_object_id = OBJECT_ID(@ObjectName)
	OR	fk.referenced_object_id = OBJECT_ID(@ObjectName)
	OR	@ObjectName IS NULL	/* Show all if no object is specified */
	ORDER BY
		OBJECT_SCHEMA_NAME(fk.parent_object_id)
		,OBJECT_NAME(fk.parent_object_id)
		,fk.name
	;
END;
GO

EXEC sys.sp_MS_marksystemobject 'sp_foreignkeys2'
GO