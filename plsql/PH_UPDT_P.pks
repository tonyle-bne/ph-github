CREATE OR REPLACE PACKAGE ph_updt_p IS
/**
* Manage workgroup structure Be able to update,delete
*    insert new phone group and job title, and can update
*    print order for organisations.
*
*/
----------------------------------------------------------------------
--  Package name:  ph_updt_p
--  Author:        Amy Zhang
--  Created:       28 Aug 2002
--
--  Specification Modification History
--  Date         Author           Description
--  -----------  ------------------------------------------------------
--  29-Apr-2004  L Chang         Added QV standard style for package specifications
--  02-Nov-2006  E Wood          Added extra parameters to allow a display flag to be used
--                               to turn on and off Groups and Subgroups.
--  24-03-2009   Tony Le          SAMS upgrade
----------------------------------------------------------------------

--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------

    -- NIL

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

    -- NIL

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
FUNCTION  check_clevel4 (p_org_unit_code IN VARCHAR2 DEFAULT NULL) RETURN NUMBER;
--------------------------------------------------------------------------------------
-- Name:    check_clevel4
-- Purpose: to return the number of records for the specific group
-- Pre:     TRUN
-- Post:    A number is returned
--------------------------------------------------------------------------------------

FUNCTION check_access_cd (p_org_unit_code IN VARCHAR2
		 				 ,p_username IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
--------------------------------------------------------------------------------------
-- Name:    check_access_cd
-- Purpose: To return the n
-- Pre:     TRUE
-- Post:    Return org_unit_code according to user access level
--------------------------------------------------------------------------------------

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE main_menu;
--------------------------------------------------------------------------------------
-- Name:    main_menu
-- Purpose: Display faculties/disvision by the print order
-- Pre:     TRUN
-- Post:    All accessible faculties/division are displayed
--------------------------------------------------------------------------------------

PROCEDURE dep_sch    (p_org_unit_code  IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    dep_sch
-- Purpose: Display the deparpments/shcools in the faculty/division
-- Pre:     TRUE
-- Post:    all departments/schools are displayed for the selected faculty/division
--------------------------------------------------------------------------------------

PROCEDURE print_order_update (p_org_unit_code IN VARCHAR2 DEFAULT NULL
			  				 ,p_sort_order    IN VARCHAR2 DEFAULT NULL
			  				 ,p_update        IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    print_order_update
-- Purpose: Update print order
-- Pre:     TRUE
-- Post:    Print order is updated
--------------------------------------------------------------------------------------

PROCEDURE ph_list (p_org_unit_code IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:     ph_list
-- Purpose:  Phone group list
-- Pre:      TRUE
-- Post:     display all phone group list for the selected department/school
--------------------------------------------------------------------------------------

PROCEDURE phone_group_update (p_org_unit_code IN VARCHAR2 DEFAULT NULL
			        		 ,p_group_code    IN VARCHAR2 DEFAULT NULL
							 ,p_group_name    IN VARCHAR2 DEFAULT NULL
							 ,p_print_order   IN VARCHAR2 DEFAULT NULL
							 ,p_primary_extn  IN VARCHAR2 DEFAULT NULL
							 ,p_primary_fax   IN VARCHAR2 DEFAULT NULL
                             ,p_display_ind   IN VARCHAR2 DEFAULT NULL
							 ,p_update        IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    phone_group_update
-- Purpose: Update selected phone group
-- Pre:     TRUE
-- Post:    Phone group is updated
--------------------------------------------------------------------------------------

PROCEDURE phone_group_delete (p_org_unit_code IN VARCHAR2 DEFAULT NULL
			        		 ,p_group_code    IN VARCHAR2 DEFAULT NULL
							 ,p_delete        IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    phone_group_delete
-- Purpose: delete unwanted phone group
-- Pre:     TRUE
-- Post:    Remove selected phone group for department/school
--------------------------------------------------------------------------------------

PROCEDURE phone_group_insert (p_org_unit_code IN VARCHAR2 DEFAULT NULL
		  					 ,p_group_code    IN VARCHAR2 DEFAULT NULL
							 ,p_group_name    IN VARCHAR2 DEFAULT NULL
							 ,p_print_order   IN VARCHAR2 DEFAULT NULL
							 ,p_primary_extn  IN VARCHAR2 DEFAULT NULL
							 ,p_primary_fax   IN VARCHAR2 DEFAULT NULL
                             ,p_display_ind   IN VARCHAR2 DEFAULT NULL
		  					 ,p_insert        IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    phone_group_insert
-- Purpose: Insert a new phone group in the department/school
-- Pre:     TRUE
-- Post:    A new phone group is inserted into the department/school
--------------------------------------------------------------------------------------

PROCEDURE job_title (p_org_unit_code IN VARCHAR2 DEFAULT NULL
             		,p_group_code    IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    job_title
-- Purpose: display all job titles in selected phone group
-- Pre:     TRUE
-- Post:    All job titles are displayed for the selected phone group
--------------------------------------------------------------------------------------

PROCEDURE job_title_update (p_org_unit_code   IN VARCHAR2 DEFAULT NULL
		      			   ,p_group_code 	  IN VARCHAR2 DEFAULT NULL
		            	   ,p_subgroup_code   IN VARCHAR2 DEFAULT NULL
						   ,p_subgroup_name   IN VARCHAR2 DEFAULT NULL
						   ,p_print_order     IN VARCHAR2 DEFAULT NULL
                           ,p_display_ind     IN VARCHAR2 DEFAULT NULL
						   ,p_update          IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    job_title_update
-- Purpose: Update job title
-- Pre:     TRUE
-- Post:    Job title is updated
--------------------------------------------------------------------------------------

PROCEDURE job_title_delete (p_org_unit_code  IN VARCHAR2 DEFAULT NULL
		      		       ,p_group_code 	 IN VARCHAR2 DEFAULT NULL
		                   ,p_subgroup_code  IN VARCHAR2 DEFAULT NULL
						   ,p_delete         IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    job_title_delete
-- Purpose: Delete a job title
-- Pre:     TRUE
-- Post:    A job title is deleted from a phone group
--------------------------------------------------------------------------------------

PROCEDURE job_title_insert (p_org_unit_code IN VARCHAR2 DEFAULT NULL
                           ,p_group_code    IN VARCHAR2 DEFAULT NULL
						   ,p_subgroup_code IN VARCHAR2 DEFAULT NULL
			   			   ,p_subgroup_name IN VARCHAR2 DEFAULT NULL
			   			   ,p_print_order   IN VARCHAR2 DEFAULT NULL
                           ,p_display_ind   IN VARCHAR2 DEFAULT NULL
					       ,p_insert        IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    job_title_insert
-- Purpose: Insert a new job title in the phone group
-- Pre:     TRUE
-- Post:    A new job title is inserted into the phone group
--------------------------------------------------------------------------------------

PROCEDURE show_staff (p_org_unit_code 	   IN VARCHAR2 DEFAULT NULL
			 		 ,p_group_code 		   IN VARCHAR2 DEFAULT NULL
			 		 ,p_subgroup_code 	   IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    show_staff
-- Purpose: Display all staff under the job title in the group
-- Pre:     TRUE
-- Post:    Display all staff with the select job title
--------------------------------------------------------------------------------------

PROCEDURE help  (p_arg_values IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    Help
-- Purpose: Display help message
-- Pre:     TRUE
-- Post:    TRUE
--------------------------------------------------------------------------------------

END;
/
