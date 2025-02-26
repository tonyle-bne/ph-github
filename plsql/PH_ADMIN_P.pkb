CREATE OR REPLACE PACKAGE BODY ph_admin_p IS
/**
* Phone book administration
*/
--------------------------------------------------------------------------------------
-- Package Name: ph_admin_p
-- Author:       Amy Zhang
-- Purpose:      Phonebook Adminstration Activities
-- Created:      28-Aug-2002
-- Modification:
-- 23 Sep  2002 Amy Zhang Correct some spelling and font format
--                        Add active_flag='Y''in all SQL statments using emp_org_unit table
-- 22 Oct 2002  Amy Zhang Fixed up the staff title display
-- 23 OCt 2002  Amy Zhang Modified to only allow EMP staff updated at this stage
-- 19 NOV 2002  Amy Zhang Display staff based on work structure , and allow CCR staff to be
--                        updated here
-- 04 Mar 2003  Amy Zhang Modified cursors in dep_sch_list, display all areas regardless
--                        if there is any staff attached.
-- 12 Mar 2003  Evan Wood Modified Org unit name update to change codes as well to prevent overwrites
-- 14 Mar 2003  Amy Zhang Fixed too_many_rows return error in procedure add_admin
-- 17 Jun 2005  D Hunt    Added location dropdown boxes
-- 24 Jun 2005  D Hunt    Swaped campus and title fields on staff updates screen
-- 11 Nov 2005  Fook Lee  Added Closed User Group number to staff_update
-- 01 Aug 2006  Evan Wood 10g UPGRADE - Removed calls to common_style;
--                        Corrected qv_common_links references to use the qv_common_links.get_reference_link;
--                        Replaced Phone Book Administration email referece to appropriate qv_common_links.get_reference_link call;
--                        Replaced QUT Phone Extention Prefix to appropriate qv_common_links.get_reference_link call;
--						  Replaced deprecated <b> & </b> tags with <strong> & </strong>;
--	 					  Removed the <pre> & </pre> tags as they were efficting the application display;
--						  Corrected Layouts from the removal of the <pre> tags.
--						  Fixed Spacing & Character Case issues identified;
-- 23-Nov-2006  M Huth	  Added in passing of l_username into ph_updt_p.check_access_cd function to improve
-- 				  		  performance
-- 28-Nov-2006  E Wood	  Made Form Layout / Element Note changes as per Sharyn Leeman's Request.
-- 26-Mar-2007  E Wood    Modified application to show P prefixed organisational units.
--                        Added has_qut_access(p_username) Function returns a boolean value if the username has access to all
--                        QUT areas within the phone book.
--                        Tidied up some ordering of organisational unit listings.
--                        Added releveant calls to UPPER() and LOWER() for Cursors.
-- 04-May-2007  M Huth    Removed usage of g_username which may be causing Portal function calls to be called recursively.
--                        Put username into local subprograms instead.
-- 07-Dec-2008  C.Wong    Fix body onload references, replace with addLoadEvent
-- 22-Dec-2008  J Choy    Uppercase display of staff group
-- 23-03-2009   Tony Le   SAMS upgrade
-- 26-05-2009   Tony Le   Replace references emp_org_unit with emp_org_unit
-- 17-06-2009   Tony Le   Remove any references to codes table
-- 03-Aug-2010  L Lin     changes on staff image display options to use the new table of qv_image_display instead of ip.image_flag table.
-- 23-Aug_2010  L Lin     Fixing the insert statement to only insert a record if the image display option has changed
-- 18-Nov-2010  P Cherur  Modify staff list display to not include ip_status of pst
-- 06-Sep-2011  L Dorman  Changed value for l_local_name from emp_org_unit.local_name to emp_org_unit.org_unit_desc in following procedures:
--                        local_name_update, add_admin, remove_admin
-- 14-Sep-2011  L Dorman  Changed almost all references to local_name data from emp_org_unit table to look at org_unit_desc instead.
--                        Mostly left the local_name_update procedure alone as it is not used anywhere anyway.
--                        Updated the help page, tidied up modification history formatting.
-- 16 Oct 2012   Ali Tan  Changed access table from qv_access to access_type_member
-- 16 Nov 2015  Tony Le   Added 'Gender X' and 'Title Mx' in staff_update procedure
-- 27-Nov-2015  F Johnston  Added calls to common logging procedures
-- 20-Oct-2017  Tony Le   QVPH-34: Application refactoring.
-- 17-May-2018  S.Kambil  QVPH-41 Apply site and service reference to HiQ.
-- 18-May-2018  Tony LE   QVPH-41: Removed unnecessary <div> in some pages.
-- 12-Dec-2019  N.Shanmugam  QVPH-56: Ability to update the temp_org_code for staff by phone book administrators
-- 31-Jan-2020  S.Thomas     QVPH-57: Modified to add ip_num while retrieving and updating the record
-- 10-Sept-2020 N.Shanmugam  Heat Inc#1523717 - Always return one row irrespective of its active status while fetching org unit details.
-- 16-Sept-2020 N.Shanmugam  Heat SR#423923  - Ability to select any title for the staff by phone book administrators
--------------------------------------------------------------------------------------


-------------------------------------------
--            GLOBAL Variables
--------------------------------------------
g_restrict_access  			       EXCEPTION;

-- table row background shade
g_background_shade	 VARCHAR2(7)   DEFAULT common_style.C_WHITE_COLOUR;
g_application_cd              VARCHAR2(50) := 'QVPH';


--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
-- GLOBAL CONSTANT
C_ORG_NAME_HEADER   CONSTANT     VARCHAR2(100) :='Update Organisational Unit Names';
C_ORG_NAME_HELP     CONSTANT     VARCHAR2(100) :='ph_admin_p.help?p_arg_values=org_unit_help';

C_ADMIN_HEADER      CONSTANT     VARCHAR2(100) :='Manage Phonebook Administrator Access';
C_ADMIN_HELP        CONSTANT     VARCHAR2(100) :='ph_admin_p.help?p_arg_values=admin_person_help';

C_STAFF_HEADER      CONSTANT     VARCHAR2(100) :='Perform Staff Updates';
C_STAFF_HELP        CONSTANT     VARCHAR2(100) :='ph_admin_p.help?p_arg_values=person_update_help';

C_DIV_FAC           CONSTANT     VARCHAR2(100) :='Division/Faculty';
C_DEP_SCH           CONSTANT     VARCHAR2(100) :='Department/School';
C_STAFF_LIST        CONSTANT     VARCHAR2(100) :='Staff List';

C_PH_LDAP_GROUP   CONSTANT VARCHAR2(5) := 'QV_PH';
C_LDAP_ADD     CONSTANT VARCHAR2(1) := 'Y';
C_LDAP_DELETE  CONSTANT VARCHAR2(1) := 'N';

--------------------------------------------
--         LOCAL PROCEDURES
--------------------------------------------

PROCEDURE show_error_help_text
IS
BEGIN
    htp.p('<p>An unexpected error has occurred. Please contact HiQ for assistance.</p>');
END show_error_help_text;

--------------------------------------------
--            GLOBAL FUNCTION
--------------------------------------------
FUNCTION access_permitted RETURN BOOLEAN
IS
BEGIN
	--access to this portlet is only available
	--to staff members and staff has to be in the group
	IF qv_common_access.is_user_in_group('PH') THEN
        IF qv_common_access.is_user_in_group('EMP') OR
           qv_common_access.is_user_in_group('CCR')
        THEN
	    	RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
	ELSE
		RETURN FALSE;
 	END IF;

END access_permitted;

--------------------------------------------------------------------------------
-- Returns org unit code and description
--------------------------------------------------------------------------------
FUNCTION org_code_desc(p_org_unit_code IN VARCHAR2 DEFAULT NULL)
RETURN VARCHAR2 IS

    rec    emp_org_unit%ROWTYPE;
BEGIN
	SELECT    org_unit_cd
             ,org_unit_desc
    INTO      rec.org_unit_cd
             ,rec.org_unit_desc
    FROM      emp_org_unit
    WHERE     org_unit_cd             = p_org_unit_code
    ORDER BY  CASE WHEN SYSDATE BETWEEN start_dt
                                    AND end_dt    THEN  1
                   WHEN end_dt       IS NULL      THEN  2
                   ELSE                                 3
              END
              FETCH FIRST 1 ROWS ONLY
              ;

	RETURN rec.org_unit_cd||' - '||rec.org_unit_desc;

EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END org_code_desc;


--------------------------------------------------------------------------------
-- Returns the minimum length of access code
--------------------------------------------------------------------------------
FUNCTION get_access_cd_length
RETURN NUMBER IS
	l_min_access_cd		NUMBER;
BEGIN
	SELECT MIN(NVL(LENGTH(access_cd),0))
	INTO   l_min_access_cd
	FROM   access_type_member
	WHERE  username  = qv_common_id.get_username
	AND    group_cd = 'PH';

	RETURN l_min_access_cd;

END get_access_cd_length;

--------------------------------------------------------------------------------
-- Returns true if the person has QUT access level
--------------------------------------------------------------------------------
FUNCTION has_qut_access (p_username IN VARCHAR2) RETURN BOOLEAN IS

    l_cnt NUMBER := 0;

BEGIN

    SELECT count(*)
    INTO   l_cnt
    FROM   access_type_member
    WHERE  username = p_username
    AND    group_cd = 'PH'
    AND    access_cd = '1';

    IF l_cnt != 0 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;

END has_qut_access;

--------------------------------------------------------------------------------
-- Returns 'checked' if string 1 equals to string 2 for check boxes
--------------------------------------------------------------------------------
FUNCTION checkcheckbox (p_str1	IN VARCHAR2 DEFAULT NULL
                       ,p_str2	IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
BEGIN
  	IF p_str1 = p_str2 THEN
   		RETURN ' CHECKED';
   	ELSE
   		RETURN '';
   	END IF;
END checkcheckbox;


--------------------------------------------------------------------------------
-- Returns 'selected' if string 1 equals to string 2 for drop down list
--------------------------------------------------------------------------------
FUNCTION checkselect(p_str1	IN VARCHAR2 DEFAULT NULL
					,p_str2	IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
BEGIN
	IF p_str1 = p_str2 THEN
		RETURN ' SELECTED';
	ELSE
		RETURN '';
	END IF;
END checkselect;


--------------------------------------------------------------------------------
-- Show drop-down list and return the number of records on the list
--------------------------------------------------------------------------------
FUNCTION listbox (p_sql IN VARCHAR2
                 ,p_id  IN VARCHAR2) RETURN VARCHAR2
IS
    l_id        VARCHAR2(100);
    l_text      VARCHAR2(100);
    n           NUMBER;
    rec_count   NUMBER;
    temp_cursor INTEGER;
BEGIN
    temp_cursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(temp_cursor, p_sql, DBMS_SQL.NATIVE);
    DBMS_SQL.DEFINE_COLUMN(temp_Cursor,1,l_id,25);
    DBMS_SQL.DEFINE_COLUMN(temp_Cursor,2,l_text,100);

    n := DBMS_SQL.EXECUTE(temp_cursor);
    rec_count := 0;

    LOOP
        IF DBMS_SQL.FETCH_ROWS(temp_cursor) <> 1 THEN
       	    EXIT;
        END IF;

        DBMS_SQL.COLUMN_VALUE(temp_Cursor,1,l_id);
        DBMS_SQL.COLUMN_VALUE(temp_cursor,2,l_text);

		rec_count := rec_count + 1;

        IF l_id = p_id THEN
            htp.p('<option value="'||l_id||'" selected>'||l_id||' : '||l_text||'</option>');
 	    ELSE
	        htp.p('<option value="'||l_id||'">'||l_id||' : '||l_text||'</option>');
	    END IF;

    END LOOP;

    DBMS_SQL.CLOSE_CURSOR(temp_Cursor);

	RETURN rec_count;

END listbox;

--------------------------------------------
--            GLOBAL PROCEDURE
--------------------------------------------
--------------------------------------------------------------------------------
-- Show drop-down list
--------------------------------------------------------------------------------
PROCEDURE listbox (p_sql IN VARCHAR2
                  ,p_id  IN VARCHAR2)
IS
    rec VARCHAR2(350);
BEGIN
    rec := listbox(p_sql, p_id);
END listbox;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE local_name  IS

CURSOR c1 IS
       SELECT  *
       FROM    emp_org_unit
       WHERE   hierarchy_level = 'CLEVEL1'
       AND     LOWER(org_unit_desc) <> 'central initiatives'
       AND     UPPER(org_unit_desc) NOT LIKE '%DELETE%'
	   AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
       ORDER BY sort_order;

CURSOR c2 (cur_code IN VARCHAR2) IS
       SELECT  *
       FROM    emp_org_unit
       WHERE   hierarchy_level = 'CLEVEL2'
       AND     org_unit_cd LIKE cur_code||'%'
       AND     LOWER(org_unit_desc) <> 'central initiatives'
       AND     UPPER(org_unit_desc) NOT LIKE '%DELETE%'
	   AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
       ORDER BY sort_order;

CURSOR c3 (cur_code IN VARCHAR2) IS
       SELECT *
       FROM   emp_org_unit
       WHERE  hierarchy_level = 'CLEVEL3'
       AND    org_unit_cd LIKE cur_code||'%'
       AND    LOWER(org_unit_desc) <> 'central initiatives'
       AND    UPPER(org_unit_desc) NOT LIKE '%DELETE%'
	   AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
       ORDER BY sort_order;

CURSOR c4 (cur_code IN VARCHAR2) IS
       SELECT *
       FROM   emp_org_unit
       WHERE  hierarchy_level = 'CLEVEL4'
       AND    org_unit_cd LIKE cur_code||'%'
       AND    LOWER(org_unit_desc) <> 'central initiatives'
       AND    UPPER(org_unit_desc) NOT LIKE '%DELETE%'
	   AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
       ORDER BY sort_order;

    codesrec  emp_org_unit%ROWTYPE;
    codesrec2 emp_org_unit%ROWTYPE;
    codesrec3 emp_org_unit%ROWTYPE;
    codesrec4 emp_org_unit%ROWTYPE;

BEGIN
	common_template.get_full_page_header(p_title=>C_ORG_NAME_HEADER
										   ,p_heading=>C_ORG_NAME_HEADER
										   ,p_help_url=>C_ORG_NAME_HELP );

	IF (NOT access_permitted) OR NOT has_qut_access(qv_common_id.get_username) THEN
	   RAISE g_restrict_access;
	END IF;

    -- Inline Style:

    htp.p('<style type="text/css">');
    htp.p('  ul.phbook {');
    htp.p('     list-style-type: none;');
    htp.p('  }');
    htp.p('</style>');

    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > '||LOWER(C_ORG_NAME_HEADER));

    -- Heading
    htp.p('<h2>Phone Book</h2>');

    OPEN c1;
    LOOP
        FETCH c1 INTO CodesRec;
        EXIT WHEN c1%NOTFOUND;
            htp.p('<ul class="phbook">');
            htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||codesrec.org_unit_cd||'">'||UPPER(org_code_desc(codesrec.org_unit_cd))||'</a>');

            htp.p('<ul class="phbook">');

            OPEN c2(codesrec.org_unit_cd);
                LOOP
                    FETCH c2 INTO codesrec2;
                    EXIT WHEN c2%NOTFOUND;
                    htp.nl;
                    htp.p('<li><a href="ph_admin_p.local_name_update?p_org_unit_code='||codesrec2.org_unit_cd||'">'||UPPER(org_code_desc(codesrec2.org_unit_cd))||'</a></li>');
                    htp.p('<ul class="phbook">');

                    OPEN c3(codesrec2.org_unit_cd);
                        LOOP
                            FETCH c3 INTO CodesRec3;
                            EXIT WHEN c3%NOTFOUND;
                            htp.nl;
                            htp.p('<li><a href="ph_admin_p.local_name_update?p_org_unit_code='||codesrec3.org_unit_cd||'">'||org_code_desc(codesrec3.org_unit_cd)||'</a></li>');
                            htp.p('<ul class="phbook">');
                            htp.nl;

                            OPEN c4(CodesRec3.org_unit_cd);
                                LOOP
                                    FETCH c4 INTO CodesRec4;
                                    EXIT WHEN c4%NOTFOUND;
                                    htp.p('<li><a href="ph_admin_p.local_name_update?p_org_unit_code='||codesrec4.org_unit_cd||'">'||org_code_desc(codesrec4.org_unit_cd)||'</a></li>');

                                END LOOP;
                            CLOSE c4;
                            htp.p('</ul>');
                        END LOOP;
                    CLOSE c3;
        		htp.p('</ul>');
                END LOOP;
            CLOSE c2;

        htp.p('</ul>');

        htp.p('</ul>');

        END LOOP;
    CLOSE c1;

     -- log page usage
    logger.usage(p_application_cd => g_application_cd
                ,p_activity_cd => 'View organisational unit names');

    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > '||LOWER(C_ORG_NAME_HEADER));
    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
        ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'View phone book'
                   ,p_log_data => 'outcome="User attempted to view organisational unit names but does not have access"');

    WHEN OTHERS THEN
        htp.p('<p>An error has occurred.</p>');
        qv_common_help.help_text;
        htp.ulistclose;
        common_template.get_full_page_footer;
END local_name;


--------------------------------------------------------------------------------
-- Update org unit local name
--------------------------------------------------------------------------------
PROCEDURE local_name_update (p_org_unit_code 		IN VARCHAR2 DEFAULT NULL
		  					,p_local_name 		    IN VARCHAR2 DEFAULT NULL
		  					,p_update				IN VARCHAR2 DEFAULT NULL) IS

    codesrec 		 emp_org_unit%ROWTYPE;
    l_local_name 	 emp_org_unit.org_unit_desc%TYPE;

BEGIN

    common_template.get_full_page_header(p_title=>C_ORG_NAME_HEADER
										   ,p_heading=>'Modify Organisational Unit Name'
										   ,p_help_url=>C_ORG_NAME_HELP );

    IF (NOT access_permitted) OR NOT has_qut_access(qv_common_id.get_username) THEN
        RAISE g_restrict_access;
	END IF;

    SELECT  org_unit_cd
	       ,org_unit_desc
    INTO    codesrec.org_unit_cd
		   ,codesrec.org_unit_desc
    FROM    emp_org_unit
    WHERE   org_unit_cd = p_org_unit_code
	AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);

	htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
	htp.p('<a href="ph_admin_p.local_name">'||LOWER(C_ORG_NAME_HEADER)||'</a> > modify unit name');

	-- Heading
	htp.p('<h2>Phone Book</h2>');

    IF p_update IS NULL THEN

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'View update organisational unit name'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

        htp.p('Modify organisational unit name for <strong>'||org_code_desc(p_org_unit_code)||'</strong>');
        htp.nl;
        htp.nl;

        htp.p('<center><form method="post" action="ph_admin_p.local_name_update">');
        htp.p('<input type="hidden" name="p_update" value="yes">');
        htp.p('<input type="hidden" name="p_org_unit_code" value="'||codesrec.org_unit_cd||'">');

        htp.p('<input type="text" name="p_local_name" size=70 value="'||TRIM(codesrec.org_unit_desc)||'">');
        htp.p('<input  type="submit" value="SUBMIT">');
        htp.p('</form></center>');

    ELSIF p_update ='yes' THEN

        SELECT org_unit_desc
        INTO   l_local_name
        FROM   emp_org_unit
        WHERE  org_unit_cd = p_org_unit_code
        AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);

        UPDATE  emp_org_unit
        SET     local_name = p_local_name
        WHERE  org_unit_cd = p_org_unit_code
        AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);

        COMMIT;

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Update organisational unit name'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

        -- log audit information
        logger.audit(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Update organisational unit name'
                    ,p_log_data => 'org unit name="'||p_local_name||'"');

        htp.p('<center><strong>Records Updated! </strong><br><br>');
        htp.p('<strong>'||l_local_name||'</strong> changed to: <strong>'||p_local_name||'</strong></center>');
        htp.nl;
        htp.p('<a href="ph_admin_p.local_name">'
        	||'Modify another organisational name</a><br>');
    END IF;

    htp.nl;
    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_admin_p.local_name">'||LOWER(C_ORG_NAME_HEADER)||'</a> > modify unit name');
    common_template.get_full_page_footer;

EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
        ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'Update organisational unit name'
                   ,p_log_data => 'outcome="User attempted to access the phone book to modify organisational unit name but does not have access"');

    WHEN OTHERS THEN

        logger.error(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Update organisational unit name'
                    ,p_log_data => 'Outcome="Unexpected exception", p_org_unit_code='||p_org_unit_code||',p_local_name='||p_local_name||', p_update='||p_update);

        show_error_help_text;
        common_template.get_full_page_footer;
END local_name_update;

--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE admin_person  IS

CURSOR c1 IS
       SELECT  *
       FROM    emp_org_unit
       WHERE   hierarchy_level = 'CLEVEL1'
       --AND     (sort_order < 90 OR sort_order IS NULL)
       AND     LOWER(org_unit_desc) <> 'central initiatives'
	   AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
       ORDER BY sort_order;

CURSOR c2 (cur_code IN VARCHAR2) IS
       SELECT  *
       FROM    emp_org_unit eou
       WHERE   eou.hierarchy_level = 'CLEVEL2'
       AND     eou.org_unit_cd LIKE cur_code||'%'
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

CURSOR c3 (cur_code IN VARCHAR2) IS
       SELECT  *
       FROM    emp_org_unit eou
       WHERE   eou.hierarchy_level = 'CLEVEL3'
       AND     eou.org_unit_cd LIKE cur_code||'%'
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

CURSOR c4 (cur_code IN VARCHAR2) IS
       SELECT  *
       FROM    emp_org_unit eou
       WHERE   eou.hierarchy_level = 'CLEVEL4'
       AND     eou.org_unit_cd LIKE cur_code||'%'
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

    codesrec  emp_org_unit%ROWTYPE;
    codesrec2 emp_org_unit%ROWTYPE;
    codesrec3 emp_org_unit%ROWTYPE;
    codesrec4 emp_org_unit%ROWTYPE;

BEGIN
	common_template.get_full_page_header(p_title=>C_ADMIN_HEADER
									    ,p_heading=>C_ADMIN_HEADER
                                        ,p_help_url=>C_ADMIN_HELP );

    IF (NOT access_permitted) OR NOT has_qut_access(qv_common_id.get_username) THEN
        RAISE g_restrict_access;
	END IF;

	-- Inline Style:
	htp.p('<style type="text/css">');
	htp.p('  ul.phbook {');
	htp.p('     list-style-type: none;');
	htp.p('  }');
	htp.p('</style>');


	htp.p('<a href="'||common_template.C_HOME||'">'||'Home</a> > '||LOWER(C_ADMIN_HEADER));

	-- Heading
	htp.p('<h2>Phone Book</h2>');

    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                ,p_activity_cd => 'View org unit listing for managing administrator access');

    OPEN c1;
        LOOP

            FETCH c1 INTO CodesRec;
            EXIT WHEN c1%NOTFOUND;

            htp.p('<ul class="phbook">');
            htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||codesrec.org_unit_cd||'">'||UPPER(org_code_desc(codesrec.org_unit_cd))||'</a>');

            htp.p('<ul class="phbook">');

            OPEN c2(CodesRec.org_unit_cd);

                LOOP

                    FETCH c2 INTO CodesRec2;
                    EXIT WHEN c2%NOTFOUND;

                    htp.nl;
                    htp.p('<li><a href="ph_admin_p.admin_list?p_org_unit_code='||codesrec2.org_unit_cd||'">'||UPPER(org_code_desc(codesrec2.org_unit_cd))||'</a></li>');
                    htp.p('<ul class="phbook">');

                    OPEN c3(CodesRec2.org_unit_cd);
                        LOOP
                            FETCH c3 INTO CodesRec3;
                            EXIT WHEN c3%NOTFOUND;

                            htp.nl;
                            htp.p('<li><a href="ph_admin_p.admin_list?p_org_unit_code='||codesrec3.org_unit_cd||'">'||org_code_desc(codesrec3.org_unit_cd)||'</a></li>');
                            htp.p('<ul class="phbook">');
                            htp.nl;

                            OPEN c4(codesrec3.org_unit_cd);
                                LOOP
                                    FETCH c4 INTO CodesRec4;
                                    EXIT WHEN c4%NOTFOUND;

                                    htp.p('<li><a href="ph_admin_p.admin_list?p_org_unit_code='||codesrec4.org_unit_cd||'">'||org_code_desc(codesrec4.org_unit_cd)||'</a></li>');

                                END LOOP;
                            CLOSE c4;

                            htp.p('</ul>');
                        END LOOP;
                    CLOSE c3;
                    htp.p('</ul>');
                END LOOP;

            CLOSE c2;
            htp.p('</ul>');
            htp.p('</ul>');
        END LOOP;
    CLOSE c1;

    htp.p('<a href="'||common_template.C_HOME||'">'||'Home</a> > '||LOWER(C_ADMIN_HEADER));
    common_template.get_full_page_footer;

EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'View org unit listing for managing administrator access'
                   ,p_log_data => 'outcome="User attempted to access phone book org unit listing for managing administrator access but does not have access"');

    WHEN OTHERS THEN

        logger.error(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'View org unit listing for managing administrator access'
           ,p_log_data => 'Outcome="Unexpected exception"'
        );
        show_error_help_text;
        common_template.get_full_page_footer;
END admin_person;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE admin_list (p_org_unit_code		 IN VARCHAR2 DEFAULT NULL) IS

CURSOR pho (costc IN VARCHAR2) IS
       SELECT   qv_common.get_preferred_name(c.username)  preferred_name
	           ,qv_common.get_surname(c.username)   surname
			   ,c.username                          username
			   ,c.access_cd                         access_cd
			   ,c.update_who                        qv_update_user
			   ,c.update_dt                         granted_dt
			   ,decode(length(c.access_cd),1,1
			   					         ,3,2
										 ,5,3
										 ,6,4)      access_level
			   ,o.org_unit_desc                     org_unit_desc
			   ,r.role_cd                           role_cd
			   ,r.id                                id
			   ,r.trs_client_id                     ip_num
       FROM     access_type_member      c
			   ,emp_org_unit      o
			   ,qv_client_role r
       WHERE    c.group_cd       = 'PH'
	   AND      costc             LIKE c.access_cd||'%'
	   AND      c.access_cd       = o.org_unit_cd
	   AND      c.username        = r.username
	   AND      r.role_active_ind = 'Y'
	   AND      r.role_cd         IN ('CCR','EMP')
	   AND      r.role_cd         =  (SELECT MAX(role_cd)
	                                  FROM   qv_client_role
							          WHERE  username = r.username)
	   AND      (SYSDATE BETWEEN o.start_dt AND o.end_dt OR o.end_dt IS NULL)
	   ORDER BY  access_level
	            ,2
				,1 ;

    phorec pho%ROWTYPE;
    codesrec emp_org_unit%ROWTYPE;

BEGIN
	common_template.get_full_page_header(p_title=>C_ADMIN_HEADER
										   ,p_heading=>'Phone Book Administrator Listing'
										   ,p_help_url=>C_ADMIN_HELP );

    IF (NOT access_permitted) OR NOT has_qut_access(qv_common_id.get_username) THEN
        RAISE g_restrict_access;
	END IF;

    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_admin_p.admin_person">'||LOWER(C_ADMIN_HEADER)||'</a> > administrator listing - ');
    htp.p(LOWER(org_code_desc(p_org_unit_code)));

    -- Heading
    htp.p('<h2>Phone Book</h2>');

    htp.p('Note: The following lists all phone book administrators who have access to this area.');
    htp.nl;htp.nl;
    htp.p('<table align=center cellspacing=0 border="0" width="100%">');
    htp.p('<tr>');
    htp.p('<td width="15%"><strong>Staff Name</strong>');
    htp.p('</td>');
    htp.p('<td width="39%"><strong>Organisational Name</strong>');
    htp.p('</td>');
    htp.p('<td width="10%"><strong>Access Level</strong>');
    htp.p('</td>');
    htp.p('<td width="15%"><strong>Grantor ID</strong>');
    htp.p('</td>');
    htp.p('<td width="13%"><strong>Granted Date</strong>');
    htp.p('</td>');
    htp.p('<td width="9%">&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('<td width="9%">&nbsp;&nbsp;');
    htp.p('</td>');
    htp.p('</tr>');

    OPEN pho (p_org_unit_code);
        LOOP
            FETCH pho INTO phorec;
            EXIT WHEN pho%NOTFOUND;
            g_background_shade := common_style.get_background_shade(g_background_shade);
            htp.p('<tr bgcolor="'||g_background_shade||'">');
            IF phorec.role_cd ='EMP' THEN
                htp.p('<td width="15%"><a href="srch_common_people_p.show?p_arg_names=p_id&p_arg_values='||phorec.id
							  ||'&p_arg_names=p_ip_type&p_arg_values='||phorec.role_cd
							  ||'&p_arg_names=p_show_mode&p_arg_values='||srch_stu_people.C_SRCH_STU_PEOPLE_3
							  ||'&p_arg_names=p_from&p_arg_values='||srch_stu_people.C_FROM_PORTLET
							  ||'">'||INITCAP(phorec.preferred_name)||' '||INITCAP(phorec.surname)||'</a>');
            ELSE
                htp.p('<td width="15%"><a href="srch_common_people_p.show?p_arg_names=p_id&p_arg_values='||phorec.ip_num
							  ||'&p_arg_names=p_ip_type&p_arg_values='||phorec.role_cd
							  ||'&p_arg_names=p_show_mode&p_arg_values='||srch_stu_people.C_SRCH_STU_PEOPLE_3
							  ||'&p_arg_names=p_from&p_arg_values='||srch_stu_people.C_FROM_PORTLET
							  ||'">'||INITCAP(phorec.preferred_name)||' '||INITCAP(phorec.surname)||'</a>');
            END IF;
            htp.p('</td>');
            htp.p('<td width="35%">'||phorec.access_cd||':'||phorec.org_unit_desc);
            htp.p('</td>');
            htp.p('<td width="5%">'||phorec.access_level);
            htp.p('</td>');
            htp.p('<td width="15%">'||phorec.qv_update_user);
            htp.p('</td>');
            htp.p('<td width="10%">'||TO_CHAR(phorec.granted_dt,'dd/mm/rrrr'));
            htp.p('</td>');
            htp.p('<td width="10%"><a href="ph_admin_p.modify_admin?p_org_unit_code='||p_org_unit_code||'&p_username='||phorec.username||'&p_access_cd='||phorec.access_cd||'">Modify</a>');
            htp.p('</td>');
            htp.p('<td width="15%"><a href="ph_admin_p.remove_admin?p_org_unit_code='||p_org_unit_code||'&p_username='||phorec.username||'&p_access_cd='||phorec.access_cd||'">Delete</a>');
            htp.p('</td>');
            htp.p('</tr>');
        END LOOP;
    CLOSE pho;
    htp.p('</table>');

    htp.nl;
    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                ,p_activity_cd => 'View phone book administrator listing'
                ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

    htp.p('<a href="ph_admin_p.add_admin?p_org_unit_code='||p_org_unit_code||'">Add a new administrator</a>');

    htp.nl;
    htp.nl;
    htp.p('<a href="'||common_template.C_HOME||'">'||'Home</a> > ');
    htp.p('<a href="ph_admin_p.admin_person">'||LOWER(C_ADMIN_HEADER)||'</a> > administrator listing - ');
    htp.p(LOWER(org_code_desc(p_org_unit_code)));
    common_template.get_full_page_footer;

EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'View phone book add new administrator'
                   ,p_log_data => 'outcome="User attempted to access the phone book administrator listing but does not have access"');
    WHEN OTHERS THEN

        logger.error(
             p_application_cd => g_application_cd
            ,p_activity_cd => 'View phone book add new administrator'
            ,p_log_data => 'Outcome="Unexpected exception",p_org_unit_code='||p_org_unit_code
        );
        show_error_help_text;
        common_template.get_full_page_footer;
END admin_list;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE add_admin(p_org_unit_code		 IN VARCHAR2    DEFAULT  NULL
		           ,p_username			 IN VARCHAR2	DEFAULT	 NULL
				   ,p_add				 IN VARCHAR2	DEFAULT	 NULL)  IS

    error_message       EXCEPTION;
    l_message           VARCHAR2(500);
    l_cnt				NUMBER;
    l_id				qv_client_role.id%TYPE;
    l_local_name        emp_org_unit.org_unit_desc%TYPE;
    l_ldap_err          VARCHAR2(500);

BEGIN
    common_template.get_full_page_header(p_title=>C_ADMIN_HEADER
	       							    ,p_heading=>'Add New Phone Book Administrator'
										,p_help_url=>C_ADMIN_HELP);

    IF (NOT access_permitted) OR NOT has_qut_access(qv_common_id.get_username) THEN
        RAISE g_restrict_access;
	END IF;

    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_admin_p.admin_person">'||LOWER(C_ADMIN_HEADER)||'</a> > ');
    htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||p_org_unit_code||'">administrator listing - '||org_code_desc(p_org_unit_code)||'</a> > add new administrator');

    -- Heading
    htp.p('<h2>Phone Book</h2>');

    IF p_add IS NULL THEN

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'View add new phone book administrator'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

        htp.p('Note: The following option is displayed in the format <strong>organisation code : organisation unit name : access level</strong>');
        htp.nl; htp.nl;
        htp.p('<center><form method="post" action="ph_admin_p.add_admin">');
        htp.p('<input type="hidden" name="p_add" value="yes">');
        htp.p('<table cellpadding="2" cellspacing="1" border="0">');
        htp.p('<tr><td align="left"><strong>QUT access username: </strong></td>');
        htp.p('<td align="left"><input type="text" name=p_username size=30 maxlength=30></td><tr>');

        htp.p('<tr><td align="left"><strong>Organisation Unit: </strong></td>');
        htp.p('<td align="left"><select name="p_org_unit_code">');
        htp.p('<option></option>');

		FOR rec IN
		   (SELECT  org_unit_cd
				    ,org_unit_desc
				    ,DECODE(LENGTH(org_unit_cd),1,1
			   	   				               ,3,2
										       ,5,3
										       ,6,4)  access_level
            FROM    emp_org_unit
	     	WHERE   org_unit_cd LIKE p_org_unit_code||'%'
			AND     hierarchy_level in ('CLEVEL1','CLEVEL2','CLEVEL3','CLEVEL4')
            AND     LOWER(org_unit_desc) <> 'central initiatives'
            AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
            ORDER  BY 1)
        LOOP
            htp.p('<option value="'||rec.org_unit_cd||'" >'||rec.org_unit_cd||' : '||rec.org_unit_desc||' : '||rec.access_level||'</option>');
        END LOOP;

     	htp.p('</select></td></tr>');

        htp.p('<tr><td colspan="2">&nbsp;</td></tr>');
        htp.p('<tr><td colspan="2">');
        htp.p('<center><input type="submit" value="ADD">'
               ||' '||'<input type="reset" value="RESET"></center>');

        htp.p('</td></tr>');
        htp.p('</table>');
        htp.p('</form></center>');

	ELSIF p_add='yes' THEN

        IF p_username IS NULL THEN
		    l_message := 'QUT access username must be filled in.';
		    RAISE error_message;

        ELSE
		    BEGIN
                SELECT id
                INTO   l_id
                FROM   qv_client_role
                WHERE  username        =  UPPER(p_username)
                AND    role_cd         IN ('EMP','CCR')
                AND    role_active_ind =  'Y'
                AND    ROWNUM          = 1
                ORDER  BY role_cd DESC;
                EXCEPTION
                WHEN NO_DATA_FOUND THEN
				    l_message := 'Invalid QUT access username.';
				    RAISE error_message;
	        END;

            SELECT  count(*)
            INTO    l_cnt
            FROM    access_type_member
            WHERE   username  = UPPER(p_username)
            AND     group_cd = 'PH'
            AND     p_org_unit_code like access_cd||'%';

            IF l_cnt = 0  THEN
                INSERT INTO access_type_member (username, group_cd, access_cd, access_type, owner_ind)
                VALUES(UPPER(p_username),'PH', p_org_unit_code,'USER', 'N');
                COMMIT;

                qv_common_ldap.add_remove_user_from_group( p_username    => UPPER(p_username)
                                                          ,p_ldap_group  => C_PH_LDAP_GROUP
                                                          ,p_add_ind     => C_LDAP_ADD
                                                          ,p_error       => l_ldap_err );

                -- log page usage
                logger.usage(p_application_cd => g_application_cd
                            ,p_activity_cd => 'Add new phone book administrator'
                            ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

                -- log audit information
                logger.audit(p_application_cd => g_application_cd
                            ,p_activity_cd => 'Add new phone book administrator'
                            ,p_log_data => 'org unit cd="'||p_org_unit_code||'",username="'||p_username||'"');

                htp.p('<center><strong>Record Added !</strong><br><br>');
                htp.p('<strong>'||qv_common.get_full_preferred_name(UPPER(p_username))||'</strong> was granted access in '
                    ||'<strong>'||org_code_desc(p_org_unit_code)||'</strong></center>');
                htp.nl;
                htp.p('<a href="ph_admin_p.add_admin?p_org_unit_code='||p_org_unit_code||'">'
                    ||'Add another new administrator</a>');
                htp.nl;
                htp.nl;

            ELSE
                l_message := ''||qv_common.get_full_preferred_name(UPPER(p_username))||' already has access to <strong>'||org_code_desc(p_org_unit_code)||'</strong>';
                RAISE error_message;
            END IF;
        END IF;
    END IF;
    htp.p('<a href="'||common_template.C_HOME||'">'||'Home</a> > ');
    htp.p('<a href="ph_admin_p.admin_person">'||LOWER(C_ADMIN_HEADER)||'</a> > ');
    htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||p_org_unit_code||'">administrator listing - '||org_code_desc(p_org_unit_code)||'</a> > add new administrator');
    common_template.get_full_page_footer;

EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
        ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'Add new phone book administrator'
                   ,p_log_data => 'outcome="User attempted to access the phone book to add new administrator but does not have access"');

    WHEN error_message THEN
        ph_admin_p.error_message(l_message);
    WHEN NO_DATA_FOUND THEN
        l_message := 'Organisational name must be selected.';
        ph_admin_p.error_message(l_message);
    WHEN OTHERS THEN
        logger.error(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'Add new phone book administrator'
           ,p_log_data => 'Outcome="Unexpected exception",p_org_unit_code='||p_org_unit_code||',p_username='||p_username||',p_add='||p_add
        );

        show_error_help_text;
        common_template.get_full_page_footer;

END add_admin;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE remove_admin(p_org_unit_code   IN VARCHAR2    DEFAULT  NULL
                      ,p_access_cd		 IN VARCHAR2    DEFAULT  NULL
		              ,p_username		 IN VARCHAR2	DEFAULT	 NULL
				      ,p_remove		     IN VARCHAR2	DEFAULT	 NULL)  IS

    l_access_cd 		emp_org_unit.org_unit_cd%TYPE;
    l_local_name 		emp_org_unit.org_unit_desc%TYPE;
    l_ldap_err          VARCHAR2(500);

BEGIN
    common_template.get_full_page_header(p_title=>C_ADMIN_HEADER
					  			        ,p_heading=>'Remove Phone Book Administrator'
										,p_help_url=>C_ADMIN_HELP );

    IF (NOT access_permitted) OR NOT has_qut_access(qv_common_id.get_username) THEN
        RAISE g_restrict_access;
	END IF;

    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_admin_p.admin_person">'||LOWER(C_ADMIN_HEADER)||'</a> > ');
    htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||p_org_unit_code||'">administrator listing - '||LOWER(org_code_desc(p_org_unit_code))||'</a> > delete access');

	-- Heading
	htp.p('<h2>Phone Book</h2>');

    IF p_remove IS NULL THEN

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'View remove phone book administrator'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

        htp.p('<center><form method="post" action="ph_admin_p.remove_admin">');
        htp.p('<input type="hidden" name="p_username" value="'||p_username||'">');
        htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
        htp.p('<input type="hidden" name="p_access_cd" value="'||p_access_cd||'">');
        htp.p('<input type="hidden" name="p_remove" value="yes">');

        htp.p('Are you sure to remove <strong>'||qv_common.get_full_preferred_name(p_username)||'</strong> from <br><br>');
        htp.p('<strong>'||org_code_desc(p_access_cd)||'</strong> administration list?');
        htp.nl;
        htp.nl;
        htp.p('<input type="submit" value="REMOVE">');
        htp.p('</form></center>');
        htp.nl;

    ELSIF p_remove='yes' THEN

        DELETE  access_type_member
        WHERE   username  = p_username
        AND     access_cd = p_access_cd
        AND     group_cd = 'PH';

        COMMIT;

        qv_common_ldap.add_remove_user_from_group( p_username    => UPPER(p_username)
                                                ,p_ldap_group  => C_PH_LDAP_GROUP
                                                ,p_add_ind     => C_LDAP_DELETE
                                                ,p_error       => l_ldap_err );

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Remove phone book administrator'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

        -- log audit information
        logger.audit(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Remove phone book administrator'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'",username="'||p_username||'"');

        htp.p('<center><strong>Record Deleted ! </strong><br>');
        htp.p('<p>'||qv_common.get_full_preferred_name(p_username)||'<strong> has been removed from </strong><br><br>');
        htp.p('<strong>'||org_code_desc(p_access_cd) ||'</strong> administration list.</center>');
        htp.nl;
        htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||p_org_unit_code||'">Remove another administrator</a><br>');
        htp.nl;
    END IF;
    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_admin_p.admin_person">'||LOWER(C_ADMIN_HEADER)||'</a> > ');
    htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||p_org_unit_code||'">administrator listing - '||LOWER(org_code_desc(p_org_unit_code))||'</a> > delete access');
    common_template.get_full_page_footer;

EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
        ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'Remove phone book administrator'
                   ,p_log_data => 'outcome="User attempted to access the phone book to remove administrator but does not have access"');

    WHEN OTHERS THEN
        logger.error(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'Remove phone book administrator'
           ,p_log_data => 'Outcome="Unexpected exception",p_org_unit_code='||p_org_unit_code||',p_username='||p_username||',p_remove='||p_remove||',p_access_cd='||p_access_cd
        );
        show_error_help_text;
        common_template.get_full_page_footer;

END remove_admin;

--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE modify_admin(p_org_unit_code IN VARCHAR2 DEFAULT NULL
                      ,p_username      IN VARCHAR2 DEFAULT NULL
                      ,p_access_cd     IN VARCHAR2 DEFAULT NULL
					  ,p_modify        IN VARCHAR2 DEFAULT NULL
					  ,p_new_access_cd IN VARCHAR2 DEFAULT NULL) IS

    l_sql			      VARCHAR2(1000);
    oldrec				  emp_org_unit%ROWTYPE;
    newrec				  emp_org_unit%ROWTYPE;
BEGIN
    common_template.get_full_page_header(p_title=>C_ADMIN_HEADER
									    ,p_heading=>'Modify Phone Book Administrator Access'
										,p_help_url=>C_ADMIN_HELP);

    IF (NOT access_permitted) OR NOT has_qut_access(qv_common_id.get_username) THEN
        RAISE g_restrict_access;
	END IF;

    SELECT  org_unit_cd
	       ,org_unit_desc
    INTO    oldrec.org_unit_cd
	       ,oldrec.org_unit_desc
    FROM    emp_org_unit
    WHERE   org_unit_cd = p_access_cd
	AND     (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);

    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_admin_p.admin_person">'||LOWER(C_ADMIN_HEADER)||'</a> > ');
    htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||p_org_unit_code||'">administrator listing - '||LOWER(org_code_desc(p_org_unit_code))||'</a> > ');
    htp.p('modify access');

	-- Heading
	htp.p('<h2>Phone Book</h2>');

    IF p_modify IS NULL THEN

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'View update phone book administrator access'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

        htp.p('Modify access for <strong>'||qv_common.get_full_preferred_name(p_username)||'</strong>');
        htp.nl;
        htp.nl;
        htp.p('Note: The following option is displayed in the format <strong>organisation code : organisation unit name : access level</strong>');
        htp.nl;
        htp.nl;
        htp.p('<center><form method="post" action="ph_admin_p.modify_admin">');
        htp.p('<input type="hidden" name="p_modify" value="yes">');
        htp.p('<input type="hidden" name="p_org_unit_code" value="'||p_org_unit_code||'">');
        htp.p('<input type="hidden" name="p_access_cd" value="'||oldrec.org_unit_cd||'">');
        htp.p('<input type="hidden" name="p_username" value="'||p_username||'">');

        htp.p('<table cellpadding="2" cellspacing="1" border="0">');
        htp.p('<tr><td><strong>Organisation Unit: </strong></td>');
    	htp.p('<td><select name="p_new_access_cd">');

     	l_sql := 'SELECT  DISTINCT org_unit_cd
		         ,org_unit_desc||'' : ''||
		  	      DECODE(LENGTH(org_unit_cd),1,1
			   	    				        ,3,2
										    ,5,3
										    ,6,4)
                  FROM    emp_org_unit
	     	      WHERE	  org_unit_cd LIKE ''1%''
                  AND     LENGTH(org_unit_cd)<>4
				  AND     hierarchy_level in (''CLEVEL1'',''CLEVEL2'',''CLEVEL3'',''CLEVEL4'')
                  AND     LOWER(org_unit_desc) <> ''central initiatives''
				  AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
                  ORDER BY 1';

        listbox(l_sql,oldrec.org_unit_cd);
        htp.p('</select>');
        htp.p('</td></tr>');
        htp.p('<tr><td colspan="2">&nbsp;</td></tr>');
        htp.p('<tr><td colspan="2">');
        htp.p('<center><input type="submit" value="SAVE">'
            ||' '||'<input type="reset" value="RESET"></center>');

        htp.p('</td></tr>');
        htp.p('</table>');
        htp.p('</form></center>');


    ELSIF p_modify = 'yes' then

        UPDATE access_type_member
        SET    access_cd       = p_new_access_cd
               ,update_dt      = sysdate
        WHERE  username        = p_username
        AND    access_cd       = p_access_cd
        AND    group_cd       = 'PH';

        COMMIT;

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Update phone book administrator access'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

        -- log audit information
        logger.audit(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Update phone book administrator access'
                    ,p_log_data => 'org unit cd="'||p_org_unit_code||'",username="'||p_username||'"');

        htp.nl;htp.nl;
        htp.p('<center>Records Updated for <strong>'||qv_common.get_full_preferred_name(p_username)||'</strong>!<br><br>');
        htp.p('Access to <strong>'||org_code_desc(oldrec.org_unit_cd) ||'</strong> changed to access to '
            ||'<strong>'||org_code_desc(p_new_access_cd)||'</strong></center>');
        htp.nl;
        htp.nl;
        htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||p_org_unit_code||'">'
            ||'Modify another access</a><br>');
        htp.nl;
    END IF;

    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
    htp.p('<a href="ph_admin_p.admin_person">'||LOWER(C_ADMIN_HEADER)||'</a> > ');
    htp.p('<a href="ph_admin_p.admin_list?p_org_unit_code='||p_org_unit_code||'">administrator listing - '||LOWER(org_code_desc(p_org_unit_code))||'</a> > ');
    htp.p('modify access');
    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'Update phone book administrator access'
                   ,p_log_data => 'outcome="User attempted to access the phone book to update administrator access but does not have access"');

    WHEN OTHERS THEN

        logger.error(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'Update phone book administrator access'
           ,p_log_data => 'Outcome="Unexpected exception",p_org_unit_code='||p_org_unit_code||',p_username='||p_username||',p_modify='||p_modify||',p_access_cd='||p_access_cd||',p_new_access_cd='||p_new_access_cd
        );

        show_error_help_text;
        common_template.get_full_page_footer;

END modify_admin;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE staff_group  IS

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
    AND     LOWER(eou.org_unit_desc) <> 'central initiatives'
    AND     UPPER(eou.org_unit_desc) NOT LIKE '%DELETE%'
	AND    (SYSDATE BETWEEN eou.start_dt AND eou.end_dt OR eou.end_dt IS NULL)
    AND     SUBSTR(eou.org_unit_cd, 1, 3) IN (
            SELECT  reference_cd
            FROM    qv_reference_cd
            WHERE   code_category_cd = 'PH_FACULTY_DIVISION'
            AND     active_ind = 'Y')
    AND EXISTS (SELECT *
                FROM      ip i
                         ,group_codes gc
                         ,subgroup_codes sgc
                WHERE     i.owner_org_code LIKE eou.org_unit_cd||'%'
                AND 	  i.ip_status = 'cur'
                AND       i.print_flag = 'Y'
                AND       i.owner_org_code = gc.owner_org_code
                AND       i.phone_group = gc.phone_group
                AND       gc.display_ind = 'Y'
                AND       gc.owner_org_code = sgc.owner_org_code
                AND       gc.phone_group = sgc.phone_group
                AND       i.phone_subgroup = sgc.phone_subgroup
                AND       sgc.display_ind = 'Y'
                )
    ORDER BY sort_order;

BEGIN

	common_template.get_full_page_header (p_title       => C_STAFF_HEADER
										 ,p_heading     => C_DIV_FAC
										 ,p_help_url    => C_STAFF_HELP
                                         ,p_version     => 2);

	IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
        RAISE g_restrict_access;
	END IF;

	htp.p('<a href="'||common_template.C_HOME||'">Home</a> > '||LOWER(C_DIV_FAC));

	-- Heading
	htp.p('<h1>Phone Book - '|| C_DIV_FAC ||'</h1>');
    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                ,p_activity_cd => 'View phone book org unit listing to perform staff updates');

	htp.ulistopen;

	FOR adminrec IN admin_cur
	LOOP
        FOR org_rec IN emp_org_unit_cur(adminrec.access_cd,adminrec.hierarchy_level)
        LOOP
            IF adminrec.hierarchy_level <>'CLEVEL4' THEN
                htp.p('<a href="ph_admin_p.dep_sch_list?p_org_unit_code='||org_rec.org_unit_cd||'">'
                     ||UPPER(ph_admin_p.org_code_desc(org_rec.org_unit_cd))||'</a>');
                htp.nl;

            ELSIF adminrec.hierarchy_level ='CLEVEL4' THEN
                htp.p('<a href="ph_admin_p.staff_list?p_org_unit_code='||org_rec.org_unit_cd||'">'
                      ||UPPER(ph_admin_p.org_code_desc(org_rec.org_unit_cd))||'</a>');
                htp.p('<input type="hidden" name="p_access_cd" value="'||adminrec.access_cd||'">');
                htp.nl;
            END IF;
        END LOOP;
    END LOOP;

	htp.ulistclose;
    htp.p('<a href="'||common_template.C_HOME||'">Home</a> > '||LOWER(C_DIV_FAC));
    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'View phone book'
                   ,p_log_data => 'outcome="User attempted to access the phone book org unit listing to perform staff updates but does not have access"');

    WHEN OTHERS THEN

        logger.error(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'View phone book'
           ,p_log_data => 'Outcome="Unexpected exception"'
        );

        show_error_help_text;
        htp.ulistclose;
        common_template.get_full_page_footer;
END staff_group;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE dep_sch_list (p_org_unit_code	IN VARCHAR2 DEFAULT NULL) IS

    c2rec                emp_org_unit%ROWTYPE;

    -- internal procedure 1
    PROCEDURE clevel3 (clevel2_code VARCHAR2) IS
        c3_cnt	NUMBER;
        CURSOR list_o_clevels3 IS
        SELECT	org_unit_cd
		       ,org_unit_desc
		       ,sort_order
        FROM	emp_org_unit eou
        WHERE   hierarchy_level = 'CLEVEL3'
        AND	    org_unit_cd LIKE clevel2_code||'%'
        AND	    LOWER(org_unit_desc) NOT IN ('central initiatives', 'pro-vice-chancellor (academic)')
        AND     UPPER(org_unit_desc) NOT LIKE '%DELETE%'
        AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
        AND     EXISTS (SELECT  *
                        FROM    ip i
                        WHERE   i.owner_org_code LIKE eou.org_unit_cd||'%'
                        AND     i.ip_status = 'cur')
        ORDER BY sort_order
	            ,hierarchy_level
			    ,org_unit_cd;

    -- internal procedure 2
    PROCEDURE clevel4 (clevel3_code VARCHAR2) IS

        CURSOR   list_o_clevels4 IS
        SELECT 	 org_unit_cd
                ,org_unit_desc
                ,DECODE(sort_order, NULL, ' '
                                     , TO_CHAR(sort_order))	sort_order
        FROM	 emp_org_unit eou
        WHERE	 org_unit_cd LIKE Clevel3_code||'%'
        AND		 hierarchy_level = 'CLEVEL4'
        AND      UPPER(org_unit_desc) NOT LIKE '%DELETE%'
        AND     (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
        AND      EXISTS (SELECT  *
                         FROM    ip i
                         WHERE   I.OWNER_ORG_CODE LIKE eou.org_unit_cd||'%'
                         AND     i.ip_status = 'cur')
        ORDER BY eou.sort_order
                ,eou.org_unit_cd;

    BEGIN
        htp.ulistopen;
        FOR clevel4_rec IN list_o_clevels4 LOOP
            htp.p('<a href="ph_admin_p.staff_list?p_org_unit_code='|| clevel4_rec.org_unit_cd||'">'|| ph_admin_p.org_code_desc(clevel4_rec.org_unit_cd)||'</a>');
            htp.nl;
        END LOOP;
        htp.ulistclose;
    END clevel4;

    -- procedure clevel3 statement begins
    BEGIN
        htp.ulistopen;
        FOR clevel3_rec IN list_o_clevels3
        LOOP
            htp.nl;
            c3_cnt := ph_updt_p.check_clevel4(clevel3_rec.org_unit_cd);
            IF c3_cnt = 0 THEN
                htp.p('<span class="strong">'|| ph_admin_p.org_code_desc(clevel3_rec.org_unit_cd) || '</span>');
            ELSE
                htp.p('<a href="ph_admin_p.staff_list?p_org_unit_code='||clevel3_rec.org_unit_cd||'">'||ph_admin_p.org_code_desc(clevel3_rec.org_unit_cd));
            END IF;
            htp.nl;htp.nl;
            clevel4(clevel3_rec.org_unit_cd);

        END LOOP;
        htp.ulistclose;
    END Clevel3;

BEGIN

    IF (NOT ph_admin_p.access_permitted) OR ph_admin_p.get_access_cd_length =0 THEN
        RAISE g_restrict_access;
	END IF;

	common_template.get_full_page_header(p_title    => C_STAFF_HEADER
	                                    ,p_heading  => C_DEP_SCH--'Phone Group Updates for Department/School'
	    								,p_help_url => C_STAFF_HELP
                                        ,p_version  => 2);

    SELECT    org_unit_cd
             ,org_unit_desc
    INTO      c2rec.org_unit_cd
             ,c2rec.org_unit_desc
    FROM      emp_org_unit
    WHERE     hierarchy_level IN ( 'CLEVEL2','CLEVEL3','CLEVEL4')
    AND       org_unit_cd  = p_org_unit_code
    AND       LOWER(org_unit_desc)  <> 'central initiatives'
    AND       UPPER(org_unit_desc) NOT LIKE '%DELETE%'
    AND      (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
    ORDER BY  sort_order
             ,hierarchy_level
             ,org_unit_cd;


	htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
	htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_DIV_FAC)||'</a> > ' || LOWER(C_DEP_SCH));

	-- Heading
    htp.p('<h1>Phone Book - '|| ph_admin_p.org_code_desc(c2rec.org_unit_cd) ||'</h1>');

	clevel3(c2rec.org_unit_cd);

    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                ,p_activity_cd => 'View phone book listing for department/school for staff updates');

    -- log audit information
    logger.audit(p_application_cd => g_application_cd
                ,p_activity_cd => 'View phone book listing for department/school for staff updates'
                ,p_log_data => 'org unit cd="'||ph_admin_p.org_code_desc(c2rec.org_unit_cd)||'"');

    htp.p('<div>');
	htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
	htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_DIV_FAC)||'</a> > ' || LOWER(C_DEP_SCH));
    htp.p('</div>');
    common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'View phone book department/school listing'
                   ,p_log_data => 'outcome="User attempted to view the phone book department/school listing for performing staff updates but does not have access"');

    WHEN OTHERS THEN

        logger.error(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'View phone book department/school listing'
           ,p_log_data => 'Outcome="Unexpected exception",p_org_unit_code='||p_org_unit_code
        );
        show_error_help_text;
        htp.ulistclose;
        common_template.get_full_page_footer;
END dep_sch_list;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE staff_list   (p_org_unit_code		IN VARCHAR2 DEFAULT NULL) IS

    l_username    qv_client_computer_account.username%TYPE := qv_common_id.get_username;

    CURSOR staff (cur_org_code IN VARCHAR2) IS
        SELECT  surname
               ,NVL(preferred_name,first_name) preferred_name
               ,title
               ,primary_extn
               ,primary_location
               ,primary_campus
               ,primary_fax
               ,mobile
               ,speed_dial
               ,print_flag
               ,r.username username
               ,ip_num
        FROM   ip
              ,qv_client_role r
        WHERE  ip.owner_org_code LIKE cur_org_code||'%'
        AND    ip.employee_num   =  r.id
        AND    ip.ip_status = 'cur'
        AND    r.role_cd         = 'EMP'
        AND    r.role_active_ind = 'Y'
        UNION
        SELECT  ip.surname  surname
               ,NVL(ip.preferred_name,ip.first_name) preferred_name
               ,ip.title title
               ,primary_extn
               ,primary_location
               ,primary_campus
               ,primary_fax
               ,mobile
               ,speed_dial
               ,print_flag
               ,r.username username
               ,ip.ip_num
        FROM   ip
              ,qv_client_role r
              ,ccr_clients    c
        WHERE  ip.owner_org_code LIKE cur_org_code||'%'
        AND    ip.ip_num         = c.ip_num
        AND    ip.ip_status = 'cur'
        AND    r.id              = c.ccr_client_id
        AND    c.deceased_flag   = 'N'
        AND    r.role_cd         = 'CCR'
        AND    r.role_active_ind = 'Y'
        ORDER  BY surname
                 ,preferred_name;

    l_cnt  NUMBER :=0;

BEGIN

	common_template.get_full_page_header (p_title       => C_STAFF_HEADER
	                                     ,p_heading     => C_STAFF_LIST
								         ,p_help_url    => C_STAFF_HELP 
                                         ,p_version     => 2);

    IF (NOT access_permitted) OR get_access_cd_length =0 THEN
        RAISE g_restrict_access;
	END IF;

	-- Set the navigation path
	IF length(ph_updt_p.check_access_cd(p_org_unit_code, l_username)) < 6 THEN
        htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
        htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_DIV_FAC)||'</a> > ');
        htp.p('<a href="ph_admin_p.dep_sch_list?p_org_unit_code='||ph_updt_p.check_access_cd(p_org_unit_code, l_username)||'">'
	    	|| LOWER(C_DEP_SCH) ||'</a> > '|| LOWER(C_STAFF_LIST) ||'');
	ELSE
        htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
        htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_DIV_FAC)||'</a> > '||LOWER(C_STAFF_LIST)||'');
	END IF;

    htp.p('<script type="text/javascript" src="/js/qut/plugins/jquery.dataTables.min.js"></script>');
    htp.p('<script type="text/javascript" src="/js/qut/plugins/jquery.dataTables.bootstrap.js"></script>');
    htp.p('<link type="text/css" rel="stylesheet" href="/css/qut/js/plugins/jquery.dataTables.bootstrap.css" />');
    htp.p('<script type="text/javascript"><!--');
    htp.p('$(document).ready(function() {');
    htp.p('  $("#staff_list_table").dataTable({');
    htp.p('    "sDom": "<''row-fluid''<''span6''l><''span6''f>r>t<''row-fluid''<''span6''i><''span6''p>>"');
    htp.p('   ,"sPaginationType": "bootstrap"');
    htp.p('   ,"aaSorting": [[0,"asc"]]');
    htp.p('   ,"aLengthMenu": [[50, 100, 200, 500], [50, 100, 200, 500]]');
    htp.p('   ,"iDisplayLength" : 50');
    htp.p('   ,"oLanguage": { ');
    htp.p('      "sLengthMenu": "_MENU_ records per page"');
    htp.p('     }');
    htp.p('   });');
    htp.p('  });');
    htp.p('//-->');
    htp.p('</script>');

    -- log page usage
    logger.usage(p_application_cd => g_application_cd
                ,p_activity_cd => 'View phone book department/school staff listing'
                ,p_log_data => 'org unit cd="'||p_org_unit_code||'"');

	htp.p('<h1>Phone Book - '|| org_code_desc(p_org_unit_code) ||'</h1>');

    htp.p('<table class="table table-bordered table-striped table-qv dataTables" id="staff_list_table" width="100%">');
    htp.p('<thead>');
    htp.p('  <tr>');
    htp.p('    <th width="23%"><strong>Staff Name</strong>');
    htp.p('    </th>');
    htp.p('    <th width="5%"><strong>Title</strong>');
    htp.p('    </th>');
    htp.p('    <th width="10%"><strong>Phone </strong>');
    htp.p('    </th>');
    htp.p('    <th width="15%"><strong>Location</strong>');
    htp.p('    </th>');
    htp.p('    <th width="10%"><strong>Campus</strong>');
    htp.p('    </th>');
    htp.p('    <th width="10%"><strong>Fax</strong>');
    htp.p('    </th>');
    htp.p('    <th width="10%"><strong>Mobile</strong>');
    htp.p('    </th>');
    htp.p('    <th width="10%"><strong>Speed Dial</strong>');
    htp.p('    </th>');
    htp.p('    <th width="7%" align="center"><strong>Display?</strong>');
    htp.p('    </th>');
    htp.p('  </tr>');
    htp.p('</thead>');
    htp.p('<tbody>');

    FOR staffrec IN staff(p_org_unit_code) LOOP

	    htp.p('<tr>');
		htp.p('<td><a href="ph_admin_p.staff_update?p_username='||staffrec.username||'&p_num='||staffrec.ip_num||'">'
            ||qv_common.get_full_preferred_name(staffrec.username)||'</a></strong>');
		htp.p('</td>');

		htp.p('<td>'||staffrec.title);
		htp.p('</td>');
		htp.p('<td>'||staffrec.primary_extn);
		htp.p('</td>');
		htp.p('<td>'||staffrec.primary_location);
		htp.p('</td>');
		htp.p('<td>'||staffrec.primary_campus);
		htp.p('</td>');
		htp.p('<td>'||staffrec.primary_fax);
		htp.p('</td>');
		htp.p('<td>'||staffrec.mobile);
		htp.p('</td>');
		htp.p('<td>'||staffrec.speed_dial);
		htp.p('</td>');
		IF staffrec.print_flag='Y' THEN
            htp.p('<td>Yes');
		ELSIF staffrec.print_flag='N' THEN
            htp.p('<td>No');
		END IF;
		htp.p('</td>');
	    htp.p('</tr>');
		l_cnt := l_cnt +1;
	END LOOP;
    
    htp.p('</tbody></table>');
    
    htp.nl;
    htp.p('<div>');

    -- Set the navigation path
	IF length(ph_updt_p.check_access_cd(p_org_unit_code, l_username)) < 6 THEN
        htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
        htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_DIV_FAC)||'</a> > ');
        htp.p('<a href="ph_admin_p.dep_sch_list?p_org_unit_code='||ph_updt_p.check_access_cd(p_org_unit_code, l_username)||'">'
	    	|| LOWER(C_DEP_SCH) ||'</a> > '|| LOWER(C_STAFF_LIST) ||'');
	ELSE
        htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
        htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_DIV_FAC)||'</a> > '||LOWER(C_STAFF_LIST)||'');
	END IF;

    htp.p('</div>');
    common_template.get_full_page_footer;

EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'View phone book department/school staff listing'
                   ,p_log_data => 'outcome="User attempted to view the phone book department/school staff listing but does not have access"');
    WHEN OTHERS THEN

        logger.error(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'View phone book department/school staff listing'
           ,p_log_data => 'Outcome="Unexpected exception",p_org_unit_code='||p_org_unit_code
        );
        show_error_help_text;
        common_template.get_full_page_footer;
END staff_list;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE staff_update
(
     p_username 			   IN VARCHAR2 DEFAULT NULL
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
) IS

    l_username    qv_client_computer_account.username%TYPE := qv_common_id.get_username;

	CURSOR titles (phg IN VARCHAR2, ooc IN VARCHAR2) IS
		SELECT  *
	    FROM    subgroup_codes
	    WHERE   phone_group    = phg
	    AND     owner_org_code = ooc;

	CURSOR  grps (ooc IN VARCHAR2) IS
		SELECT  *
	    FROM   group_codes
	    WHERE  owner_org_code = ooc
		ORDER  BY phone_group;

    ocode               emp_org_unit%ROWTYPE;
	qcrec               qv_client_role%ROWTYPE;
	iprec               ip%ROWTYPE;
	grpcode             grps%ROWTYPE;
	jobs                titles%ROWTYPE;
	crec                access_type_member%ROWTYPE;
	subgrp              subgroup_codes%ROWTYPE;
	grp                 group_codes%ROWTYPE;
	error_message       EXCEPTION;
	l_message           VARCHAR2(500);

	l_cnt               number := 0;

    l_campus_id		 	locn_site.site_id%TYPE   			DEFAULT NULL;
	l_building_id		locn_building.building_id%TYPE		DEFAULT NULL;
	l_floor_id		  	locn_floor.floor_id%TYPE			DEFAULT NULL;
	l_room_id		  	locn_room.room_id%TYPE				DEFAULT NULL;

	l_location_campus	locn_site.name%TYPE 	   			DEFAULT NULL;
	l_location_building	locn_building.name%TYPE 	   		DEFAULT NULL;
	l_location_floor	locn_floor.name%TYPE 		   		DEFAULT NULL;
	l_location_room		locn_room.room_id%TYPE	   			DEFAULT NULL;
	l_primary_location 	ip.primary_location%TYPE 			DEFAULT NULL;
	l_new_location_id	locn_location.location_id%TYPE 		DEFAULT NULL;
    l_display_ind       VARCHAR2(1) := 'Y';
    l_ccr_owner_org_cd  ip.owner_org_code%TYPE              DEFAULT NULL;
    l_phone_group       ip.phone_group%TYPE;
    l_phone_subgroup    ip.phone_subgroup%TYPE;
    l_email_address     qv_client_computer_account.chosen_email%TYPE;    

    FUNCTION get_display_ind
    (
        p_id              IN NUMBER   DEFAULT NULL
    )
    RETURN VARCHAR2
    ---------------------------------------------
    -- Purpose: Return whether to display image
    ---------------------------------------------
    IS
        l_cnt NUMBER:=0;
    BEGIN
        SELECT COUNT(*)
        INTO   l_cnt
        FROM   qv_image_display
        WHERE  id = p_id
        AND    role_cd = common_client.C_EMP_ROLE_TYPE;

        IF l_cnt >  0 THEN
            RETURN 'N';
        ELSE
            RETURN 'Y';
        END IF;

    END get_display_ind;
    
    PROCEDURE display_campus (p_campus IN  VARCHAR DEFAULT NULL)
    IS
    
        l_selected       VARCHAR2(10);
        l_kind_of_campus VARCHAR2(20);
    
        -- select zOther so it is always returned as the last campus
        --  (we need to bring other back as last campus so it is displayed last)
        CURSOR c_campus
        IS
            SELECT   REPLACE(ls.site_id, 'OC', 'zOther') campus, ls.name
            FROM 	 locn_site ls
            WHERE	 ls.active_ind = 'Y'
            AND      ls.site_id NOT IN ('CA', 'CB')
            ORDER BY campus;
        BEGIN
    
        htp.p('<select id="p_campus" onChange="CampusOnSelect(false);" name="p_campus">');
        FOR r_campus IN c_campus LOOP
    
            l_selected := '';
    
            IF r_campus.campus = 'zOther' THEN
                l_kind_of_campus := 'OC';
            ELSE
                l_kind_of_campus := r_campus.campus;
            END IF;
    
            IF l_kind_of_campus = p_campus THEN
                l_selected := 'selected';
            END IF;
    
            htp.p('<option value="'|| l_kind_of_campus ||'" '|| l_selected ||'>'|| r_campus.name ||'</option>');
    
        END LOOP;
        htp.p('</select>');
    
    END display_campus;

    FUNCTION get_location_id
    (
        p_campus		   IN VARCHAR2 DEFAULT NULL
        ,p_building		   IN VARCHAR2 DEFAULT NULL
        ,p_floor		   IN VARCHAR2 DEFAULT NULL
        ,p_room			   IN VARCHAR2 DEFAULT NULL
    ) RETURN locn_location.location_id%TYPE
    IS
        l_location_id 	   locn_location.location_id%TYPE DEFAULT NULL;
    
    BEGIN
        BEGIN
            SELECT  ll.location_id
            INTO    l_location_id
            FROM    locn_location ll
            WHERE   ll.site_id               = NVL(p_campus, '0')
            AND	    NVL(ll.building_id, '0') = NVL(p_building, '0')
            AND	    NVL(ll.floor_id, '0')    = NVL(p_floor, '0')
            AND	    NVL(ll.room_id, '0')     = NVL(p_room, '0')
            AND     rownum = 1
            ORDER BY update_on;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_location_id :=  NULL;
                
            WHEN OTHERS THEN
                -- log unexpected error
                logger.error(p_application_cd => g_application_cd
                            ,p_log_data => 'An unexpected exception occurred in ph_admin_p.get_location_id');              
                l_location_id :=  NULL;
        END;
    
        RETURN l_location_id;
    END get_location_id;
    

BEGIN
	common_template.get_full_page_header(p_title=>C_STAFF_HEADER
										   ,p_heading=>'Staff Updates'
										   ,p_help_url=>C_STAFF_HELP 
                                           ,p_version => 2);


    IF p_update IS NULL THEN
        htp.p('<script language="Javascript">');
        htp.p('    addLoadEvent(function () { CampusOnSelect(true); });');
        htp.p('</script>');

        -- get javascript for dynamic location dropdowns
        locn_common.get_dynamic_javascript;
        common_js.load_page;
    END IF;


    IF (NOT access_permitted) OR get_access_cd_length =0 THEN
        RAISE g_restrict_access;
	END IF;

	BEGIN
		SELECT  *
		INTO    qcrec
		FROM    qv_client_role
		WHERE   username        =  p_username
		AND     role_active_ind =  'Y'
		AND     role_cd         IN ('CCR','EMP')
		AND     ROWNUM          = 1
		ORDER  BY role_cd DESC;
        
        
        
	EXCEPTION
        WHEN OTHERS THEN
            htp.p('No match data found');
	END;

    IF qcrec.role_cd = 'EMP' THEN
    	BEGIN
            SELECT  *
            INTO    iprec
            FROM    ip
            WHERE   employee_num   = LPAD(qcrec.id,8,'0') -- must have LPAD
              AND   ip_num         = p_num;

		EXCEPTION
            WHEN NO_DATA_FOUND THEN
                htp.p('No match data found in IP');
            WHEN OTHERS THEN
                htp.p('No match data found in IP');
		END;

    ELSIF qcrec.role_cd = 'CCR' THEN
    	BEGIN
            SELECT  *
            INTO    iprec
            FROM    ip
            WHERE   ip_num   =  (SELECT DISTINCT ip_num
                                 FROM    ccr_clients    cc
                                        ,qv_client_role r
                                 WHERE 	 r.id              = qcrec.id
                                 AND     r.id              = cc.ccr_client_id
                                 AND     r.role_cd         = 'CCR'
                                 AND     r.role_active_ind = 'Y');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                htp.p('No match data found in IP or CCR_CLIENTS');
            WHEN OTHERS THEN
                htp.p('No match data found in IP or CCR_CLIENTS');
        END;
    END IF;

    -- This will ensure that the user can only update either the job title or the temp. org.
    -- unit and not both at the same time.
    htp.p('<script type="text/javascript">');
    htp.p('<!--');
    htp.p('$(document).ready(function() {');
    htp.p('    toggleOrgJobTitleList();');
    htp.p('$(function() {');
    htp.p('    var date = $("#dt_picker").datepicker({dateFormat: "dd/mm/yy", minDate: -14, maxDate: 365}).val();');
    htp.p('    $("#dt_picker").html(date);');
    htp.p('    $("#dt_picker_to").val(date)');
    htp.p('});');
    htp.p('var dtPickerTo;');
    -- stop the user from changing the date 
    htp.p('$("#dt_picker").keyup(function() {');
    htp.p('    dtPickerTo = $("#dt_picker_to").val();');
    htp.p('    $("#dt_picker").val(dtPickerTo);');
    htp.p('});');
    
    htp.p('});');
    htp.p('function toggleOrgJobTitleList() {');
    htp.p('    if (($("#jobtitle").val() == "") || ($("#orgunit").val() != "" && ($("#orgunit").val()) == "' || iprec.temp_owner_org_code || '")){');
    htp.p('        $("#orgunit").prop("disabled", false);');
    htp.p('    } else {');
    htp.p('        $("#orgunit").prop("disabled", true);');
    htp.p('    }');
    htp.p('    if (($("#orgunit").val() == "") || ($("#orgunit").val() != "" && ($("#orgunit").val()) == "' || iprec.temp_owner_org_code || '")) {');
    htp.p('        $("#jobtitle").prop("disabled", false);');
    htp.p('    } else {');
    htp.p('        $("#jobtitle").prop("disabled", true);');
    htp.p('    }');
    htp.p('}');  
    htp.p('-->');
    htp.p('</script>');
    
        BEGIN
            SELECT  *
            INTO    subgrp
            FROM    subgroup_codes
            WHERE   phone_group    = iprec.phone_group
            AND     phone_subgroup = iprec.phone_subgroup
            AND     owner_org_code = iprec.owner_org_code;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    logger.warn(
                        p_application_cd => g_application_cd
                       ,p_activity_cd => 'Update staff details'
                       ,p_log_data => 'Outcome="Staff member assigned to invalid job title; cannot update",staff_username='||p_username||',iprec.owner_org_code='||iprec.owner_org_code||',iprec.phone_group='||iprec.phone_group||',iprec.phone_subgroup='||iprec.phone_subgroup
                    );
        END;

        BEGIN
            SELECT  *
            INTO    grp
            FROM    group_codes
            WHERE   phone_group    = iprec.phone_group
            AND     owner_org_code = iprec.owner_org_code;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                logger.warn(
                    p_application_cd => g_application_cd
                   ,p_activity_cd => 'Update staff details'
                   ,p_log_data => 'Outcome="Staff member assigned to invalid phone group; cannot update",staff_username='||p_username||',iprec.owner_org_code='||iprec.owner_org_code||',iprec.phone_group='||iprec.phone_group
                );
        END;


        BEGIN
            SELECT  *
            INTO    ocode
            FROM    emp_org_unit
            WHERE   org_unit_cd  = iprec.owner_org_code
            AND     hierarchy_level = 'CLEVEL4';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    htp.p('<p>The staff member is assigned to an invalid organisational area. Please contact HiQ if you require assistance.</p>');
                    logger.warn(p_application_cd => g_application_cd
                               ,p_activity_cd => 'Update staff details'
                               ,p_log_data => 'Outcome="Staff member assigned to invalid organisational area; cannot update",staff_username='||p_username||',iprec.owner_org_code='||iprec.owner_org_code);
        END;

        -- Set the navigation path
        IF length(ph_updt_p.check_access_cd(iprec.owner_org_code, l_username)) < 6 THEN
            htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
            htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_STAFF_HEADER)||'</a> > ');
            htp.p('<a href="ph_admin_p.dep_sch_list?p_org_unit_code='||ph_updt_p.check_access_cd(iprec.owner_org_code, l_username)||'">'
            ||'department/school listing</a> > ');
            htp.p('<a href="ph_admin_p.staff_list?p_org_unit_code='||iprec.owner_org_code||'"> staff listing - '||LOWER(org_code_desc(iprec.owner_org_code))||'</a> > ');
            htp.p('modify staff details');
        ELSE
            htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
            htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_STAFF_HEADER)||'</a> > ');
            htp.p('<a href="ph_admin_p.staff_list?p_org_unit_code='||iprec.owner_org_code||'"> staff listing - '||LOWER(org_code_desc(ph_updt_p.check_access_cd(iprec.owner_org_code, l_username)))||'</a> > ');
            htp.p('modify staff details');
        END IF;

        -- Heading
        htp.p('<h1>Phone Book - Modify Staff Details</h1>');

        IF p_update IS NULL THEN
             -- log page usage
            logger.usage(p_application_cd => g_application_cd
                        ,p_activity_cd => 'View update staff details'
                        ,p_log_data => 'username="'||p_username||'"');
            -- get individual location id's so form can be populated with initial values)
            locn_common.get_locn_location_ids (
                iprec.location_id
                ,l_campus_id
                ,l_building_id
                ,l_floor_id
                ,l_room_id);

            -- get location names ie the values in the drop down's from the location id
            --   even on refresh we do this as the values passed as parameters are the id's
            --   we need the text equivalent so we can match it against the drop downs
            locn_common.get_location_name (
                iprec.location_id
                ,l_location_campus
                ,l_location_building
                ,l_location_floor
                ,l_location_room);
                
            l_email_address := qv_common.get_email (p_username      => p_username
                                                   ,p_full_address  => 'Y');

            htp.p('<form name="details_form" method="post" action="ph_admin_p.staff_update" class="form-horizontal">');
            htp.p('<input type="hidden" name="p_update" value="yes">');
            htp.p('<input type="hidden" name="p_username" value="'||p_username||'">');
            htp.p('<input type="hidden" name="p_num" value="'||p_num||'">');
            htp.p('<input id=p_master_campus_id type=hidden name=p_master_campus_id> ');
            -- Store location details, so javascript can use them (as we need to set values depending on these values)
            htp.p('<input id=p_building_copy type=hidden name=p_building_copy value="' || l_location_building || '">');
            htp.p('<input id=p_floor_copy type=hidden name=p_floor_copy value="'|| l_location_floor ||'">');
            htp.p('<input id=p_room_copy type=hidden name=p_room_copy value="'|| l_location_room ||'">');
            -- style to control table spacing
            htp.p('<style>');
            htp.p('    tr {');
            htp.p('        padding: 2px 0px !important; ');
            htp.p('    }');
            htp.p('</style>');
            
            htp.p('<fieldset><legend>Staff Details</legend>');
            htp.p('<div class="alert alert-warning">');
            htp.p('<sup class="strong">#</sup>: Data entered in these fields will be displayed on the Internet. Do not enter private contact details in the fields marked with <sup>#</sup>.');
            htp.p('</div>');
            -- name, email address, and gender (read-only)
            htp.p('<div class="control-group"><label class="control-label">Staff name:</label>');
            htp.p('<div class="controls"><span class="input-xlarge uneditable-input">'|| qv_common.get_full_preferred_name(p_username) ||'</span></div></div>');
            htp.p('<div class="control-group"><label class="control-label">Email:</label>');
            htp.p('<div class="controls"><span class="input-xlarge uneditable-input">'|| l_email_address ||'</span><a href="mailto:'|| l_email_address ||'" class="link-mailto"> </a></div></div>');
            htp.p('<div class="control-group"><label class="control-label">Gender:</label>');
            htp.p('<div class="controls"><span class="uneditable-input">'|| iprec.gender ||'</span>');
            htp.p('</div></div>');
            -- preferred name
            htp.p('<div class="control-group"><label class="control-label" for="p_preferred_name">Preferred name:</label>');
            htp.p('<div class="controls"><input type="text" id="p_preferred_name" name="p_preferred_name" value="'|| iprec.preferred_name ||'">');
            htp.p('</div></div>');
            -- tittle
            htp.p('<div class="control-group"><label class="control-label" for="p_title">Title:</label>');
            htp.p('<div class="controls"><select name="p_title" id="p_title" class="required">');
            htp.p('<option '|| ph_admin_p.checkselect(iprec.title, 'MISS') ||' value="MISS">MISS</option>');
            htp.p('<option '|| ph_admin_p.checkselect(iprec.title, 'MR') ||' value="MR">MR</option>');
            htp.p('<option '|| ph_admin_p.checkselect(iprec.title, 'MX') ||' value="MX">MX</option>');
            htp.p('<option '|| ph_admin_p.checkselect(iprec.title, 'MRS') ||' value="MRS">MRS</option>');
            htp.p('<option '|| ph_admin_p.checkselect(iprec.title, 'MS') ||' value="MS">MS</option>');
            htp.p('</select>');
            htp.p('</div></div>');
            -- campus
            htp.p('<div class="control-group"><label class="control-label" for="p_campus">Campus:</label>');
            htp.p('<div class="controls">');
            display_campus(l_campus_id);
            htp.p('</div></div>');
            -- building
            htp.p('<div class="control-group"><label class="control-label" for="p_campus">Building:</label>');
            htp.p('<div class="controls">');
            htp.p('<select id="p_building" onChange="LoadFloors(this, false);" name="p_building" disabled>');
            htp.p('<option value="" selected>Select Campus</option>');
            htp.p('</select>');
            htp.p('</div></div>');
            -- floor
            htp.p('<div class="control-group"><label class="control-label" for="p_campus">Floor:</label>');
            htp.p('<div class="controls">');
            htp.p('<select id="p_floor" onChange="LoadRooms(this, false);" name="p_floor" disabled>');
            htp.p('<option value="" selected>Select Campus</option>');
            htp.p('</select>');
            htp.p('</div></div>');
            -- room
            htp.p('<div class="control-group"><label class="control-label" for="p_campus">Room:</label>');
            htp.p('<div class="controls">');
            htp.p('<select id="p_room" name="p_room" disabled>');
            htp.p('<option value="" selected>Select Campus</option>');
            htp.p('</select>');
            htp.p('</div></div>');
            -- phone
            htp.p('<div class="control-group"><label class="control-label" for="p_extn">Phone <sup>#</sup>:</label>');
            htp.p('<div class="controls"><input type="text" id="p_extn" name="p_extn" value ="'||TRIM(IPrec.primary_extn)||'" maxlength="30" size="30">');
            htp.p('<span class="help-block" style="margin-top: 0px;" id="p_extn_help"><i class="icon-info-sign"></i> For example: 3138 1234 if it is a QUT number.</span>');    
            htp.p('</div></div>');
            -- fax
            htp.p('<div class="control-group"><label class="control-label" for="p_fax">Fax <sup>#</sup>:</label>');
            htp.p('<div class="controls"><input type="text" id="p_fax" name="p_fax" value ="'||TRIM(IPrec.primary_fax)||'" maxlength="30" size="30">');
            htp.p('<span class="help-block" style="margin-top: 0px;" id="p_fax_help"><i class="icon-info-sign"></i> For example: 3138 1234 if it is a QUT number.</span>');    
            htp.p('</div></div>');
            -- mobile
            htp.p('<div class="control-group"><label class="control-label" for="p_mobile">Mobile <sup>#</sup>:</label>');
            htp.p('<div class="controls"><input type="text" id="p_mobile" name="p_mobile" value ="'||TRIM(IPrec.mobile)||'" maxlength="20" size="30">');
            htp.p('<span class="help-block" style="margin-top: 0px;" id="p_mobile_help"><i class="icon-info-sign"></i> For example: 0412 345 678.</span>');    
            htp.p('</div></div>');
            -- speed dial
            htp.p('<div class="control-group"><label class="control-label" for="p_speed_dial">Speed Dial:</label>');
            htp.p('<div class="controls"><input type="text" id="p_speed_dial" name="p_speed_dial" value ="'||TRIM(IPrec.speed_dial)||'" maxlength="20" size="30">');
            htp.p('</div></div>');
            -- pager
--            htp.p('<div class="control-group"><label class="control-label" for="p_pager">Pager:</label>');
--            htp.p('<div class="controls"><input type="text" id="p_pager" name="p_pager" value ="'||TRIM(IPrec.pager)||'" maxlength="20" size="30">');
--            htp.p('</div></div>');
            -- URL
            htp.p('<div class="control-group"><label class="control-label" for="p_url">URL:</label>');
            htp.p('<div class="controls"><input type="text" class="input-xxlarge" id="p_url" name="p_url" value ="'||TRIM(IPrec.ip_url)||'" maxlength="240">');
            htp.p('<span class="help-block" style="margin-top: 0px;" id="p_url_help"><i class="icon-info-sign"></i> 240 character limit.</span>');    
            htp.p('</div></div>');

            htp.p('<div class="control-group"><label class="control-label">&nbsp;</label>');
            htp.p('<div class="controls"><span class="strong">Temporary Job Title and Organisational Unit</span>');
            htp.p('</div></div>');

            htp.p('<div class="alert alert-info info-msg info-msg-background">');            
            htp.p('<p>If you would like to update both job title and temporary organisational unit, please move the staff to the new organisational unit first and then update their job title in the new area.</p>');
            htp.p('</div>');
            -- current phone group and job title (read-only)
            htp.p('<div class="control-group"><label class="control-label">Current Phone Group:</label>');
            htp.p('<div class="controls"><span class="input-xxlarge uneditable-input">'|| CASE WHEN grp.description IS NOT NULL THEN ocode.org_unit_desc ||' - '|| grp.description ELSE 'Undefined' END ||'</span>');
            htp.p('</div></div>');
            htp.p('<div class="control-group"><label class="control-label">Current Job Title:</label>');
            htp.p('<div class="controls"><span class="input-xlarge uneditable-input">'|| NVL(subgrp.description, 'Undefined') ||'</span>');
            htp.p('</div></div>');
            -- new group and job title
            OPEN grps (iprec.owner_org_code);
                htp.p('<div class="control-group"><label class="control-label" for="p_group">New Group / Job Title:</label>');
                htp.p('<div class="controls"><select class="input-xxlarge" name="p_group" onChange="toggleOrgJobTitleList();" id="jobtitle">');
                htp.p('<option value="">Select a new group and title</option>');

                LOOP
                    FETCH grps INTO grpcode;
                    EXIT WHEN Grps%NOTFOUND;
                    htp.p('<option value="">'||grpcode.description ||' - DO NOT SELECT</option>');

                    OPEN titles (grpcode.phone_group, iprec.owner_org_code);
                    LOOP
                        FETCH titles INTO jobs;
                        EXIT WHEN titles%NOTFOUND;
                        htp.p('<option value="'||grpcode.phone_group||'.'||jobs.phone_subgroup||'">&nbsp;&nbsp;'||grpcode.phone_group||'.'||jobs.phone_subgroup||': '||jobs.description||'</option>');
                    END LOOP;

                    CLOSE titles;
                END LOOP;
                htp.p('</select>');
                htp.p('</div></div>');
            CLOSE grps;

            OPEN grps (iprec.owner_org_code);
                htp.p('<div class="control-group"><label class="control-label" for="p_temp_org_code">Temporary Org. Unit:</label>');
                htp.p('<div class="controls"><select class="input-xxlarge" name="p_temp_org_code" onChange="toggleOrgJobTitleList();" id="orgunit">');
                htp.p('<option value="">Select a temporary organisation unit</option>');
                htp.p('<option value="">No Temporary Organisation Unit</option>');

                FOR rec IN
    
                (
                    SELECT org_unit_cd,
                           org_unit_desc
                       FROM   emp_org_unit
                       WHERE  hierarchy_level = 'CLEVEL4'
                       AND    LOWER(org_unit_desc) <> 'central initiatives'
                       AND    UPPER(org_unit_desc) NOT LIKE '%DELETE%' 
                       AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
                       -- remove all old org units
                       AND    SUBSTR(org_unit_cd, 1, 3) IN (
                              SELECT reference_cd 
                              FROM  qv_reference_cd
                              WHERE code_category_cd = 'PH_FACULTY_DIVISION')
                       ORDER BY org_unit_cd
                )

                LOOP
                    IF (iprec.temp_owner_org_code IS NOT NULL) THEN
                        IF (rec.org_unit_cd = iprec.temp_owner_org_code) THEN
                            htp.p('<option value="'||rec.org_unit_cd||'" selected>'||rec.org_unit_cd||' : '||rec.org_unit_desc||'</option>');
                        ELSE
                            htp.p('<option value="'||rec.org_unit_cd||'">'||rec.org_unit_cd||' : '||rec.org_unit_desc||'</option>');
                        END IF;
                    ELSE
                        htp.p('<option value="'||rec.org_unit_cd||'">'||rec.org_unit_cd||' : '||rec.org_unit_desc||'</option>');
                    END IF;
                END LOOP;
                htp.p('</select>');
                htp.p('</div></div>');
            CLOSE grps;

--            htp.p('<div class="control-group"><label class="control-label">&nbsp;</label>');
--            htp.p('<div class="controls"><span class="strong">Supervision</span>');
--            htp.p('</div></div>');
--
--            htp.p('<div class="alert alert-info info-msg info-msg-background">');            
--            htp.p('<p>To replace the official supervisor with a temporary one, you must also specify an end date. After this end date, your 
--                   supervisor will revert to the one recorded in the HR systems.</p>');
--            htp.p('</div>');
--            -- official supervisor (read-only)
--            htp.p('<div class="control-group"><label class="control-label">Official Supervisor:</label>');
--            htp.p('<div class="controls"><span class="input-xxlarge uneditable-input">'|| get_supervisor_name_email (p_username) ||'</span>');
--            htp.p('</div></div>');
--            -- new temporary supervisor
--            htp.p('<div class="control-group"><label class="control-label" for="p_temp_supervisor">Temporary Supervisor:</label>');
--            htp.p('<div class="controls"><select name id="p_temp_supervisor" class="input-xxlarge">');
--            htp.p('<option value=""> </option>');
--            FOR r_sup IN sups (NVL(iprec.temp_owner_org_code, iprec.owner_org_code)) LOOP
--
--                htp.p('<option value="'|| r_sup.username ||'">'|| r_sup.surname ||', '|| r_sup.first_name ||' ('|| r_sup.chosen_email ||')</option>');
--                
--            END LOOP;
--            htp.p('</select>');
--            htp.p('<span class="help-block" style="margin-top: 0px;" id="p_extn_help"><i class="icon-info-sign"></i> Only QUT staff with a supervision role are on this list.</span>');    
--            htp.p('</div></div>');
--            -- supervisor's effective end date, default for 30 days
--            htp.p('<input type="hidden" id="dt_picker_to" name="dt_picker_to" value="">');
--            htp.p('<div class="control-group"><label class="control-label" for="dt_picker_to">Effective End Date #:</label>');
--            htp.p('<div class="controls"><input type="text" id="dt_picker" name="dt_picker" value="'|| TO_CHAR(SYSDATE, 'DD/MM/YYYY') ||'">');
--            htp.p('</div></div>');
            htp.p('<div class="control-group"><label class="control-label" for="p_temp_org_code">&nbsp;</label>');
            htp.p('<div class="controls"><span class="strong">Show/Hide Image and Profile</span>');
            htp.p('</div></div>');
            -- image display?
            htp.p('<div class="control-group"><label class="control-label" for="p_img_flag">Display Image?</label>');
            htp.p('<div class="controls">');
            htp.p('<label class="radio inline">');
            htp.p('<input name="p_img_flag" type="radio" ' ||REPLACE(REPLACE(get_display_ind(qcrec.id), 'Y', 'CHECKED'),'N','') || ' value="Y">Yes');
            htp.p('</label>');
            htp.p('<label class="radio inline">');            
            htp.p('<input name="p_img_flag" type="radio" ' ||REPLACE(REPLACE(get_display_ind(qcrec.id), 'N', 'CHECKED'),'Y','') || ' value="N">No');
            htp.p('</label>');
            htp.p('</div></div>');
            -- profile display?
            htp.p('<div class="control-group"><label class="control-label" for="p_img_flag">Display Profile?</label>');
            htp.p('<div class="controls">');
            htp.p('<label class="radio inline">');
            htp.p('<input name="p_print_flag" type="radio" ' || ph_admin_p.checkcheckbox(NVL(iprec.print_flag,'Y'),'Y') || ' value="Y">Yes');
            htp.p('</label>');
            htp.p('<label class="radio inline">');
            htp.p('<input name="p_print_flag" class="marginLeft30" type="radio" ' || ph_admin_p.checkcheckbox(iprec.print_flag,'N') || ' value="N">No');
            htp.p('</label>');
            htp.p('</div></div>');

            htp.p('<div class="form-actions">');
            htp.p('<button class="btn btn-custom" id="submit_button" type="submit">Submit</button>');
            htp.p('<button type="button" class="btn" onClick="history.back()">Cancel</button>');
            htp.p('</div>');

            htp.p('</fieldset>');

            htp.p('</form>');

        ELSIF p_update ='yes' THEN

            IF LENGTH(p_preferred_name) > 20 THEN
                l_message :='Preferred name must be less than 20 characters.';
                RAISE error_message;
            ELSIF LENGTH(RTRIM(p_fax)) >30 THEN
                l_message :='Fax number must be less than 30 characters.';
                RAISE error_message;
            ELSIF LENGTH(RTRIM(p_mobile)) >20 THEN
                l_message :='Mobile number must be less than 20 characters.';
                RAISE error_message;
            ELSIF LENGTH(RTRIM(p_speed_dial)) > 20 THEN
                l_message :='Speed dial must be less than 20 characters.';
                RAISE error_message;
            ELSIF LENGTH(RTRIM(p_closed_user_group)) > 10 THEN
                l_message :='Closed User Group number must be less than 11 characters.';
                RAISE error_message;
            ELSIF LENGTH(RTRIM(p_pager)) >20 THEN
                l_message :='Pager must be less than 20 characters.';
                RAISE error_message;
            ELSIF LENGTH(p_url) > 240 THEN
                l_message :='URL must be less than 240 characters.';
                RAISE error_message;
            END IF;

            l_new_location_id := get_location_id(p_campus, p_building, p_floor, p_room);
            
            -- Avoid using the locn_common package as there is a bug in there
            locn_common.get_location_name (l_new_location_id
                                          ,l_location_campus
                                          ,l_location_building
                                          ,l_location_floor
                                          ,l_location_room);


            l_primary_location := SUBSTR(l_location_building || ' ' || l_location_floor || ' ' || l_location_room, 1, 65);
            
            -- determine the phone_group and phone_subgroup value
            -- if the user has a new temp_owner_org_code, then reset the phone_group and phone_subgroup to 999
            IF (p_temp_org_code IS NOT NULL AND iprec.temp_owner_org_code IS NULL)
            OR (p_temp_org_code IS NULL AND iprec.temp_owner_org_code IS NOT NULL)
            OR (p_temp_org_code IS NOT NULL AND iprec.temp_owner_org_code IS NOT NULL AND p_temp_org_code <> iprec.temp_owner_org_code) THEN
                l_phone_group       := 999;
                l_phone_subgroup    := 999;
            ELSE
                l_phone_group       := NVL(SUBSTR(p_group,1,INSTR(p_group,'.')-1), grp.phone_group);
                l_phone_subgroup    := NVL(SUBSTR(p_group,INSTR(p_group,'.')+1), subgrp.phone_subgroup);
            END IF;

            IF qcrec.role_cd = 'EMP' THEN
                UPDATE ip
                SET    preferred_name      = INITCAP(p_preferred_name)
                       ,title              = p_title
                       ,phone_group        = l_phone_group
                       ,phone_subgroup     = l_phone_subgroup
                       ,primary_campus     = p_campus
                       ,primary_location   = l_primary_location
                       ,primary_extn       = RTRIM(p_extn)
                       ,primary_fax        = RTRIM(p_fax)
                       ,print_flag         = p_print_flag
                       ,mobile             = RTRIM(p_mobile)
                       ,speed_dial         = RTRIM(p_speed_dial)
                       ,closed_user_group  = RTRIM(p_closed_user_group)
                       ,pager              = RTRIM(p_pager)
                       ,img_flag           = p_img_flag
                       ,ip_url             = p_url
                       ,location_id	   	   = l_new_location_id
                       ,temp_owner_org_code = p_temp_org_code
                       ,owner_org_code      = (SELECT CASE WHEN p_temp_org_code IS NULL THEN owner_org_code_new ELSE p_temp_org_code END
                                                FROM   ip
                                                WHERE  ip_num       = iprec.ip_num)
                WHERE  ip_num              = iprec.ip_num; -- unique key

                COMMIT;

            ELSIF qcrec.role_cd = 'CCR' THEN
            
                -- for CCR/Visitor account, once the phone book admin override the original owner org code with temp
                -- owner org code, unlike staff account, we don't have the original org code info in ip table
                -- if the phone book admin wanted to revert back to the original org unit code, we have to go to
                -- ccr_client_roles to retrieve it
                IF (p_temp_org_code IS NULL) THEN
                
                    BEGIN
                        SELECT  DISTINCT SUBSTR(org_unit_code, 1, 6)
                        INTO    l_ccr_owner_org_cd
                        FROM    ccr_client_roles
                        WHERE   client_id = qcrec.id
                        AND     TRUNC(SYSDATE) BETWEEN TRUNC(start_date) AND TRUNC(end_date) 
                        AND     TRUNC(start_date) = (
                                SELECT  MAX(TRUNC(start_date)) 
                                FROM    ccr_client_roles
                                WHERE   client_id = qcrec.id
                                AND     TRUNC(SYSDATE) BETWEEN TRUNC(start_date) AND TRUNC(end_date) 
                                )
                        AND     rownum = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            -- let's hope that it doesn't go here!
                            -- but if it does, the overnight script will repopulate the value for us
                            l_ccr_owner_org_cd := NULL;
                    END; 
                ELSE
                    l_ccr_owner_org_cd := p_temp_org_code;
                END IF;

               UPDATE ip
               SET    preferred_name     = INITCAP(p_preferred_name)
                     ,title            	 = p_title
                     ,phone_group      	 = l_phone_group
                     ,phone_subgroup   	 = l_phone_subgroup
                     ,primary_campus   	 = p_campus
                     ,primary_location 	 = l_primary_location
                     ,primary_extn     	 = RTRIM(p_extn)
                     ,primary_fax      	 = RTRIM(p_fax)
                     ,print_flag       	 = p_print_flag
                     ,mobile           	 = RTRIM(p_mobile)
                     ,speed_dial       	 = RTRIM(p_speed_dial)
                     ,closed_user_group  = RTRIM(p_closed_user_group)
                     ,pager            	 = RTRIM(p_pager)
                     ,img_flag           = p_img_flag
                     ,ip_url           	 = p_url
                     ,location_id	   	 = l_new_location_id
                     ,temp_owner_org_code = (CASE WHEN p_temp_org_code IS NOT NULL THEN l_ccr_owner_org_cd ELSE NULL END)
                     ,owner_org_code      = l_ccr_owner_org_cd
              WHERE  ip_num       =  (SELECT DISTINCT ip_num
                                      FROM    ccr_clients    cc
                                             ,qv_client_role r
                                      WHERE   r.id              = qcrec.id
                                      AND     r.id              = cc.ccr_client_id
                                      AND     r.role_cd         = 'CCR'
                                      AND     r.role_active_ind = 'Y');
              COMMIT;

              UPDATE  ccr_clients
              SET     preferred_name   = UPPER(p_preferred_name)
                     ,title           =  p_title
                     ,changed_from    =  SYSDATE
              WHERE   ccr_client_id   =  qcrec.id
              AND     start_date      =  (SELECT MAX(START_DATE)
                                          FROM   ccr_clients
                                          WHERE  ccr_client_id = qcrec.id);

              COMMIT;

            END IF;

            -- update the changes in table qv_image_display (a new table used) for either displaying or not displaying staff image
            IF p_img_flag = 'Y' THEN
                DELETE
                FROM    qv_image_display
                WHERE   id = qcrec.id;
                COMMIT;
            ELSE
                BEGIN
                    --check if image display part changed or not. Only update data if image display option has changed.
                    SELECT  'N'
                    INTO    l_display_ind
                    FROM    qv_image_display
                    WHERE   id = qcrec.id;
                EXCEPTION
                    WHEN no_data_found THEN
                        l_display_ind := 'Y';
                END;
                IF l_display_ind = 'Y' THEN
                    INSERT INTO qv_image_display
                    VALUES (qcrec.id, qcrec.role_cd);
                END IF;
                COMMIT;
            END IF;

        -- log page usage
        logger.usage(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Update staff details');

        -- log audit information
        logger.audit(p_application_cd => g_application_cd
                    ,p_activity_cd => 'Update staff details'
                    ,p_log_data => 'username="'||p_username||'"');

		htp.p('<div>');
		htp.nl;htp.nl;
		htp.p('<center><strong>'||qv_common.get_full_preferred_name(p_username)||'</strong>''s records have been updated!</center>');
		htp.nl;htp.nl;
		htp.p('</div>');
    END IF;

	htp.p('<div>');

    htp.nl;
    htp.nl;

	-- Set the navigation path
	IF length(ph_updt_p.check_access_cd(iprec.owner_org_code, l_username)) < 6 THEN
		htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
		htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_STAFF_HEADER)||'</a> > ');
		htp.p('<a href="ph_admin_p.dep_sch_list?p_org_unit_code='||ph_updt_p.check_access_cd(iprec.owner_org_code, l_username)||'">'
		||'department/school listing</a> > ');
		htp.p('<a href="ph_admin_p.staff_list?p_org_unit_code='||iprec.owner_org_code||'"> staff listing - '||LOWER(org_code_desc(iprec.owner_org_code))||'</a> > ');
		htp.p('modify staff details');
	ELSE
		htp.p('<a href="'||common_template.C_HOME||'">Home</a> > ');
		htp.p('<a href="ph_admin_p.staff_group">'||LOWER(C_STAFF_HEADER)||'</a> > ');
		htp.p('<a href="ph_admin_p.staff_list?p_org_unit_code='||iprec.owner_org_code||'"> staff listing - '||LOWER(org_code_desc(ph_updt_p.check_access_cd(iprec.owner_org_code, l_username)))||'</a> > ');
		htp.p('modify staff details');
	END IF;

	htp.p('</div>');
	common_template.get_full_page_footer;
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p>You do not have the correct authorisation to access this page, '
            ||'Please contact <a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');

        -- log attempted access
        logger.warn(p_application_cd => g_application_cd
                   ,p_activity_cd => 'Update staff details'
                   ,p_log_data => 'outcome="User attempted to access the phone book to update staff details but does not have access"');

    WHEN error_message THEN
        ph_admin_p.error_message(l_message);

    WHEN OTHERS THEN

        logger.error(
            p_application_cd => g_application_cd
           ,p_activity_cd => 'Update staff details'
           ,p_log_data => 'Outcome="Unexpected exception",staff_username='||p_username
        );

        show_error_help_text;
        common_template.get_full_page_footer;

END staff_update;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE help( p_arg_values IN VARCHAR2 DEFAULT NULL) IS

BEGIN

	htp.p('<div>');

   -- log page usage
    logger.usage(p_application_cd => g_application_cd
                ,p_activity_cd => 'View phone book administration help');

   IF p_arg_values= 'org_unit_help' THEN

        common_template.get_help_page_header(p_title    => C_ORG_NAME_HEADER
                                            ,p_heading  => C_ORG_NAME_HEADER);
        htp.p('<p>');
        htp.p('The QUT Phone Book Organisational Unit Names Function allows you to update the '
            ||'QUT Organisational Unit Names. Only QUT Staff with Phone Book Access Level 1 have '
            ||'authorisation to use this function.');
        htp.p('</p>');
        htp.p('<p>');
        htp.p('Click on the relevant QUT Organisational Unit Name you wish to change.');
        htp.p('</p>');
        htp.p('<p>');
        htp.p('Update the new name and click SUBMIT to make your change.');
        htp.p('</p>');
    ELSIF p_arg_values= 'admin_person_help' THEN
        common_template.get_help_page_header(p_title    => C_ADMIN_HEADER
                                            ,p_heading  => C_ADMIN_HEADER);
        htp.p('<p>');

        htp.p('The QUT Phone Book Phone Book Administrators Function allows you to grant and '
            ||'revoke Phone Book Administrator access to staff members within QUT. Only QUT Staff '
            ||'with Phone Book Access Level 1 have authorisation to use this function.');
        htp.p('</p>');
        htp.p('<p>');
        htp.p('Select the relevant QUT organisational unit who administration rights you wish to modify.');
        htp.p('</p>');
        htp.p('<p>');
        htp.p('You will then see a listing of all Current administrators and have the option to '
            ||'"Add" a new QUT Phone Book Administrator and "Modify" or "Delete" an existing QUT Phone Book Administrator.');
        htp.p('</p>');
        htp.p('<p>');
        htp.p('If you wish to add a new administrator click the "Add A New Administrator" link and '
            ||'specify their QUT access username and the organisational unit code they are responsible for, for example:');
        htp.p('<ol>');
        htp.p('<li>Organisational Unit Code 1 = QUT, means the person gets access level 1 for the whole university, '
            ||'they can also change QUT Organisational Unit Names and grant and revoke QUT Phone Book Administrator Privileges to staff.');
        htp.p('<li>Organisational Unit Code 113 = QUT, Faculty of Education means the person gets access level 2 to the Faculty.');
        htp.p('<li>Organisational Unit Code 16404 = QUT, Division of Information and Academic Services - Information '
            ||'Technology Services Department means the person gets access level 3 to the department.');
        htp.p('<li>Organisational Unit Code 164048 = QUT, Division of Information and Academic Services, '
            ||'Information Technology Services Department - Corporate Information Servers Section means '
            ||'the person gets access level 4 to the section.');
        htp.p('</ol>');
        htp.p('</p>');
        htp.p('<p>');
        htp.p('If you wish to update / delete an administrator click on the relevant link to invoke the functionality.');

        htp.p('</p>');
    ELSIF p_arg_values= 'person_update_help' THEN
        common_template.get_help_page_header(p_title    => C_STAFF_HEADER
                                            ,p_heading  => C_STAFF_HEADER);
        htp.p('<p>');
        htp.p('The QUT Phone Book Staff Updates Function allows you to modify QUT Staff contact details.'
            ||' Below is a listing of all the QUT staff in your area to which you have access to in order to update '
            ||'their details. The following details can be modified for each staff member:');
        htp.p('<ol type="1">');
        htp.p('<li>Preferred Name [Max characters = (20)].');
        htp.p('<li>Title - This can be modified for female staff members only. Select the relevant title.');
        htp.p('<li>Primary Campus - Select the relevant campus code radio button.');
        htp.p('<li>Building - You can choose from the list of buildings in the drop down menu.');
        htp.p('<li>Floor - You can choose from the list of floors in the drop down menu, once you have selected the building.');
        htp.p('<li>Room - You can choose from the list of rooms in the drop down menu, once you have selected the building and floor.');
        htp.p('<li>Phone - 30 character limit, 8 digit number (e.g. 3138 1234) if it is a QUT number.');
        htp.p('<li>Fax - 30 character limit, 8 digit number (e.g. 3138 1234) if it is a QUT number.');
        htp.p('<li>Mobile [Max characters = (20)]');
        htp.p('<li>Speed Dial [Max characters = (20)]');
        htp.p('<li>Closed User Group number [Max characters = (10)]</li>');
        htp.p('<li>Pager [Max characters = (20)]');
        htp.p('<li>URL - Their specified Homepage [Max characters = (240)]');
        htp.p('<li>New Group and Job Title - You can choose from the list of Phone Groups '
            ||'and Job titles in the drop down menu. These are created and modified from '
            ||'the Phone Book Work Group Structure Function.');
        htp.p('<li>Image Displayed - You can set [Yes/No] whether the staff members Image is '
            ||'to be displayed in their profile.');
        htp.p('<li>Print Flag - You can set the flag [Yes/No] if the record is to be displayed '
            ||'in the QUT Phonebook. If this option is set to "No" the record will not '
            ||'be displayed in the LDAP or PH Lookups for the following day.');
        htp.p('</ol>');
    END IF;

    common_template.get_full_page_footer;
    htp.p('</div>');

END help;


--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
PROCEDURE error_message(p_error IN VARCHAR2) IS
BEGIN
    htp.p('<div>');
	htp.nl;htp.nl;
    htp.p('<center><strong> ERROR !<br><br>');
    htp.p(p_error);
    htp.p('</strong><form>');
    htp.nl;
    htp.p('<input type="button" value="BACK" onclick="window.history.back()">');
    htp.p('</form>');
    htp.p('</center>');
    htp.p('</div>');
    common_template.get_full_page_footer;
END error_message;

END ph_admin_p;
/