--------------------------------------------------------------------------
-- Program name: ph_migrate_data.sql
-- Author:      Tony Le
-- Created:     8 May 2009
-- Modify:      Tony Le
-- Purpose:     Query to populate data for Phone Book application
--------------------------------------------------------------------------

INSERT INTO qv_closed_user_group_wk SELECT * FROM qv_closed_user_group_wk@oldqv;

COMMIT;

/
