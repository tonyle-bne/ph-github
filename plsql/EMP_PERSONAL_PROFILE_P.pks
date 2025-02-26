create or replace
PACKAGE emp_personal_profile_p IS

/**
* Staff personal details portlet
* @version 1.0.0
*/

-----------------------------------------------------------------------------------------
--  Package Name: emp_personal_profile_p
--  Purpose:	  Staff personal details  portlet
--  Author:		  S Jeong
--  Created:      19 Sep 2002
--
--  Specification Modification History
--  Date          Author       Description
--  -----------  ------------------------------------------------------------------------
--  19-SEP-2002   S Jeong      Created
--  08-OCT-2002   S Jeong      Proc name changed,
--				  			   process_update_form --> process_details_from
--  02-APR-2002   S Jeong      Formal parameter removed from help
--	29-Apr-2005	  D Hunt	   Added code to reference the LOCN set of tables.
--  01-Nov-2005	  F Lee		   Added Closed User Group
--  31-Jul-2006   E Wood       10g UPGRADE - Corrected case of the portal schema references and added the portal schema reference where applicable;
--  01-May-2009   F Johnston   Added emergency contact mobile to process_details_form
-----------------------------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
	-- variable argument array
    empty_vc_arr owa.vc_arr;


PROCEDURE process_details_form
(
    p_arg_names       		  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values      		  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_title			  		  IN VARCHAR2    DEFAULT NULL
   ,p_preferred_name  		  IN VARCHAR2    DEFAULT NULL
   ,p_campus		  		  IN VARCHAR2    DEFAULT NULL
   ,p_location_notes  		  IN VARCHAR2    DEFAULT NULL
   ,p_phone 		  		  IN VARCHAR2    DEFAULT NULL
   ,p_fax 			  		  IN VARCHAR2    DEFAULT NULL
   ,p_mobile 		  		  IN VARCHAR2    DEFAULT NULL
   ,p_emergency_mobile        IN VARCHAR2    DEFAULT NULL
   ,p_speed_dial 	  		  IN VARCHAR2    DEFAULT NULL
   ,p_closed_user_group		  IN VARCHAR2    DEFAULT NULL
   ,p_pager 		  		  IN VARCHAR2    DEFAULT NULL
   ,p_pers_url 		  		  IN VARCHAR2    DEFAULT NULL
   ,p_pers_message	  		  IN VARCHAR2    DEFAULT NULL
   ,p_master_campus_id	  	  IN VARCHAR2    DEFAULT NULL
   ,p_building_copy			  IN VARCHAR2    DEFAULT NULL
   ,p_floor_copy 			  IN VARCHAR2    DEFAULT NULL
   ,p_room_copy				  IN VARCHAR2    DEFAULT NULL
   ,p_building	  			  IN VARCHAR2    DEFAULT NULL
   ,p_floor	  				  IN VARCHAR2    DEFAULT NULL
   ,p_room	  				  IN VARCHAR2    DEFAULT NULL
   ,p_action  				  IN VARCHAR2    DEFAULT NULL
);
----------------------------------------------------------------------
--  Name.    process_details_form
--  Purpose: Populate array with incoming name and value pairs
--			 Call business logic to process a form
--  Pre:
--  Post:    Array has been populated and passed to a business logic
--			 to process a form
----------------------------------------------------------------------

PROCEDURE show
(
     p_arg_names 	  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	  IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--  Name.    show
--  Purpose: Turn on/off display of photo
--			 Show update personal details form
--			 Show success page
--  Pre:
--  Post:    Display of photo has been turned on/off OR
--			 Update form has been displayed OR
--			 Success page has been displayed after a form submission
----------------------------------------------------------------------

PROCEDURE help;
----------------------------------------------------------------------
--  Name:    help
--  Purpose: Personal details specific help
--  Pre:     True
--  Post:    Help has been displayed
----------------------------------------------------------------------

END emp_personal_profile_p;
/
