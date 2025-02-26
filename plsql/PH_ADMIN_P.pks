CREATE OR REPLACE PACKAGE ph_admin_p IS
/**
* Phone book administration
*/
----------------------------------------------------------------------
--  Package name:  ph_admin_p
--  Author:        Amy Zhang
--  Created:       28 Aug 2002
--
--  Specification Modification History
--  Date         Author           Description
--  -----------  ---------------  ---------------------------------------
--  17 Jun 2005  Damon Hunt 	  Added location dropdown boxes
--  11 Nov 2005	Fook Lee		  Added Closed User Group number to staff update
--  26 Mar 2007  Evan Wood        Added the has_qut_access(p_username) Function
--  23-03-2009   Tony Le          SAMS upgrade
--  20-Oct-2017  Tony Le          QVPH-34: Application refactoring.  
--  12-Dec-2019  N.Shanmugam      QVPH-56: Ability to update the temp_org_code for staff by phone book administrators
-- 31-Jan-2020  S.Thomas          QVPH-57: Modified to add ip_num while retrieving and updating the record
----------------------------------------------------------------------

FUNCTION access_permitted RETURN BOOLEAN;
--------------------------------------------------------------------------------------
--  Name:   access_permitted
-- Purpose: Function to check is user is in the group''PH_ADM''
-- Pre:
-- Post:    Return TRUE if use is in the group else return FALSE;
--------------------------------------------------------------------------------------


FUNCTION get_access_cd_length 	RETURN NUMBER;
--------------------------------------------------------------------------------------
-- Name:     get_access_cd_length
-- Purpose:  Function to return the length of access cd of a user
-- pre:
-- Post:     1  CLEVEL1 e.g. access_cd =1
--           3  CLEVEL2 e.g. access_cd=164
--           5  CLEVEL3 e.g. access_cd=16404
--           6  CLEVEL4 e.g. access_cd=164048
--------------------------------------------------------------------------------------

FUNCTION has_qut_access (p_username IN VARCHAR2) RETURN BOOLEAN;
--------------------------------------------------------------------------------------
-- Name:     has_qut_access
-- Purpose:  Function to return a boolean value - relating to if the user (identified
--           by p_username) has QUT Wide Phonebook administration access.
-- Pre:      p_username is a valid QUT Client
-- Post:     Boolean value is returned - TRUE if QUT wide access is granted or FALSE otherwise.
--------------------------------------------------------------------------------------

FUNCTION org_code_desc(p_org_unit_code IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
--------------------------------------------------------------------------------------
-- Name:     org_code_desc
-- Purpose:  Function to return org_unit_code and org_unit_desc
-- Pre:      true
-- Post:     org_unit_code and org_unit_desc are returned
--------------------------------------------------------------------------------------

FUNCTION checkcheckbox(p_str1	 IN VARCHAR2 DEFAULT NULL
    				  ,p_str2	 IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
--------------------------------------------------------------------------------------
-- Name:     CheckCheckBox
-- Purpose:  Function to produce check list of values for a radio select result
-- Pre:      true
-- Post:     IF str1 = str2 THEN  RETURN ' CHECKED'; ELSE RETURN '';
--------------------------------------------------------------------------------------


FUNCTION checkselect		(p_str1	IN VARCHAR2 DEFAULT NULL
					 		,p_str2	IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
--------------------------------------------------------------------------------------
-- Name:     CheckSelect
-- Purpose:  Function to produce check list of values for a select option result
-- Pre:      true
-- Post:     IF str1 = str2 THEN  RETURN 'SELECTED'; ELSE RETURN '';
--------------------------------------------------------------------------------------


FUNCTION listbox 	 		(p_sql  IN VARCHAR2 DEFAULT NULL
                     		,p_id   IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
--------------------------------------------------------------------------------------
-- Name:    listbox
-- Purpose: Function to produce drop down list of values for a sql select result
-- Pre:     TRUE
-- Post:    Selected results are returned
--------------------------------------------------------------------------------------


PROCEDURE listbox 	 		(p_sql  IN VARCHAR2 DEFAULT NULL
                     		,p_id   IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    listbox
-- Purpose: Procedure to produce drop down list for range of numeric values.
-- Pre:     TRUE
-- Post:    A drop down list is produced
--------------------------------------------------------------------------------------


PROCEDURE local_name;
--------------------------------------------------------------------------------------
-- Name:    local_name
-- Purpose: List all user accessible organisational unit names in the print order
-- Pre:     TRUE
-- Post:    Organisational unit names are listed
--------------------------------------------------------------------------------------


PROCEDURE local_name_update (p_org_unit_code IN VARCHAR2 DEFAULT NULL
		  					,p_local_name 	 IN VARCHAR2 DEFAULT NULL
		  					,p_update		 IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    local_name_update
-- Purpose: Update organisational name
-- Pre:     TRUE
-- Post:    The organisational name is updated
--------------------------------------------------------------------------------------


PROCEDURE admin_person ;
--------------------------------------------------------------------------------------
-- Name:    admin_person
-- Purpose: List all organisations
-- Pre:     TRUE
-- Post:    Organisation names are displayed in the print order
--------------------------------------------------------------------------------------

PROCEDURE admin_list   	 (p_org_unit_code   IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:     admin_list
-- Purpose: List all adminiatrators have access to the selected area
-- Pre:     TRUE
-- Post:    Administrators are listed for the area
--------------------------------------------------------------------------------------


PROCEDURE add_admin	 	 (p_org_unit_code	IN VARCHAR2 DEFAULT  NULL
		           		 ,p_username	    IN VARCHAR2	DEFAULT	 NULL
				   		 ,p_add				IN VARCHAR2	DEFAULT	 NULL);
--------------------------------------------------------------------------------------
-- Name:     add_admin
-- Purpose:  Add administrator for this selected group
-- Pre:      TRUE
-- Post:     Staff has been granted the access for the group
--------------------------------------------------------------------------------------


PROCEDURE remove_admin	 (p_org_unit_code   IN VARCHAR2 DEFAULT NULL
                         ,p_access_cd		IN VARCHAR2 DEFAULT  NULL
		           		 ,p_username		IN VARCHAR2	DEFAULT	 NULL
				   		 ,p_remove			IN VARCHAR2	DEFAULT	 NULL) ;
--------------------------------------------------------------------------------------
-- Name:       remove_admin
-- Purpose:    Remove administrator access for a specified group
-- Pre:        TRUE
-- Post:       The administrator is removed from the group
--------------------------------------------------------------------------------------


PROCEDURE modify_admin   (p_org_unit_code   IN VARCHAR2 DEFAULT NULL
                         ,p_username        IN VARCHAR2 DEFAULT NULL
                         ,p_access_cd  	 	IN VARCHAR2 DEFAULT NULL
					     ,p_modify          IN VARCHAR2 DEFAULT NULL
					     ,p_new_access_cd   IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:     modify_admin
-- Purpose:  Modify current administrator access
-- Pre:      TRUE
-- Post:     Administrator access is updated
--------------------------------------------------------------------------------------
PROCEDURE staff_group;
PROCEDURE dep_sch_list (p_org_unit_code	IN VARCHAR2 DEFAULT NULL);
PROCEDURE staff_list   (p_org_unit_code		IN VARCHAR2 DEFAULT NULL);

--PROCEDURE staff_group    (p_pass		 	IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:    staff_group
-- Purpose: List all user accessible groups
-- Pre:     TRUE
-- Post:    groups are listed in the order of print order
--------------------------------------------------------------------------------------

PROCEDURE staff_update
(
    p_username 			       IN VARCHAR2 DEFAULT NULL
    ,p_num                     IN VARCHAR2 DEFAULT NULL
    ,p_master_campus_id 	   IN VARCHAR2 DEFAULT NULL
	,p_building_copy		   IN VARCHAR2 DEFAULT NULL
	,p_floor_copy			   IN VARCHAR2 DEFAULT NULL
	,p_room_copy			   IN VARCHAR2 DEFAULT NULL
	,p_building				   IN VARCHAR2 DEFAULT NULL
	,p_floor				   IN VARCHAR2 DEFAULT NULL
	,p_room					   IN VARCHAR2 DEFAULT NULL
	,p_preferred_name  		   IN VARCHAR2 DEFAULT NULL
	,p_campus				   IN VARCHAR2 DEFAULT NULL
	,p_title				   IN VARCHAR2 DEFAULT NULL
	,p_location				   IN VARCHAR2 DEFAULT NULL
	,p_extn					   IN VARCHAR2 DEFAULT NULL
	,p_fax		    		   IN VARCHAR2 DEFAULT NULL
	,p_mobile				   IN VARCHAR2 DEFAULT NULL
	,p_speed_dial			   IN VARCHAR2 DEFAULT NULL
	,p_closed_user_group	   IN VARCHAR2 DEFAULT NULL
	,p_pager				   IN VARCHAR2 DEFAULT NULL
	,p_url					   IN VARCHAR2 DEFAULT NULL
	,p_group				   IN VARCHAR2 DEFAULT NULL
	,p_img_flag				   IN VARCHAR2 DEFAULT NULL
	,p_print_flag			   IN VARCHAR2 DEFAULT NULL
	,p_update				   IN VARCHAR2 DEFAULT NULL
	,p_temp_org_code           IN VARCHAR2 DEFAULT NULL
);
--------------------------------------------------------------------------------------
-- Name:       staff_update
-- Purpose:    Update selected staff contact details
-- Pre:        staff is selected
-- Post:       Staff contact details are updated
--------------------------------------------------------------------------------------


PROCEDURE help           (p_arg_values      IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:      help
-- Purpose:   display help message
-- Pre:       TRUE
-- Post:      TRUE
--------------------------------------------------------------------------------------

PROCEDURE error_message  (p_error           IN VARCHAR2 DEFAULT NULL);
--------------------------------------------------------------------------------------
-- Name:       error_message
-- Purpose:    Display message when user defined error is raised
-- Pre:        TRUE
-- Post:       TRUE
--------------------------------------------------------------------------------------
END;
/