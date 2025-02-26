CREATE OR REPLACE PACKAGE ph_admin_search IS
/**
* Phone book administrator search
*/
--------------------------------------------------------------------------------------
-- Package Name: ph_admin_search
-- Author:       Fook Lee
-- Created:      15 Feb 2007
-- Modification History
--------------------------------------------------------------------------------------
--  23-03-2009   Tony Le          SAMS upgrade
--  21-09-2009   P.Totagiancaspro Added has_access
--------------------------------------------------------------------------------------
    -- navigational array
    empty_vc_arr owa.vc_arr;

FUNCTION get_nav_struct (p_location   VARCHAR2   DEFAULT NULL)
		 RETURN owa.vc_arr;
--------------------------------------------------------------------------------------
-- Name: get_nav_struct
-- Purpose: Gets the navigational structure
-- Pre:
-- Post: Navigational structure is returned
--------------------------------------------------------------------------------------

FUNCTION has_access
RETURN BOOLEAN;
------------------------------------------------------------------------------
-- Name:    has_access
-- Purpose: checks whether the user has access to view Phone book administrator search
-- Pre:     True
-- Post:    Returns true if use has access
------------------------------------------------------------------------------

PROCEDURE show (p_username      VARCHAR2  DEFAULT NULL
               ,p_email_alias   VARCHAR2  DEFAULT NULL
               ,p_surname       VARCHAR2  DEFAULT NULL
               ,p_first_name    VARCHAR2  DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    show
-- Purpose: Display the phone book administrator search
-- Pre:
-- Post:    Phone book administrator search functions displayed
--------------------------------------------------------------------------------------

PROCEDURE help;
--------------------------------------------------------------------------------------
-- Name:    help
-- Purpose: Displays help information
-- Pre:
-- Post:    Help information displayed
--------------------------------------------------------------------------------------

END ph_admin_search;
/


