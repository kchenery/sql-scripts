IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_helpindex2'))
BEGIN;
    DROP PROCEDURE dbo.sp_helpindex2;
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_helpfile2'))
BEGIN;
    DROP PROCEDURE dbo.sp_helpfile2;
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_useroptions'))
BEGIN;
    DROP PROCEDURE dbo.sp_useroptions;
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_foreignkeys2'))
BEGIN;
    DROP PROCEDURE dbo.sp_foreignkeys2;
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_cdc_estimate_space'))
BEGIN;
    DROP PROCEDURE dbo.sp_cdc_estimate_space;
END;
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('dbo.sp_trust_foreignkeys'))
BEGIN;
    DROP PROCEDURE dbo.sp_trust_foreignkeys;
END;
GO