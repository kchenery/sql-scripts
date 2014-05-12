/*
---
Description:    This code loops over the CDC meta data adding in any missing columns to CDC capture instance tables 
                and the CDC meta data.  It then updates the stored procedures use to capture data out of the
                transaction log into the capture instance table.  It does this procedure change in what can only
                be described as "gnarly".  It actually creates a new instance of CDC on the source table and copies
                the procedure code from that new instance to the old one.  It then drops the temp instance.  As
                such there are a few assumptions made by this code:

                  - Only one CDC capture instance is permitted on a table under normal operations
                  - Columns are added to the end of the table
                  - All columns are captured by CDC
                  - Probably some others I have missed too!
...
*/

/* "Parameters" */
DECLARE @Tibble                 NVARCHAR(30) = '$tmp$';     /* Temp cdc capture instance name prepended to the original capture instance name */

/* Variables */
DECLARE @ObjectID               INT;                        /* Object ID of the table in CDC */
DECLARE @MaxColumnID            INT;                        /* Max column_id being captured currently */
DECLARE @ErrorMessage           NVARCHAR(MAX);              /* Error message holder */
DECLARE @SchemaName             NVARCHAR(128);              /* Schema name of the object under CDC */
DECLARE @ObjectName             NVARCHAR(128);              /* Object name of the object under CDC */
DECLARE @CaptureInstance        NVARCHAR(128);              /* Capture instance name */
DECLARE @TmpCaptureInstance     NVARCHAR(128);              /* Temp capture instance name.  Its @Tibble + @CaptureInstance */
DECLARE @ColumnName             NVARCHAR(128);              /* Name of a column we're adding */
DECLARE @ColumnID               INT;                        /* Column ID of a column we're adding */
DECLARE @ColumnDataType         NVARCHAR(128);              /* The column data type with length where appropriate (in the form NVARCHAR(30) for example) */
DECLARE @ColumnTypeName         NVARCHAR(128);              /* The column data type (e.g. nvarchar) */
DECLARE @SQL                    NVARCHAR(MAX);              /* Holder to run dynamic SQL - yep we have that too */
DECLARE @ColumnOrdinal          INT;                        /* Ordinal value for the colummn in the CDC capture instance table */
DECLARE @IsComputed             BIT;                        /* Flag to show if the column is a computed column */
DECLARE @OriginalCDCObjectID    INT;                        /* Object ID for the original CDC capture instance */
DECLARE @NewCDCObjectID         INT;                        /* Object ID for the temp CDC capture instance we create, then destroy later */

/*
 * WARNING: Cursors are everywhere in this code!  Its nasty, but its a necessary nasty.
 */

/* Is CDC in use? */
IF EXISTS(SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('cdc.change_tables'))
BEGIN;

    /* Drop the "tmp" CDC objects. Maybe we left some over from last time.  This is just a precaution step. */
    DECLARE TmpCDCObjects CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            OBJECT_SCHEMA_NAME(source_object_id)
            ,OBJECT_NAME(source_object_id)
            ,capture_instance
        FROM
            cdc.change_tables
        WHERE
            capture_instance LIKE @Tibble + '%';

    OPEN TmpCDCObjects;
    FETCH NEXT FROM TmpCDCObjects INTO @SchemaName, @ObjectName, @CaptureInstance;

    WHILE (@@FETCH_STATUS = 0)
    BEGIN;

        /* Remove the CDC capture instance */
        EXEC sys.sp_cdc_disable_table @source_schema = @SchemaName, @source_name = @ObjectName, @capture_instance = @CaptureInstance;

        FETCH NEXT FROM TmpCDCObjects INTO @SchemaName, @ObjectName, @CaptureInstance;
    END;

    CLOSE TmpCDCObjects;    /* Close, but do not deallocate as we will use this cursor again later */



    /* Are there any objects with more than 1 capture instance in play.  If there are we cannot use this approach. */
    IF EXISTS(SELECT source_object_id, COUNT(*) FROM cdc.change_tables GROUP BY source_object_id HAVING COUNT(*) > 1)
    BEGIN;
        DEALLOCATE TmpCDCObjects;    /* Better deallocate since we're about to throw an error */

        SELECT @ErrorMessage = 'Unable to update CDC as there are objects with more than one capture instance in use. You must update CDC manually';
        THROW 50000, @ErrorMEssage, 1;
    END;    

    /* Loop over all the CDC tables that do not have the latest columns */
    DECLARE CDCObjects CURSOR LOCAL FAST_FORWARD FOR
        SELECT
             ct.object_id
             ,ct.source_object_id
             ,MAX(cc.column_id)        AS MaxCapturedColumnID
        FROM
            cdc.captured_columns AS cc
            INNER JOIN cdc.change_tables AS ct
                ON cc.object_id = ct.object_id
        GROUP BY
            ct.source_object_id
            ,ct.object_id
        HAVING
            MAX(cc.column_id) < (SELECT MAX(column_id) FROM sys.columns AS c WHERE c.object_id = ct.source_object_id)
        ;

    OPEN CDCObjects;
    FETCH NEXT FROM CDCObjects INTO @OriginalCDCObjectID, @ObjectID, @MaxColumnID;

    WHILE (@@FETCH_STATUS = 0)
    BEGIN;

        /* Get some names */
        SELECT
            @SchemaName = OBJECT_SCHEMA_NAME(@ObjectID)
            ,@ObjectName = OBJECT_NAME(@ObjectID)
            ,@CaptureInstance = (SELECT TOP 1 capture_instance FROM cdc.change_tables WHERE source_object_id = @ObjectID ORDER BY create_date);

        SELECT @TmpCaptureInstance = @Tibble + '_' + @CaptureInstance

        /* Add a new CDC capture instance to the object with the temp name */
        EXEC sys.sp_cdc_enable_table @source_schema = @SchemaName, @source_name = @ObjectName, @capture_instance = @TmpCaptureInstance, @role_name = NULL;

        /* Add the new columns to CDC table */
        DECLARE cColumns CURSOR LOCAL FAST_FORWARD FOR
        WITH LastColumn AS (
            /* Get the max column id for the table that we have cdc on */
            SELECT
                ct.source_object_id
                ,MAX(column_id)            AS MaxColumnID
            FROM
                cdc.captured_columns AS cc
                INNER JOIN cdc.change_tables AS ct
                    ON cc.object_id = ct.object_id
            WHERE
                cc.object_id = @OriginalCDCObjectID
            GROUP BY
                ct.source_object_id

        )
        SELECT
            c.name
            ,c.column_id
            ,CASE
                WHEN t.name IN ('datetime2', 'varchar', 'char', 'binary', 'varbinary', 'float') THEN t.name + '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS NVARCHAR(20)) END + ')'
                WHEN t.name IN ('nchar', 'nvarchar') THEN t.name + '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS NVARCHAR(20)) END  + ')'
                WHEN t.name IN ('decimal', 'numeric') THEN t.name+ '(' + CAST(c.scale AS NVARCHAR(20)) + ', ' + CAST(c.precision AS NVARCHAR(20)) + ')'
                ELSE t.name
            END AS DataType
            ,t.name    AS TypeName
            ,c.is_computed
        FROM
            sys.columns AS c
            INNER JOIN LastColumn AS lc
                ON c.object_id = lc.source_object_id
            INNER JOIN sys.types AS t
                ON c.user_type_id = t.user_type_id
        WHERE
            c.column_id > lc.MaxColumnID;

        OPEN cColumns;
        FETCH NEXT FROM cColumns INTO @ColumnName, @ColumnID, @ColumnDataType, @ColumnTypeName, @IsComputed;

        /* Find the max column ordinal */
        SELECT @ColumnOrdinal = MAX(column_ordinal)
        FROM
            cdc.captured_columns
        WHERE
            [object_id] = @OriginalCDCObjectID;

        WHILE @@FETCH_STATUS = 0
        BEGIN;

            SELECT @ColumnOrdinal += 1;    /* Increment the column ordinal */
            
            SELECT @CaptureInstance, @ColumnName, @ColumnDataType, @ColumnOrdinal

            SELECT @SQL = 'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(@OriginalCDCObjectID)) + '.' + QUOTENAME(OBJECT_NAME(@OriginalCDCObjectID)) + ' ADD [' + @ColumnName + '] ' + @ColumnDataType + ' NULL';
            PRINT @SQL;
            EXEC(@SQL);

            /* Update the meta data in cdc.captured_colums */
            INSERT INTO cdc.captured_columns([object_id], column_name, column_id, column_type, column_ordinal, is_computed)
            VALUES(@OriginalCDCObjectID, @ColumnName, @ColumnID, @ColumnTypeName, @ColumnOrdinal, @IsComputed);
            
            FETCH NEXT FROM cColumns INTO @ColumnName, @ColumnID, @ColumnDataType, @ColumnTypeName, @IsComputed
        END;

        /* Find the new ID of the cdc object we just created */
        SELECT
            @NewCDCObjectID = [object_id]
        FROM
            cdc.change_tables 
        WHERE
            source_object_id = @ObjectID 
        AND object_id != @OriginalCDCObjectID

        /* batch insert proc */
        SELECT @SQL = STUFF(OBJECT_DEFINITION(OBJECT_ID('cdc.sp_batchinsert_' + CAST(@NewCDCObjectID AS NVARCHAR(20)))), 1, 6, 'alter');
        SELECT @SQL = REPLACE(@SQL, CAST(@NewCDCObjectID AS NVARCHAR(20)), CAST(@OriginalCDCObjectID AS NVARCHAR(20)));
        SELECT @SQL = REPLACE(@SQL, @TmpCaptureInstance, @CaptureInstance);
        EXEC(@SQL);

        /* insdel insert proc */
        SELECT @SQL = STUFF(OBJECT_DEFINITION(OBJECT_ID('cdc.sp_insdel_' + CAST(@NewCDCObjectID AS NVARCHAR(20)))), 1, 6, 'alter');
        SELECT @SQL = REPLACE(@SQL, CAST(@NewCDCObjectID AS NVARCHAR(20)), CAST(@OriginalCDCObjectID AS NVARCHAR(20)));
        SELECT @SQL = REPLACE(@SQL, @TmpCaptureInstance, @CaptureInstance);
        EXEC(@SQL);

        /* upd insert proc */
        SELECT @SQL = STUFF(OBJECT_DEFINITION(OBJECT_ID('cdc.sp_upd_' + CAST(@NewCDCObjectID AS NVARCHAR(20)))), 1, 6, 'alter');
        SELECT @SQL = REPLACE(@SQL, CAST(@NewCDCObjectID AS NVARCHAR(20)), CAST(@OriginalCDCObjectID AS NVARCHAR(20)));
        SELECT @SQL = REPLACE(@SQL, @TmpCaptureInstance, @CaptureInstance);
        EXEC(@SQL);

        /* Get the next CDC object to modify */
        FETCH NEXT FROM CDCObjects INTO @OriginalCDCObjectID, @ObjectID, @MaxColumnID;
    END;


    /* Drop the "tmp" CDC objects. Use the previously declared cursor */
    OPEN TmpCDCObjects;
    FETCH NEXT FROM TmpCDCObjects INTO @SchemaName, @ObjectName, @CaptureInstance;

    WHILE (@@FETCH_STATUS = 0)
    BEGIN;

        /* Remove the CDC capture instance */
        EXEC sys.sp_cdc_disable_table @source_schema = @SchemaName, @source_name = @ObjectName, @capture_instance = @TmpCaptureInstance;

        FETCH NEXT FROM TmpCDCObjects INTO @SchemaName, @ObjectName, @CaptureInstance;
    END;

    CLOSE TmpCDCObjects;
    DEALLOCATE TmpCDCObjects;
END;
