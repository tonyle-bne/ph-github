create or replace
PACKAGE srch_common_people 
/**
* Display list of employee and contact details
* @author Sophie Jeong
* @version 1.0.0
*/
IS
----------------------------------------------------------------------
--  Specification Modification History
--  Date         Author            Description
--  -----------  ----------------  ------------------------------------
--  04-SEP-2002	 S Jeong           Created
--  23_SEP-2002  S Jeong           Campus inserted into contact details
--				   			       Reference to removed to when calling qv_search_orgunit_p.show
--  27-SEP-2002  S Jeong           Parameter value for [qv_search_orgunit_p.show] modified
--  06-Aug-2007  C Wong            IAM Upgrade
--  24-Oct-2008  P.Totagiancaspro  Reverse IAM changes.
--  29-Jul-2009  D.Jack            SAMS Upgrade
--  08-11-2010   Tony Le           Add new procedure to display JP list as a result of JP search
----------------------------------------------------------------------

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
    C_VCARD              CONSTANT VARCHAR2(100) := 'vCard';
--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
--
--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE show_emp_list
(
    p_first_name    IN VARCHAR2    DEFAULT NULL
   ,p_surname		IN VARCHAR2    DEFAULT NULL
   ,p_org_unit_code	IN VARCHAR2    DEFAULT NULL
   ,p_search_type   IN VARCHAR2    DEFAULT NULL
   ,p_from		    IN VARCHAR2    DEFAULT NULL
   ,p_arg_names  IN owa.vc_arr DEFAULT srch_stu_people_p.empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT srch_stu_people_p.empty_vc_arr
);
----------------------------------------------------------------------
--	Name.    show_emp_list
--  Purpose: Display list of employee with name and position description.
--           Link provides detailed description of each employee.
--  Pre:
--  Post:    List of employee is displayed. Each link lead to contact
--			 details.
----------------------------------------------------------------------

PROCEDURE show_jp_list (p_arg_names  IN owa.vc_arr DEFAULT srch_stu_people_p.empty_vc_arr
                       ,p_arg_values IN owa.vc_arr DEFAULT srch_stu_people_p.empty_vc_arr
                       ,p_campus                IN VARCHAR2 DEFAULT NULL
                       ,p_attribute_value       IN VARCHAR2 DEFAULT NULL
                       ,p_attribute_type        IN VARCHAR2 DEFAULT NULL
                       ,p_searchby_ppl          IN VARCHAR2 DEFAULT NULL                       
                       ,p_from                  IN VARCHAR2 DEFAULT NULL
                       ,p_print_ind             IN VARCHAR2 DEFAULT NULL);
----------------------------------------------------------------------
--  Name.    show_jp
--  Purpose: display a list of JPs who matched the search criteria
--  Pre:     Param not null
--  Post:    JPs and their details displayed
----------------------------------------------------------------------

PROCEDURE show_emp_details
(
    p_id  			IN NUMBER     DEFAULT NULL
   ,p_ip_type		IN VARCHAR2	  DEFAULT NULL
);
----------------------------------------------------------------------
--	Name.    show_emp_details
--  Purpose: Display detailed description of employee.
--  Pre:
--  Post:    Detailed description of employee displayed
----------------------------------------------------------------------

PROCEDURE show_vcard
(
    p_id  			IN NUMBER     DEFAULT NULL
   ,p_ip_type		IN VARCHAR2	  DEFAULT NULL
);
----------------------------------------------------------------------
--	Name.    show_vcard
--  Purpose: Download staff members vcard details
--  Pre:     true
--  Post:    vcard has been downloaded
----------------------------------------------------------------------

END srch_common_people;
