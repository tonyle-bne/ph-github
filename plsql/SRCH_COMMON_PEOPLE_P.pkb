create or replace
PACKAGE BODY srch_common_people_p 
/**
* Display list of employee and contact details
* @author Sophie Jeong
* @version 1.0.0
*/
IS
----------------------------------------------------------------------
--  Modification History:
--  Date         Author      Description
--  -----------  ------------------------------------------------------
--  03-SEP-2002  S Jeong     Created
--  10-OCT-2002  S Jeong     Modified access_permitted function-return
--				   			 false if not satistied
--  20-APR-2005  T Baisden   Added access for SCH group
--  18-JUL-2006   S.Jeong    10g Upgrade Modification
--                           Unused procedures, functions and portal variables removed.
--                           Removed qv_common_style.apply
--  06-Aug-2007  C Wong      IAM Upgrade
--  09-Oct-2008  A McBride   Made QV 1.5 changes
--  24-Oct-2008  P.Totagiancaspro
--                           Reverse IAM Changes
--  29-Jul-2009  D.Jack      SAMS Upgrade
--  08-11-2010  Tony Le      Add new procedure to process JP search on advanced staff search page
--  01-07-2015  Tony Le      Removed links to help text as it is not valid anymore (JIRA : QVJPL-7)
--  01-12-2015  F Johnston   Added calls to common logging procedures [JIRA QVEMP-44]
--  22-Mar-2017  Tony Le     QVEMP-51: HiQ changes (removing and replacing any references to
--                           QV,DW,Student Gateway etc. with HiQ, or QUT Students site etc.)
-------------------------------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------

-- NIL

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

    g_portlet_title		VARCHAR2(200)  := 'Person Search';
 
    g_application_cd    VARCHAR2(50) := 'EMP';  
    g_help_url          VARCHAR2(1000)  := '';
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
	IF qv_common_access.is_user_in_group(common_client.C_STU_ROLE_TYPE)
	    OR qv_common_access.is_user_in_group(common_client.C_EMP_ROLE_TYPE)
		OR qv_common_access.is_user_in_group('CCR')
        OR qv_common_access.is_user_in_group(common_client.C_ALU_ROLE_TYPE)
                    OR qv_common_access.is_user_in_group('SCH')  THEN

		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END;

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------

-- NIL

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------

PROCEDURE show_internal
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Control display of employee contact details page
----------------------------------------------------------------------
IS

    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;

	l_help_url   VARCHAR2(500);
	l_title      VARCHAR2(500);

    -- local function to retrieve value
    FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
	IS
    BEGIN
        RETURN common_utils.get_string(l_arg_names, l_arg_values, p_name);
    END get_value;

BEGIN

    l_arg_names.DELETE;
    l_arg_values.DELETE;
    l_arg_names  := p_arg_names;
    l_arg_values := p_arg_values;

    -- prepare arguments and values
    common_utils.normalize(l_arg_names, l_arg_values);

	l_title    := srch_stu_people.C_SRCH_STU_PEOPLE||' '
	            ||srch_stu_people.C_SRCH_STU_PEOPLE_2||' - '
				||srch_stu_people.C_SRCH_STU_PEOPLE_3;
	--l_help_url := g_help_url||srch_stu_people.C_SRCH_STU_PEOPLE_3;
  
    l_help_url :='';
    IF get_value('p_show_mode') = srch_common_people.C_VCARD THEN

        -- download vcard of staff member
        srch_common_people.show_vcard(get_value('p_id'),get_value('p_ip_type'));

    ELSIF get_value('p_show_mode') = srch_stu_people.C_SRCH_STU_PEOPLE_2 THEN
    
        l_title    := srch_stu_people.C_SRCH_STU_PEOPLE || ' - ' || srch_stu_people.C_SRCH_JP_RESULTS;
       -- l_help_url := g_help_url||srch_stu_people.C_SRCH_STU_PEOPLE_2;
        l_help_url :='';
        IF (get_value('p_print_ind') = 'Y') THEN

            common_template.get_print_page_header (p_title    => l_title
                                                     ,p_heading  => l_title
                                                     ,p_help_url => l_help_url);
        
            srch_common_people.show_jp_list (p_campus            => get_value('p_campus')
                                            ,p_attribute_value   => get_value('p_attribute_value')
                                            ,p_attribute_type    => get_value('p_attribute_type')
                                            ,p_searchby_ppl      => get_value('p_searchby_ppl')
                                            ,p_from              => get_value('p_from')
                                            ,p_print_ind         => get_value('p_print_ind')
                                            ,p_arg_names         => l_arg_names
                                            ,p_arg_values        => l_arg_values);
                                            
            -- log page usage
            logger.usage(p_application_cd => g_application_cd
                        ,p_activity_cd => 'Print Justice of the Peace contact details');
       
        ELSE
    
            common_template.get_full_page_header (p_title     => l_title
                                                    ,p_heading   => l_title
                                                    ,p_help_url  => l_help_url);
            -- navigation
            srch_stu_people.get_nav_path
                            (l_arg_names
                            ,l_arg_values);

            srch_common_people.show_jp_list (p_campus            => get_value('p_campus')
                                            ,p_attribute_value   => get_value('p_attribute_value')
                                            ,p_attribute_type    => get_value('p_attribute_type')
                                            ,p_searchby_ppl      => get_value('p_searchby_ppl')
                                            ,p_from              => get_value('p_from')
                                            ,p_print_ind         => get_value('p_print_ind')                                         
                                            ,p_arg_names         => l_arg_names
                                            ,p_arg_values        => l_arg_values);

             -- log page usage
            logger.usage(p_application_cd => g_application_cd
                        ,p_activity_cd => 'View Justice of the Peace contact details');
       

            srch_stu_people.get_nav_path
                            (l_arg_names
                            ,l_arg_values);
        END IF;
        
        common_template.get_full_page_footer;

    ELSIF (get_value('p_show_mode') = srch_stu_people.C_SRCH_JP_RESULTS) THEN

        l_title    := srch_stu_people.C_SRCH_STU_PEOPLE || ' - ' || srch_stu_people.C_SRCH_JP_RESULTS || ' - ' || srch_stu_people.C_SRCH_STU_PEOPLE_3;
       -- l_help_url := g_help_url||srch_stu_people.C_SRCH_STU_PEOPLE_2;
        l_help_url := '';
        common_template.get_full_page_header (p_title    => l_title
                                                ,p_heading  => l_title
                                                ,p_help_url => l_help_url);

        -- navigation
        srch_stu_people.get_nav_path
                            (l_arg_names
                            ,l_arg_values);

        -- contact details of staff
        srch_common_people.show_emp_details(get_value('p_id'),get_value('p_ip_type'));

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'View staff contact details');
        
         -- log audit information
        logger.audit(p_application_cd => g_application_cd
                    ,p_activity_cd => 'View staff contact details'
                    ,p_log_data => 'staff id="'||get_value('p_id')||'"');  

        -- navigation
        srch_stu_people.get_nav_path
                            (l_arg_names
                            ,l_arg_values);

        -- footer
        common_template.get_full_page_footer;

    ELSE
        -- header
        common_template.get_full_page_header
                            (p_title    => l_title
                            ,p_heading  => l_title
                            ,p_help_url => l_help_url);
        -- navigation
        srch_stu_people.get_nav_path
                            (l_arg_names
                            ,l_arg_values);

        -- contact details of staff
        srch_common_people.show_emp_details(get_value('p_id'),get_value('p_ip_type'));

         -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'View staff contact details');
        
         -- log audit information
        logger.audit(p_application_cd => g_application_cd
                    ,p_activity_cd => 'View staff contact details'
                    ,p_log_data => 'staff id="'||get_value('p_id')||'"');  

        -- navigation
        srch_stu_people.get_nav_path
                            (l_arg_names
                            ,l_arg_values);

        -- footer
        common_template.get_full_page_footer;

    END IF;

END show_internal;

PROCEDURE show
(
     p_arg_names 	  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	  IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Control access
----------------------------------------------------------------------
IS

BEGIN

  IF access_permitted THEN

    show_internal(
		    p_arg_names      => p_arg_names
		   ,p_arg_values     => p_arg_values
         );
  ELSE
    -- display page to indicate user cannot access this page
    qv_access_p.not_permitted;
    
     -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'View employee person search'
                   ,p_log_data => 'outcome="User attempted to access employee person search but does not have access"');    
    
  END IF;

END show;


PROCEDURE process_jp_form (p_arg_names             IN owa.vc_arr DEFAULT empty_vc_arr
                          ,p_arg_values            IN owa.vc_arr DEFAULT empty_vc_arr
                          ,p_campus                IN VARCHAR2 DEFAULT NULL
                          ,p_attribute_value       IN VARCHAR2 DEFAULT NULL
                          ,p_attribute_type        IN VARCHAR2 DEFAULT NULL
                          ,p_searchby_ppl          IN VARCHAR2 DEFAULT NULL
                          ,p_print_ind             IN VARCHAR2 DEFAULT NULL)
----------------------------------------------------------------------
--  Name:    process_jp_form
--  Purpose: Populate array with parameter name and value pairs and
--           call business logic to process search
--  Pre:
--  Post:    Parameter array has been populated
----------------------------------------------------------------------
IS

    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;
    l_cnt        NUMBER;

BEGIN

    l_arg_names.DELETE;
    l_arg_values.DELETE;
    l_arg_names  := p_arg_names;
    l_arg_values := p_arg_values;

    l_cnt := p_arg_names.COUNT;

    l_arg_names (l_cnt + 1) := 'p_campus';
    l_arg_values(l_cnt + 1) :=  p_campus;
    l_arg_names (l_cnt + 2) := 'p_attribute_type';
    l_arg_values(l_cnt + 2) :=  p_attribute_type;
    l_arg_names (l_cnt + 3) := 'p_attribute_value';
    l_arg_values(l_cnt + 3) :=  p_attribute_value;
    l_arg_names (l_cnt + 4) := 'p_print_ind';
    l_arg_values(l_cnt + 4) :=  p_print_ind;
    l_arg_names (l_cnt + 5) := 'p_searchby_ppl';
    l_arg_values(l_cnt + 5) :=  p_searchby_ppl;  

    srch_common_people_p.show (l_arg_names, l_arg_values);

END process_jp_form;

END  srch_common_people_p;
