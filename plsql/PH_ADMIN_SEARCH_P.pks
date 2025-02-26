CREATE OR REPLACE PACKAGE ph_admin_search_p IS
/**
* Phone book administrator search
*/
----------------------------------------------------------------------
--  Package Name: ph_admin_search_p
--  Author:		  Fook Lee
--  Created:      15 Feb 2007
--
--  Specification Modification History
--  Date         Author           Description
--  -----------  ------------------------------------------------------
--  23-03-2009   Tony Le          SAMS upgrade
--
----------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
-- NIL
--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------
	-- variable argument array
    empty_vc_arr owa.vc_arr;
--------------------------------------------
--            GLOBAL TYPE DEFINITIONS
--------------------------------------------
-- NIL
--------------------------------------------
--            GLOBAL EXCEPTIONS
--------------------------------------------
-- NIL
--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
-- NIL
--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE show
(
    p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--  Name.    show
--  Purpose: Contains access permitted check and is the entry point for accessing
--			 local functions and procedures.
--  Pre:	 True
--  Post:	 Access permitted AND access to local functions and procedures allowed
--			 OR access not permitted AND access not permitted message displayed
----------------------------------------------------------------------

PROCEDURE process_pba_search (p_username    IN VARCHAR2 DEFAULT NULL
                             ,p_email_alias IN VARCHAR2 DEFAULT NULL
                             ,p_surname     IN VARCHAR2 DEFAULT NULL
                             ,p_first_name  IN VARCHAR2 DEFAULT NULL
	                         ,p_arg_names   IN owa.vc_arr DEFAULT empty_vc_arr
                             ,p_arg_values  IN owa.vc_arr DEFAULT empty_vc_arr);
----------------------------------------------------------------------
--  Name.     process_pba_search
--  Purpose:  Processes the phone book administrator search
--  Pre:      p_username is declared
--  Post:     Phone book administrator is searched
----------------------------------------------------------------------

PROCEDURE help
(
    p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--  Name:    help
--  Purpose: Display help page
--  Pre:	 True
--  Post:	 Help page displayed
----------------------------------------------------------------------

PROCEDURE print
(
    p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--	Name:    print
--  Purpose: Display print page
--  Pre:	 True
--  Post:	 Print page displayed
----------------------------------------------------------------------

END ph_admin_search_p;
/


