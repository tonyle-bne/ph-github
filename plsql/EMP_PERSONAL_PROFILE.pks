CREATE OR REPLACE PACKAGE emp_personal_profile IS

/**
* Staff personal details portlet
* @version 1.0.0
*/

-----------------------------------------------------------------------------------------
--  Package Name: emp_personal_profile_p
--  Purpose:	  Staff personal details
--				  Provide details form to update employee's personal details
--				  If invalid entries are found re-display a form with message otherwise
--				  show success page
--  Author:		  S Jeong
--  Created:      19 Sep 2002
--
--  Specification Modification History
--  Date         Author      Description
--  -----------  ------------------------------------------------------------------------
--  19-SEP-2002  S Jeong     Created
--  08-OCT-2002  S Jeong     Proc name changed process_update --> validate_details_form,
--				   			 show_update_form --> show_details_from
--  28-MAR-2003  S Jeong     global constants C_UPDATE_PROFILE & C_SUCCESS added
--                           function get_nav_struct added
--  03-NOV-2003  S Jeong     Add parameter @p_success_ind to procedure success
--                           CONSTANT C_SUCCESS changed to C_SUBMITTED.
--  18-Dec-2017  Tony Le     QVEMP-56: Rename 'Update Personal Details' to 'Update Contact Details'
-----------------------------------------------------------------------------------------

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

	-- array structures for navigation path
    empty_vc_arr owa.vc_arr;

--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
	C_UPDATE_PROFILE     CONSTANT VARCHAR2(100) := 'Update contact details';
	C_SUBMITTED          CONSTANT VARCHAR2(100) := 'Submitted';

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
FUNCTION get_nav_struct
(
    p_show_mode 	  IN VARCHAR2 DEFAULT NULL
)
    RETURN owa.vc_arr;

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------

PROCEDURE show_personal_details;
----------------------------------------------------------------------
--	Name.    show_personal_details;
--  Purpose: Show personal details
--  Pre:
--  Post:
----------------------------------------------------------------------

PROCEDURE show_details_form
(
     p_arg_names 	  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	  IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--	Name.    show_details_form
--  Purpose: Show details form or display message with a form if invalid
--			 entries are found
--  Pre:
--  Post:
----------------------------------------------------------------------

PROCEDURE validate_details_form
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--	Name.    validate_details_form
--  Purpose: Validate details form and call success page if all entries
--			 are valid otherwise re-display a form with message
--  Pre:
--  Post:    Form has been validated and success page has been called or
--			 a form has been re-displayed
----------------------------------------------------------------------

PROCEDURE show_success
(
    p_success_ind   IN VARCHAR2    DEFAULT NULL
);

PROCEDURE show_help
(
    p_help_mode		IN VARCHAR2    DEFAULT NULL
);
----------------------------------------------------------------------
--	Name.    show_help
--  Purpose: Show personal details specific help
--  Pre:
--  Post:    Personal details specific help has been displayed
----------------------------------------------------------------------

END emp_personal_profile;
/