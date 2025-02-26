create or replace
PACKAGE BODY srch_stu_people_p 
/**
* Control access to people search results
* @version 1.0.0
*/
IS
----------------------------------------------------------------------
--  Modification History:
--  Date         Author      Description
--  -----------  ------------------------------------------------------
--  03-SEP-2002  S Jeong     Created
--  25-NOV-2004  J Choy      Allow ALU group access
--  10-APR-2004  T Baisden   Allow SCH group access
--  18-JUL-2006  S.Jeong     10g Upgrade Modification
--                           Unused procedures, functions and portlet variables removed.
--                           Removed qv_common_style.apply
--  06-Aug-2007  C Wong      IAM Upgrade
--  09-Oct-2008  A McBride   Made QV 1.5 User interface changes
--  24-Oct-2008  P.Totagiancaspro
--                           Reversed IAM changes
--  29-Jul-2009  D.Jack      SAMS Upgrade
--  09-Nov-2010  Tony Le     Add new JP search to process_advanced_form
--  29-Jan-2018  K. Farlow   Added usage logging (JIRA: QVSEARCH-93).
--                           Removed commented out code and redundant comments.
----------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

    g_application_cd      VARCHAR2(50)   := 'QVSEARCH';
    
    g_portlet_title		  VARCHAR2(200)  := 'Advanced people search';
	g_help_url     		  VARCHAR2(1000) := 'srch_stu_people_p.help'
	                                         ||'?p_arg_names=p_help_mode'
											 ||'&p_arg_values=';

    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;

--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------

FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
IS
--------------------------------------------------------------------------------------
-- Purpose: Gets the value of an array variable
--------------------------------------------------------------------------------------
BEGIN
   RETURN common_utils.get_string(l_arg_names, l_arg_values, p_name);
END get_value;

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
    OR qv_common_access.is_user_in_group(common_client.C_SCH_ROLE_TYPE) THEN
        RETURN TRUE;
    ELSIF (qv_common_access.is_user_in_group(common_client.C_EMP_ROLE_TYPE)
           OR qv_common_access.is_user_in_group('CCR')
           OR qv_common_access.is_user_in_group(common_client.C_ALU_ROLE_TYPE))
           AND
           NOT qv_common_access.is_user_in_group(common_client.C_EMP_STUDENT_INFO) THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;

END;

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
-- None
--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------

PROCEDURE process_surname_form
(
    p_arg_names       IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values      IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_surname  		  IN VARCHAR2 		DEFAULT NULL
   ,p_surname_submit  IN VARCHAR2		DEFAULT NULL
)
----------------------------------------------------------------------
--  Purpose: Populate array with parameter name and value pairs and
--           call business logic to process search
----------------------------------------------------------------------
IS
    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;
BEGIN

    l_arg_names.DELETE;
	l_arg_values.DELETE;
    l_arg_names := p_arg_names;
	l_arg_values := p_arg_values;

	l_arg_names (p_arg_names.count+1) := 'p_surname';
	l_arg_values(p_arg_values.count+1):=  TRIM(p_surname);
	l_arg_names (p_arg_names.count+2) := 'p_surname_submit';
	l_arg_values(p_arg_values.count+2):=  p_surname_submit;

    logger.usage(
        p_application_cd => g_application_cd
       ,p_activity_cd => 'Process surname search'
       ,p_log_data => 'surname="'|| TRIM(p_surname) ||'", surname_submit="'|| p_surname_submit ||'"'
    );

	srch_stu_people.process_search(l_arg_names, l_arg_values);

END process_surname_form;

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
)
----------------------------------------------------------------------
--  Purpose: Populate array with parameter name and value pairs and
--           call business logic to process search
----------------------------------------------------------------------
IS
    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;
    l_cnt        NUMBER := 0;

BEGIN

    l_arg_names.DELETE;
	l_arg_values.DELETE;
    l_arg_names := p_arg_names;
	l_arg_values := p_arg_values;
    
    l_cnt := p_arg_names.COUNT;

    IF (p_searchby_ppl = search.C_SEARCH_PERSON_BY_STAFF) THEN
    
        logger.usage(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'Process advanced search form (search for staff)'
           ,p_log_data => 'first_name="'|| TRIM(p_first_name) ||'"'
                        ||',surname="'|| TRIM(p_surname) ||'"'
                        ||',org_unit_cd="'|| p_org_unit_code ||'"'
                        ||',search_type="'|| p_search_type ||'"'          
                        ||',advanced_submit="'|| p_advanced_submit ||'"'                             
        );    
    
        l_arg_names (l_cnt + 1) := 'p_first_name';
        l_arg_values(l_cnt + 1) :=  TRIM(p_first_name);
        l_arg_names (l_cnt + 2) := 'p_surname';
        l_arg_values(l_cnt + 2) :=  TRIM(p_surname);
        l_arg_names (l_cnt + 3) := 'p_org_unit_code';
        l_arg_values(l_cnt + 3) :=  p_org_unit_code;
        l_arg_names (l_cnt + 4) := 'p_search_type';
        l_arg_values(l_cnt + 4) :=  p_search_type;
        l_arg_names (l_cnt + 5) := 'p_advanced_submit';
        l_arg_values(l_cnt + 5) :=  p_advanced_submit;
        srch_stu_people.process_search(l_arg_names, l_arg_values);
        
    ELSIF (p_searchby_ppl = search.C_SEARCH_PERSON_BY_JP) THEN
    
        logger.usage(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'Process advanced search form (search for JP)'
           ,p_log_data => 'campus="'|| p_campus ||'"'
                        ||',attribute_type="'|| p_attribute_type ||'"'
                        ||',attribute_value="'|| p_attribute_value ||'"'  
                        ||',advanced_submit="'|| p_advanced_submit ||'"'  
                        ||',searchby_ppl="'|| p_searchby_ppl ||'"'                                
        );      
    
        l_arg_names (l_cnt + 1) := 'p_campus';
        l_arg_values(l_cnt + 1) :=  p_campus;
        l_arg_names (l_cnt + 2) := 'p_attribute_type';
        l_arg_values(l_cnt + 2) :=  p_attribute_type;
        l_arg_names (l_cnt + 3) := 'p_attribute_value';
        l_arg_values(l_cnt + 3) :=  p_attribute_value;
        l_arg_names (l_cnt + 4) := 'p_advanced_submit';
        l_arg_values(l_cnt + 4) :=  p_advanced_submit;
        l_arg_names (l_cnt + 5) := 'p_searchby_ppl';
        l_arg_values(l_cnt + 5) :=  p_searchby_ppl;

        srch_common_people_p.show (l_arg_names, l_arg_values);
    END IF;

END process_advanced_form;

PROCEDURE show
(
     p_arg_names 	  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	  IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Control display of search results
----------------------------------------------------------------------
IS
    -- browser and page title
	l_title		            VARCHAR2(200);
	l_help_url	 			VARCHAR2(200);

BEGIN

    IF access_permitted THEN

	    l_arg_names.DELETE;
	    l_arg_values.DELETE;
	    l_arg_names  := p_arg_names;
	    l_arg_values := p_arg_values;

	    -- prepare arguments and values
	    common_utils.normalize(l_arg_names, l_arg_values);
        
        logger.usage(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'Load relevant search page'
           ,p_log_data => 'show_mode="'||get_value('p_show_mode')||'"'
                        ||', first_name="'||get_value('p_first_name')||'"'
                        ||', surname="'||get_value('p_surname')||'"'
                        ||', org_unit_cd="'||get_value('p_org_unit_code')||'"'
                        ||', search_type="'||get_value('p_search_type')||'"'                             
                        ||', from="'||get_value('p_from')||'"'  
                        ||', exception="'||get_value('p_exception')||'"'
        );           

		-- START of assigning appropriate browser and page title and help url
		-- if to show an advanced search
        IF get_value('p_show_mode') = srch_stu_people.C_SRCH_STU_PEOPLE THEN

		    l_title    := srch_stu_people.C_SRCH_STU_PEOPLE;
			l_help_url := g_help_url||srch_stu_people.C_SRCH_STU_PEOPLE;

		-- to show results
        ELSIF get_value('p_show_mode') = srch_stu_people.C_SRCH_STU_PEOPLE_2 OR get_value('p_show_mode') IS NULL THEN

		    l_title    := srch_stu_people.C_SRCH_STU_PEOPLE||' '||srch_stu_people.C_SRCH_STU_PEOPLE_2;
			l_help_url := g_help_url||srch_stu_people.C_SRCH_STU_PEOPLE_2;

	    -- if to show details
	    ELSE
		    l_title    := srch_stu_people.C_SRCH_STU_PEOPLE||' '
			              ||srch_stu_people.C_SRCH_STU_PEOPLE_2||' - '
				 	      ||srch_stu_people.C_SRCH_STU_PEOPLE_3;
		    l_help_url := g_help_url||srch_stu_people.C_SRCH_STU_PEOPLE_3;
		END IF;
        -- END of assigning appropriate browser and page title and help url

		-- header
	    common_template.get_full_page_header
						(p_title    => l_title
		     			,p_heading  => l_title
						,p_help_url => l_help_url
						);
		-- navigation
        srch_stu_people.get_nav_path
                        (l_arg_names
						,l_arg_values);

		-- START of calling different business logic pages
		-- if to show results page
        IF get_value('p_show_mode') = srch_stu_people.C_SRCH_STU_PEOPLE THEN

		    srch_stu_people.show_advanced_srch;

		-- to show results
        ELSIF get_value('p_show_mode') = srch_stu_people.C_SRCH_STU_PEOPLE_2 OR get_value('p_show_mode') IS NULL THEN

		    IF (get_value('p_exception')) IS NOT NULL THEN
			    srch_stu_people.show_exceptions( get_value('p_exception')
                                                ,l_arg_names
						                        ,l_arg_values);
			ELSE
				srch_common_people.show_emp_list
						            (get_value('p_first_name')
									,get_value('p_surname')
									,get_value('p_org_unit_code')
									,get_value('p_search_type')
									,get_value('p_from')
                                    ,l_arg_names
                                    ,l_arg_values);
		        --htp.nl;
			END IF;
	    -- if to show details page
	    ELSE
        IF (get_value('p_exception')) IS NOT NULL THEN
            srch_stu_people.show_exceptions( get_value('p_exception')
                                                  ,l_arg_names
                                        ,l_arg_values);
          ELSE
            srch_common_people.show_emp_details(get_value('p_id'),get_value('p_ip_type'));
          END IF;

		END IF;
        -- END of calling different business logic pages

		-- navigation
        srch_stu_people.get_nav_path
                        (l_arg_names
						,l_arg_values);
		-- footer
	    common_template.get_full_page_footer;

    ELSE
        logger.warn(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'Show search'     
           ,p_log_data => 'outcome="User attempted to view search but does not have access"'
        );      
        -- display page to indicate user cannot access this page
        qv_access_p.not_permitted;
    END IF;

END show;

END  srch_stu_people_p;
