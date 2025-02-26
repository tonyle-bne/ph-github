CREATE OR REPLACE PACKAGE BODY emp_personal_profile_p IS

/**
* Staff personal details portlet
* @version 1.0.0
*/


----------------------------------------------------------------------
--  Purpose:	 Staff personal details portlet
--  Modification History
--  Date         Author        Description
--  -----------  ------------------------------------------------------------------------
--  19-SEP-2002   S Jeong      Created
--  08-OCT-2002   S Jeong      Proc name changed,
--				  			   process_update_form --> process_details_from
--  02-APR-2003   S Jeong      Reference to Constants and get_nav_struct in
--                             stu_personal_profile changed to emp_personal_profile.
--                             qv_common_help.qv_help_text removed
--  						   Formal parameter removed from help
--  03-NOV-2003   S Jeong      procedure 'show' modifed where it calls emp_personal_profile.show_success
--	29-Apr-2005	  D Hunt	   Added code to reference the LOCN set of tables.
--	15-Jun-2005	  D Hunt	   changed process_details parameters
--  01-Nov-2005	  F Lee		   Added Closed User Group
--  20-Jul-2006   E Wood       10g UPGRADE - added a c_ prefix to the g_portlet_id; Removed calls to qv_common_style;
--                             Corrected case of the portal schema references and added the portal schema reference where applicable;
--  01-May-2009   F Johnston   Added emergency contact mobile to process_details_form
-- 22-May-2009    C Wong       Modify portlet help url to use AskQUT
-----------------------------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
--
--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

    g_portlet_title		    VARCHAR2(200)  := 'Personal Details';
    g_portlet_name 		    VARCHAR2(30)   := 'emp_personal_profile_p';
    g_portlet_description VARCHAR2(200)  := 'Staff personal details';
    g_portlet_help_url    VARCHAR2(1000) :=  qv_common_help.get_help_link('STAFF_PERSONAL_INFO');
	  g_help_url     		    VARCHAR2(1000) := 'emp_personal_profile_p.help';

    -- application code for logging
    g_application_cd      VARCHAR2(50) := 'EMP';
    
    -- activity codes for logging
    C_MANAGE_PERSONAL_PROFILE CONSTANT VARCHAR2(100) := 'Manage personal profile';    
    
--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------

FUNCTION access_permitted
---------------------------------------------------------------------------------------
-- Name:    access_permitted
-- Purpose: contains all Portal group checking that is required in this package
--          this function is to be used in is_runnable and all show type procedures
--          in the IF statement use qv_common_access.is_user_in_group and
--          qv_common_access.is_group_owner (with NOT where required).
---------------------------------------------------------------------------------------
  RETURN BOOLEAN
IS
BEGIN
	RETURN (qv_common_access.is_user_in_group('EMP')
	        OR
          qv_common_access.is_user_in_group('CCR'));
END;

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE process_details_form
(
    p_arg_names       		  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values      		  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_title	    		  		  IN VARCHAR2    DEFAULT NULL
   ,p_preferred_name  		  IN VARCHAR2    DEFAULT NULL
   ,p_campus		       		  IN VARCHAR2    DEFAULT NULL
   ,p_location_notes  		  IN VARCHAR2    DEFAULT NULL
   ,p_phone 		  	    	  IN VARCHAR2    DEFAULT NULL
   ,p_fax 			  		      IN VARCHAR2    DEFAULT NULL
   ,p_mobile 		  		      IN VARCHAR2    DEFAULT NULL
   ,p_emergency_mobile      IN VARCHAR2    DEFAULT NULL
   ,p_speed_dial 	  		    IN VARCHAR2    DEFAULT NULL
   ,p_closed_user_group		  IN VARCHAR2    DEFAULT NULL
   ,p_pager 		  		      IN VARCHAR2    DEFAULT NULL
   ,p_pers_url 		  		    IN VARCHAR2    DEFAULT NULL
   ,p_pers_message	  		  IN VARCHAR2    DEFAULT NULL
   ,p_master_campus_id	    IN VARCHAR2    DEFAULT NULL
   ,p_building_copy			    IN VARCHAR2    DEFAULT NULL
   ,p_floor_copy 			      IN VARCHAR2    DEFAULT NULL
   ,p_room_copy				      IN VARCHAR2    DEFAULT NULL
   ,p_building	  			    IN VARCHAR2    DEFAULT NULL
   ,p_floor	  				      IN VARCHAR2    DEFAULT NULL
   ,p_room	  				      IN VARCHAR2    DEFAULT NULL
   ,p_action  				      IN VARCHAR2    DEFAULT NULL
)
----------------------------------------------------------------------
--  Purpose: Populate array with incoming name and value pairs
--			 Call business logic to process a form
----------------------------------------------------------------------
IS
    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;

BEGIN

    l_arg_names.DELETE;
    l_arg_values.DELETE;
    l_arg_names := p_arg_names;
    l_arg_values := p_arg_values;

    l_arg_names (p_arg_names.count+1) := 'p_title';
    l_arg_values(p_arg_names.count+1):=  TRIM(p_title);

    l_arg_names (p_arg_names.count+2) := 'p_preferred_name';
    l_arg_values(p_arg_names.count+2):=  REPLACE(REPLACE(TRIM(p_preferred_name),'<',''),'>','');

    l_arg_names (p_arg_names.count+3) := 'p_campus';
    l_arg_values(p_arg_names.count+3):=  REPLACE(REPLACE(TRIM(p_campus),'<',''),'>','');

    l_arg_names (p_arg_names.count+4) := 'p_location_notes';
    l_arg_values(p_arg_names.count+4):=  REPLACE(REPLACE(TRIM(p_location_notes),'<',''),'>','');

    l_arg_names (p_arg_names.count+5) := 'p_phone';
    l_arg_values(p_arg_names.count+5):=  REPLACE(REPLACE(TRIM(p_phone),'<',''),'>','');

    l_arg_names (p_arg_names.count+6) := 'p_fax';
    l_arg_values(p_arg_names.count+6):=  REPLACE(REPLACE(TRIM(p_fax),'<',''),'>','');

    l_arg_names (p_arg_names.count+7) := 'p_mobile';
    l_arg_values(p_arg_names.count+7):=  REPLACE(REPLACE(TRIM(p_mobile),'<',''),'>','');

    l_arg_names (p_arg_names.count+8) := 'p_emergency_mobile';
    l_arg_values(p_arg_names.count+8):=  REPLACE(REPLACE(TRIM(p_emergency_mobile),'<',''),'>','');

    l_arg_names (p_arg_names.count+9) := 'p_speed_dial';
    l_arg_values(p_arg_names.count+9):=  REPLACE(REPLACE(TRIM(p_speed_dial),'<',''),'>','');

    l_arg_names (p_arg_names.count+10) := 'p_closed_user_group';
    l_arg_values(p_arg_names.count+10):=  REPLACE(REPLACE(TRIM(p_closed_user_group),'<',''),'>','');

    l_arg_names (p_arg_names.count+11) := 'p_pager';
    l_arg_values(p_arg_names.count+11):=  REPLACE(REPLACE(TRIM(p_pager),'<',''),'>','');

    l_arg_names (p_arg_names.count+12) := 'p_pers_url';
    l_arg_values(p_arg_names.count+12):=  TRIM(p_pers_url);

    l_arg_names (p_arg_names.count+13) := 'p_pers_message';
    l_arg_values(p_arg_names.count+13):=  REPLACE(REPLACE(SUBSTR((TRIM(p_pers_message)),1,250),'<',''),'>','');

    l_arg_names (p_arg_names.count+14) := 'p_building';
    l_arg_values(p_arg_names.count+14):=  p_building;

    l_arg_names (p_arg_names.count+15) := 'p_floor';
    l_arg_values(p_arg_names.count+15):=  p_floor;

    l_arg_names (p_arg_names.count+16) := 'p_room';
    l_arg_values(p_arg_names.count+16):=  p_room;

    emp_personal_profile.validate_details_form(l_arg_names, l_arg_values);

END process_details_form;

PROCEDURE show
(
     p_arg_names 	  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Turn on/off display of photo
--			 Show update personal details form
--			 Show success page
----------------------------------------------------------------------
IS

    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;

    l_action_cd VARCHAR2(300) := 'Load personal details form';
    l_log_data  VARCHAR2(1000);

	FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
	IS
	BEGIN
	   RETURN common_utils.get_string(l_arg_names, l_arg_values, p_name);
	END get_value;

BEGIN

    IF access_permitted THEN

	    l_arg_names.DELETE;
	    l_arg_values.DELETE;
	    l_arg_names  := p_arg_names;
	    l_arg_values := p_arg_values;

	    -- prepare arguments and values
	    common_utils.normalize(l_arg_names, l_arg_values);

		IF get_value('p_show_mode') = emp_personal_profile.C_SUBMITTED THEN
        
        l_action_cd  := 'Load outcome message';
        l_log_data := 'success_ind="'||get_value('p_success_ind')||'"';            
        
		    common_template.get_full_page_header (p_title    => emp_personal_profile.C_UPDATE_PROFILE
			                                       ,p_heading  => emp_personal_profile.C_UPDATE_PROFILE
				            								         ,p_help_url => g_help_url);
			
        common_template.get_nav_path(emp_personal_profile.get_nav_struct(emp_personal_profile.C_UPDATE_PROFILE),l_arg_names,l_arg_values);

        emp_personal_profile.show_success(p_success_ind=>get_value('p_success_ind'));

        common_template.get_nav_path(emp_personal_profile.get_nav_struct(emp_personal_profile.C_UPDATE_PROFILE),l_arg_names,l_arg_values);

        common_template.get_full_page_footer;

		-- show update form
		ELSE

        l_action_cd  := 'Load personal details form';        

		    common_template.get_full_page_header (p_title    => emp_personal_profile.C_UPDATE_PROFILE
                                             ,p_heading  => emp_personal_profile.C_UPDATE_PROFILE
												                     ,p_help_url => g_help_url);

        common_template.get_nav_path(emp_personal_profile.get_nav_struct(emp_personal_profile.C_UPDATE_PROFILE),l_arg_names,l_arg_values);

        emp_personal_profile.show_details_form(l_arg_names,l_arg_values);

        common_template.get_nav_path(emp_personal_profile.get_nav_struct(emp_personal_profile.C_UPDATE_PROFILE),l_arg_names,l_arg_values);
        common_template.get_full_page_footer;
		
    END IF;
    
    logger.usage (p_application_cd => g_application_cd
                 ,p_activity_cd    => C_MANAGE_PERSONAL_PROFILE
                 ,p_action_cd      => l_action_cd 
                 ,p_log_data       => l_log_data );    
    
    ELSE
    
        logger.warn( p_application_cd => g_application_cd
                    ,p_activity_cd => C_MANAGE_PERSONAL_PROFILE
                    ,p_log_data => 'outcome="Access denied - user attempted to manage personal details but does not have the required access"');           
        -- display page to indicate user cannot access this page
        qv_access_p.not_permitted;
    
    END IF;
    
END show;

PROCEDURE help
----------------------------------------------------------------------
--  Purpose: Personal details specific help
----------------------------------------------------------------------
IS
BEGIN

    logger.usage( p_application_cd => g_application_cd
                 ,p_activity_cd    => C_MANAGE_PERSONAL_PROFILE
                 ,p_action_cd      => 'Load help content'); 

    -- header
    common_template.get_help_page_header(
						p_title    => g_portlet_title
   					   ,p_heading  => g_portlet_title
			         );
	-- help
	emp_personal_profile.show_help;
	-- footer
    common_template.get_full_page_footer;

END help;

END emp_personal_profile_p;
/
