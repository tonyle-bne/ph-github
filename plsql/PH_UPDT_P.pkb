CREATE OR REPLACE PACKAGE BODY ph_updt_p IS
/**
* Manage workgroup structure Be able to update,delete
*    insert new phone group and job title, and can update
*    print order for organisations.
*
*/
--------------------------------------------------------------------------------------
-- Package Name: ph_admin_p
-- Author:       Amy Zhang
-- Created:      28-Aug-2002
--
--  Specification Modification History
--  Date         Author           Description
--  -----------  ------------------------------------------------------
-- 25 Sep 2002  Amy Zhang   Modified help message, Add active_flag='Y''in
--                          all SQL statments using emp_org_unit table
-- 04 Mar 2003  Amy Zhang   Modified cursors in dep_sch, display all areas regardless
--                          if there is any staff attached.
-- 12 Mar 2003  Evan Wood   Modified Org unit name update to change codes as well to prevent overwrites
-- 19 Jun 2003  Amy Zhang   Fixed the queries to join the ip table and qv_client_role table
--                          with the condition ip.ip_num = qv_client_role.trs_client_id
-- 29-Apr-2004  L Chang     Fixed mailto format and adjusted header/footer where applicable.
--                          Also applied for QV standard style on whole package body where needed
-- 01-Aug-2006  Evan Wood   10g UPGRADE - Removed calls to qv_common_style;
--                          Corrected qv_common_links references to use the qv_common_links.get_reference_link;
--                          Replaced Phone Book Administration email referece to appropriate qv_common_links.get_reference_link call;
--                          Replaced QUT Phone Extention Prefix to appropriate qv_common_links.get_reference_link call;
--						    Replaced deprecated <b> & </b> tags with <strong> & </strong>;
--							Removed the <pre> & </pre> tags as they were efficting the application display;
--							Corrected Layouts from the removal of the <pre> tags.
--							Added a Heading of "Phone Book" on each page.
--						    Fixed Spacing & Character Case issues identified;
-- 02-Nov-2006  Evan Wood   Added a Display indicator for Groups and Subgroups.
--                          Removed reference to 3864 in logic that was manipulating the group_code fax number.
--                          Switched l_staff_cnt to a NUMBER variable as it was limited to VARCHAR2(2) which was triggering an
--                          exception due to the overflow when staff numbers exceed 99.
-- 23-Nov-2006  M Huth		Added in default null param into check_access_cd function.
-- 				  			Added in NVL so that the passed in username is used if not null, else the global variable.
--						    All calls to check_access_cd function within this package now have the username passed in.
-- 28-Nov-2006  E Wood	    Made Form Layout / Element Note changes as per Sharyn Leeman's Request.
-- 30-Jan-2006  E Wood      Fixed the form for Job Title Inserts and Updates. Bug was caused when the Parent Group code is
--                          set to display = 'N' the children display values are all updated to 'N' and the form controll is
--                          disabled. When a form element is disabled the value for it .. even if set and checked is NULL.
-- 26-Mar-2007  E Wood      Modified application to show P prefixed organisational units.
--                          Tidied up some ordering of organisational unit listings.
--                          Added releveant calls to UPPER() and LOWER() for Cursors.
-- 04-May-2007  M Huth      Removed usage of g_username which may be causing Portal function calls to be called recursively.
--                          Put username into local subprograms instead.
-- 24-03-2009   Tony Le     SAMS upgrade
-- 26-05-2009   Tony Le     Replace references to org_units with emp_org_unit
-- 17-06-2009   Tony Le     Remove any references to codes table
-- 15-09-2011   L Dorman    Changed references to emp_org_unit.local_name to emp_org_unit.org_unit_desc
-- 16 Oct 2012   Ali Tan    Changed access table from qv_access to access_type_member
-- 18-04-2013   Tony Le     Fixed Group and Job Title deletion. The submit tag missing the closing '>'
-- 27-11-2015   F Johnston Added calls to common logging procedures
-- 17-05-2018   S. Kambil   Apply site and service reference to HiQ. [QVPH-41]
-- 07-06-2018   Tony Le     QVPH-42: Increased the length of the group code description to 100 chars
-- 05-06-2020   N.Shanmugam Heat SR#403081: Ability to set the print order range greater than 90
--------------------------------------------------------------------------------------

--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------

    C_STRUC_HEADER CONSTANT     VARCHAR2(100) :='Manage Workgroup Structure';
    C_STRUC_HELP   CONSTANT     VARCHAR2(100) :='ph_updt_p.help?p_arg_values=struct_help';

-------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

    g_restrict_access  			      EXCEPTION;
    g_message                      VARCHAR(1000);
    error_message                EXCEPTION;
    -- table row background shade
    g_background_shade	           VARCHAR2(7)   DEFAULT common_style.C_WHITE_COLOUR;
    g_application_cd              VARCHAR2(50) := 'QVPH';
--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------

    -- NIL

--------------------------------------------
--            LOCAL PROCEDURES
--------------------------------------------

    -- NIL

--------------------------------------------
--            GLOBAL FUNCTION
--------------------------------------------
FUNCTION check_clevel4 (p_org_unit_code IN VARCHAR2) RETURN NUMBER IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
    l_cnt          NUMBER:=0;
BEGIN
	Select  count(*)
    INTO    l_cnt
	FROM    group_codes
	WHERE   owner_org_code = p_org_unit_code;

	RETURN(l_cnt);
EXCEPTION
    WHEN OTHERS THEN
        l_cnt :=0;
        RETURN(l_cnt);
END;

FUNCTION check_access_cd (p_org_unit_code IN VARCHAR2
		 				 ,p_username IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
    l_flag  VARCHAR(10);
    l_username     qv_client_computer_account.username%TYPE;

BEGIN
    IF p_username IS NULL THEN
        l_username := qv_common_id.get_username;
    ELSE
        l_username := p_username;
    END IF;
    <<end_loop>>
    FOR r IN (
               SELECT access_cd
		       FROM   access_type_member
		       WHERE  group_cd='PH'
		       AND    username = l_username
             ) LOOP

        IF length(r.access_cd) = 1 THEN
           l_flag := substr(p_org_unit_code,1,3);
           EXIT end_loop;
        ELSIF length(r.access_cd) = 3 and substr(r.access_cd,1,3) = substr(p_org_unit_code,1,3) THEN
		   l_flag := r.access_cd;
           EXIT end_loop;
        ELSIF length(r.access_cd) = 5 and substr(r.access_cd,1,5) = substr(p_org_unit_code,1,5) THEN
           l_flag := r.access_cd;
           EXIT end_loop;
        ELSIF length(r.access_cd) = 6 and substr(r.access_cd,1,6) = substr(p_org_unit_code,1,6) THEN
           l_flag:= r.access_cd;
		   EXIT end_loop;
        END IF  ;

    END LOOP end_loop;

    RETURN l_flag;

end check_access_cd;

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE main_menu  IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------

CURSOR admin_cur IS
	SELECT  DISTINCT username
	        ,access_cd
	        ,DECODE(length(access_cd),1, 'CLEVEL2'
		 	   				  		 ,3, 'CLEVEL2'
									 ,5, 'CLEVEL3'
									 ,6, 'CLEVEL4') hierarchy_level
	FROM    access_type_member
	WHERE   group_cd       = 'PH'
	AND     username        = qv_common_id.get_username
    ORDER BY hierarchy_level;

CURSOR emp_org_unit_cur(cur_access_cd  VARCHAR2
                    ,cur_clevel     VARCHAR2) IS
    SELECT  *
    FROM    emp_org_unit eou
    WHERE   eou.hierarchy_level  = cur_clevel
    AND     eou.org_unit_cd   LIKE cur_access_cd||'%'
--    AND    (sort_order < 90 OR sort_order IS NULL)
    AND     LOWER(eou.org_unit_desc) <> 'central initiatives'
	AND     UPPER(eou.org_unit_desc) NOT LIKE '%DELETE%'
	AND    (SYSDATE BETWEEN eou.start_dt AND eou.end_dt OR eou.end_dt IS NULL)
    AND     EXISTS ( SELECT   *
                     FROM     ip i
                             ,group_codes gc
                             ,subgroup_codes sgc
                     WHERE    i.owner_org_code LIKE eou.org_unit_cd||'%'
                     AND      i.ip_status = 'cur'
                     AND      i.print_flag = 'Y'
                     AND      i.owner_org_code = gc.owner_org_code
                     AND      i.phone_group = gc.phone_group
                     AND      gc.display_ind = 'Y'
                     AND      gc.owner_org_code = sgc.owner_org_code
                     AND      gc.phone_group = sgc.phone_group
                     AND      i.phone_subgroup = sgc.phone_subgroup
                     AND      sgc.display_ind = 'Y'
             )
    ORDER BY sort_order;

BEGIN

	common_template.get_full_page_header(p_title=>C_STRUC_HEADER
										   ,p_heading=>C_STRUC_HEADER
										   ,p_help_url=>C_STRUC_HELP);

	IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length = 0 THEN
	   RAISE g_restrict_access;
	END IF;

    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                          ,p_activity_cd => 'View phone book for Division/Faculties');

    -- log audit information
    logger.audit(p_application_cd => g_application_cd
                        ,p_activity_cd => 'View phone book for Division/Faculties');

	-- Heading
	htp.p('<h1>Phone Book</h1>');

    htp.p('<table align="left" cellspacing="0" cellpadding="5" border="0" width="775px">');

	htp.p('<tr>');
	htp.p('<th width="25px">&nbsp;</th>');
	htp.p('<th>&nbsp;</th>');
	htp.p('<th align="left">Print Order</th>');
    htp.p('<th align="left">Divisions/Faculties</th>');
	htp.p('</tr>');

	For adminrec in admin_cur LOOP
	    FOR org_rec IN emp_org_unit_cur(adminrec.access_cd,adminrec.hierarchy_level) LOOP

	        IF adminrec.hierarchy_level <>'CLEVEL4' THEN
			   htp.p('<tr>');
			   htp.p('<td>&nbsp;</td>');
		       htp.p('<td><a href="ph_updt_p.print_order_update?p_org_unit_code='||org_rec.org_unit_cd||'&p_sort_order='||org_rec.sort_order||'">[Modify print order]</a></td>');
		       htp.p('<td>'||org_rec.sort_order||'</td>');
	           htp.p('<td><a href="ph_updt_p.dep_sch?p_org_unit_code='||org_rec.org_unit_cd||'">'||ph_admin_p.org_code_desc(org_rec.org_unit_cd)||'</a></td>');
			   htp.p('</tr>');

		    ELSIF adminrec.hierarchy_level ='CLEVEL4' THEN
			   htp.p('<tr>');
			   htp.p('<td>&nbsp;</td>');
		       htp.p('<td><a href="ph_updt_p.print_order_update?p_org_unit_code='||org_rec.org_unit_cd||'&p_sort_order='||org_rec.sort_order||'">[Modify print order]</a></td>');
		       htp.p('<td>'||org_rec.sort_order||'</td>');
	           htp.p('<td><a href="ph_updt_p.ph_list?p_org_unit_code='||org_rec.org_unit_cd||'">'||ph_admin_p.org_code_desc(org_rec.org_unit_cd)||'</a><input type="hidden" name="p_access_cd" value="'||adminrec.access_cd||'"></td>');
			   htp.p('</tr>');
		    END IF;
	    END LOOP;
    END LOOP;

	htp.p('</table>');

	htp.p('<div style="clear:both;">&nbsp;</div>');

    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
             ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');
       common_template.get_full_page_footer;

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                          ,p_activity_cd => 'View phone book'
                          ,p_log_data => 'outcome="User attempted to access the phone book for Division/Faculties but does not have access"');

    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END main_menu;

PROCEDURE dep_sch (p_org_unit_code	IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
    c2rec                emp_org_unit%ROWTYPE;

   -- internal procedure 1
   PROCEDURE clevel3 (clevel2_code VARCHAR2) IS
       c3_cnt	NUMBER;
       CURSOR list_o_clevels3 IS
           SELECT     eou.org_unit_cd
                     ,eou.org_unit_desc
                     ,eou.sort_order
   	       FROM       emp_org_unit eou
           WHERE    eou.hierarchy_level  =        'CLEVEL3'
           AND      eou.org_unit_cd   LIKE     clevel2_code || '%'
           AND      LOWER(eou.org_unit_desc) NOT IN ('central initiatives', 'pro-vice-chancellor (academic)')
           AND      UPPER(eou.org_unit_desc) NOT LIKE '%DELETE%'
           AND     (SYSDATE BETWEEN eou.start_dt AND eou.end_dt OR eou.end_dt IS NULL)
           AND      EXISTS ( SELECT   *
                             FROM     ip i
                                     ,group_codes gc
                                     ,subgroup_codes sgc
                             WHERE    i.owner_org_code LIKE eou.org_unit_cd||'%'
                             AND      i.ip_status = 'cur'
                             AND      i.print_flag = 'Y'
                             AND      i.owner_org_code = gc.owner_org_code
                             AND      i.phone_group = gc.phone_group
                             AND      gc.display_ind = 'Y'
                             AND      gc.owner_org_code = sgc.owner_org_code
                             AND      gc.phone_group = sgc.phone_group
                             AND      i.phone_subgroup = sgc.phone_subgroup
                             AND      sgc.display_ind = 'Y'
                     )
           ORDER BY  sort_order
                    ,hierarchy_level
                    ,org_unit_cd;

        -- internal procedure 2
        PROCEDURE clevel4 (clevel3_code VARCHAR2) IS
            CURSOR list_o_clevels4 IS
                SELECT     eou.org_unit_cd
                          ,eou.org_unit_desc
                          ,eou.local_name
                          ,DECODE(eou.sort_order, NULL, ' ' , TO_CHAR(eou.sort_order))  sort_order
                FROM       emp_org_unit eou
                WHERE      eou.org_unit_cd  LIKE     Clevel3_code || '%'
                AND        eou.hierarchy_level =    'CLEVEL4'
                AND        UPPER(eou.org_unit_desc) NOT LIKE '%DELETE%'
                AND       (SYSDATE BETWEEN eou.start_dt AND eou.end_dt OR eou.end_dt IS NULL)
                AND     EXISTS ( SELECT   *
                                 FROM     ip i
                                         ,group_codes gc
                                         ,subgroup_codes sgc
                                 WHERE    i.owner_org_code LIKE eou.org_unit_cd||'%'
                                 AND      i.ip_status = 'cur'
                                 AND      i.print_flag = 'Y'
                                 AND      i.owner_org_code = gc.owner_org_code
                                 AND      i.phone_group = gc.phone_group
                                 AND      gc.display_ind = 'Y'
                                 AND      gc.owner_org_code = sgc.owner_org_code
                                 AND      gc.phone_group = sgc.phone_group
                                 AND      i.phone_subgroup = sgc.phone_subgroup
                                 AND      sgc.display_ind = 'Y'
                         )
                ORDER BY eou.sort_order
                        ,eou.org_unit_cd;

        BEGIN
            htp.ulistopen;
            FOR clevel4_rec IN list_o_clevels4 LOOP
                g_background_shade := common_style.get_background_shade(g_background_shade);
                htp.p('<tr bgcolor="'||g_background_shade||'">');
                htp.p('<td width="15%"><a href="ph_updt_p.print_order_update?p_org_unit_code='||clevel4_rec.org_unit_cd||
                      '&p_sort_order='||clevel4_rec.sort_order||'">[Modify print order]</a>');
                htp.p('</td>');
                htp.p('<td align=center width="10%">'||clevel4_rec.sort_order);
                htp.p('</td>');
                htp.p('<td width="45%">&nbsp;&nbsp;&nbsp;&nbsp;'
                    ||'<a href="ph_updt_p.ph_list?p_org_unit_code='|| clevel4_rec.org_unit_cd||'">'|| ph_admin_p.org_code_desc(clevel4_rec.org_unit_cd)||'</a>');
                htp.p('</td>');
                htp.p('</tr>');

            END LOOP;
            htp.UListClose;
        END clevel4;

        -- procedure clevel3 statement begins
        BEGIN
            htp.ulistopen;
            FOR clevel3_rec IN list_o_clevels3 LOOP
                c3_cnt := check_clevel4(clevel3_rec.org_unit_cd);
                IF c3_cnt = 0 THEN
		           htp.p('<tr >');
				   htp.p('<td width="15%"><strong><a href="ph_updt_p.print_order_update?p_org_unit_code='||clevel3_rec.org_unit_cd||
                         '&p_sort_order='||clevel3_rec.sort_order||'">[Modify print order]</a></strong>');
		           htp.p('</td>');
		           htp.p('<td align=center width="10%"><strong>'||clevel3_rec.sort_order||'</strong>');
		           htp.p('</td>');
		           htp.p('<td width="45%"><strong>'||ph_admin_p.org_code_desc(clevel3_rec.org_unit_cd)||'</strong>');
		           htp.p('</td>');
                   htp.p('</tr>');
                ELSE
                   htp.p('<tr >');
		           htp.p('<td width="15%"><strong><a href="ph_updt_p.print_order_update?p_org_unit_code='||clevel3_rec.org_unit_cd||
                         '&p_sort_order='||clevel3_rec.sort_order||'">[Modify print order]</a></strong>');
		           htp.p('</td>');
				   htp.p('<td align=center width="10%"><strong>'||clevel3_rec.sort_order||'</strong>');
		           htp.p('</td>');
		           htp.p('<td width="45%"><strong><a href="ph_updt_p.ph_list?p_org_unit_code='||clevel3_rec.org_unit_cd||'">'||ph_admin_p.org_code_desc(clevel3_rec.org_unit_cd)||'</a></strong>');
		           htp.p('</td>');
                   htp.p('</tr>');
                END IF;
                Clevel4(clevel3_rec.org_unit_cd);
            END LOOP;
            htp.ulistclose;
        END Clevel3;

BEGIN

    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
                                           ,p_heading=>'Phone Group Updates for Department/School'
                                           ,p_help_url=>C_STRUC_HELP);

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

    SELECT    org_unit_cd
             ,org_unit_desc
    INTO      c2rec.org_unit_cd
             ,c2rec.org_unit_desc
    FROM      emp_org_unit
    WHERE     hierarchy_level IN ( 'CLEVEL2','CLEVEL3','CLEVEL4')
    AND       org_unit_cd  =  p_org_unit_code
    AND       LOWER(org_unit_desc)  <> 'central initiatives'
    AND       UPPER(org_unit_desc) NOT LIKE '%DELETE%'
    AND       (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
    ORDER BY  sort_order
	         ,hierarchy_level
             ,org_unit_cd;

    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > department/school listing');

	-- Heading
    htp.p('<h2>Phone Book</h2>');

    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                          ,p_activity_cd => 'View phone book for Department/School'
                          ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

    -- log audit information
    logger.audit(p_application_cd => g_application_cd
                        ,p_activity_cd => 'View phone book for Department/School');

    htp.p('Department/School listing for <strong>'||ph_admin_p.org_code_desc(c2rec.org_unit_cd)||'</strong>');
    htp.nl;
    htp.nl;

    htp.p('<table align=center cellspacing=0 border="0" width="75%">');
    htp.p('<tr>');
    htp.p('<td width="15%">&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('<td align=center width="10%"><strong>Print Order</strong>');
    htp.p('</td>');
    htp.p('<td width="45%"><strong>Departments/Schools</strong>');
    htp.p('</td>');
    htp.p('</tr>');
    htp.p('<tr>');
    htp.p('<td width="15%">&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('<td align=center width="10%">&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('<td width="45%">&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('</tr>');
    clevel3(c2rec.org_unit_cd);
    htp.p('</table>');

    htp.nl;
    htp.p('<div>');
    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > department/school listing');
    htp.p('</div>');
    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                          ,p_activity_cd => 'View phone book'
                          ,p_log_data => 'outcome="User attempted to access the phone book for Department/School but does not have access"');

        common_template.get_full_page_footer;
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END dep_sch;

PROCEDURE print_order_update
    (
     p_org_unit_code IN VARCHAR2 DEFAULT NULL
    ,p_sort_order    IN VARCHAR2 DEFAULT NULL
    ,p_update        IN VARCHAR2 DEFAULT NULL
    )
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
IS

    l_username    qv_client_computer_account.username%TYPE := qv_common_id.get_username;

    orgrec                  emp_org_unit%ROWTYPE;

BEGIN

    htp.p('<script language="Javascript">');
    htp.p('<!--');
    htp.p('function validateForm(form)');
    htp.p('{');
    
    htp.p('var printorder = document.getElementById("p_sort_order").value;');
    htp.p('if (printorder > 89)  ');
    htp.p('{');
    htp.p('var res = confirm("Are you sure you want to hide the faculty/school?"); ');
    htp.p('if (res == false) { return false; } ');
    htp.p('}');
   
    htp.p('} ');
    htp.p('//-->');
    htp.p('</script>');
    
    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
										   ,p_heading=>'Modify Print Order'
										   ,p_help_url=>C_STRUC_HELP );

	IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
	   RAISE g_restrict_access;
	END IF;

    SELECT   org_unit_cd
		    ,org_unit_desc description
		    ,sort_order
	INTO     orgrec.org_unit_cd
			,orgrec.org_unit_desc
	        ,orgrec.sort_order
    FROM     emp_org_unit
    WHERE    org_unit_cd = p_org_unit_code
	AND      (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);

	-- Set the navigation path
    IF length(p_org_unit_code) = 3 OR length(check_access_cd(p_org_unit_code, l_username)) = 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > update phone group order - '||LOWER(ph_admin_p.org_code_desc(p_org_unit_code)));
    ELSIF length(check_access_cd(p_org_unit_code, l_username)) < 6 AND length(p_org_unit_code) > 3  THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > update phone group order');
    END IF;

	-- Heading
	htp.p('<h2>Phone Book</h2>');

    IF p_update IS NULL THEN
       htp.p('<form method="post" action="ph_updt_p.print_order_update" onsubmit="javascript:return validateForm(this)">');
       htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
       htp.p('<input type="hidden" name="p_update" value="yes">');
       htp.nl;
       htp.p('Fill in the details and click <strong> SAVE </strong> at the end!');
       htp.nl;
       htp.nl;
       htp.p('Print Order:  <input type="text" id="p_sort_order" name="p_sort_order" value ="'||TRIM(orgrec.sort_order)||'" size="10" maxlength = "10">');
       htp.nl;
       htp.p('The Print Order range is between <strong>1</strong> to <strong>89</strong>.');        
       htp.p('To hide a school/faculty enter a print order range <strong>greater than 89</strong>.');
       htp.nl;
       htp.nl;
       htp.p('<input type="submit" value="SAVE"> <input type="reset" value="RESET">');
       htp.nl;
       htp.nl;
       htp.p('</form>');
    ELSIF p_update='yes' THEN

    	  UPDATE emp_org_unit
    	  SET    sort_order     = TRIM(p_sort_order)
    	  WHERE  org_unit_cd  = p_org_unit_code
		  AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);

--		  UPDATE codes
--		  SET	 print_order = TRIM(p_sort_order)
--		  WHERE	 code 		 = p_org_unit_code;

    	  COMMIT;

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                              ,p_activity_cd => 'Update phone group order');

        -- log audit information
        logger.audit(p_application_cd => g_application_cd
                            ,p_activity_cd => 'Update phone group order'
                            ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

    	  htp.p('<center><strong>Records Updated! </strong><br><br>');
          htp.p('Print order <strong>'||orgrec.sort_order||'</strong> changed to <strong>'||p_sort_order||'</strong>'
    	  ||' <br>for group <strong>'||ph_admin_p.org_code_desc(p_org_unit_code)||'</strong></center>');
    	  htp.nl;
		  htp.nl;
    	  htp.p('<a href="ph_updt_p.main_menu">Modify another print order</a>');
          htp.nl;
		  htp.nl;
    END IF;

    -- Set the navigation path
    IF length(p_org_unit_code) = 3 OR length(check_access_cd(p_org_unit_code, l_username)) = 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > update phone group order - '||LOWER(ph_admin_p.org_code_desc(p_org_unit_code)));
    ELSIF length(check_access_cd(p_org_unit_code, l_username)) < 6 AND length(p_org_unit_code) > 3  THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'phone group list</a> > update phone group order');
    END IF;
            common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');
        common_template.get_full_page_footer;

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                          ,p_activity_cd => 'Update phone group order'
                          ,p_log_data => 'outcome="User attempted to update phone group order but does not have access",org unit cd="'||p_org_unit_code||'"');

    WHEN error_message THEN
        ph_admin_p.error_message(g_message);
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END ;

PROCEDURE ph_list (p_org_unit_code IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------

CURSOR list_o_group IS
    SELECT   owner_org_code
            ,phone_group
            ,description
            ,print_order
            ,NVL(primary_extn,'----') primary_extn
            ,NVL(primary_fax,'----') primary_fax
            ,DECODE(display_ind,'Y','Yes','No') AS display_ind
    FROM     group_codes
    WHERE    owner_org_code = p_org_unit_code
    ORDER BY  owner_org_code
             ,print_order;

    l_username          qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    orgrec              emp_org_unit%ROWTYPE;
    l_cnt               NUMBER:=0;
    l_primary_fax_new   VARCHAR2(30);
    l_clevel            VARCHAR2(10);
    l_access_cd         access_type_member.access_cd%TYPE;

BEGIN

    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
									       ,p_heading=>'Phone Group Listing'
									       ,p_help_url=>C_STRUC_HELP);

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

    -- Determine if the Clevel code
    IF (length(p_org_unit_code)) > 1 THEN
	   l_clevel := 'CLEVEL'||(length(p_org_unit_code)-2);
    ELSE
	   l_clevel := 'CLEVEL1';
    END IF;

    -- Get the Clevel Description
    SELECT org_unit_cd
	      ,org_unit_desc
    INTO   orgrec.org_unit_cd
	      ,orgrec.org_unit_desc
    FROM   emp_org_unit
    WHERE  org_unit_cd  LIKE (p_org_unit_code||'%')
    AND    hierarchy_level = l_clevel
	AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > phone group updates');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > phone group updates');
    END IF;

    -- Heading
    htp.p('<h2>Phone Book</h2>');

    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                          ,p_activity_cd => 'View phone groups');

    -- log audit information
    logger.audit(p_application_cd => g_application_cd
                        ,p_activity_cd => 'View phone groups'
                        ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

    htp.p('Phone group updates for <strong>'||orgrec.org_unit_cd||'  '||orgrec.org_unit_desc||'</strong>');
    htp.nl;
    htp.nl;
	htp.p('  Click <strong>Modify</strong> or <strong>Delete</strong> to modify or delete the phone group from system.');
	htp.nl;
    htp.nl;
	htp.p('  Click <strong>phone group name</strong> to make changes on the job titles of the phone group.');
	htp.nl;
    htp.nl;
	htp.p('  Note: You cannot delete a phone group if there is any job title relevant to this phone group!');
	htp.nl;
    htp.nl;
	htp.p('<table align=center cellspacing=0 border="0" width="90%">');
    htp.p('<tr >');
    htp.p('<td><strong>Print Order</strong>');
    htp.p('</td>');
    htp.p('<td><strong>Enquiries</strong>');
    htp.p('</td>');
    htp.p('<td><strong>Fax</strong>');
    htp.p('</td>');
    htp.p('<td><strong>Phone Group Name</strong>');
    htp.p('</td>');
    htp.p('<td><strong>Number of Job Titles</strong>');
    htp.p('</td>');
    htp.p('<td>&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('<td>&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('<td><strong>Display</strong>');
    htp.p('</td>');
    htp.p('</tr>');

    FOR grouprec IN list_o_group LOOP
        l_cnt := l_cnt + 1;
	    FOR jobrec IN (SELECT  NVL(count(owner_org_code),0)  cnt
				   	   FROM    subgroup_codes
        			   WHERE   owner_org_code LIKE (grouprec.owner_org_code || '%')
        			   AND     phone_group    =     grouprec.phone_group) LOOP

		    g_background_shade := common_style.get_background_shade(g_background_shade);
            htp.p('<tr bgcolor="'||g_background_shade||'">');
            htp.p('<td>'||grouprec.print_order);
            htp.p('</td>');
            htp.p('<td>'||grouprec.primary_extn);
            htp.p('</td>');
            htp.p('<td>'||grouprec.primary_fax);
            htp.p('</td>');
            htp.p('<td>&nbsp;<a href="ph_updt_p.job_title?p_org_unit_code='||grouprec.owner_org_code ||
                  '&p_group_code=' || grouprec.phone_group || '">'||grouprec.description||'</a>');
            htp.p('</td>');
            htp.p('<td>'||jobrec.cnt);
            htp.p('</td>');
            htp.p('<td><a href="ph_updt_p.phone_group_update?p_org_unit_code='||grouprec.owner_org_code||
                  '&p_group_code=' || grouprec.phone_group || '">Modify</a>');
            htp.p('</td>');

		    IF jobrec.cnt =0 THEN
               htp.p('<td><a href="ph_updt_p.phone_group_delete?p_org_unit_code='||grouprec.owner_org_code||
                     '&p_group_code=' || grouprec.phone_group || '">Delete</a>');
            ELSIF  jobrec.cnt > 0 THEN
               htp.p('<td>&nbsp;&nbsp;');
            END IF;
            htp.p('</td>');
            htp.p('<td>'||grouprec.display_ind);
            htp.p('</td>');
            htp.p('</tr>');
		END LOOP;

    END LOOP;
    htp.p('</table>');
    htp.nl;
    htp.p('<strong>Total: '||l_cnt||' phone group members.</strong><br>');
    htp.nl;
    htp.p('<a href="ph_updt_p.phone_group_insert?p_org_unit_code='||p_org_unit_code||
          '"> Add a new group</a>');

    htp.nl;
    htp.nl;
    htp.p('<div>');
    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > phone group updates');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > phone group updates');
    END IF;
    htp.p('</div>');
    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<CENTER>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</CENTER>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                           ,p_activity_cd => 'View phone groups'
                           ,p_log_data => 'outcome="User attempted to view phone groups but does not have access",org unit cd="'||NVL(p_org_unit_code,'n/a')||'"');

        common_template.get_full_page_footer;
    WHEN error_message THEN
        ph_admin_p.error_message(g_message);
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END ph_list;

PROCEDURE phone_group_update
    (
     p_org_unit_code IN VARCHAR2 DEFAULT NULL
    ,p_group_code    IN VARCHAR2 DEFAULT NULL
    ,p_group_name    IN VARCHAR2 DEFAULT NULL
    ,p_print_order   IN VARCHAR2 DEFAULT NULL
    ,p_primary_extn  IN VARCHAR2 DEFAULT NULL
    ,p_primary_fax   IN VARCHAR2 DEFAULT NULL
    ,p_display_ind   IN VARCHAR2 DEFAULT NULL
    ,p_update        IN VARCHAR2 DEFAULT NULL
    )
IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------

    l_username               qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    grouprec                 group_codes%ROWTYPE;
    l_cnt                    NUMBER:=0;
    l_display_y_checked      VARCHAR2(10) := '';
    l_display_n_checked      VARCHAR2(10) := '';

BEGIN
    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
                                           ,p_heading=>'Modify Phone Group'
                                           ,p_help_url=>C_STRUC_HELP);

	IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
	END IF;

    SELECT  description
           ,print_order
    	   ,primary_extn
    	   ,primary_fax
           ,display_ind
    INTO    grouprec.description
           ,grouprec.print_order
    	   ,grouprec.primary_extn
    	   ,grouprec.primary_fax
           ,grouprec.display_ind
    FROM   group_codes
    WHERE  owner_org_code = p_org_unit_code
    AND    phone_group    = p_group_code;

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	modify phone group');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	modify phone group');
    END IF;

	-- Heading
    htp.p('<h2>Phone Book</h2>');

    IF p_update IS NULL THEN
       htp.p('Modify Phone Group <strong>'||p_org_unit_code||' '||grouprec.description||'</strong>');
       htp.p('<form method="post" action="ph_updt_p.phone_group_update">');
       htp.p('<input type="hidden" name="p_update" value="yes">');
       htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
       htp.p('<input type="hidden" name="p_group_code" value="'||p_group_code||'">');

	   htp.nl;

       htp.p('Fill in the details and click <strong> SAVE</strong> at the end!');

       htp.nl;
       htp.nl;

	   htp.p('<table cellspacing="0" align="left" cellpadding="3" border="0">');
	   htp.p('<tr>');
       htp.p('  <td>Phone Group:</td><td><input type="text" name="p_group_name" value ="'||TRIM(grouprec.description)||'" size="70" maxlength = "100">'
           ||'&nbsp;&nbsp;<strong>100</strong> character limit.</td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       htp.p('  <td>Print Order:</td><td><input type="text" name="p_print_order" value ="'||TRIM(grouprec.print_order)||'" size="10" maxlength = "10">'
           ||'&nbsp;&nbsp;The Print Order range is between <strong>1</strong> to <strong>999</strong>.</td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       htp.p('  <td>Enquiries:</td><td><input type="text" name="p_primary_extn" value ="'||TRIM(grouprec.primary_extn)||'" size="30" maxlength = "30">'
           ||'&nbsp;&nbsp;8 digit phone number (eg. 3138 1234)</td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       htp.p('  <td>Fax:</td><td><input type="text" name="p_primary_fax" value ="'||TRIM(grouprec.primary_fax)||'" size="30" maxlength = "30">'
           ||'&nbsp;&nbsp;8 digit fax number (eg. 3138 1234)</td>');
	   htp.p('</tr>');
       IF grouprec.display_ind = 'Y' THEN
           l_display_y_checked := 'checked';
           l_display_n_checked := '';
       ELSE
           l_display_n_checked := 'checked';
           l_display_y_checked := '';
       END IF;
       htp.p('  <td valign="top">Display:</td><td><input type="radio" name="p_display_ind" value="Y" '||l_display_y_checked||'> Yes &nbsp;&nbsp;&nbsp;Staff associated with this phone group will display in the both the external Phone Directory and '||ph_main.C_STAFF_SERVICE_NAME||' searches.<br>'||
                '<input type="radio" name="p_display_ind" value="N" '||l_display_n_checked||'> No &nbsp;&nbsp;&nbsp;&nbsp;Staff associated with this phone group will not display in the external Phone Directory, but will display in '||ph_main.C_STAFF_SERVICE_NAME||' searches.</td>');
	   htp.p(' </tr>');

       htp.p('<tr>');
	   htp.p('<td colspan="2">&nbsp;</td>');
	   htp.p('</tr>');
	   htp.p('<td colspan="2"><input type="submit" value="SAVE">  <input type="reset" value="RESET"></td>');
	   htp.p('</tr>');

	   htp.p('</table>');

       htp.p('</form>');


    ELSIF p_update = 'yes' THEN
       IF p_group_name IS NULL THEN
	      g_message:='The group name can not be empty!';
	      RAISE error_message;
	   ELSIF  p_print_order IS NULL THEN
	      g_message:='The print order must be filled!';
	      RAISE error_message;
	   ELSIF (p_print_order <1 OR p_print_order > 999) THEN
	      g_message :='The print order is out of range. Should be within 1 to 999!';
		  RAISE error_message;
	   ELSE

          UPDATE  group_codes
          SET     description    = TRIM(SUBSTR(p_group_name,1,100))
    	         ,print_order    = TRIM(p_print_order)
    	         ,primary_extn   = TRIM(p_primary_extn)
    	         ,primary_fax    = TRIM(p_primary_fax)
                 ,display_ind    = p_display_ind
          WHERE   owner_org_code = p_org_unit_code
          AND     phone_group    = p_group_code;

          -- Cach to make all associated subgroups not display if the parent group is set not to display.
          IF p_display_ind = 'N' THEN

             UPDATE subgroup_codes
             SET    display_ind    = 'N'
             WHERE  owner_org_code = p_org_unit_code
             AND    phone_group    = p_group_code;

          END IF;

          COMMIT;

          -- log page usage
             logger.usage(p_application_cd => g_application_cd
                                   ,p_activity_cd => 'Update phone group');

             -- log audit information
             logger.audit(p_application_cd => g_application_cd
                                 ,p_activity_cd => 'Update phone group'
                                 ,p_log_data => 'org unit cd="'||p_org_unit_code||'",group name="'||p_group_name||'"');

          htp.p('<center><strong>Records Updated! </strong><br><br>');
          htp.p('for phone group <strong>'||grouprec.description||'</center></strong>');

          htp.nl;
          htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||
                '">Update another phone group</a>');

       END IF;
    END IF;

	htp.p('<div style="clear:both;">&nbsp;</div>');

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	modify phone group');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	modify phone group');
    END IF;
       common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                           ,p_activity_cd => 'Modify phone group'
                           ,p_log_data => 'outcome="User attempted to modify phone group but does not have access",org unit cd="'||p_org_unit_code||'"');

        common_template.get_full_page_footer;
    WHEN error_message THEN
        ph_admin_p.error_message(g_message);
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END phone_group_update;

PROCEDURE phone_group_delete
    (
     p_org_unit_code IN VARCHAR2 DEFAULT NULL
    ,p_group_code    IN VARCHAR2 DEFAULT NULL
    ,p_delete        IN VARCHAR2 DEFAULT NULL
    )
IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
    l_username               qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    grouprec                 group_codes%ROWTYPE;
    l_subgroup_cnt           NUMBER:=0;

BEGIN
    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
									       ,p_heading=>'Modify a Phone Group'
									       ,p_help_url=>C_STRUC_HELP);

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

    SELECT description
	INTO   grouprec.description
	FROM   group_codes
	WHERE  owner_org_code = p_org_unit_code
	AND    phone_group    = p_group_code;

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	delete phone group');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	delete phone group');
       htp.nl;
       htp.nl;
    END IF;

	-- Heading
    htp.p('<h2>Phone Book</h2>');


	IF p_delete IS NULL THEN
	   htp.p('<center><form class="qv_form" method="post" action="ph_updt_p.phone_group_delete">');
       htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
       htp.p('<input type="hidden" name="p_group_code" value="'||p_group_code||'">');
       htp.p('<input type="hidden" name="p_delete" value="yes">');

       htp.p('Are you sure you want to remove <strong>'||p_org_unit_code||':'||grouprec.description||'</strong><br>');
       htp.nl;
       htp.p('<input type="submit" value="REMOVE">');
       htp.p('</form></center>');
    ELSIF p_delete='yes' THEN

       SELECT count(*) subgroup_cnt
       INTO   l_subgroup_cnt
       FROM   subgroup_codes
       WHERE  owner_org_code = p_org_unit_code
       AND    phone_group    = p_group_code;

	   IF l_subgroup_cnt = 0 then

		  DELETE group_codes
	      WHERE  owner_org_code = p_org_unit_code
	      AND    phone_group    = p_group_code;
	      COMMIT;

           -- log page usage
             logger.usage(p_application_cd => g_application_cd
                                   ,p_activity_cd => 'Delete phone group');

             -- log audit information
             logger.audit(p_application_cd => g_application_cd
                                 ,p_activity_cd => 'Delete phone group'
                                 ,p_log_data => 'org unit cd="'||p_org_unit_code||'",group cd="'||p_group_code||'"');

          htp.p('<center><strong>Record Deleted ! <br><br>');
          htp.p(p_org_unit_code||':'||grouprec.description||'</strong> has been removed</strong></center><br>');
          htp.nl;
          htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||
                '">Delete another phone group</a>');
          htp.nl;
       ELSE
	      g_message:='There are '||l_subgroup_cnt||' job titles relevant to this phone group!<br>'
                   ||'Please make sure no job titles are relevant to this phone group!';
          RAISE error_message;
       END IF;

	END IF;
    htp.nl;
    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	||'phone group updates</a> >	modify phone group');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	||'phone group updates</a> >	modify phone group');
    END IF;
        common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                           ,p_activity_cd => 'Delete phone group'
                           ,p_log_data => 'outcome="User attempted to delete phone group in phone book but does not have access."');

        common_template.get_full_page_footer;
    WHEN error_message THEN
        ph_admin_p.error_message(g_message);
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END phone_group_delete;

procedure phone_group_insert (p_org_unit_code IN VARCHAR2 DEFAULT NULL
		  					 ,p_group_code    IN VARCHAR2 DEFAULT NULL
							 ,p_group_name    IN VARCHAR2 DEFAULT NULL
							 ,p_print_order   IN VARCHAR2 DEFAULT NULL
							 ,p_primary_extn  IN VARCHAR2 DEFAULT NULL
							 ,p_primary_fax   IN VARCHAR2 DEFAULT NULL
                             ,p_display_ind   IN VARCHAR2 DEFAULT NULL
                             ,p_insert        IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------

    l_username      qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    orgrec          emp_org_unit%ROWTYPE;
    l_group_code    NUMBER;
    l_cnt			NUMBER :=0;

BEGIN
    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
                                           ,p_heading=>'Add New Phone Group'
                                           ,p_help_url=>C_STRUC_HELP );

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

	SELECT  count(*)
    INTO    l_cnt
    FROM    group_codes
    WHERE   owner_org_code = p_org_unit_code
	AND     phone_group    < 300;

	IF l_cnt = 0 THEN
		l_group_code := 1;
	ELSE
		SELECT MAX(phone_group)+1
		INTO   l_group_code
		FROM   group_codes
		WHERE  owner_org_code = p_org_unit_code
		AND    phone_group    < 300;
	END IF;

   -- Get the Clevel Description
    SELECT  org_unit_desc
	       ,sort_order
    INTO    orgrec.org_unit_desc
	       ,orgrec.sort_order
    FROM    emp_org_unit
    WHERE   org_unit_cd = p_org_unit_code;

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	add new phone group');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	add new phone group');
    END IF;

   	-- Heading
    htp.p('<h2>Phone Book</h2>');

    IF p_insert IS NULL THEN
	   htp.p('<p>Insert a new phone group in <strong>'||p_org_unit_code||': '||orgrec.org_unit_desc||'</strong></p>');
	   htp.p('<form method="post" ACTION="ph_updt_p.phone_group_insert">');
       htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
       htp.p('<input type="hidden" name="p_group_code" value="'||l_group_code||'">');
       htp.p('<input type="hidden" name="p_insert" value="yes">');
       htp.p('<p>Fill in the details and click <strong> SAVE</strong> at the end!</p>');

	   htp.p('<table cellspacing="0" cellpadding="3" border="0">');
	   htp.p('<tr>');
       htp.p('  <td>Phone Group:</td><td><input type="text" name="p_group_name"  size="70" maxlength = "100">'
           ||'&nbsp;&nbsp;<strong>100</strong> character limit.</td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       htp.p('  <td>Print Order:</td><td><input type="text" name="p_print_order"  size="10" maxlength = "10">'
           ||'&nbsp;&nbsp;The Print Order range is between <strong>1</strong> to <strong>999</strong>.</td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       htp.p('  <td>Phone:</td><td><input type="text" name="p_primary_extn"  size="20" maxlength = "20">'
           ||'&nbsp;&nbsp;8 digit phone number (eg. 3138 1234) </td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       htp.p('  <td>Fax:</td><td><input type="text" name="p_primary_fax" size="20" maxlength = "20">'
           ||'&nbsp;&nbsp;8 digit fax number (eg. 3138 1234) </td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       htp.p('  <td valign="top">Display:</td><td><input type="radio" name="p_display_ind" value="Y" checked>Yes &nbsp;&nbsp;&nbsp;Staff associated with this phone group will display in the both the external Phone Directory and '||ph_main.C_STAFF_SERVICE_NAME||' searches.<br>'||
             '  <input type="radio" name="p_display_ind" value="N">No &nbsp;&nbsp;&nbsp;&nbsp;Staff associated with this phone group will not display in the external Phone Directory, but will display in '||ph_main.C_STAFF_SERVICE_NAME||' searches.</td>');
	   htp.p('</tr>');
	   htp.p('</table>');
	   htp.nl;
       htp.p('<input type="submit" value="SAVE"> <input type="reset" value="RESET">');
       htp.p('</form>');

	ELSIF p_insert='yes' THEN
       IF p_group_name IS NULL THEN
	      g_message:='The group name must be filled!';
	      RAISE error_message;
	   ELSIF  p_print_order IS NULL THEN
	      g_message:='The print order must be filled!';
	      RAISE error_message;
	   ELSIF(p_print_order <1 OR p_print_order > 999) THEN
	      g_message :='The print order is out of range. Should be within 1 to 999!';
		  RAISE error_message;
	   ELSE

		  SELECT count(*)
		  INTO   l_cnt
		  FROM   group_codes
		  WHERE  owner_org_code = p_org_unit_code
		  AND    (phone_group   = p_group_code
		         OR print_order = TRIM(p_print_order))  ;

          IF l_cnt = 0 THEN

	         INSERT INTO group_codes (owner_org_code
		                             ,phone_group
                                     ,description
                                     ,print_order
                                     ,primary_extn
                                     ,primary_fax
                                     ,email_group_alias
                                     ,display_ind)
	         VALUES (p_org_unit_code
		            ,p_group_code
                    ,TRIM(SUBSTR(p_group_name,1,100))
                    ,TRIM(p_print_order)
                    ,TRIM(p_primary_extn)
                    ,TRIM(p_primary_fax)
                    ,NULL
                    ,p_display_ind);
	         COMMIT;


             -- log page usage
             logger.usage(p_application_cd => g_application_cd
                                   ,p_activity_cd => 'Create phone group');

             -- log audit information
             logger.audit(p_application_cd => g_application_cd
                                 ,p_activity_cd => 'Create phone group'
                                 ,p_log_data => 'org unit cd="'||p_org_unit_code||'",group name="'||p_group_name||'"');

             htp.p('<center><strong>Record Added !</strong><br><br>');
             htp.p('<strong>'||p_group_name||'</strong> was added in <strong>'||p_org_unit_code||': '||orgrec.org_unit_desc||'</strong></center>');
             htp.nl;
             htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||
                   '">Add another new phone group</a>');
             htp.nl;
             htp.nl;
          ELSE
			 htp.nl;
             htp.p('<center><strong> ERROR !<br><br>');
		     htp.p('The phone group has already existed!</strong></center>');
             htp.nl;
		  END IF;

	   END IF;
	END IF;
    
   htp.nl;
   htp.nl;    

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	add new phone group');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> >	add new phone group');
    END IF;

    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

         -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                           ,p_activity_cd => 'Create phone group'
                           ,p_log_data => 'outcome="User attempted to create phone group in phone book but does not have access."');

        common_template.get_full_page_footer;
    WHEN error_message THEN
        ph_admin_p.error_message(g_message);
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END phone_group_insert;

PROCEDURE job_title (p_org_unit_code IN VARCHAR2 DEFAULT NULL
                    ,p_group_code    IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------

CURSOR list_o_job is
    SELECT   owner_org_code
            ,phone_group
            ,phone_subgroup
            ,description
            ,print_order
            ,DECODE(display_ind,'Y','Yes','No') AS display_ind
    FROM     subgroup_codes
    WHERE    owner_org_code LIKE (p_org_unit_code || '%')
    AND      phone_group    = p_group_code
    ORDER BY owner_org_code
            ,phone_group
	        ,print_order;

    l_username          qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    coderec   			subgroup_codes%ROWTYPE;
    l_cnt           	NUMBER:=0;
    l_staff_cnt       	NUMBER:=0;

BEGIN

    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
                                           ,p_heading=>'Job Title Listing'
                                           ,p_help_url=>C_STRUC_HELP);

	IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

    SELECT owner_org_code
          ,NVL(description,' ')
          ,display_ind
    INTO   coderec.owner_org_code
          ,coderec.description
          ,coderec.display_ind
    FROM   group_codes
    WHERE  owner_org_code = p_org_unit_code
    AND    phone_group    = p_group_code;

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	||'phone group updates</a> > job title listing');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	||'phone group updates</a> > job title listing');
    END IF;

	-- Heading
    htp.p('<h2>Phone Book</h2>');

    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                         ,p_activity_cd => 'View job titles');

    -- log audit information
    logger.audit(p_application_cd => g_application_cd
                        ,p_activity_cd => 'View job titles'
                        ,p_log_data => 'group cd="'||NVL(p_group_code,'n/a')||'"');

    htp.p('Job title listing for <strong>'||coderec.owner_org_code||': '||coderec.description||'</strong>');
    htp.nl;
	htp.nl;
    htp.p('Note: You cannot delete a job title if there is any staff relevant to this job title!');
    htp.nl;
	htp.nl;
    htp.p('<table align=center cellspacing=0 border="0" width="80%">');
    htp.p('<tr >');
    htp.p('<td><strong>Print Order</strong>');
    htp.p('</td>');
    htp.p('<td><strong>Job Title</strong>');
    htp.p('</td>');
    htp.p('<td><strong>Number of Staff</strong>');
    htp.p('</td>');
    htp.p('<td>&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('<td>&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('<td><strong>Display</strong>');
    htp.p('</td>');
    htp.p('</tr>');

    FOR grouprec IN list_o_job LOOP

        SELECT count(DISTINCT ip.ip_num)
        INTO   l_staff_cnt
        FROM   ip
              ,qv_client_role r
        WHERE  ip.owner_org_code = p_org_unit_code
        AND    ip.phone_group    = grouprec.phone_group
        AND    ip.phone_subgroup = grouprec.phone_subgroup
        AND    ip.ip_num         = r.trs_client_id
        AND    r.role_cd         IN ('EMP','CCR')
        AND    r.role_active_ind = 'Y';

	    g_background_shade := common_style.get_background_shade(g_background_shade);
        htp.p('<tr bgcolor="'||g_background_shade||'">');
		htp.p('<td>'||grouprec.print_order);
		htp.p('</td>');
		htp.p('<td>'||grouprec.description);
		htp.p('</td>');

		IF l_staff_cnt > 0 THEN
		   htp.p('<td><a href="ph_updt_p.show_staff?p_org_unit_code='
                ||p_org_unit_code||'&p_group_code='|| grouprec.phone_group ||'&p_subgroup_code='|| grouprec.phone_subgroup ||'">'||l_staff_cnt||'</a>');
		ELSIF l_staff_cnt=0 THEN
           htp.p('<td>0');
		END IF;
		htp.p('</td>');
		htp.p('<td><a href="ph_updt_p.job_title_update?p_org_unit_code='||grouprec.owner_org_code ||
              '&p_group_code=' || grouprec.phone_group ||
              '&p_subgroup_code=' || grouprec.phone_subgroup || '">Modify</a>');
		htp.p('</td>');
		IF l_staff_cnt =0 THEN
	       htp.p('<td><a href="ph_updt_p.job_title_delete?p_org_unit_code='||grouprec.owner_org_code ||
	             '&p_group_code=' || grouprec.phone_group ||
	             '&p_subgroup_code=' || grouprec.phone_subgroup || '">Delete</a>');
		ELSIF l_staff_cnt>0 THEN
		   htp.p('<td>&nbsp;&nbsp;');
		END IF;
		htp.p('</td>');

        IF coderec.display_ind = 'N' THEN
            htp.p('<td>No</td>');
        ELSE
            htp.p('<td>'||grouprec.display_ind||'</td>');
	    END IF;
        htp.p('</tr>');

	    l_cnt := l_cnt + 1;
	    l_staff_cnt := 0;

    END LOOP;

    htp.p('</table>');
	htp.nl;
    htp.p('<strong>Total: '||l_cnt||' job titles.</strong>');
    htp.p('<a href="ph_updt_p.job_title_insert?p_org_unit_code='||
	      p_org_unit_code || '&p_group_code=' || p_group_code ||
	      '"> Add a new job title</a>');

	htp.nl;
	htp.nl;
    htp.p('<div>');
    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > job title listing');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > job title listing');
    END IF;
    htp.p('</div>');
    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p >You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                           ,p_activity_cd => 'View job titles'
                           ,p_log_data => 'outcome="User attempted to view job titles in phone book but does not have access."');

        common_template.get_full_page_footer;
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END job_title;

PROCEDURE job_title_update (p_org_unit_code  IN VARCHAR2 DEFAULT NULL
		      		       ,p_group_code 	 IN VARCHAR2 DEFAULT NULL
		                   ,p_subgroup_code  IN VARCHAR2 DEFAULT NULL
						   ,p_subgroup_name  IN VARCHAR2 DEFAULT NULL
						   ,p_print_order    IN VARCHAR2 DEFAULT NULL
                           ,p_display_ind    IN VARCHAR2 DEFAULT NULL
						   ,p_update         IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
    l_username               qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    l_staff_cnt              NUMBER :=0;
    grouprec                 group_codes%ROWTYPE;
    subrec                   subgroup_codes%ROWTYPE;
    l_cnt                    NUMBER :=0;
    l_display_y_checked      VARCHAR2(10) := '';
    l_display_n_checked      VARCHAR2(10) := '';

BEGIN
    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
                                           ,p_heading=>'Modify Job Title Details'
                                           ,p_help_url=>C_STRUC_HELP);

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

    SELECT   description
            ,print_order
            ,display_ind
    INTO     subrec.description
            ,subrec.print_order
            ,subrec.display_ind
    FROM    subgroup_codes
    WHERE   owner_org_code = p_org_unit_code
    AND     phone_group    = p_group_code
    AND     phone_subgroup = p_subgroup_code;

    --Get the Clevel Description
    SELECT  NVL(description,' ') description
           ,display_ind
    INTO    grouprec.description
           ,grouprec.display_ind
    FROM    group_codes
    WHERE   owner_org_code = p_org_unit_code
    AND     phone_group    = p_group_code;

    --Get the number of staff with the same title in the group
    SELECT  count(DISTINCT ip.ip_num)
    INTO    l_staff_cnt
    FROM    ip
           ,qv_client_role r
    WHERE  ip.owner_org_code = p_org_unit_code
    AND    ip.phone_group    = p_group_code
    AND    ip.phone_subgroup = p_subgroup_code
    AND    ip.ip_num         = r.trs_client_id
    AND    r.role_cd         IN ('EMP', 'CCR')
    AND    r.role_active_ind = 'Y';

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	||'job title listing</a> >	modify job title');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	||'job title listing</a> >	modify job title');
    END IF;

	-- Heading
    htp.p('<h2>Phone Book</h2>');

    IF p_update IS NULL THEN
       htp.p('<form method="post" action="ph_updt_p.job_title_update">');
       htp.p('<input type="hidden" name="p_update" value="yes">');
	   htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
       htp.p('<input type="hidden" name="p_group_code" value="'||p_group_code||'">');
	   htp.p('<input type="hidden" name="p_subgroup_code" value="'||p_subgroup_code||'">');

       IF l_staff_cnt = 0 then
	      htp.p('Fill in the details and click '||'<strong>SAVE</strong>  at the end!');
	      htp.nl;
		  htp.nl;
	      htp.p('<strong>Note</strong>:'||' There are no staff member assigned to this job title.');
       ELSE
	      htp.p('Fill in the details and click <strong> SAVE</strong> at the end!');
	      htp.nl;
		  htp.nl;
	      htp.p('<strong>Note</strong>: There are '||
	            '<a href="ph_updt_p.show_staff?p_org_unit_code='||
	            p_org_unit_code||'&p_group_code='|| p_group_code ||'&p_subgroup_code='|| p_subgroup_code ||'">'
	           ||l_staff_cnt|| '</a> staff member(s) assigned to this job title.');
       END IF;
       htp.nl;
       htp.nl;
	   htp.p(' <table cellspacing="0" cellpadding="3" border="0">');
	   htp.p(' <tr>');
       htp.p('  <td>Job Title:</td><td><input type="text" name="p_subgroup_name" value ="'||TRIM(' ' FROM subrec.description)||'" size="70" maxlength = "100">'
	       ||'&nbsp;&nbsp;<strong>100</strong> character limit.</td>');
	   htp.p(' </tr>');
	   htp.p(' <tr>');
	   htp.p('  <td>Print Order:</td><td><input type="text" name="p_print_order" value ="'||TRIM(' ' FROM subrec.print_order)||'" size="10" maxlength = "10">'
	       ||'&nbsp;&nbsp;The Print Order range is between <strong>1</strong> to <strong>999</strong>.</td>');
	   htp.p(' </tr>');
	   htp.p(' <tr>');
       IF subrec.display_ind = 'Y' AND grouprec.display_ind = 'Y' THEN
           l_display_y_checked := 'checked';
           l_display_n_checked := '';
       ELSE
           l_display_n_checked := 'checked';
           l_display_y_checked := '';
       END IF;

       IF grouprec.display_ind = 'N' THEN
           htp.p('  <td valign="top">Display:</td><td><input type="radio" name="p_display_ind" value="Y" '||l_display_y_checked||' DISABLED> Yes &nbsp;&nbsp;&nbsp;Staff associated with this job title will display in the both the external Phone Directory and '||ph_main.C_STAFF_SERVICE_NAME||' searches.<br>'||
    	         '<input type="radio" name="p_display_ind" value="N" '||l_display_n_checked||' DISABLED> No &nbsp;&nbsp;&nbsp;&nbsp;Staff associated with this job title will not display in the external Phone Directory, but will display in '||ph_main.C_STAFF_SERVICE_NAME||' searches.'||
                 -- Include the value as a hidden input field for the p_display_ind as it is disabled due to the parent phone group being set not to display.
                 '<input type="hidden" name="p_display_ind" value="N"/></td>');
       ELSE
           htp.p('  <td valign="top">Display:</td><td><input type="radio" name="p_display_ind" value="Y" '||l_display_y_checked||'> Yes &nbsp;&nbsp;&nbsp;Staff associated with this job title will display in the both the external Phone Directory and '||ph_main.C_STAFF_SERVICE_NAME||' searches.<br>'||
                 '<input type="radio" name="p_display_ind" value="N" '||l_display_n_checked||'> No &nbsp;&nbsp;&nbsp;&nbsp;Staff associated with this job title will not display in the external Phone Directory, but will display in '||ph_main.C_STAFF_SERVICE_NAME||' searches.</td>');
	   END IF;
       htp.p(' </tr>');
	   htp.p(' <tr>');
	   htp.p('<td colpspan="2">&nbsp;</td>');
	   htp.p(' </tr>');
	   htp.p(' <tr>');
       htp.p('<td colpspan="2"><input type="submit" value="SAVE"> <input type="reset" value="RESET"></td>');
	   htp.p(' </tr>');
	   htp.p(' </table>');

       htp.p('</form>');

    ELSIF p_update ='yes' THEN

	   IF p_subgroup_name IS NULL THEN
	      g_message:='The Job Title should not be empty! ';
		  RAISE error_message;
	   ELSIF (p_print_order <1 OR p_print_order > 999) THEN
	      g_message :='The Print Order is out of range. Should be within 1 to 999!';
		  RAISE error_message;
	   ELSE

          UPDATE  subgroup_codes
          SET     description    = TRIM(p_subgroup_name)
		         ,print_order    = TRIM(p_print_order)
                 ,display_ind    = p_display_ind
		  WHERE   owner_org_code = p_org_unit_code
		  AND     phone_group    = p_group_code
		  AND     phone_subgroup = p_subgroup_code;
          COMMIT;

       -- log page usage
       logger.usage(p_application_cd => g_application_cd
                             ,p_activity_cd => 'Update job title');

        -- log audit information
       logger.audit(p_application_cd => g_application_cd
                            ,p_activity_cd => 'Update job title'
                            ,p_log_data => 'org unit cd="'||NVL(p_org_unit_code,'n/a')||'",group cd="'||NVL(p_group_code,'n/a')||'",subgroup cd="'||NVL(p_subgroup_code,'n/a')||'",subgroup name="'||NVL(p_subgroup_name,'n/a')||'"');

		  htp.p('<center><strong>Records Updated! </strong><br><br>');
          htp.p(' for job <strong>'||subrec.description||'</strong><br></center>');

          htp.nl;

          htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||
		        '&p_group_code=' || p_group_code||'">Update another job title</a>');
		  htp.nl;
		  htp.nl;

	   END IF;
    END IF;

     -- Set the navigation path
    IF LENGTH(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> >	modify job title');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
           ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
           ||'job title listing</a> >	modify job title');
    END IF;
       common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');
        common_template.get_full_page_footer;

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                           ,p_activity_cd => 'Update job title'
                           ,p_log_data => 'outcome="User attempted to update job title in phone book but does not have access."');

    WHEN error_message THEN
        ph_admin_p.error_message(g_message);
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END job_title_update;

PROCEDURE job_title_delete (p_org_unit_code  IN VARCHAR2 DEFAULT NULL
		      		       ,p_group_code 	 IN VARCHAR2 DEFAULT NULL
		                   ,p_subgroup_code  IN VARCHAR2 DEFAULT NULL
						   ,p_delete         IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
    l_username               qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    l_staff_cnt              NUMBER:=0;
    grouprec                 group_codes%ROWTYPE;
    subrec                   subgroup_codes%ROWTYPE;

BEGIN
    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
                                           ,p_heading=>'Delete Job Title'
                                           ,p_help_url=>C_STRUC_HELP);

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

    SELECT   description
            ,print_order
    INTO     subrec.description
            ,subrec.print_order
    FROM    subgroup_codes
    WHERE   owner_org_code = p_org_unit_code
    AND     phone_group    = p_group_code
    AND     phone_subgroup = p_subgroup_code;

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> >	delete job title');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> >	delete job title');
    END IF;

	-- Heading
    htp.p('<h2>Phone Book</h2>');

    IF p_delete IS NULL THEN
       htp.p('<center><form method="post" ACTION="ph_updt_p.job_title_delete">');
       htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
       htp.p('<input type="hidden" name="p_group_code" value="'||p_group_code||'">');
       htp.p('<input type="hidden" name="p_subgroup_code" value="'||p_subgroup_code||'">');
       htp.p('<input type="hidden" name="p_delete" value="yes">');

       htp.p('Are you sure you want to remove <strong>'||subrec.description||'</strong>');
	   htp.nl;
	   htp.nl;
       htp.p('<input type="submit" value="REMOVE">');
       htp.p('</form></center>');
    ELSIF p_delete='yes' THEN
       SELECT COUNT(DISTINCT ip.ip_num)
       INTO   l_staff_cnt
       FROM   ip
	         ,qv_client_role r
       WHERE  ip.owner_org_code = p_org_unit_code
       AND    ip.phone_group    = p_group_code
       AND    ip.phone_subgroup = p_subgroup_code
       AND    ip.ip_num         = r.trs_client_id
       AND    r.role_cd         IN ('EMP','CCR')
       AND    r.role_active_ind = 'Y';

       IF l_staff_cnt = '0' then

          DELETE FROM subgroup_codes
          WHERE       owner_org_code = p_org_unit_code
          AND         phone_group    = p_group_code
          AND         phone_subgroup = p_subgroup_code;
          COMMIT;

        -- log page usage
       logger.usage(p_application_cd => g_application_cd
                             ,p_activity_cd => 'Delete job title');

        -- log audit information
        logger.audit(p_application_cd => g_application_cd
                            ,p_activity_cd => 'Delete job title'
                            ,p_log_data => 'org unit cd="'||p_org_unit_code||'",group cd="'||p_group_code||'",subgroup cd="'||p_subgroup_code||'"');

		  htp.p('<center><strong>Record Deleted ! <br><br>');
          htp.p('<strong>'||subrec.description||'</strong> has been removed.</strong></center>');
	      htp.nl;
		  htp.nl;
	      htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||
		        '&p_group_code=' || p_group_code||'">Delete another job title</a>');
   	      htp.nl;

       ELSE
          g_message := 'There are '||l_staff_cnt||' staffs relevant to this job title!<br>'
                     ||'Please make sure no staffs are relevant to this job title!';
          RAISE error_message;
       END IF;
    END IF;
	htp.nl;
    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
           ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
           ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
           ||'job title listing</a> >	delete job title');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
           ||'phone group updates</a> > ');
	   htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
           ||'job title listing</a> >	delete job title');
    END IF;
       common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');
        common_template.get_full_page_footer;

         -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                           ,p_activity_cd => 'Delete job title'
                           ,p_log_data => 'outcome="User attempted to delete job title in phone book but does not have access."');

    WHEN error_message THEN
        ph_admin_p.error_message(g_message);
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END job_title_delete;

PROCEDURE job_title_insert (p_org_unit_code IN VARCHAR2 DEFAULT NULL
			               ,p_group_code    IN VARCHAR2 DEFAULT NULL
						   ,p_subgroup_code IN VARCHAR2 DEFAULT NULL
			   			   ,p_subgroup_name IN VARCHAR2 DEFAULT NULL
			   			   ,p_print_order   IN VARCHAR2 DEFAULT NULL
                           ,p_display_ind   IN VARCHAR2 DEFAULT NULL
					       ,p_insert        IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
    l_username           qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    l_subgroup_code      NUMBER;
    grouprec			 group_codes%ROWTYPE;
    l_cnt			     NUMBER:=0;
BEGIN
	common_template.get_full_page_header(p_title=>C_STRUC_HEADER
                                           ,p_heading=>'Add New Job Title'
                                           ,p_help_url=>C_STRUC_HELP);

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

    SELECT COUNT(*)
    INTO   l_cnt
    FROM   subgroup_codes
    WHERE  owner_org_code = p_org_unit_code
    AND    phone_group    = p_group_code
    AND    phone_subgroup < 300;

	IF l_cnt = 0 THEN
        l_subgroup_code := 1;
	ELSE
		SELECT MAX(phone_subgroup)+1
		INTO   l_subgroup_code
		FROM   subgroup_codes
		WHERE  owner_org_code = p_org_unit_code
		AND    phone_group    = p_group_code
		AND    phone_subgroup < 300;
	END IF;

    --Get the Clevel Description
    SELECT NVL(description,' ') description
          ,display_ind
    INTO   grouprec.description
          ,grouprec.display_ind
    FROM   group_codes
    WHERE  owner_org_code = p_org_unit_code
    AND    phone_group    = p_group_code;

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> >	add new job title');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> >	add new job title');
    END IF;

	-- Heading
    htp.p('<h2>Phone Book</h2>');

	IF p_insert IS NULL THEN
       htp.p('<p>Insert a new job title in <strong>'||p_org_unit_code||': '||grouprec.description||'</strong></p>');
       htp.p('<form method="post" ACTION="ph_updt_p.job_title_insert">');
       htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
       htp.p('<input type="hidden" name="p_group_code" value="'||p_group_code||'">');
       htp.p('<input type="hidden" name="p_subgroup_code" value="'||l_subgroup_code||'">');
       htp.p('<input type="hidden" name="p_insert" value="yes">');
       htp.p('<p>Fill in the details and click <strong> SAVE</strong> at the end!</p>');

	   htp.p('<table cellspacing="0" cellpadding="3" boder="0">');
	   htp.p('<tr>');
       htp.p('  <td>Job Title:</td><td><input type="text" name="p_subgroup_name"  size="70" maxlength = "100">'
	       ||'&nbsp;&nbsp;<strong>100</strong> character limit.</td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       htp.p('  <td>Print Order:</td><td><input type="text" name="p_print_order"  size="10" maxlength = "10">'
	       ||'&nbsp;&nbsp;The Print Order range is between <strong>1</strong> to <strong>999</strong>.</td>');
	   htp.p('</tr>');
	   htp.p('<tr>');
       IF grouprec.display_ind = 'N' THEN
           htp.p('  <td valign="top">Display:</td><td><input type="radio" name="p_display_ind" value="Y" DISABLED>Yes &nbsp;&nbsp;&nbsp;Staff associated with this job title will display in the both the external Phone Directory and '||ph_main.C_STAFF_SERVICE_NAME||' searches.<br>'||
                 '<input type="radio" name="p_display_ind" value="N" checked DISABLED>No &nbsp;&nbsp;&nbsp;&nbsp;Staff associated with this job title will not display in the external Phone Directory, but will display in '||ph_main.C_STAFF_SERVICE_NAME||' searches.'||
                 -- Include the value as a hidden input field for the p_display_ind as it is disabled due to the parent phone group being set not to display.
                 '<input type="hidden" name="p_display_ind" value="N"/></td>');
	   ELSE
           htp.p('  <td valign="top">Display:</td><td><input type="radio" name="p_display_ind" value="Y" checked> Yes &nbsp;&nbsp;&nbsp;Staff associated with this job title will display in the both the external Phone Directory and '||ph_main.C_STAFF_SERVICE_NAME||' searches.<br>'||
    	         '<input type="radio" name="p_display_ind" value="N"> No &nbsp;&nbsp;&nbsp;&nbsp;Staff associated with this job title will not display in the external Phone Directory, but will display in '||ph_main.C_STAFF_SERVICE_NAME||' searches.</td>');
       END IF;
       htp.p('</tr>');
	   htp.p('</table>');
	   htp.nl;
       htp.p('<input type="submit" value="SAVE"> <input type="reset" value="RESET">');
       htp.p('</form>');

    ELSIF p_insert='yes' THEN
	   IF p_subgroup_name IS NULL THEN
	      g_message:='The group name must be filled!';
	      RAISE error_message;
	   ELSIF  p_print_order IS NULL THEN
	      g_message:='The print order must be filled!';
	      RAISE error_message;
	   ELSIF(p_print_order <1 OR p_print_order > 999) THEN
	      g_message :='The print order is out of range. Should be within 1 to 999!';
		  RAISE error_message;
	   ELSE
          SELECT count(*)
          INTO   l_cnt
          FROM   subgroup_codes
          WHERE  owner_org_code  = p_org_unit_code
          AND    phone_group     = p_group_code
          AND    (phone_subgroup = p_subgroup_code
			      OR print_order = TRIM(p_print_order));

          IF l_cnt = 0 THEN
             INSERT INTO subgroup_codes (owner_org_code
    		                            ,phone_group
    									,phone_subgroup
    									,description
    									,print_order
                                        ,display_ind)
    		 VALUES (p_org_unit_code
    		        ,p_group_code
    			    ,p_subgroup_code
    			    ,TRIM(p_subgroup_name)
                    ,TRIM(p_print_order)
                    ,p_display_ind);

             COMMIT;

         -- log page usage
       logger.usage(p_application_cd => g_application_cd
                             ,p_activity_cd => 'Create job title');

        -- log audit information
        logger.audit(p_application_cd => g_application_cd
                            ,p_activity_cd => 'Create job title'
                            ,p_log_data => 'org unit cd="'||p_org_unit_code||'",group cd="'||p_group_code||'",subgroup cd="'||p_subgroup_code||'"');

			 htp.p('<center><strong>Record Added !</strong><br><br>');
		     htp.p('<strong>'||p_subgroup_name||'</strong> was added in <strong>'||p_org_unit_code||': '||grouprec.description||'</strong></center>');
             htp.nl;
			 htp.nl;
		     htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||
		           '&p_group_code=' || p_group_code||'">Add another job title</a>');
			 htp.nl;
			 htp.nl;

          ELSE
			 htp.nl;htp.nl;
			 htp.p('<center><strong> ERROR !<br><br>');
		     htp.p('The job title has already existed!</strong></center>');
             htp.nl;htp.nl;
          END IF;

       END IF;

    END IF;
    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> >	add new job title');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> >	add new job title');
    END IF;
       common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');
        common_template.get_full_page_footer;

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                          ,p_activity_cd => 'Create job title'
                          ,p_log_data => 'outcome="User attempted to create job title in phone book but does not have access"');

    WHEN error_message THEN
        ph_admin_p.error_message(g_message);
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END job_title_insert;

PROCEDURE show_staff (p_org_unit_code IN VARCHAR2 DEFAULT NULL
			         ,p_group_code    IN VARCHAR2 DEFAULT NULL
			 		 ,p_subgroup_code IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
CURSOR list_o_staff IS
    SELECT DISTINCT qv_common.get_surname(r.username)  surname
                   ,qv_common.get_preferred_name(r.username)   preferred_name
                   ,r.id            id
                   ,r.role_cd       role_cd
                   ,r.trs_client_id client_id
    FROM   ip
          ,qv_client_role r
    WHERE  owner_org_code    = p_org_unit_code
    AND    phone_group       = p_group_code
    AND    phone_subgroup    = p_subgroup_code
    AND    r.role_cd         IN ('CCR','EMP')
    AND    r.role_active_ind = 'Y'
    AND    r.trs_client_id   = ip.ip_num
    ORDER BY surname
            ,preferred_name;

    staffs list_o_staff%ROWTYPE;
    l_username              qv_client_computer_account.username%TYPE := qv_common_id.get_username;
    l_cnt                   NUMBER:=0;
    grouprec				group_codes%ROWTYPE;
    subgrouprec             subgroup_codes%ROWTYPE;


BEGIN
    common_template.get_full_page_header(p_title=>C_STRUC_HEADER
									      ,p_heading=>'Staff Listing'
									      ,p_help_url=>C_STRUC_HELP);

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
       RAISE g_restrict_access;
    END IF;

    -- Get Job Title
    SELECT description
    INTO   subgrouprec.description
    FROM   subgroup_codes
    WHERE  owner_org_code  = p_org_unit_code
    AND    phone_group     = p_group_code
    AND    phone_subgroup  = p_subgroup_code;

    -- Get Phone Group Name
    SELECT NVL(description,' ') description
    INTO   grouprec.description
    FROM   group_codes
    WHERE  owner_org_code = p_org_unit_code
    AND    phone_group    = p_group_code;

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> > staff listing');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> > staff listing');
    END IF;

	-- Heading
	htp.p('<h2>Phone Book</h2>');

    htp.p('Staff member(s) assigned to Job Title <strong>'||subgrouprec.description||'</strong>');
    htp.p('in Phone Group <strong>'||grouprec.description||'</strong>');

    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                          ,p_activity_cd => 'View staff members assigned to job title');

    -- log audit information
    logger.audit(p_application_cd => g_application_cd
                            ,p_activity_cd => 'View staff members assigned to job title'
                            ,p_log_data => 'org unit cd="'||NVL(p_org_unit_code,'n/a')||'",group cd="'||NVL(p_group_code,'n/a')||'",subgroup cd="'||NVL(p_subgroup_code,'n/a')||'"');

	htp.nl;
	htp.nl;

    FOR r IN list_o_staff LOOP
        l_cnt :=l_cnt+1;
	    IF r.role_cd='EMP' THEN
	       htp.p('<a href="srch_common_people_p.show?p_arg_names=p_id&p_arg_values='||r.id
							  ||'&p_arg_names=p_ip_type&p_arg_values='||r.role_cd
							  ||'&p_arg_names=p_show_mode&p_arg_values='||srch_stu_people.C_SRCH_STU_PEOPLE_3
							  ||'&p_arg_names=p_from&p_arg_values='||srch_stu_people.C_FROM_PORTLET
							  ||'">'
                              ||r.surname||', '||r.preferred_name||'</a>');
           htp.nl;
	    ELSE
	       htp.p('<a href="srch_common_people_p.show?p_arg_names=p_id&p_arg_values='||r.client_id
							  ||'&p_arg_names=p_ip_type&p_arg_values='||r.role_cd
							  ||'&p_arg_names=p_show_mode&p_arg_values='||srch_stu_people.C_SRCH_STU_PEOPLE_3
							  ||'&p_arg_names=p_from&p_arg_values='||srch_stu_people.C_FROM_PORTLET
							  ||'">'
                              ||r.surname||', '||r.preferred_name||'</a>');
           htp.nl;
	    END IF;
    END LOOP;

    IF l_cnt = 0 THEN
       htp.p('<strong>There are no records for this Group! No records to display!</strong>');
    END IF;
    htp.nl;
    htp.p('<strong>Total: '||l_cnt||' staff member(s).</strong>');
    htp.nl;
    htp.nl;

    -- Set the navigation path
    IF length(check_access_cd(p_org_unit_code, l_username)) < 6 THEN
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.dep_sch?p_org_unit_code='||check_access_cd(p_org_unit_code, l_username)||'">'
    	   ||'department/school listing</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
           ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
           ||'job title listing</a> > staff listing');
    ELSE
       htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
       htp.p('<a href="ph_updt_p.main_menu">'||LOWER(C_STRUC_HEADER)||'</a> > ');
       htp.p('<a href="ph_updt_p.ph_list?p_org_unit_code='||p_org_unit_code||'">'
    	   ||'phone group updates</a> > ');
       htp.p('<a href="ph_updt_p.job_title?p_org_unit_code='||p_org_unit_code||'&p_group_code='||p_group_code||'">'
    	   ||'job title listing</a> > staff listing');
    END IF;
       common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                          ,p_activity_cd => 'View staff members assigned to job title'
                          ,p_log_data => 'outcome="User attempted to view staff members assigned to job title but does not have access"');

        common_template.get_full_page_footer;
    WHEN OTHERS THEN
        htp.p('<p>There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.ulistclose;
        common_template.get_full_page_footer;
END show_staff;

PROCEDURE help( p_arg_values IN VARCHAR2 DEFAULT NULL) IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
BEGIN

    IF p_arg_values= 'struct_help' THEN
	   common_template.get_help_page_header(
						                       p_title    => C_STRUC_HEADER
   					                          ,p_heading  => C_STRUC_HEADER
			                                  );

	   htp.p('<p>');
	   htp.p('The QUT Phone Book Workgroup Structure Function allows you to modify your QUT '
	       ||'work group structure. You can navigate the QUT Organisational Units you have access '
	       ||'to and make the following changes:</p>');

       htp.p('<p>You can modify the print order of your Division/Faculty/Section/School to '
           ||'appear in a different order in the phone book by clicking on the [Modify print order] '
           ||'hyperlink preceding the relevant organisational unit name.</p>');

       htp.p('<p>You can add/remove/modify various Phone Groups (known as sub sections) that '
           ||'are located within your Divisional Sections/Faculty Schools/Centres.');
       htp.p('<ol>');
       htp.p('<li>Click on the relevant link, Modify, Delete or Add a new group'
           ||' to invoke these functions.');

       htp.p('<li>When adding a Phone Group you must specify a Name [Max Characters (100)], a '
           ||'Print Order [1-998],and a Fax and Phone Number for the primary contact for the phone group'
		   ||' Phone and Fax numbers may be omitted.');

	   htp.p('<li>You must allocate print order ''999'' to the Undefined Phone Group which is MANDATORY for all Phone Groups.');
       htp.p('</ol></p>');

       htp.p('<p>You can add/modify/remove various Job Titles by clicking on the relevant Phone'
           ||' Group that the job titles belong to.');
	   htp.p('<ol>');
       htp.p('<li>Click on the relevant link, Modify, Delete or Add Job title  '
	       ||'Title to invoke these functions.');
	   htp.p('<li>When adding a Job Title you must specify a name [Max Characters (100)] and a'
	       ||'print order [1-998]');
       htp.p('<li>You must allocate print order ''999'' to the Undefined Title which is MANDATORY.');
       htp.p('</ol></p>');

	   htp.p('<p>');
       htp.p('It is the combination of phone group and job title that staff are assigned to for'
           ||' grouping in the phone book. A staff member will be allocated the default '
           ||'Group/Title of Undefined/Undefined when they are first allocated to the section.');
       htp.p('</p>');

	END IF;
    common_template.get_full_page_footer;

END help;

END ph_updt_p;
/