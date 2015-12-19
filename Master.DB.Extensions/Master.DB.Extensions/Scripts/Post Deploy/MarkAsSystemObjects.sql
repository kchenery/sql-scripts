IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_helpindex2'))
BEGIN;
    EXEC sys.sp_MS_marksystemobject 'dbo.sp_helpindex2'
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_helpfile2'))
BEGIN;
    EXEC sys.sp_MS_marksystemobject 'dbo.sp_helpfile2'
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_useroptions'))
BEGIN;
    EXEC sys.sp_MS_marksystemobject 'dbo.sp_useroptions'
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_foreignkeys2'))
BEGIN;
    EXEC sys.sp_MS_marksystemobject 'dbo.sp_foreignkeys2'
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_cdc_estimate_space'))
BEGIN;
    EXEC sys.sp_MS_marksystemobject 'dbo.sp_cdc_estimate_space'
END;
GO