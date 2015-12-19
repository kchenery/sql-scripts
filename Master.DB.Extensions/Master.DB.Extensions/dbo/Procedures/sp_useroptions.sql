CREATE PROCEDURE [dbo].[sp_useroptions]
AS
/*
---
Description:    Decodes the @@options values according to http://technet.microsoft.com/en-us/library/ms177525.aspx

Parameters:
 - None

Output:
 - Single row that decodes the @@option values into flags for each option that can be set
...
*/
BEGIN;
	SELECT
		(@@OPTIONS & 1) / 1				AS DISABLE_DEF_CNST_CHK
		,(@@OPTIONS & 2) / 2			AS IMPLICIT_TRANSACTIONS
		,(@@OPTIONS & 4) / 4			AS CURSOR_CLOSE_ON_COMMIT
		,(@@OPTIONS & 8) / 8			AS ANSI_WARNINGS
		,(@@OPTIONS & 16) / 16			AS ANSI_PADDING
		,(@@OPTIONS & 32) / 32			AS ANSI_NULLS
		,(@@OPTIONS & 64) / 64			AS ARITHABORT
		,(@@OPTIONS & 128) / 128		AS ARITHIGNORE
		,(@@OPTIONS & 256) / 256		AS QUOTED_IDENTIFIER
		,(@@OPTIONS & 512) / 512		AS NOCOUNT
		,(@@OPTIONS & 1024) / 1024		AS ANSI_NULL_DFLT_ON
		,(@@OPTIONS & 2048) / 2048		AS ANSI_NULL_DFLT_OFF
		,(@@OPTIONS & 4096) / 4096		AS CONCAT_NULL_YIELDS_NULL
		,(@@OPTIONS & 8192) / 8192		AS NUMERIC_ROUNDABORT
		,(@@OPTIONS & 16384) / 16384	AS XACT_ABORT
END;
GO