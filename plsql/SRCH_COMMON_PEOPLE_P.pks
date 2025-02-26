create or replace
PACKAGE srch_common_people_p 
/**
* Display list of employee and contact details
* @author Sophie Jeong
* @version 1.0.0
*/
IS
----------------------------------------------------------------------
--  Specification Modification History
--  Date         Author           Description
--  -----------  ------------------------------------------------------
--  03-SEP-2002  S Jeong          Created
--  18-JUL-2006   S.Jeong         10g Upgrade Modification
--                                Unused procedures and functions removed.
--  29-JUL-2009   D.Jack          SAMS Upgrade
--  08-11-2010   Tony Le         Add new procedure to process JP search on advanced staff search page
----------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
	-- variable argument array
    empty_vc_arr owa.vc_arr;

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------

--NIL

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------

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

PROCEDURE process_jp_form (p_arg_names             IN owa.vc_arr DEFAULT empty_vc_arr
                          ,p_arg_values            IN owa.vc_arr DEFAULT empty_vc_arr
                          ,p_campus                IN VARCHAR2 DEFAULT NULL
                          ,p_attribute_value       IN VARCHAR2 DEFAULT NULL
                          ,p_attribute_type        IN VARCHAR2 DEFAULT NULL
                          ,p_searchby_ppl          IN VARCHAR2 DEFAULT NULL
                          ,p_print_ind             IN VARCHAR2 DEFAULT NULL);
----------------------------------------------------------------------
--  Name:    process_jp_form
--  Purpose: Populate array with parameter name and value pairs and
--           call business logic to process search
--  Pre:
--  Post:    Parameter array has been populated
----------------------------------------------------------------------

END  srch_common_people_p;
