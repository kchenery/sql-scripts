USE [master]
GO

IF NOT EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_helpindex2'))
BEGIN;
    EXEC('CREATE PROCEDURE sp_helpindex2 AS SELECT ''ProcedureStub'' AS Stub;');
END;
GO

ALTER PROCEDURE sp_helpindex2
    @ObjectName NVARCHAR(128)
AS
/*
---
Description:    Returns information about indexing of an object.  Similar to sp_helpindex but with
                extra information about the include list and any filters on the index.

Parameters:
 - ObjectName:  Name of the object you want index information about.

Output:
 - Similar information to sp_helpindex.  Extra columns are Include list and any filter information.
...
*/
BEGIN;
    /* No row counting */
    SET NOCOUNT ON;

    /* Return index info */
    SELECT
        i.name                      AS IndexName
        ,STUFF(
			  CASE WHEN i.is_disabled = 1 THEN ', disabled' ELSE '' END
			+ CASE WHEN i.index_id = 1 THEN ', clustered' WHEN i.index_id <= 254 THEN ', non-clustered' ELSE '' END
			+ CASE WHEN i.is_unique = 1 THEN ', unique' ELSE '' END
			+ CASE WHEN i.is_primary_key = 1 THEN ', primary key' ELSE '' END
			+ CASE WHEN i.is_unique_constraint = 1 THEN ', unique constraint' ELSE '' END
			+ CASE WHEN i.is_padded = 1 THEN ', padded' ELSE '' END
			+ CASE WHEN i.filter_definition IS NOT NULL THEN ', filtered' ELSE '' END
			+ CASE WHEN i.type IN (5, 6) THEN ', column store' ELSE '' END
			+ CASE WHEN i.is_hypothetical = 1 THEN ', hypothetical' ELSE '' END
			+ CASE WHEN s.auto_created = 1 AND i.type NOT IN (5, 6) THEN ', auto created' ELSE '' END
			+ CASE WHEN s.no_recompute = 1 AND i.type NOT IN (5, 6) THEN ', no recompute' ELSE '' END
			+ CASE WHEN p.data_compression = 1 THEN ', compressed (row)' ELSE '' END
			+ CASE WHEN p.data_compression = 2 THEN ', compressed (page)' ELSE '' END
			+ ' located on ' + ds.name
			, 1, 2, '')                 AS [Description]
        ,ColumnList.KeyColumns      AS KeyColumns
        ,IncludeList.IncludeColumns AS IncludeColumns
        ,i.filter_definition        AS Filter
        ,i.fill_factor              AS [FillFactor]
		,stat.user_seeks			AS [UserSeeks]
		,stat.user_scans			AS [UserScans]
		,stat.user_lookups			AS [UserLookups]
		,stat.user_updates			AS [UserUpdates]
		,stat.last_user_seek		AS [LastUserSeek]
		,stat.last_user_scan		AS [LastUserScan]
		,stat.last_user_lookup		AS [LastUserLookup]
		,stat.last_user_update		AS [LastUserUpdate]
    FROM
        sys.indexes AS i
        INNER JOIN sys.stats AS s
            ON i.object_id = s.object_id
            AND i.index_id = s.stats_id
        INNER JOIN sys.data_spaces AS ds
            ON i.data_space_id = ds.data_space_id
		LEFT OUTER JOIN sys.partitions AS p			/* Needs to be OUTER JOIN as disabled indexes have no reference here */
			ON i.object_id = p.object_id
			AND i.index_id = p.index_id
        CROSS APPLY (
            SELECT (
                STUFF(( SELECT ', ' + c.name
                        FROM sys.index_columns AS ic
                        INNER JOIN sys.columns AS c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                        WHERE ic.object_id = i.object_id
                        AND ic.index_id = i.index_id
                        AND ic.is_included_column = 0
                        ORDER BY ic.key_ordinal
                        FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)')
                        ,1, 2, '')
                ) KeyColumns
            ) ColumnList
        CROSS APPLY (
            SELECT (
                STUFF(( SELECT ', ' + c.name
                        FROM sys.index_columns AS ic
                        INNER JOIN sys.columns AS c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                        WHERE ic.object_id = i.object_id
                        AND ic.index_id = i.index_id
                        AND ic.is_included_column = 1
                        ORDER BY ic.key_ordinal
                        FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)')
                        ,1, 2, '')
                ) IncludeColumns
            ) IncludeList
		LEFT OUTER JOIN sys.dm_db_index_usage_stats as stat
			ON stat.database_id = DB_ID()
			AND stat.object_id = i.object_id
			AND stat.index_id = i.index_id
    WHERE
        i.object_id = OBJECT_ID(@ObjectName)
    ;

END;
GO

EXEC sys.sp_MS_marksystemobject 'sp_helpindex2'
GO