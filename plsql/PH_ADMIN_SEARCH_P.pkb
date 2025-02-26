CREATE OR REPLACE PACKAGE BODY ph_admin_search_p IS
/**
* Phone book administrator search
*/
----------------------------------------------------------------------
--  Modification History:
--  Date         Author      Description
--  -----------  ------------------------------------------------------
--  01-Mar-2007  F.Lee       Added access for PH
--  23-03-2009   Tony Le     SAMS upgrade
--  21-09-2009   P.Totagiancaspro
--                           Updated access_permitted to call has_access (required for Qv search portlet)
--  01-12-2015   F Johnston Added calls to common logging procedures
----------------------------------------------------------------------
--------------------------------------------
--            LOCAL CONSTANTS
--------------------------------------------
-- NIL
--------------------------------------------
--            LOCAL VARIABLES
--------------------------------------------
	  -- title
    g_portlet_title		    VARCHAR2(200)  := 'Phone book administrator search';

    -- help url
    g_help_url     		    VARCHAR2(1000) := 'ph_admin_search_p.help';
    g_application_cd VARCHAR2(50) := 'QVPH';    

    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;

--------------------------------------------
--            LOCAL TYPE DEFINITIONS
--------------------------------------------
-- NIL
--------------------------------------------
--            LOCAL EXCEPTIONS
--------------------------------------------
-- NIL
--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------
FUNCTION access_permitted
---------------------------------------------------------------------------------------
-- Purpose: contains group checking (access control) for this package
---------------------------------------------------------------------------------------
    RETURN BOOLEAN
IS
BEGIN
	IF qv_common_access.is_user_in_group('EMP') OR
		qv_common_access.is_user_in_group('CCR')
	THEN
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END;

--------------------------------------------
--            LOCAL PROCEDURES
--------------------------------------------
FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
IS
--------------------------------------------------------------------------------------
-- Purpose: Gets the value of an array variable
--------------------------------------------------------------------------------------
BEGIN
   RETURN common_utils.get_string(l_arg_names, l_arg_values, p_name);
END get_value;

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
-- NIL
--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE show
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)
IS
----------------------------------------------------------------------
--  Purpose: Display the phone book administrator search
----------------------------------------------------------------------
BEGIN
  	 IF access_permitted THEN
     	l_arg_names.DELETE;
    	l_arg_values.DELETE;
    	l_arg_names  := p_arg_names;
    	l_arg_values := p_arg_values;

    	-- prepare arguments AND VALUES
    	common_utils.normalize(l_arg_names, l_arg_values);

    	common_template.get_full_page_header(
	     			    p_title    => g_portlet_title
	     			   ,p_heading  => g_portlet_title
					   ,p_help_url => g_help_url
					   );

	    common_template.get_nav_path(ph_admin_search.get_nav_struct, l_arg_names, l_arg_values);

	    ph_admin_search.show (get_value('p_username')
                             ,get_value('p_email_alias')
                             ,get_value('p_surname')
                             ,get_value('p_first_name'));

    IF get_value('p_username') IS NULL AND get_value('p_email_alias') IS NULL AND get_value('p_surname') IS NULL AND get_value('p_first_name') IS NULL THEN
    
       -- log page usage
        logger.usage(p_application_cd => g_application_cd
                              ,p_activity_cd => 'View phone book administrator search');
      
    ELSE
    
         -- log page usage
        logger.usage(p_application_cd => g_application_cd
                              ,p_activity_cd => 'Phone book administrator search results');
        
         -- log audit information
        logger.audit(p_application_cd => g_application_cd
                            ,p_activity_cd => 'Phone book administrator search results'
                            ,p_log_data => 'username="'||get_value('p_username')||'",email alias="'||get_value('p_email_alias')||'",surname="'||get_value('p_surname')||'",first name="'||get_value('p_first_name')||'"');
    
    END IF;

	    common_template.get_nav_path(ph_admin_search.get_nav_struct, l_arg_names, l_arg_values);

        common_template.get_full_page_footer;
     ELSE
     	 -- display page to indicate user cannot access this page
    	 qv_access_p.not_permitted;
       
       -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                           ,p_activity_cd => 'Search for phone book administrator'
                           ,p_log_data => 'outcome="User attempted to access phone book administrator search but does not have access"');
       
     END IF;
END show;

PROCEDURE process_pba_search
(    p_username        IN VARCHAR2 DEFAULT NULL
    ,p_email_alias     IN VARCHAR2 DEFAULT NULL
    ,p_surname         IN VARCHAR2 DEFAULT NULL
    ,p_first_name      IN VARCHAR2 DEFAULT NULL
	,p_arg_names  	   IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	   IN owa.vc_arr DEFAULT empty_vc_arr
) IS
----------------------------------------------------------------------
--  Name. 	  process_pba_search
--  Purpose:  Processes the search for a phone book administrator
----------------------------------------------------------------------
    l_arg_names  owa.vc_arr DEFAULT empty_vc_arr;
    l_arg_values owa.vc_arr DEFAULT empty_vc_arr;

BEGIN
	l_arg_names := p_arg_names;
	l_arg_values := p_arg_values;

	l_arg_names(p_arg_names.COUNT+1) := 'p_username';
	l_arg_values(p_arg_values.COUNT+1) := TRIM(p_username);
	l_arg_names(p_arg_names.COUNT+2) := 'p_email_alias';
	l_arg_values(p_arg_values.COUNT+2) := TRIM(p_email_alias);
	l_arg_names(p_arg_names.COUNT+3) := 'p_surname';
	l_arg_values(p_arg_values.COUNT+3) := TRIM(p_surname);
	l_arg_names(p_arg_names.COUNT+4) := 'p_first_name';
	l_arg_values(p_arg_values.COUNT+4) := TRIM(p_first_name);

	ph_admin_search_p.show (l_arg_names, l_arg_values);

END process_pba_search;

PROCEDURE help
(
    p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Display help page
----------------------------------------------------------------------
IS
BEGIN
    -- display header
    common_template.get_help_page_header(
						p_title   => g_portlet_title
   					   ,p_heading => g_portlet_title);

    ph_admin_search.help;

     -- log page usage
        logger.usage(p_application_cd => g_application_cd
                              ,p_activity_cd => 'View phone book administrator search help');

    -- display footer
    common_template.get_full_page_footer;
END help;

PROCEDURE print
(
    p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Display print page
----------------------------------------------------------------------
IS
BEGIN
    -- display header
    common_template.get_print_page_header(
						p_title => g_portlet_title);



    -- Call to business logic print procedure



    -- display footer
    common_template.get_full_page_footer;
END print;

END  ph_admin_search_p;
/


