create or replace
PACKAGE srch_stu_people_p 
/**
* Control access to people search results
* @version 1.0.0
*/
IS
----------------------------------------------------------------------
--  Specification Modification History
--  Date         Author           Description
--  -----------  ------------------------------------------------------
--  03-SEP-2002  S Jeong          Created
--  18-JUL-2006  S.Jeong          10g Upgrade Modification
--                                Unused procedures and functions removed.
--  18-NOV-2008  C.Wong           Removed unused global variable g_ccr_ind
--  29-Jul-2009  D.Jack           SAMS Upgrade
--  03-Mar-2010  Tony Le          Bring new staff UI across
--  08-Nov-2010  Tony Le          Add more parameters for JP search to process_advance_form
----------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
	-- variable argument array
    empty_vc_arr owa.vc_arr;

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------
-- NIL

PROCEDURE process_surname_form
(
    p_arg_names       IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values      IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_surname  		    IN VARCHAR2 	DEFAULT NULL
   ,p_surname_submit  IN VARCHAR2	  DEFAULT NULL
);
----------------------------------------------------------------------
--  Name:    process_surname_form
--  Purpose: Populate array with incoming parameters and
--           call business logic to process search
--  Pre:     True
--  Post:    Parameter array has been populated
----------------------------------------------------------------------

PROCEDURE process_advanced_form
(
    p_arg_names       IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values      IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_first_name      IN VARCHAR2    DEFAULT NULL
   ,p_surname		  IN VARCHAR2    DEFAULT NULL
   ,p_search_type     IN VARCHAR2    DEFAULT NULL
   ,p_org_unit_code	  IN VARCHAR2    DEFAULT NULL
   ,p_advanced_submit IN VARCHAR2	 DEFAULT NULL
   ,p_campus          IN VARCHAR2    DEFAULT NULL
   ,p_attribute_value IN VARCHAR2    DEFAULT NULL
   ,p_attribute_type  IN VARCHAR2    DEFAULT NULL
   ,p_searchby_ppl    IN VARCHAR2    DEFAULT NULL
);
----------------------------------------------------------------------
--  Name:    process_advanced_form
--  Purpose: Populate array with incoming parameters and
--           call business logic to process search
--  Pre:     True
--  Post:    Parameter array has been populated
----------------------------------------------------------------------

PROCEDURE show
(
     p_arg_names 	  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	  IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--  Name.    show
--  Purpose: Control display of search results
--  Pre:     @p_arg_names and @p_arg_values contains @p_show_mode
--			 and @p_from
--  Post:    Results of search has been displayed
----------------------------------------------------------------------

END  srch_stu_people_p;
