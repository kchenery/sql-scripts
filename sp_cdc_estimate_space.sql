USE [master]
GO

IF NOT EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_cdc_estimate_space'))
BEGIN;
    EXEC('CREATE PROCEDURE sp_cdc_estimate_space AS SELECT ''ProcedureStub'' AS Stub;');
END;
GO

ALTER PROCEDURE sp_cdc_estimate_space
    @TableName		NVARCHAR(128)
    ,@SampleTime	INT	= 300	/* Default = 5 mins */
AS
/*
---
Description:    Uses index stats information to calculate space requirements for CDC.
                The proc runs for the @SampleTime number of seconds and uses that plus
                average row size to calculate requirements per hour and per day.

Parameters:
 - TableName:   Name of the object you want to create CDC against
 - SampleTime:  Number of seconds to sample - longer = more accurate.  Default = 5mins

Output:
 - NumOfUpdates:    Number of updates that occurred against @TableName in the @SampleTime period
 - AvgRowSizeMB:    Average row size in MB
 - EstMBPerHour:    Estimated MB required for an hour of CDC
 - EstMBPerDay:     Estimated MB required for a day of CDC
...
*/
BEGIN;
    DECLARE @Update1	    INT;
    DECLARE @Update2	    INT;
    DECLARE @Time		    NVARCHAR(100);
    DECLARE @AvgRowSize	    NUMERIC(20, 10);
    DECLARE @ErrorMessage   NVARCHAR(1000);

    IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(@TableName))
    BEGIN;
        SET @ErrorMessage = 'Unable to locate ' + @TableName;
        THROW 50000, @ErrorMessage, 1;

        RETURN;
    END;

    SELECT @Time = 
        RIGHT('00' + CAST(@SampleTime / (60 * 60)											AS NVARCHAR(100)), 2)
        + ':' + RIGHT('00' + CAST((@SampleTime / (60)) - ((@SampleTime / (60 * 60)) * 60)	AS NVARCHAR(100)), 2)
        + ':' + RIGHT('00' + CAST(@SampleTime - ((@SampleTime / (60)) * 60)					AS NVARCHAR(100)), 2)
        ;

    SELECT
        @Update1 = isnull(user_updates, 0)
    FROM
        sys.dm_db_index_usage_stats
    WHERE
        database_id = db_id()
    AND	object_id = OBJECT_ID(@TableName)
    AND	index_id IN (0, 1);

    WAITFOR DELAY @Time;

    SELECT
        @Update2 = isnull(user_updates, 0)
    FROM
        sys.dm_db_index_usage_stats
    WHERE
        database_id = db_id()
    AND	object_id = OBJECT_ID(@TableName)
    AND	index_id IN (0, 1);

    SELECT @AvgRowSize = CAST((SUM(
            CASE
                WHEN (pt.index_id < 2) THEN (pt.in_row_data_page_count + pt.lob_used_page_count + pt.row_overflow_used_page_count)
                ELSE pt.lob_used_page_count + pt.row_overflow_used_page_count
            END
            ) * 8 / 1024.0) AS NUMERIC(20, 10))
        / MAX(pt.row_count)
    FROM
        sys.dm_db_partition_stats AS pt
    WHERE
        object_id = OBJECT_ID(@TableName)
    ;


    SELECT 
        @Time																AS SampleTime
		,@Update2 - @Update1												AS NumOfUpdates
        ,@AvgRowSize														AS AvgRowSizeMB
        ,CAST(@AvgRowSize * (@Update2 - @Update1) * (3600 / @SampleTime) AS NUMERIC(20, 2))			AS EstMBPerHour
		,CAST(24 * @AvgRowSize * (@Update2 - @Update1) * (3600 / @SampleTime) AS NUMERIC(20, 2))	AS EstMBPerDay

END;
GO

EXEC sys.sp_MS_marksystemobject 'sp_cdc_estimate_space'
GO