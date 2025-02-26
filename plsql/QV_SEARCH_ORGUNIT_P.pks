CREATE OR REPLACE PACKAGE qv_search_orgunit_p IS
/**
* Used to call package qv_search_orgunit to display organisational hierarchy
* structure and their staff members details and contact informations.
* @version 1.0.0
*/
----------------------------------------------------------------------
--  Specification Modification History
--  Date         Author      Description
--  -----------  ------------------------------------------------------
--  19 Aug.2002  Lin Lin     Developed
--  19-JUL-2006  S.Jeong     10g Upgrade Modification
--                           Unused procedures and functions removed.
--  29-Jul-2009  D.Jack      SAMS Upgrade
--  13-Sep-2017  Tony Le     QVSEARCH-90: Application refactory. Removed any unused procedures,
--                           added logging for tracking purposes
----------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
	-- variable argument array
    empty_vc_arr owa.vc_arr;

PROCEDURE process_submit
(
     p_name  		   IN VARCHAR2 		DEFAULT NULL
    ,p_show_mode	   IN VARCHAR2		DEFAULT NULL
);
----------------------------------------------------------------------
--  Name. 	 process_submit
--  Purpose: define array values from data selected by user through web browser
--  Pre:	 True
--  Post:	 an array values defined
----------------------------------------------------------------------


PROCEDURE show
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
);

----------------------------------------------------------------------
--  Name. show
--  Purpose:  Contains all logic for the package.
--  Pre:
--  Post:
----------------------------------------------------------------------
PROCEDURE help
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--  Name: help
--  Purpose:  For use when a help full-screen portlet is required
--  Pre:
--  Post:
----------------------------------------------------------------------

END  qv_search_orgunit_p;
/
