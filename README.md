sql-scripts
===========

SQL scripts.  Free to use, but you use at your own peril.

The procedures can be installed by deploying the Master.DB.Extensions project.  It is recommended you deploy with the publish profile.

| Script or Procedure | Description |
|:--------|:-------------|
| [CDC - Add new columns to CDC capture.sql](Change%20Data%20Capture/CDC%20-%20Add%20new%20columns%20to%20CDC%20capture.sql) | Script to allow objects participating in change data capture (CDC) to have the new columns added to CDC. |
| [sp_foreignkeys2](Master.DB.Extensions/Master.DB.Extensions/dbo/Procedures/sp_foreignkeys2.sql) | Reports foreign key information about the supplied table.  A little bit easier to read/consume than the sp_help output IMHO |
| [sp_helpfile2](Master.DB.Extensions/Master.DB.Extensions/dbo/Procedures/sp_helpfile2.sql) | Alternative to sp_helpfile.  Adds size information to the output |
| [sp_helpindex2](Master.DB.Extensions/Master.DB.Extensions/dbo/Procedures/sp_helpindex2.sql) | Alternative to sp_helpindex.  Provides the include columns in the output and index usage statistics |
| [sp_useroptions](Master.DB.Extensions/Master.DB.Extensions/dbo/Procedures/sp_useroptions.sql) | Decodes the @@options values into a table |
