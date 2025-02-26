CREATE OR REPLACE PACKAGE BODY qv_search_orgunit_p IS
/**
* Used to call package qv_search_orgunit to display organisational hierarchy
* structure and their staff members details and contact informations.
* @version 1.0.0
*/
----------------------------------------------------------------------
--  Modification History:
--  Date         Author      Description
--  -----------  ------------------------------------------------------
--  19 Aug 2002  Lin Lin
--  19-JUL-2006  S.Jeong     10g Upgrade Modification
--                           Unused procedures, functions and portal variables removed.
--                           htp.nl; statement after each help test removed in help procedure
--                           Removed qv_common_style.apply
--                           Missing </p> tag placed in help.
--  29-Jul-2009  D.Jack      SAMS Upgrade
--  13-Sep-2017  Tony Le     QVSEARCH-90: Application refactory. Removed any unused procedures,
--                           added logging for tracking purposes.
--  29-Jan-2018  K.Farlow    Added usage logging (JIRA: QVSEARCH-93).
----------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
    C_APPLICATION_CD    VARCHAR2(10)   := 'QVSEARCH';
--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------
    g_title		        VARCHAR2(200)  := 'QUT Faculty & Division Search';
	g_help_url     		VARCHAR2(1000) := 'qv_search_orgunit_p.help';

	l_arg_names  		owa.vc_arr;
    l_arg_values 		owa.vc_arr;
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
RETURN BOOLEAN IS

BEGIN
    RETURN (qv_common_access.is_user_in_group('STU') OR
	        qv_common_access.is_user_in_group('CCR') OR
            qv_common_access.is_user_in_group('EMP') OR
            qv_common_access.is_user_in_group('ALU') OR
            qv_common_access.is_user_in_group('SCH'));
END access_permitted;

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------

PROCEDURE process_submit
(
     p_name  		   IN VARCHAR2 		DEFAULT NULL
    ,p_show_mode	   IN VARCHAR2		DEFAULT NULL
)
----------------------------------------------------------------------
--  Purpose: define array values from data selected by user through web browser
----------------------------------------------------------------------
IS
    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;
BEGIN

	l_arg_names (1) := 'p_show_mode';
	l_arg_values(1) :=  p_show_mode;
	l_arg_names (2) := 'p_name';
	l_arg_values(2) :=  trim(p_name);
	qv_search_orgunit_p.show(l_arg_names, l_arg_values);
END process_submit;

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
IS
BEGIN
        RETURN common_utils.get_string(l_arg_names, l_arg_values, p_name);
END get_value;

PROCEDURE show_internal
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
IS

    l_org_unit      ORG_UNIT_TYP;
    l_local_name    qv_org_unit.title%TYPE;
    l_area_name     qv_org_unit.title%TYPE;
    l_org_unit_cd   qv_org_unit.org_unit_cd%TYPE;
    l_campus        VARCHAR2(20) := '';
    l_show_mode     VARCHAR2(50) := '';
    l_clevel        VARCHAR2(10) := '';
    e_data_error    EXCEPTION;

BEGIN

    l_arg_names.DELETE;
    l_arg_values.DELETE;
    l_arg_names  := p_arg_names;
    l_arg_values := p_arg_values;

    -- prepare arguments and values
    common_utils.normalize(l_arg_names, l_arg_values);

    BEGIN
        l_org_unit_cd   := NVL(get_value('p_org_code'), get_value('p_org_unit_code'));
        l_campus        := NVL(get_value('p_campus'), 'all');
        l_show_mode     := get_value('p_show_mode');
        l_clevel        := get_value('p_clevel');

        IF (l_clevel IS NOT NULL AND l_clevel <> 'clevel') THEN
            l_clevel := NULL;
        END IF;
    
        IF (l_org_unit_cd = '1' OR LENGTH(l_org_unit_cd) <= 2) THEN
            l_show_mode := 'BROWSE';
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
        
            RAISE e_data_error;

    END;    
   
	IF l_show_mode = 'BROWSE' THEN

        common_template.get_full_page_header(p_title    => g_title
                                            ,p_heading  => g_title
                                            ,p_help_url => g_help_url||'?p_arg_names=p_load_help&p_arg_values=Browse'
                                            ,p_version  => 2);
                                            
    	htp.p('<a href="'||common_template.C_HOME||'">Home</a> > divisions and faculties');

        logger.usage(
            p_application_cd   => C_APPLICATION_CD
           ,p_activity_cd      => 'View division/faculty list'
        );

        qv_search_orgunit.show_orgunit_list(p_browse        => TRUE
										   ,p_org_unit_code => NULL);

        htp.p('<a href="'||common_template.C_HOME||'">Home</a> > divisions and faculties');
        
	ELSIF l_show_mode = 'defined_org' THEN
    
	    common_template.get_full_page_header(p_title    => g_title
                                            ,p_heading  => g_title
                                            ,p_help_url => g_help_url||'?p_arg_names=p_load_help&p_arg_values=defined_org'
                                            ,p_version  => 2);

        qv_search_orgunit.get_org_unit_names (l_org_unit_cd, l_local_name, l_area_name);
        
    	htp.p('<a href="'||common_template.C_HOME||'">Home</a> > <a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=BROWSE">divisions and faculties</a> > '|| LOWER(l_local_name));

        logger.usage(
            p_application_cd   => C_APPLICATION_CD
           ,p_activity_cd      => 'View all sections within a division or faculty'
        );

        qv_search_orgunit.show_orgunit_list(p_browse        => FALSE
										   ,p_org_unit_code => get_value('p_org_unit_code'));

    	htp.p('<a href="'||common_template.C_HOME||'">Home</a> > <a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=BROWSE">divisions and faculties</a> > '|| LOWER(l_local_name));
        
	ELSIF l_show_mode = 'ally' THEN
    
	    common_template.get_full_page_header(p_title    => g_title
                                            ,p_heading  => g_title
                                            ,p_help_url => g_help_url||'?p_arg_names=p_load_help&p_arg_values=defined_org'
                                            ,p_version => 2);
                                            
        logger.usage(
            p_application_cd   => C_APPLICATION_CD
           ,p_activity_cd      => 'View QUT Ally Directory'
        );

        qv_search_orgunit.show_all_ally;

	ELSIF l_clevel = 'clevel' THEN
    
        qv_search_orgunit.get_org_unit_names (l_org_unit_cd, l_local_name, l_area_name);

        common_template.get_full_page_header(p_title    => g_title
                                            ,p_heading  => g_title
                                            ,p_help_url => g_help_url||'?p_arg_names=p_load_help&p_arg_values=Clevel'
                                            ,p_version  => 2);
                                            
        IF (LENGTH(l_org_unit_cd) = 3) THEN
            htp.p('<a href="'||common_template.C_HOME||'">Home</a> > <a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=BROWSE">divisions and faculties</a> > '|| LOWER(l_local_name));

        ELSE
            htp.p('<a href="'||common_template.C_HOME||'">Home</a> > <a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=BROWSE">divisions and faculties</a> '||
                  '> <a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=defined_org'||
                  '&p_arg_names=p_org_unit_code&p_arg_values='|| SUBSTR(l_org_unit_cd, 1, 3) ||'">'|| LOWER(l_local_name) ||'</a> '||
                  '> '|| LOWER(l_area_name) ||' ' || CASE l_campus WHEN 'all' THEN '' ELSE '- '|| LOWER(l_campus) ||'' END);
        END IF;        

        IF (l_campus = 'all') THEN

            logger.usage(
                p_application_cd   => C_APPLICATION_CD
               ,p_activity_cd      => 'View section staff for all campuses'
               ,p_log_data         => 'Campus="All", Org cd="'|| l_org_unit_cd ||'"'
            );
            
            qv_search_orgunit.show_details(l_org_unit_cd, NULL, get_value('p_from'));

        ELSE --when get_value('p_campus') IS NOT NULL

            logger.usage(
                p_application_cd   => C_APPLICATION_CD
               ,p_activity_cd      => 'View section staff for individual campus'
               ,p_log_data         => 'Campus="'|| l_campus ||'", Org cd="'|| l_org_unit_cd ||'"'
            );
            
            qv_search_orgunit.show_details(l_org_unit_cd, l_campus, get_value('p_from'));

        END IF;

        IF (LENGTH(l_org_unit_cd) = 3) THEN
            htp.p('<a href="'||common_template.C_HOME||'">Home</a> > <a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=BROWSE">divisions and faculties</a> > '|| LOWER(l_local_name));

        ELSE
            htp.p('<a href="'||common_template.C_HOME||'">Home</a> > <a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=BROWSE">divisions and faculties</a> '||
                  '> <a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=defined_org' ||
                  '&p_arg_names=p_org_unit_code&p_arg_values='|| SUBSTR(l_org_unit_cd, 1, 3) ||'">'|| LOWER(l_local_name) ||'</a> '||
                  '> '|| LOWER(l_area_name) ||' ' || CASE l_campus WHEN 'all'  THEN '' ELSE '- '|| LOWER(l_campus) ||'' END);
        END IF;        
        
    ELSIF l_show_mode = 'print' THEN
    
        common_template.get_print_page_header(p_title   => g_title
     										 ,p_heading => g_title);
        IF (l_campus = 'all') THEN

            logger.usage(
                p_application_cd   => C_APPLICATION_CD
               ,p_activity_cd      => 'Print section staff for all campuses'
               ,p_log_data         => 'Campus="All", Org cd="'|| l_org_unit_cd ||'"'
            );
            
            qv_search_orgunit.print_details(l_org_unit_cd, NULL);
            
        ELSE --when get_value('p_campus') IS NOT NULL

            logger.usage(
                p_application_cd   => C_APPLICATION_CD
               ,p_activity_cd      => 'Print section staff for individual campus'
               ,p_log_data         => 'Campus="'|| l_campus ||'", Org cd="'|| l_org_unit_cd ||'"'
            );
                        
            qv_search_orgunit.print_details(l_org_unit_cd, l_campus);
            
	    END IF;
    ELSE
        common_template.get_full_page_header(p_title    => g_title
                                            ,p_heading  => g_title
                                            ,p_help_url => g_help_url||'?p_arg_names=p_load_help&p_arg_values=Clevel'
                                            ,p_version  => 2);
        qv_search_orgunit.show_error_page;
	END IF;
    common_template.get_full_page_footer;

EXCEPTION
    WHEN e_data_error THEN
        common_template.get_full_page_header(p_title    => g_title
                                            ,p_heading  => g_title
                                            ,p_help_url => g_help_url||'?p_arg_names=p_load_help&p_arg_values=Browse'
                                            ,p_version  => 2);
        qv_search_orgunit.show_error_page;
        common_template.get_full_page_footer;

    WHEN OTHERS THEN
        logger.error(
            p_application_cd  => C_APPLICATION_CD
           ,p_activity_cd     => 'Staff listing within division/faculty'
           ,p_log_data        => 'Campus="'|| l_campus ||'", Org cd="'|| l_org_unit_cd ||'", From page="'|| get_value('p_from') ||'"'
        );
        common_template.get_full_page_header(p_title    => g_title
                                            ,p_heading  => g_title
                                            ,p_help_url => g_help_url||'?p_arg_names=p_load_help&p_arg_values=Browse'
                                            ,p_version  => 2);

        qv_search_orgunit.show_error_page;

        common_template.get_full_page_footer;
END show_internal;

PROCEDURE show
(
     p_arg_names 	  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	  IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose:  Contains all logic for the package.
----------------------------------------------------------------------
IS

BEGIN
    IF access_permitted THEN

        show_internal(p_arg_names      => p_arg_names
                     ,p_arg_values     => p_arg_values);
    ELSE
        -- display page to indicate user cannot access this page
        logger.warn(
            p_application_cd  => C_APPLICATION_CD
           ,p_activity_cd     => 'Staff listing within division/faculty'
           ,p_log_data        => 'Outcome="Login error - User does not have access", User id="'|| qv_common_id.get_user_id ||'"'
        );
        
        qv_access_p.not_permitted;
    END IF;
END show;

PROCEDURE help
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)

----------------------------------------------------------------------
--  Purpose:  Display relavent Help information to different pages
----------------------------------------------------------------------
IS

BEGIN
    l_arg_names.DELETE;
    l_arg_values.DELETE;
    l_arg_names  := p_arg_names;
    l_arg_values := p_arg_values;

    -- prepare arguments and values
    common_utils.normalize(l_arg_names, l_arg_values);

    logger.usage(
        p_application_cd   => C_APPLICATION_CD
       ,p_activity_cd      => 'View help content'
       ,p_log_data         => 'load_help="'|| get_value('p_load_help') ||'"'
    );

    -- header
    common_template.get_help_page_header(p_title    => g_title
                                        ,p_heading  => g_title);

	IF get_value('p_load_help') = 'Browse' THEN
    
        htp.p('<p>Faculty / Division search is a function that will allow '
				   ||'a user to browse a list of all the divisions and faculties within QUT. </p>');
		htp.p('<p>Select a division or faculty to view its sub-sections by clicking one of the links.</p>');
    
    ELSIF  get_value('p_load_help') = 'Defined_org' THEN
	
    	htp.p('<p>To view staff members in a section, click on one of the links.</p>');
	
    ELSIF  get_value('p_load_help') = 'Clevel' THEN
	
        htp.p('<p>This page displays staff member brief contact details in the selected section. '
				   ||'By clicking on their name, you can find their released personal details. '
				   ||'By clicking on their email alias, you can write a email to them.</p>');
	
    END IF;
    -- footer
    common_template.get_full_page_footer;

END help;

END  qv_search_orgunit_p;
/
