CREATE OR REPLACE PACKAGE BODY qv_search_orgunit IS
/**
* Provide search functionality to QUT Divisions & Faculties
* Each faculty and Division can be searched top-down starting at the Faculty
* or Division at the top level down to each subsection and the staff which
* belong to that section at the lowest level.
* At the lowest level there is brief contact information about each staff
* members listed in each school/section including: Name, Position Title,
* Phone Extension, Fax Extension, Email Alias, Room, and Campus. This list
* can be reduced by clicking in the relevant campus short list option
* displayed at the bottom of the function at theis level.
* @version 1.0.0
*/
----------------------------------------------------------------------
--  Specification Modification History
--  Date         Author           Description
--  -----------  ------------------------------------------------------
--  21 Aug.2002   Lin Lin         Developed
--  27 Sep 2002   Tony Baisden	  Optimised some queries and changed some code to suit
--	   	   		  	   			  changes made to the org_units table
--  21 Jan 2004	  Lin Lin		  Replace character "&" in the organisation title (new division names)
--	   	   		  	  			  with "%26" as this name is passed as parameter in the URL,
--								  which causes confusion.
--  29 Mar 2004   Tony Le		  Remove obsolete usage of ip.qut_access_username field
--  19-JUL-2006   S.Jeong         10g Upgrade Modification
--                                Removed qv_common_style.apply
--                                Replaced with qv_common_links.get_reference_link
--                                Replaced <ul> to css style in show_lower_orgunit procedure to comply Mozilla
--                                Replaced <b> to <strong>
--                                Commented out associated codes that use client_access table - phone book admin
--                                wasn't showing as no records with PHO type found in client_access. This has
--                                been commented out.
--  02-Nov-2006   E.Wood          Removed Staff that have their Pring Flag is set to N or their subgroup_code / group_code
--                                Display Indicator is Set to N.
--  16-Jan-2008   C.Wong          Change "_new" to "_blank" to fix security issue
--  05-Dec-2008   A.McBride       Updating UI for QV 1.5 release
--  22-Apr-2009   A.McBride       Fixing minor UI bugs.
--  25-May-2009   D.Jack          Changed table from org_units to emp_org_unit
--  26-May-2009   D.Jack          Changed queries to also show end_dts and sort_orders which are null
--  29-Jul-2009   D.Jack          SAMS Upgrade
--  31-Jul-2009   C.Wong          remove sort_order NULL check, as this rule does not appear in original code
--  10-Sep-2009   P Cherukuri     Remove initcap for position title display so that the acronyms/abbreviations are displayed accroding to HR data
-- 23-Sep-2009    C Wong          Fixed position titles still displaying with sentence case (initcap) 
--                                on campus specific and print friendly pages
--  01-Jun-2010   Tony Le         Remove INITCAP when displaying department/faculty and sub-division/group name or description
--                                Previously, local name or description from emp_org_unit and group_codes table were converted to UPPER case
--                                in SQL queries and cursors and then later on INITCAP local name/description when displaying. This conversion caused 
--                                the inconsistency and abnormality in the faculty/division names in QV. For example: Qut, Its and Director'S Office 
--                                where it should really be QUT, ITS and Director's Office, respectively
--                                Indent the codes in the procedures involved 
--  18-Oct-2010   K Farlow        Modified count_staff_number slightly to use LIKE instead of = for comparison against 
--                                  p_start_org_code and added calls to check count_staff_number > 0 before displaying each 
--                                  faculty/division [QVPH-11] 
--  12-Nov-2010   Tony Le         Add other role or qualification icon (if exists) next to staff name
--                                Add legend for the icon used
--  15-Sep-2011   Loretta Dorman  Changed all references to emp_org_unit.local_name to reference emp_org_unit.org_unit_desc
--  09-Dec-2011   Tony Le         Call emp.get_role to retrieve position title
--  18-May-2015   Manjeet Kaur    Added closing table tag if exception occurs for duplicate ccr records [JIRA] (QVPH-23)
--  20-Jun-2017   Tony Le         QVSEARCH-87: Fix get_crr_client_id to handle too_many_rows returned exception
--  13-Sep-2107   Tony Le         QVSEARCH-90: Application refactoring. Added a few local functions and procedures to share common codes
--  06-Aug-2018   Sheeja Kambil   QVPH-46 Support Additional attributes in staff directory and search - Only JP and ALLY codes exists at the momement
--                                - these have been updated. Logic in procedures show_role_icon to use the attribute type instead of attribute value to work
--                                  out the Font Awsome icons. Procedure show_legend amended at the same time.
--  05-Oct-2018   Kelly Farlow    QVPH-47: Make role type icons accessible (add aria-label attribute and tooltips).
-- 05-06-2020     N.Shanmugam     Heat SR#403081: Remove the start and end date filter to be able to see staff if it belongs to an inactive faculty for better visibility.
--  18-11-2020    Tony Le         QUT-485: Removed hard-coded old org. unit code '111'
----------------------------------------------------------------------

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------
    -- comment
	empty_vc_arr 			owa.vc_arr;
	g_background_shade		VARCHAR2(10) := common_style.C_WHITE_COLOUR;
  
    C_ATTRIBUTE_TYPE           CONSTANT VARCHAR2(20)  := 'ATTRIBUTETYPE';
    C_ATTRIBUTE_VALUE          CONSTANT VARCHAR2(20)  := 'ATTRIBUTEVALUE';
    C_JPALL                    CONSTANT VARCHAR2(10)  := 'JPALL';
    C_ALLY                     CONSTANT VARCHAR2(10)  := 'ALLY'; 
    C_ITSEC                    CONSTANT VARCHAR2(10)  := 'ITSEC';

--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------
FUNCTION get_group_code (p_org_cd        VARCHAR2
                        ,p_grp_cd        NUMBER)
RETURN group_codes%ROWTYPE IS
--------------------------------------------------------------------------------
-- Purpose: Retrieve the primary phone/extension for the whole phone group
--------------------------------------------------------------------------------
    l_rec     group_codes%ROWTYPE;
    
BEGIN

    SELECT    *
    INTO	  l_rec
    FROM	  group_codes
    WHERE	  owner_org_code = p_org_cd
    AND 	  phone_group    = p_grp_cd;
    
    RETURN l_rec;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END get_group_code;

FUNCTION ccr_org_exists (p_org_cd        VARCHAR2
                        ,p_grp_cd        NUMBER)
RETURN BOOLEAN IS
--------------------------------------------------------------------------------
-- Purpose: This is basically checking to see if the org unit and group code already
--          exists for non CCR staff
--------------------------------------------------------------------------------
    l_cnt       NUMBER := 0;
BEGIN
    BEGIN
        SELECT  COUNT(DISTINCT ip_num)
        INTO    l_cnt
        FROM    ip, 
                group_codes gc,
                emp_org_unit ou
        WHERE   ip.owner_org_code = gc.owner_org_code
        AND     ip.owner_org_code = ou.org_unit_cd
        AND     start_dt <= SYSDATE
        AND    (end_dt >= SYSDATE OR end_dt IS NULL)
        AND     ip.phone_group = p_grp_cd
        AND     gc.owner_org_code = p_org_cd
        AND     gc.display_ind = 'Y'
        AND     ip_type IN ('EMP','EXT','OTH')
        AND	    ip_status = 'cur'
        AND     print_flag = 'Y';
        
        RETURN (l_cnt > 0);
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END;

END ccr_org_exists;

FUNCTION count_staff_number
(
 		  p_start_org_code  VARCHAR2
		 ,p_campus		    VARCHAR2 DEFAULT NULL
)
    RETURN NUMBER
IS
----------------------------------------------------------------------
--  Purpose:  Return a staff number for the selected organisation in the select campus.
--			  If campus is null, it includes all campuses.
----------------------------------------------------------------------
   	l_staff_ct 		 NUMBER(4) := 0;
    
BEGIN

    IF p_campus IS NULL THEN
	   BEGIN
	   		SELECT 	  COUNT (ip_num)
			INTO 	  l_staff_ct
			FROM      ip i
                     ,group_codes gc
                     ,subgroup_codes sgc
			WHERE     i.owner_org_code LIKE p_start_org_code||'%' 
			AND 	  i.ip_status = 'cur'
            AND       i.print_flag = 'Y'
            AND       i.owner_org_code = gc.owner_org_code
            AND       i.phone_group = gc.phone_group
            AND       gc.display_ind = 'Y'
            AND       gc.owner_org_code = sgc.owner_org_code
            AND       gc.phone_group = sgc.phone_group
            AND       i.phone_subgroup = sgc.phone_subgroup
            AND       sgc.display_ind = 'Y';
	   END;
	ELSE
	   BEGIN
	   		SELECT 	  COUNT (ip_num)
			INTO 	  l_staff_ct
			FROM      ip i
                     ,group_codes gc
                     ,subgroup_codes sgc
			WHERE     i.owner_org_code = p_start_org_code
			AND		  i.ip_status = 'cur'
			AND 	  i.primary_campus = p_campus
            AND       i.print_flag = 'Y'
            AND       i.owner_org_code = gc.owner_org_code
            AND       i.phone_group = gc.phone_group
            AND       gc.display_ind = 'Y'
            AND       gc.owner_org_code = sgc.owner_org_code
            AND       gc.phone_group = sgc.phone_group
            AND       i.phone_subgroup = sgc.phone_subgroup
            AND       sgc.display_ind = 'Y';
		END;
	END IF;
    
	RETURN l_staff_ct;
	EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN l_staff_ct;
        WHEN OTHERS THEN
            htp.p('<p>');
            htp.p('There was an error when producing this page. Please contact <a href="mailto:'
                ||qv_common_links.get_reference_link('QUTVIRTUAL_EMAIL')||'">'
                ||qv_common_links.get_reference_link('QUTVIRTUAL_EMAIL')||'</a> for assistance.');
            htp.p('</p>');
END count_staff_number;


FUNCTION get_ccr_client_id (p_ip_num ip.ip_num%TYPE DEFAULT NULL)
-----------------------------------------------------------------
-- Purpose: Returns ccr client id from the given ip number
-----------------------------------------------------------------
RETURN ccr_clients.client_id%TYPE IS

    l_ccr_client_id ccr_clients.client_id%TYPE;

BEGIN
	-- To find ccr_client_id by knowing ip_num. Then this number is used in common
	-- function to find client's prefered name if it is not null.
	BEGIN
        SELECT  cc.ccr_client_id
        INTO	l_ccr_client_id
        FROM 	ccr_clients cc
        WHERE   cc.ip_num = p_ip_num
        AND	   (cc.end_date >= SYSDATE OR cc.end_date IS NULL)
        AND	    cc.start_date = (
                SELECT  MAX(start_date)
	  		   	FROM 	ccr_clients
				WHERE 	ip_num = cc.ip_num
				AND	   (end_date >= SYSDATE OR end_date IS NULL));
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
		    l_ccr_client_id := NULL;
		WHEN TOO_MANY_ROWS THEN
            -- select the latest start date for the CCR record
            SELECT  cc.ccr_client_id
            INTO    l_ccr_client_id
            FROM    ccr_clients cc
            WHERE   cc.ip_num = p_ip_num
            AND	   (cc.end_date >= SYSDATE OR cc.end_date IS NULL)
            AND	    cc.start_date = (
                    SELECT MAX(start_date)
	  		   		FROM    ccr_clients
					WHERE 	ip_num = cc.ip_num
					AND	   (end_date >= SYSDATE OR end_date IS NULL))
            AND     cc.ccr_client_id IN (
                    SELECT  id
                    FROM    qv_client_role
                    WHERE   trs_client_id = cc.ip_num);
        WHEN OTHERS THEN
            l_ccr_client_id := NULL;
    END;

	RETURN l_ccr_client_id;

END get_ccr_client_id;


PROCEDURE get_org_unit_names 
(
 		 p_org_unit_cd      VARCHAR2
        ,p_local_name       OUT VARCHAR2
        ,p_area_name        OUT VARCHAR2
) IS
---------------------------------------------------------------------
--  Name:      get_org_unit_names
--	Author:	   Tony Le
--  Purpose:   Retrieve division/faculty name and/or area name.
--  Pre:	   p_org_unit_cd must not be null
--  Post:	   Send back the faculty/division name and if applicable the dep/area name
----------------------------------------------------------------------

    l_org_unit      ORG_UNIT_TYP;


BEGIN

    IF (p_org_unit_cd IS NOT NULL) AND (INSTR(LOWER(p_org_unit_cd), 'script') = 0) THEN
        
        l_org_unit := NEW ORG_UNIT_TYP(p_org_unit_cd);
    
        IF (LENGTH(p_org_unit_cd) = 3) THEN
    
            p_local_name := l_org_unit.get_title;
        
        ELSE    
        
            p_area_name  := l_org_unit.get_title;
            p_local_name := ORG_UNIT_TYP(SUBSTR(p_org_unit_cd, 1, 3)).get_title;
    
        END IF;

    END IF;

END get_org_unit_names;

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
FUNCTION get_nav_struct
(
    p_from    VARCHAR2    DEFAULT NULL
)
    RETURN owa.vc_arr
IS
	l_nav_names  owa.vc_arr DEFAULT empty_vc_arr;
BEGIN
	IF p_from = C_MY_PORTLET THEN --called by myself's links
	    l_nav_names(1) := C_DIV_FAC_BROWSE;
		l_nav_names(2) := C_SELECTED_DIV_FAC;
		l_nav_names(3) := C_ALL_CAMPUSES;
		l_nav_names(4) := C_A_CAMPUS;
	ELSE  --called by other people's links
	 	l_nav_names(1) := C_ALL_CAMPUSES;
		l_nav_names(2) := C_A_CAMPUS;
	END IF;
	RETURN l_nav_names;
END get_nav_struct;


--------------------------------------------
--            LOCAL PROCEDURES
--------------------------------------------
PROCEDURE show_table_header
IS
----------------------------------------------------------------------
--  Purpose: Show table header for staff listing
----------------------------------------------------------------------
BEGIN

    htp.p('<table class="table table-bordered table-striped table-qv dataTables" id="fac_div_staff_table" width="100%">');        
    htp.p('<thead>');
    htp.p('<tr>');
    htp.p('  <th nowrap width="20%">Name</th>');
    htp.p('  <th width="25%">Position Title</th>');
    htp.p('  <th nowrap width="10%">Phone</th>');
    htp.p('  <th nowrap width="10%">Fax</th>');
    htp.p('  <th nowrap width="10%">Email Alias</th>');
    htp.p('  <th width="20%">Room</th>');
    htp.p('  <th width="5%">Location</th>');
    htp.p('</tr>');
    htp.p('</thead>');
    htp.p('<tbody>');                    

END show_table_header;

PROCEDURE show_print_table_header
IS
----------------------------------------------------------------------
--  Purpose: Show table header for staff listing
----------------------------------------------------------------------
BEGIN

    htp.p('<table class="table table-bordered table-striped table-qv dataTables" id="fac_div_staff_table" width="100%">');        
    htp.p('<thead>');
    htp.p('<tr bgcolor="#cccccc">');
    htp.p('  <th align="left" nowrap width="20%">Name</th>');
    htp.p('  <th align="left" width="25%">Position Title</th>');
    htp.p('  <th align="left" nowrap width="10%">Phone</th>');
    htp.p('  <th align="left" nowrap width="10%">Fax</th>');
    htp.p('  <th align="left" nowrap width="10%">Email Alias</th>');
    htp.p('  <th align="left" width="20%">Room</th>');
    htp.p('  <th align="left" width="5%">Location</th>');
    htp.p('</tr>');
    htp.p('</thead>');
    htp.p('<tbody>');                    

END show_print_table_header;

--------------------------------------------
PROCEDURE show_error_page
IS
----------------------------------------------------------------------
--  Purpose: Show error page for exception 'others'
----------------------------------------------------------------------
BEGIN
	htp.p('<p>');
    htp.p('There was an error when producing this page. Please contact <a href="mailto:'
	   ||qv_common_links.get_reference_link('QUTVIRTUAL_EMAIL')||'">'
	   ||qv_common_links.get_reference_link('QUTVIRTUAL_EMAIL')||'</a> for assistance.');
    htp.p('</p>');
END show_error_page;


PROCEDURE show_lower_orgunit
(
     p_orgunit 				  emp_org_unit.org_unit_desc%TYPE
	,p_orgunit_code 		  emp_org_unit.org_unit_cd%TYPE
)
IS
----------------------------------------------------------------------
--  Purpose: To display Clevel 4 organizations and phone groups under them.
----------------------------------------------------------------------

	CURSOR c_clevel4_orgunits (p_org_unit_cd emp_org_unit.org_unit_cd%TYPE) IS
		   SELECT   ou.org_unit_cd code
				   ,UPPER(ou.org_unit_desc) org_unit_desc
		   FROM     emp_org_unit ou
		   WHERE    ou.sort_order < 90
		   AND      ou.hierarchy_level = 'CLEVEL4'
		   AND      start_dt <= sysdate
           AND      (end_dt >= sysdate OR end_dt IS NULL)
		   AND      ou.org_unit_cd LIKE p_org_unit_cd || '%'
		   ORDER BY ou.sort_order, ou.hierarchy_level, ou.org_unit_cd;

	CURSOR c_unit_groups (p_org_unit_cd emp_org_unit.org_unit_cd%TYPE) IS--all org unit code under clevel4
		   SELECT   UPPER(description) description
		   FROM	    group_codes
		   WHERE	owner_org_code = p_org_unit_cd
		   AND		phone_group < 888--Condition to take of null value groups and undefined group. eg phone_group 888 in org_code 161003
           AND      phone_group IN (
                    SELECT  DISTINCT phone_group 
                    FROM    ip 
                    WHERE   print_flag = 'Y' 
                    AND     owner_org_code = p_org_unit_cd)
           AND      display_ind = 'Y'
		   ORDER BY print_order;
BEGIN

	FOR r_clevel4 IN c_clevel4_orgunits (p_orgunit_code) LOOP
       
        IF count_staff_number(r_clevel4.code) > 0 THEN       
       
            htp.p('<tr>');
            htp.p('<td width="20">&nbsp;</td>');
            htp.p('<td colspan="2"><a href="qv_search_orgunit_p.show?p_arg_names=p_clevel&p_arg_values=clevel'
                ||'&p_arg_names=p_org_unit_code&p_arg_values='||REPLACE(r_clevel4.code,' ','+')
                ||'&p_arg_names=p_campus&p_arg_values=all'
                ||'&p_arg_names=p_from&p_arg_values='||C_MY_PORTLET
                ||'&'||common_template.set_nav_path(C_SELECTED_DIV_FAC)
                ||'">'||r_clevel4.org_unit_desc||'</a></td>');
            htp.p('</tr>');

            -- display all phone groups under clevel 4 in the corresponding organization hierarchy
            FOR r_group IN c_unit_groups(r_clevel4.code) LOOP
                IF r_group.description <> ' ' THEN
                    htp.p('<tr>');
                    htp.p('<td colspan="2" width="40">&nbsp;</td>');
                    htp.p('<td>'||r_group.description||'</td>');
                    htp.p('</tr>');
                END IF;
            END LOOP;
          
        END IF;
              
    END LOOP;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
	  	htp.p('<p>There are no staff currently in this school / section.</p>');
	WHEN OTHERS THEN
        show_error_page;
END show_lower_orgunit;

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------

PROCEDURE show_option
IS
----------------------------------------------------------------------
--  Purpose: Only used when exception happens, which will display browser link again
----------------------------------------------------------------------

BEGIN
	htp.p('<a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=BROWSE">Browse Divisions and Faculties?</a>');
EXCEPTION
	WHEN OTHERS THEN
        htp.p('<p>');
        htp.p('There was an error when producing this page. Please contact <a href="mailto:'
	       ||qv_common_links.get_reference_link('QUTVIRTUAL_EMAIL')||'">'
		   ||qv_common_links.get_reference_link('QUTVIRTUAL_EMAIL')||'</a> for assistance.');
    	htp.p('</p>');
END show_option;


PROCEDURE show_role_icon (p_employee_id IN NUMBER) IS
----------------------------------------------------------------------
--  Purpose: show the icon for various staff roles and qualifications 
----------------------------------------------------------------------

CURSOR c_role_icons (p_user_type qv_client_role.role_cd%TYPE)
IS 
    
    SELECT DISTINCT DECODE(ea.attribute_type, qrc1.reference_cd, qrc1.description) icon_details, 
                    DECODE(ea.attribute_value, qrc2.reference_cd, qrc2.sort_order) icon_order,
                    ea.attribute_type
    FROM    emp_attribute    ea
           ,qv_reference_cd  qrc1
           ,qv_reference_cd  qrc2
    WHERE   ea.employee_id        = p_employee_id
    AND     ea.attribute_type     = qrc1.reference_cd
    AND     qrc1.code_category_cd = C_ATTRIBUTE_TYPE
    AND     qrc1.active_ind       = 'Y'
    AND     ea.attribute_value    = qrc2.reference_cd
    AND     qrc2.code_category_cd = C_ATTRIBUTE_VALUE
    AND     qrc2.active_ind       = 'Y'    
    -- this is to show icon: if student, show staff JPs with staff & student availability
    -- for all staff, show everything
    AND     ea.attribute_type = DECODE(p_user_type, common_client.C_STU_ROLE_TYPE, C_JPALL, ea.attribute_type)
    ORDER BY icon_order;

    l_user_id           qv_client_role.id%TYPE;
    l_user_type         qv_client_role.role_cd%TYPE;
    l_role_desc         qv_reference_cd.description%TYPE;
    l_role_tooltip      VARCHAR2(100);

BEGIN
    
    qv_common_id.identify_role (p_username        => qv_audit.get_username
                               ,p_user_id         => l_user_id
                               ,p_user_type       => l_user_type
                               ,p_role_active_ind => 'Y');

    FOR r_role_icon IN c_role_icons (l_user_type) LOOP   
        l_role_desc := TRIM(SUBSTR(r_role_icon.icon_details, 1, INSTR(r_role_icon.icon_details, '#',1) - 1));
        l_role_tooltip := CASE r_role_icon.attribute_type 
                              WHEN C_ALLY  THEN 'Ally' 
                              WHEN C_ITSEC THEN 'Information Security Champion' 
                              ELSE              'Justice of the Peace or Commissioner for Declarations' 
                          END;
        htp.p('<span class="'|| TRIM(SUBSTR(r_role_icon.icon_details, INSTR(r_role_icon.icon_details, '#',1) + 1, ( INSTR(r_role_icon.icon_details, '#', 1, 2) - 1) - INSTR(r_role_icon.icon_details, '#',1) )) 
            ||'" style="color:'|| TRIM(SUBSTR(r_role_icon.icon_details, INSTR(r_role_icon.icon_details, '#',1, 2) + 1)) ||'" role="img" aria-label="'||l_role_desc||'" title="'||l_role_tooltip||'">&nbsp;</span>');
    END LOOP;
    
END show_role_icon;

PROCEDURE show_legend IS
----------------------------------------------------------------------
--  Purpose: show qualification legend for the icon used in staff listing page
----------------------------------------------------------------------

CURSOR c_qv_reference 
IS
     SELECT DISTINCT description
     FROM   qv_reference_cd 
     WHERE  code_category_cd = C_ATTRIBUTE_TYPE
     AND    active_ind = 'Y';

BEGIN

    htp.p('<div class="content-section-blue width55">');
    htp.p('<h3 class="content-section-blue-title">Role Types Legend</h3>');
    htp.p('<ul class="linklist">');
    FOR r_qv_reference IN c_qv_reference LOOP
        htp.p('    <li><span class="'||TRIM(SUBSTR(r_qv_reference.description, INSTR(r_qv_reference.description, '#',1) + 1, ( INSTR(r_qv_reference.description, '#', 1, 2) - 1) - INSTR(r_qv_reference.description, '#',1) ))
                   ||'" style="color:'||TRIM(SUBSTR(r_qv_reference.description, INSTR(r_qv_reference.description, '#',1, 2) + 1))||'">&nbsp;</span>' 
               ||'<span>'||TRIM(SUBSTR(r_qv_reference.description, 1, INSTR(r_qv_reference.description, '#',1) - 1)) ||'</span></li>');
    END LOOP;    
    htp.p('</ul>');
    htp.p('</div>');
    
END show_legend;

PROCEDURE show_orgunit_list
(
     p_browse        BOOLEAN	DEFAULT TRUE
    ,p_org_unit_code VARCHAR2	DEFAULT NULL
)
IS
----------------------------------------------------------------------
--  Purpose:  List QUT organisational hierarchy structure as an indented list
----------------------------------------------------------------------
	l_background_shade		VARCHAR2(10) := common_style.C_WHITE_COLOUR;
	l_org_unit_code			emp_org_unit.org_unit_cd%TYPE;
	l_local_name			emp_org_unit.org_unit_desc%TYPE;
    l_area_name             emp_org_unit.org_unit_desc%TYPE;
	l_first_loop_ind		BOOLEAN := TRUE;
    
CURSOR c_clevel2_orgunits IS
-- org_unit_desc
 	SELECT UPPER(org_unit_desc) org_unit_desc  
			,org_unit_cd
	FROM     emp_org_unit
	WHERE    hierarchy_level = 'CLEVEL2'
    AND	 	 sort_order < 90
	AND 	 start_dt <= SYSDATE
    AND     (end_dt >= SYSDATE
         OR  end_dt IS NULL)
	ORDER BY sort_order; 

CURSOR c_clevel3_orgunits (c_org_unit_code emp_org_unit.org_unit_cd%TYPE) IS
	SELECT  ou.org_unit_cd
		   ,UPPER(ou.org_unit_desc) org_unit_desc
	FROM    emp_org_unit ou
	WHERE   sort_order < 90
	AND     ou.hierarchy_level = 'CLEVEL3'
	AND     start_dt <= SYSDATE
    AND    (end_dt >= SYSDATE OR end_dt IS NULL)
	AND     ou.org_unit_cd LIKE c_org_unit_code || '%'
	AND     ou.org_unit_desc NOT IN ('Central Initiatives','Pro-Vice-Chancellor (Academic)')
   	ORDER BY ou.sort_order, ou.hierarchy_level, ou.org_unit_cd;

BEGIN
    htp.p('<script type="text/javascript"><!--');
    htp.p('$(document).ready(function() {');
    htp.p('    $("#fac_div_list_table").dataTable({');
    htp.p('    });');
    htp.p('});');
    htp.p('//-->');
    htp.p('</script>');
    htp.p('<style type="text/css">');
    htp.p('.table-bordered {');
    htp.p('    border: 0px !important;');
    htp.p('}');
    htp.p('.table-bordered th, .table-bordered td {');
    htp.p('    border: 0px !important;');
    htp.p('}');
    htp.p('</style>');

	IF p_browse THEN --happens when user clicks the link of Browser QUT Divisions and Faculties-CLEVEL2 organizations displayed
        htp.p('<h1>Divisions and Faculties</h1>');
        
	    FOR r_c2_orgunit IN c_clevel2_orgunits LOOP
        
            IF count_staff_number(r_c2_orgunit.org_unit_cd) > 0 THEN
        
                IF l_first_loop_ind THEN
                    htp.p('<table class="table table-bordered table-striped table-qv dataTables" id="fac_div_list_table" width="100%">');        
                    htp.p('<tbody>');                    
                    l_first_loop_ind := FALSE;
                END IF;

                htp.p('<tr>');
                htp.p('  <td><a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=defined_org'||
                    '&p_arg_names=p_org_unit_code&p_arg_values='||r_c2_orgunit.org_unit_cd||
                    '&'||common_template.set_nav_path(C_DIV_FAC_BROWSE)||'">'||r_c2_orgunit.org_unit_desc||'</a></td>');
                htp.p('</tr>');
            END IF;
            
        END LOOP;

        IF NOT(l_first_loop_ind) THEN
            htp.p('</tbody>');
            htp.p('</table>');
        END IF;
	ELSE
    
        get_org_unit_names (p_org_unit_code, l_local_name, l_area_name);
        
	    FOR r_c3_orgunit IN c_clevel3_orgunits (p_org_unit_code) LOOP

            IF count_staff_number(r_c3_orgunit.org_unit_cd) > 0 THEN
                    
                IF l_first_loop_ind THEN

                    htp.p('<h1>'|| REPLACE(REPLACE(l_local_name,'+',' '),'%26','&') ||'</h1>');
                    htp.p('<table class="table table-bordered table-striped table-qv dataTables" id="fac_div_list_table" width="100%">');
                    htp.p('<tbody>');
                    l_first_loop_ind := FALSE;
                END IF;
                g_background_shade := common_style.get_background_shade(g_background_shade);
                htp.p('<tr>');
                htp.p('<td colspan="3"><a href="qv_search_orgunit_p.show?p_arg_names=p_clevel&p_arg_values=clevel'
                    ||'&p_arg_names=p_org_unit_code&p_arg_values='||r_c3_orgunit.org_unit_cd
                    ||'&p_arg_names=p_campus&p_arg_values=all'
                    ||'&p_arg_names=p_from&p_arg_values='||C_MY_PORTLET
                    ||'&'||common_template.set_nav_path(C_SELECTED_DIV_FAC)
                    ||'">'||r_c3_orgunit.org_unit_desc||'</a></td>');
                htp.p('</tr>');
                show_lower_orgunit (p_orgunit => r_c3_orgunit.org_unit_desc
                                   ,p_orgunit_code => r_c3_orgunit.org_unit_cd);
                                   
            END IF; 
                                         
       END LOOP;
       IF NOT(l_first_loop_ind) THEN
           htp.p('</tbody>');
           htp.p('</table>');
       END IF;
	   htp.nl;
	END IF;
EXCEPTION
	WHEN OTHERS THEN
        show_error_page;
END show_orgunit_list;

PROCEDURE show_all_ally 
IS
----------------------------------------------------------------------
--  Name:      show_ally_list
--	Author.    Tony Le
--  Purpose:   Show all staff within ALLY Network 
--  Pre:	   TRUE
--  Post:	   A list of staff who are qualified to be an Ally within QUT
----------------------------------------------------------------------

    CURSOR  c_level2 IS
        SELECT      qrc.reference_cd org_unit_cd
                   ,qrc.description
        FROM        qv_reference_cd qrc 
        WHERE       qrc.code_category_cd = 'ALLY_FAC_DIV'
        AND         qrc.active_ind = 'Y' 
        ORDER BY    qrc.sort_order; 
    
    CURSOR  c_level3 (p_clevel2 VARCHAR2) IS
        SELECT      eou.org_unit_cd
                   ,eou.org_unit_desc
        FROM        emp_org_unit eou 
        WHERE       eou.parent_org_unit_cd = p_clevel2
	    AND         eou.sort_order < 90
	    AND         eou.hierarchy_level = 'CLEVEL3'
        AND         eou.start_dt <= TRUNC(SYSDATE)
        AND        (eou.end_dt >= TRUNC(SYSDATE) OR end_dt IS NULL)
	    AND         eou.org_unit_desc NOT IN ('Central Initiatives','Pro-Vice-Chancellor (Academic)')
        AND         EXISTS (
                    SELECT      DISTINCT 'x'
                    FROM        emp_employee_job eej
                    WHERE       eou.org_unit_cd = SUBSTR(eej.org_unit_cd, 1, 5)
                    )
        ORDER BY    eou.sort_order;

        
    CURSOR c_staff (p_clevel3       VARCHAR2
                   ,p_user_type     VARCHAR2) IS
        SELECT  DISTINCT
                eej.employee_id
               ,qcr.role_cd
               ,qv_common.get_full_preferred_name (qcr.username) full_preferred_name
               ,emp.get_role (qcr.trs_client_id) job_title
               ,qou.title section
               ,qv_common.get_surname (qcr.username) surname
               ,qcr.trs_client_id 
        FROM    emp_attribute ea
               ,emp_employee_job eej
               ,qv_client_role qcr
               ,qv_org_unit qou
        WHERE   ea.attribute_type = 'ALLY'
        AND    (ea.attribute_value = DECODE(p_user_type, 'STU', 'ALL', ea.attribute_value))
        AND     ea.employee_id = eej.employee_id
        AND 	eej.org_unit_cd LIKE p_clevel3 || '%'
        AND     eej.period_active_ind = 'Y'
        AND     TRUNC(SYSDATE) BETWEEN TRUNC(eej.start_dt) AND TRUNC(eej.end_dt)
        AND     eej.start_dt = (
                SELECT  MAX(eej2.start_dt)
                FROM    emp_employee_job eej2
                WHERE   eej2.employee_id = eej.employee_id
                AND     TRUNC(SYSDATE) BETWEEN TRUNC(eej2.start_dt) AND TRUNC(eej2.end_dt)
                AND     eej2.period_active_ind = 'Y'
                )                
        AND     eej.employee_id = qcr.id
        AND     qcr.role_cd = 'EMP'
        AND     qcr.role_active_ind = 'Y'
        AND     qou.org_unit_cd = eej.org_unit_cd
        ORDER BY surname;        

    l_cnt       NUMBER := 0;
    l_user_role qv_client_role.role_cd%TYPE := qv_common_id.get_user_role;
    
BEGIN

    htp.p('<style type="text/css">');
            -- override common style to set specific height
    htp.p('
    html {
        overflow-y: scroll;
    }
    #content ul > li {
        background: none !important;
    }
    .internal {
        padding: 0.2px;
    }
    #content ul {
        padding: 0px !important;
    }
    
    tr.even { 
        background-color: none; 
    }
    tr.odd { 
        background-color: #f9f9f9; 
    }
    a.ally {
        color: purple;
        text-decoration: underline;
    }
    ');
    htp.p('</style>');
    
    htp.p('
    <script type="text/javascript">
        $(function(){
            // Apply to each table individually and make sure nothing is doubleclassed
            // if you run this multiples of times.
            $("table").each(function() {
                $("tr:odd",  this).addClass("odd").removeClass("even");
                $("tr:even", this).addClass("even").removeClass("odd");
            });
        });
        $(document).ready(function() {
        
            $(".internal").hide();
        
            $(".slider").click(function() {
                $(this).next(".internal").slideToggle();
            }).toggle(function() {
                $(this).find($(".fa-plus-circle")).removeClass("fa-plus-circle").addClass("fa-minus-circle");
            }, function() {
                $(this).find($(".fa-minus-circle")).removeClass("fa-minus-circle").addClass("fa-plus-circle");
            });
        
        });    
    </script>
    ');

	htp.p('<h1>QUT ALLIES</h1>');
    htp.p('  <div class="alert alert-info info-msg info-msg-background">');
    htp.p('    <p>This page contains a list of trained Allies at QUT. Please feel free to reach out for support or advice. 
               For more information please visit: <a href="'|| qv_common_links.get_reference_link ('ALLY_NETWORK_URL') ||'" class="ally">Ally Network</a></p>');
    htp.p('  </div>');
    FOR r_clevel2 IN c_level2 LOOP

        htp.p('  <h4 class="slider"><a href="#"><i class="far fa-plus-circle"></i></a>&nbsp;&nbsp;' || r_clevel2.description ||'</h3>');
        htp.p('    <div class="internal">');    
        FOR r_clevel3 IN c_level3 (p_clevel2 => r_clevel2.org_unit_cd) LOOP
        
            l_cnt := 0;
            htp.p('      <ul>');
            htp.p('        <h5>'|| r_clevel3.org_unit_desc ||'</h4>');
            -- Display ally staff details
            FOR r_staff IN c_staff (p_clevel3   => r_clevel3.org_unit_cd
                                   ,p_user_type => l_user_role) LOOP
                l_cnt := l_cnt + 1;
                IF (l_cnt = 1) THEN
                    htp.p('        <ul>');
                    htp.p('          <table width="100%">');
                END IF;
                
                htp.p('            <tr>');
                htp.p('              <td width="20%"><a href="'||qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_USER_PROFILE')
                                     ||'?id='||r_staff.employee_id||'&roleCode='||r_staff.role_cd||'">'|| r_staff.full_preferred_name ||'</a></td>');
                htp.p('              <td width="40%">'|| r_staff.job_title ||'</td>');
                htp.p('              <td width="40%">'|| r_staff.section ||'</td>');
                htp.p('            </tr>');
                
            END LOOP;
            
            IF (l_cnt > 0) THEN
                htp.p('            <tr><td colspan="2"></td><td>Total:&nbsp;&nbsp;'|| l_cnt || '</td></tr>');
                htp.p('          </table>');
                htp.p('        </ul>');
            ELSE
                htp.p('        <ul>No Allies found.</ul>');
            END IF;
            
            htp.p('      </ul>');
        
        END LOOP;
        htp.p('    </div>');    
        
    END LOOP;
    
END show_all_ally;



PROCEDURE show_details
(
    p_start_org_code    VARCHAR2
   ,p_campus		    VARCHAR2 DEFAULT NULL
   ,p_from		        VARCHAR2 DEFAULT NULL
)
IS

----------------------------------------------------------------------
--  Purpose:  Display  detaided information about each staff members listed in the selected
--			  school/section.
----------------------------------------------------------------------
	l_background_shade		VARCHAR2(10) := common_style.C_WHITE_COLOUR;
	l_org_code_temp			emp_org_unit.org_unit_cd%TYPE := 0;
	l_ip_type				ip.ip_type%TYPE;
	l_num					VARCHAR2(20); --For CCR people, It's ip.ip_num; For other staffs, it's employee_num.
	l_ccr_client_id			qv_client_role.id%TYPE;
	l_full_pref_name		VARCHAR2(200);
	l_total		 			NUMBER := 0; --number of staffs in an org. unit
	l_ccr_not_display_ct	NUMBER := 0; --number of ccr staffs who have not had their info. loaded into database yet.
	l_campus_cnt		   	NUMBER := 0;
	l_phone_group		   	NUMBER := 0;
	l_sub_staff_ct			NUMBER := 0; --use to count staff number in a phone group other than non displayable CCR people
	l_email_addr			VARCHAR2(50);
	l_email_alias			VARCHAR2(30);
    l_show_legend_ind       VARCHAR2(1) := 'N';
    l_group_cd              group_codes%ROWTYPE;
    l_local_name            emp_org_unit.org_unit_desc%TYPE;
    l_area_name             emp_org_unit.org_unit_desc%TYPE;

CURSOR c_all_camp_staffs (l_org_code VARCHAR2) IS
	SELECT
	  	  ip.owner_org_code
		  , ip.employee_num
		  , ip.phone_group
		  , ip.Preferred_name
		  , ip.surname
		  , ip.ip_num
		  , ip_type
		  , ip.primary_fax
		  , ip.primary_extn
		  , NVL(ip.primary_campus,'&nbsp;') primary_campus
		  , NVL(ip.primary_location,'&nbsp;') primary_location
          , CASE WHEN  ou.start_dt <= SYSDATE
                  AND (ou.end_dt   >= SYSDATE
                    OR ou.end_dt   IS NULL   ) THEN ou.org_unit_desc
                 ELSE                               ou.org_unit_desc || ' (Inactive)'
            END    AS  code_org_unit_desc
	FROM    emp_org_unit ou
		   ,group_codes gc
		   ,subgroup_codes sgc
		   ,ip
	WHERE   ou.org_unit_cd LIKE (l_org_code || '%')	
	AND     gc.owner_org_code = ou.org_unit_cd
    AND     gc.display_ind = 'Y'
	AND     sgc.owner_org_code = gc.owner_org_code
	AND     sgc.phone_group = gc.phone_group
    AND     sgc.display_ind = 'Y'
	AND     ip.owner_org_code = sgc.owner_org_code
	AND     ip.phone_group = sgc.phone_group
	AND     ip.phone_subgroup = sgc.phone_subgroup
	AND 	ip_type IN ('EMP','EXT','OTH','CCR')
	AND		ip_status = 'cur'
    AND     print_flag = 'Y'
	ORDER BY ou.sort_order
		    ,gc.print_order
			,sgc.print_order
			,ip.surname;

CURSOR c_campuses (l_org_code VARCHAR2) IS
	SELECT     DISTINCT primary_campus prim_camp
	FROM       emp_org_unit ou, ip
	WHERE  	   ou.org_unit_cd LIKE (l_org_code || '%')
	AND        start_dt <= sysdate
    AND        (end_dt >= sysdate OR end_dt IS NULL)
	AND        ou.org_unit_cd = ip.owner_org_code
	AND 	   ip_type IN ('EMP','EXT','OTH','CCR')
    AND		   ip_status = 'cur'
    AND        ip.print_flag ='Y'
	AND 	   ip.primary_campus IS NOT NULL;

CURSOR c_a_camp_staffs (l_org_code VARCHAR2
	   				   ,l_campus VARCHAR2) IS
	SELECT
	  	  ip.owner_org_code
		  , ip.employee_num
		  , ip.phone_group
		  , ip.Preferred_name
		  , ip.surname
		  , ip.ip_num
		  , ip_type
		  , ip.primary_fax
		  , ip.primary_extn
		  , NVL(ip.primary_campus,'&nbsp;') primary_campus
		  , NVL(ip.primary_location,'&nbsp;') primary_location
          , CASE WHEN  ou.start_dt <= SYSDATE
                  AND (ou.end_dt   >= SYSDATE
                    OR ou.end_dt   IS NULL   ) THEN ou.org_unit_desc
                 ELSE                               ou.org_unit_desc || ' (Inactive)'
            END    AS  code_org_unit_desc
	FROM    emp_org_unit ou, group_codes gc, subgroup_codes sgc, ip
	WHERE   ou.org_unit_cd LIKE (l_org_code || '%')
	AND     gc.owner_org_code = ou.org_unit_cd
    AND     gc.display_ind = 'Y'
	AND     sgc.owner_org_code = gc.owner_org_code
	AND     sgc.phone_group = gc.phone_group
    AND     sgc.display_ind = 'Y'
	AND     ip.owner_org_code = sgc.owner_org_code
	AND     ip.phone_group = sgc.phone_group
	AND     ip.phone_subgroup = sgc.phone_subgroup
	AND 	ip_type IN ('EMP','EXT','OTH','CCR')
	AND		ip_status = 'cur'
	AND 	ip.primary_campus = l_campus
    AND     ip.print_flag = 'Y'
	ORDER BY ou.sort_order
		    ,gc.print_order
			,sgc.print_order
			,ip.surname;
            
BEGIN
    htp.p('<script type="text/javascript"><!--');
    htp.p('$(document).ready(function() {');
    htp.p('    $("#fac_div_staff_table").dataTable({');
    htp.p('    });');
    htp.p('});');
    htp.p('//-->');
    htp.p('</script>');
    htp.p('<style type="text/css">');
    htp.p('.table-bordered {');
    htp.p('    border: 0px !important;');
    htp.p('}');
    htp.p('.table-bordered th, .table-bordered td {');
    htp.p('    border: 0px !important;');
    htp.p('}');
    htp.p('#content h3 {');
    htp.p('    font-size: 1.3em;');
    htp.p('    font-weight: bold;');
    htp.p('    line-height: 0px;');
    htp.p('    padding: 0 0 0;');
    htp.p('}');    
    htp.p('#content ul > li {');
    htp.p('    background: none !important');
    htp.p('}');        
    htp.p('.content-section-blue {
               padding: 0 0 0 0;
          }');        
    
    htp.p('</style>');
    
    get_org_unit_names (p_start_org_code, l_local_name, l_area_name);

    htp.p('<h1>' || UPPER(NVL(l_area_name, l_local_name)) || ' ' || CASE WHEN p_campus IS NULL THEN '' ELSE '- '|| p_campus ||'' END ||'</h1>');
	IF p_campus IS NULL THEN --will display all campus staffs in the selected org.
	 	FOR r_all_camp_staff IN c_all_camp_staffs(p_start_org_code) LOOP
            l_ip_type := r_all_camp_staff.ip_type;
			IF l_org_code_temp <> r_all_camp_staff.owner_org_code THEN --only display org_unit_desc once for different owner_org_code selected from the cursor
                IF (l_total > 0) THEN
                    htp.p('</table>');
                END IF;
			    l_org_code_temp := r_all_camp_staff.owner_org_code;
		        htp.p('<h2>');
	  	        htp.p(''|| r_all_camp_staff.code_org_unit_desc || '');
			    l_total := l_total + count_staff_number(r_all_camp_staff.owner_org_code, p_campus);
			    htp.p('</h2>');
                show_table_header;
			    l_phone_group := 0; --redefine it to 0 because phone_group can be same for diff. org. Without it, the next "IF" could be false even it is in diffrent org.
			END IF;
            
			-- Check if the staff is a CCR person; if YES, checking is ccr_client_id exists;
			-- If ccr_client_id is not exists, do not display this person. If this person is the
			-- only person in the relative phone group(the last level in the displayed organisation
			-- hierarchy), do not display the phone group title(normally it is an undefined group)
			-- and column names.
			IF r_all_camp_staff.ip_type = 'CCR' THEN
			 	l_num := r_all_camp_staff.ip_num;

				l_ccr_client_id := get_ccr_client_id (l_num);

				IF l_ccr_client_id IS NOT NULL THEN
				   l_full_pref_name := ccr_common.get_full_preferred_name(l_ccr_client_id);
				   l_email_addr     := ccr_common.get_email(l_ccr_client_id,'Y');
                   l_email_alias    := ccr_common.get_email(l_ccr_client_id,'N');
				ELSE
				   l_ccr_not_display_ct := l_ccr_not_display_ct + 1;
				END IF;
			ELSE --Not CCR clients, so the ip_type can be EMP, OTH or EXT.
			 	l_num := r_all_camp_staff.employee_num;

				l_full_pref_name := NVL(emp.get_full_preferred_name(l_num),'n/a');
				l_email_addr     := emp.get_email(l_num,'Y');
				l_email_alias    := emp.get_email(l_num,'N');
			END IF;

			IF l_phone_group <> r_all_camp_staff.phone_group THEN --Only display once for diff. organisation's diff. phone group
			 	
			 	l_phone_group := r_all_camp_staff.phone_group;
                -- getting the details of org code and phone group including the description, phone and fax number
                l_group_cd    := get_group_code (l_org_code_temp
                                                ,l_phone_group);
                                                
				-- If the person is CCR client and ccr_client_id is not loaded into database
				-- yet, checking if any non CCR staff exists in this section. If not, do not
				-- display this section title and column names.
				IF (r_all_camp_staff.ip_type = 'CCR' AND l_ccr_client_id IS NULL) THEN
                
				    IF ccr_org_exists (l_org_code_temp, l_phone_group) THEN
                    
				   	    htp.p('<tr><td colspan="7"><h3>'||NVL(l_group_cd.description,' ')||'</h3></td></tr>');
			 		
                    END IF;
                    
				ELSE
                    htp.p('<tr><td colspan="7"><h3>'||NVL(l_group_cd.description,' ')||'</h3></td></tr>');
				END IF;
			END IF;
			
            -- display staff details
            IF r_all_camp_staff.ip_type <> 'CCR'  OR
              (r_all_camp_staff.ip_type = 'CCR' AND l_ccr_client_id IS NOT NULL) THEN
               l_background_shade := common_style.get_background_shade(l_background_shade);

                htp.p('  <tr>');
                htp.p('  <td><a href="'||qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_USER_PROFILE')||'?id='||l_num
							  ||'&roleCode='||l_ip_type||'">'||l_full_pref_name||'</a>');
                -- show all role icons
                IF (emp.has_other_roles(l_num)) THEN
                
                    l_show_legend_ind := 'Y';
                    show_role_icon (l_num);
                    
                END IF;
                htp.p('  </td>');
                htp.p('  <td>'
                              || emp.get_role(r_all_camp_staff.ip_num) ||'</td>');
                htp.p('  <td>'|| NVL(r_all_camp_staff.primary_extn, l_group_cd.primary_extn)||'</td>');
                htp.p('  <td>'||NVL(r_all_camp_staff.primary_fax, l_group_cd.primary_fax) ||'</td>');
                IF l_email_addr = ' ' THEN
                    htp.p('  <td>n/a</td>');
                ELSE
                    htp.p('  <td>'
                             ||'<a href="mailto:'||l_email_addr||'">'|| l_email_alias ||'</a></td>');
                END IF;
                htp.p('  <td>' ||r_all_camp_staff.primary_location ||'</td>');
                htp.p('  <td>' ||r_all_camp_staff.primary_campus ||'</td>');
                htp.p('</tr>');

			END IF;
		END LOOP;
        l_total := l_total - l_ccr_not_display_ct;
        IF (l_total > 0) THEN
            htp.p('</table>');
        END IF;		
		htp.p('<p>');
		htp.p('Total number of staff: <strong>'||l_total||'</strong><br>' );
	 	htp.p('View by campus:  ');
		FOR r_camp IN c_campuses(p_start_org_code) LOOP
			   htp.p('<a href="qv_search_orgunit_p.show?p_arg_names=p_clevel&p_arg_values=clevel'
		  	   ||'&p_arg_names=p_org_unit_code&p_arg_values='||p_start_org_code
		  	   ||'&p_arg_names=p_campus&p_arg_values='||r_camp.prim_camp
			   ||'&p_arg_names=p_from&p_arg_values='||p_from
			   ||'&'||common_template.set_nav_path(C_ALL_CAMPUSES)
			   ||'"><strong>'||r_camp.prim_camp||'</strong></a>');
		END LOOP;
		htp.p('<br><a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=print'
		   ||'&p_arg_names=p_org_unit_code&p_arg_values='||p_start_org_code
		   ||'&p_arg_names=p_campus&p_arg_values=all" target ="_blank">View print-friendly staff list</a></li>');
		htp.p('</p>');

        -- show qualification legend
        IF (l_show_legend_ind = 'Y') THEN
            show_legend;
        END IF;

    ELSE   -- p_campus is not NULL; Should display selected campus staffs for that org.
	    l_org_code_temp := 0;
		FOR r_a_camp_staff IN c_a_camp_staffs(p_start_org_code, p_campus) LOOP
			IF l_org_code_temp <> r_a_camp_staff.owner_org_code THEN -- only display org_unit_desc once for different owner_org_code selected from the cursor
			    l_org_code_temp := r_a_camp_staff.owner_org_code;
                IF (l_total > 0) THEN
                    htp.p('</table>');
                END IF;
		        htp.p('<h2>');
	  	        htp.p(r_a_camp_staff.code_org_unit_desc);
			    l_total := l_total + count_staff_number(r_a_camp_staff.owner_org_code, p_campus); --'N' means using non-printing fond
			    htp.p('</h2>');
                show_table_header;
			    l_phone_group := 0; --redefine it to 0 because phone_group can be same for diff. org. Without it, the next "IF" could be false even it is in diffrent org.
			END IF;
            
			-- Check if the staff is a CCR person; if YES, checking is ccr_client_id exists;
			-- If ccr_client_id is not exists, do not display this person. If this person is the
			-- only person in the relative phone group(the last level in the displayed organisation
			-- hierarchy), do not display the phone group title(normally it is an undefined group)
			-- and column names.
			IF r_a_camp_staff.ip_type = 'CCR' THEN
			 	l_ip_type       := 'CCR';
				l_num           := r_a_camp_staff.ip_num;
				l_ccr_client_id := get_ccr_client_id (l_num);

				IF l_ccr_client_id IS NOT NULL THEN
				    l_full_pref_name := ccr_common.get_full_preferred_name(l_ccr_client_id);
				    l_email_addr     := ccr_common.get_email(l_ccr_client_id,'Y');
				    l_email_alias    := ccr_common.get_email(l_ccr_client_id,'N');
				ELSE
				    l_ccr_not_display_ct := l_ccr_not_display_ct + 1;
				END IF;
			ELSE --Not CCR clients, so the ip_type can be EMP, OTH or EXT.
			 	l_ip_type        := 'NOT';
				l_num            := r_a_camp_staff.employee_num;
				l_full_pref_name := emp.get_full_preferred_name(l_num);
				l_email_addr     := emp.get_email(l_num,'Y');
				l_email_alias    := emp.get_email(l_num,'N');
			END IF;

			IF l_phone_group <> r_a_camp_staff.phone_group THEN --Only display once for diff. organisation's diff. phone group
			 	l_phone_group := r_a_camp_staff.phone_group;
                l_group_cd    := get_group_code (l_org_code_temp
                                                ,l_phone_group);
				-- If the person is CCR client and ccr_client_id is not loaded into database
				-- yet, checking if any non CCR staff exists in this section. If not, do not
				-- display this section title and column names.
				IF (r_a_camp_staff.ip_type = 'CCR' AND l_ccr_client_id IS NULL ) THEN
				    
                    IF ccr_org_exists (l_org_code_temp, l_phone_group) THEN
                        htp.p('<tr><td colspan="7"><h3>'||NVL(l_group_cd.description, ' ')||'</td></tr></h3>');
			 	    END IF;
				ELSE
					htp.p('<tr><td colspan="7"><h3>'||NVL(l_group_cd.description, ' ')||'</td></tr></h3>');
				END IF;
			END IF;
			
            -- display staff details
			IF r_a_camp_staff.ip_type <> 'CCR'  OR
			  (r_a_camp_staff.ip_type = 'CCR' AND l_ccr_client_id IS NOT NULL) THEN
			   l_background_shade := common_style.get_background_shade(l_background_shade);

                htp.p('<tr>');
				htp.p('  <td><a href="'||qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_USER_PROFILE')||'?id='||l_num
							  ||'&roleCode='||l_ip_type||'">'||l_full_pref_name||'</a>');
                -- show all role icons
                IF (emp.has_other_roles(l_num)) THEN
                    l_show_legend_ind := 'Y';
                    show_role_icon (l_num);
                END IF;
                htp.p('  </td>');
			    htp.p('  <td>' || emp.get_role(r_a_camp_staff.ip_num) ||'</td>');
			   	htp.p('  <td>' || NVL(r_a_camp_staff.primary_extn, l_group_cd.primary_extn)  ||'</td>');
			   	htp.p('  <td>' ||NVL(r_a_camp_staff.primary_fax, l_group_cd.primary_fax) ||'</td>');
				IF l_email_addr = ' ' THEN
				    htp.p('  <td>n/a</td>');
				ELSE
				    htp.p('  <td>'
							 ||'<a href="mailto:'||l_email_addr||'">'|| l_email_alias ||'</a></td>');
				END IF;					 
                htp.p('  <td>' ||r_a_camp_staff.primary_location ||'</td>');
			   	htp.p('  <td>' ||r_a_camp_staff.primary_campus ||'</td>');
			   	htp.p('</tr>');

			END IF;
		END LOOP;
		l_total := l_total - l_ccr_not_display_ct;
        IF (l_total > 0) THEN
            htp.p('</table>');
        END IF;
        htp.p('<p>Total number of staff: <strong>'||l_total ||'</strong><br>');
	 	htp.p('View by campus:  ');
		FOR r_camp IN c_campuses(p_start_org_code) LOOP
			   htp.p('<a href="qv_search_orgunit_p.show?p_arg_names=p_clevel&p_arg_values=clevel'
		  	   ||'&p_arg_names=p_org_unit_code&p_arg_values='||p_start_org_code
		  	   ||'&p_arg_names=p_campus&p_arg_values='||r_camp.prim_camp
			   ||'&p_arg_names=p_from&p_arg_values='||p_from
			   ||'&'||common_template.set_nav_path(C_ALL_CAMPUSES)
			   ||'"><strong>'||r_camp.prim_camp||'</strong></a>');
		END LOOP;
		htp.p('<br><a href="qv_search_orgunit_p.show?p_arg_names=p_show_mode&p_arg_values=print'
		   ||'&p_arg_names=p_org_unit_code&p_arg_values='||p_start_org_code
		   ||'&p_arg_names=p_campus&p_arg_values='||p_campus
		   ||'" class="popup print">View print-friendly staff list</a>');
        htp.p('</p>');
        -- show qualification legend
        IF (l_show_legend_ind = 'Y') THEN
            show_legend;
        END IF;

	END IF;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		htp.p('<p>There are no staff currently in this school / section.</p>');
        qv_search_orgunit.show_option;
	WHEN TOO_MANY_ROWS THEN
        htp.p('</table>');
	    htp.p('<p>More than one row returned.This should not happen.</p>');
	WHEN OTHERS THEN
        show_error_page;
END show_details;

PROCEDURE print_details
(
 		 p_start_org_code VARCHAR2
        ,p_campus		   VARCHAR2 DEFAULT NULL
)
IS

----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
	-- comment
	l_background_shade		VARCHAR2(10) := common_style.C_WHITE_COLOUR;
	l_org_code_temp         emp_org_unit.org_unit_cd%TYPE := 0;
	l_ip_type				ip.ip_type%TYPE;
	l_ccr_client_id			qv_client_role.id%TYPE;
	l_num					VARCHAR2(20);
	l_full_pref_name		VARCHAR2(200);
	l_total		            NUMBER := 0; --number of staffs in an org. unit
	l_ccr_not_display_ct	NUMBER := 0; --number of ccr staffs who have not had their info. loaded into database yet.
	l_campus_cnt		    NUMBER := 0;
	l_phone_group		    NUMBER := 0;
	l_sub_staff_ct			NUMBER := 0;
	l_email_alias			VARCHAR2(30);
    l_show_legend_ind       VARCHAR2(1) := 'N';   
    l_group_cd              group_codes%ROWTYPE;
    l_local_name            emp_org_unit.org_unit_desc%TYPE;
    l_area_name             emp_org_unit.org_unit_desc%TYPE;

CURSOR c_all_camp_staffs (l_org_code VARCHAR2) IS
	SELECT
	  	    ip.owner_org_code
		  , ip.employee_num
		  , ip.phone_group
		  , ip.Preferred_name
		  , ip.surname
		  , ip.ip_num
		  , ip_type
		  , ip.primary_fax
		  , ip.primary_extn
		  , NVL(ip.primary_campus,'&nbsp;') primary_campus
		  , NVL(ip.primary_location,'&nbsp;') primary_location
          , CASE WHEN  ou.start_dt <= SYSDATE
                  AND (ou.end_dt   >= SYSDATE
                    OR ou.end_dt   IS NULL   ) THEN ou.org_unit_desc
                 ELSE                               ou.org_unit_desc || ' (Inactive)'
            END    AS  code_org_unit_desc
	FROM    emp_org_unit ou, group_codes gc, subgroup_codes sgc, ip
	WHERE   ou.org_unit_cd LIKE (l_org_code || '%')
	AND     gc.owner_org_code = ou.org_unit_cd
    AND     gc.display_ind = 'Y'
	AND     sgc.owner_org_code = gc.owner_org_code
	AND     sgc.phone_group = gc.phone_group
    AND     sgc.display_ind = 'Y'
	AND     ip.owner_org_code = sgc.owner_org_code
	AND     ip.phone_group = sgc.phone_group
	AND     ip.phone_subgroup = sgc.phone_subgroup
	AND 	ip_type IN ('EMP','EXT','OTH','CCR')
	AND	    ip_status = 'cur'
    AND     ip.print_flag = 'Y'
	ORDER BY ou.sort_order
		    ,gc.print_order
			,sgc.print_order
			,ip.surname;

CURSOR c_a_camp_staffs (l_org_code VARCHAR2, l_campus VARCHAR2) IS
	SELECT
	  	    ip.owner_org_code
		  , ip.employee_num
		  , ip.phone_group
		  , ip.Preferred_name
		  , ip.surname
		  , ip.ip_num
		  , ip_type
		  , ip.primary_fax
		  , ip.primary_extn
		  , NVL(ip.primary_campus,'&nbsp;') primary_campus
		  , NVL(ip.primary_location,'&nbsp;') primary_location
          , CASE WHEN  ou.start_dt <= SYSDATE
                  AND (ou.end_dt   >= SYSDATE
                    OR ou.end_dt   IS NULL   ) THEN ou.org_unit_desc
                 ELSE                               ou.org_unit_desc || ' (Inactive)'
            END    AS  code_org_unit_desc
	FROM    emp_org_unit ou, group_codes gc, subgroup_codes sgc, ip
	WHERE   ou.org_unit_cd LIKE (l_org_code || '%')	
	AND     gc.owner_org_code = ou.org_unit_cd
    AND     gc.display_ind = 'Y'
	AND     sgc.owner_org_code = gc.owner_org_code
	AND     sgc.phone_group = gc.phone_group
    AND     sgc.display_ind = 'Y'
	AND     ip.owner_org_code = sgc.owner_org_code
	AND     ip.phone_group = sgc.phone_group
	AND     ip.phone_subgroup = sgc.phone_subgroup
	AND 	ip_type IN ('EMP','EXT','OTH','CCR')
	AND		ip_status = 'cur'
	AND 	ip.primary_campus = l_campus
    AND     ip.print_flag = 'Y'
	ORDER BY ou.sort_order
		   , gc.print_order
		   , sgc.print_order
		   , ip.surname;

BEGIN

    get_org_unit_names (p_start_org_code, l_local_name, l_area_name);

    htp.p('<h1>' || NVL(l_area_name, l_local_name) || '</h1>');
	IF p_campus IS NULL THEN --will display all campus staffs
	 	FOR r_all_camp_staff IN c_all_camp_staffs(p_start_org_code) LOOP
			IF l_org_code_temp <> r_all_camp_staff.owner_org_code THEN --only display org_unit_desc once for different owner_org_code selected from the cursor
			    l_org_code_temp := r_all_camp_staff.owner_org_code;
                IF (l_total > 0) THEN
                    htp.p('</table>');
                END IF;
                htp.nl;
		        htp.p('<h2>'||r_all_camp_staff.code_org_unit_desc||'</h2>');
                htp.p('<hr style="border-style: dotted" />');
                show_print_table_header;
			    l_total := l_total + count_staff_number(r_all_camp_staff.owner_org_code, p_campus);
			    l_phone_group := 0;--redefine it to 0 because phone_group can be same for diff. org. Without it, the next "IF" could be false even it is in diffrent org.
			END IF;
            
			 -- Check if the staff is a CCR person; if YES, checking is ccr_client_id exists;
			 -- If ccr_client_id is not exists, do not display this person. If this person is the
			 -- only person in the relative phone group(the last level in the displayed organisation
			 -- hierarchy), do not display the phone group title(normally it is an undefined group)
			 -- and column names.
			IF r_all_camp_staff.ip_type = 'CCR' THEN
			 	l_ip_type       := 'CCR';
				l_num           := r_all_camp_staff.ip_num;
				l_ccr_client_id := get_ccr_client_id (l_num);

				IF l_ccr_client_id IS NOT NULL THEN
				    l_full_pref_name := ccr_common.get_full_preferred_name(l_ccr_client_id);
				    l_email_alias    := ccr_common.get_email(l_ccr_client_id,'N');
				ELSE
				    l_ccr_not_display_ct := l_ccr_not_display_ct + 1;
				END IF;
			ELSE --Not CCR clients, so the ip_type can be EMP, OTH or EXT.
			 	l_ip_type        := 'NOT';
				l_num            := r_all_camp_staff.employee_num;
				l_full_pref_name := emp.get_full_preferred_name(l_num);
				l_email_alias    := emp.get_email(l_num,'N');
			END IF;

			IF l_phone_group <> r_all_camp_staff.phone_group THEN--Only display once for diff. organisation's diff. phone group
			 	l_phone_group := r_all_camp_staff.phone_group;
                -- get group details for the org unit and phone group including the description, phone and fax number
                l_group_cd    := get_group_code (l_org_code_temp
                                                ,l_phone_group);

				-- If the person is CCR client and ccr_client_id is not loaded into database
				-- yet, checking if any non CCR staff exists in this section. If not, do not
				-- display this section title and column names.
				IF (r_all_camp_staff.ip_type = 'CCR' AND l_ccr_client_id IS NULL) THEN
				    IF ccr_org_exists (l_org_code_temp, l_phone_group) THEN
                        htp.p('<tr><td colspan="7"><h3>'||l_group_cd.description||'</td></tr></h3>');
			 	    END IF;
				ELSE
					htp.p('<tr><td colspan="7"><h3>'||l_group_cd.description||'</td></tr></h3>');
				END IF;
			END IF;
		    -- display staff details or EMP and CCR iff CCR client id is not null
			IF r_all_camp_staff.ip_type <> 'CCR'  OR
			 	(r_all_camp_staff.ip_type = 'CCR' AND l_ccr_client_id IS NOT NULL) THEN
                l_background_shade := common_style.get_background_shade(l_background_shade);

                htp.p('<tr bgcolor="'||l_background_shade||'">');
                htp.p('  <td>'||l_full_pref_name);
                IF (emp.has_other_roles(l_num)) THEN
                    l_show_legend_ind := 'Y';
                    show_role_icon (l_num);
                END IF;
                htp.p('  </td>');
                htp.p('  <td>'|| emp.get_role(r_all_camp_staff.ip_num) ||'</td>');
                htp.p('  <td>'|| NVL(r_all_camp_staff.primary_extn, l_group_cd.primary_extn)  ||'</td>');
                htp.p('  <td>' || NVL(r_all_camp_staff.primary_fax, l_group_cd.primary_fax) ||'</td>');
                htp.p('  <td>'|| l_email_alias ||'</td>');
                htp.p('  <td>'|| r_all_camp_staff.primary_location ||'</td>');
                htp.p('  <td>' || r_all_camp_staff.primary_campus ||'</td>');
                htp.p('</tr>');

		    END IF;

		END LOOP;

		l_total := l_total - l_ccr_not_display_ct;

        IF (l_total > 0) THEN
            htp.p('</table>');
        END IF;

	  	htp.p('<p>Total number of staff: <strong>'||l_total ||'</strong></p>');

        -- show qualification legend
        IF (l_show_legend_ind = 'Y') THEN
            show_legend;
        END IF;
        
    ELSE --	p_campus is not NULL; Should display selected campus staffs for that org.
		FOR r_a_camp_staff IN c_a_camp_staffs(p_start_org_code, p_campus) LOOP
			IF l_org_code_temp <> r_a_camp_staff.owner_org_code THEN  --only display org_unit_desc once for different owner_org_code selected from the cursor
                IF (l_total > 0) THEN
                    htp.p('</table>');
                END IF;
			    l_org_code_temp := r_a_camp_staff.owner_org_code;
                htp.nl;
			    htp.p('<h2>'||r_a_camp_staff.code_org_unit_desc||'</h2>');
                htp.p('<hr style="border-style: dotted" />');
			    l_total := l_total + count_staff_number(r_a_camp_staff.owner_org_code, p_campus);
                show_print_table_header;
			    l_phone_group := 0;--redefine it to 0 because phone_group can be same for diff. org. Without it, the next "IF" could be false even it is in diffrent org.
			END IF;
            
			 -- Check if the staff is a CCR person; if YES, checking is ccr_client_id exists;
			 -- If ccr_client_id is not exists, do not display this person. If this person is the
			 -- only person in the relative phone group(the last level in the displayed organisation
			 -- hierarchy), do not display the phone group title(normally it is an undefined group)
			 -- and column names.
			IF r_a_camp_staff.ip_type = 'CCR' THEN
			 	l_ip_type       := 'CCR';
				l_num           := r_a_camp_staff.ip_num;
				l_ccr_client_id := get_ccr_client_id (l_num);

				IF l_ccr_client_id IS NOT NULL THEN
				    l_full_pref_name := ccr_common.get_full_preferred_name(l_ccr_client_id);
				    l_email_alias    := ccr_common.get_email(l_ccr_client_id,'N');
				ELSE
				    l_ccr_not_display_ct := l_ccr_not_display_ct + 1;
				END IF;
			ELSE --Not CCR clients, so the ip_type can be EMP, OTH or EXT.
			 	l_ip_type        := 'NOT';
				l_num            := r_a_camp_staff.employee_num;
				l_full_pref_name := emp.get_full_preferred_name(l_num);
				l_email_alias    := emp.get_email(l_num,'N');
			END IF;

			IF l_phone_group <> r_a_camp_staff.phone_group THEN --Only display once for diff. organisation's diff. phone group
			 	l_phone_group := r_a_camp_staff.phone_group;
                -- get group details for the org unit and phone group including the description, phone and fax number
                l_group_cd    := get_group_code (l_org_code_temp
                                                ,l_phone_group);
			
				-- If the person is CCR client and ccr_client_id is not loaded into database
				-- yet, checking if any non CCR staff exists in this section. If not, do not
				-- display this section title and column names.
				IF (r_a_camp_staff.ip_type = 'CCR' AND l_ccr_client_id IS NULL ) THEN

				    IF ccr_org_exists (l_org_code_temp, l_phone_group) THEN
				   	    htp.p('<tr><td colspan="7"><h3>'||l_group_cd.description||'</h3></td></tr>');
			 		END IF;
				ELSE
					htp.p('<tr><td colspan="7"><h3>'||l_group_cd.description||'</h3></td></tr>');
				END IF;
			END IF;

	        -- display staff details for EMP and CCR iff CCR client has an id
			IF r_a_camp_staff.ip_type <> 'CCR'  OR
			  (r_a_camp_staff.ip_type = 'CCR' AND l_ccr_client_id IS NOT NULL) THEN
			
               l_background_shade := common_style.get_background_shade(l_background_shade);

                htp.p('<tr bgcolor="'||l_background_shade||'">');
			    htp.p('  <td>' || l_full_pref_name);
                IF (emp.has_other_roles(l_num)) THEN
                    l_show_legend_ind := 'Y';
                    show_role_icon (l_num);
                END IF;
                htp.p('  </td>');
                htp.p('  <td>'|| emp.get_role(r_a_camp_staff.ip_num) ||'</td>');
                htp.p('  <td>'|| NVL(r_a_camp_staff.primary_extn, l_group_cd.primary_extn)  ||'</td>');
                htp.p('  <td>' || NVL(r_a_camp_staff.primary_fax, l_group_cd.primary_fax) ||'</td>');
                htp.p('  <td>'|| l_email_alias ||'</td>');
                htp.p('  <td>'|| r_a_camp_staff.primary_location ||'</td>');
                htp.p('  <td>' || r_a_camp_staff.primary_campus ||'</td>');
                htp.p('</tr>');

		    END IF;
		END LOOP;

		l_total := l_total - l_ccr_not_display_ct;
        IF (l_total > 0) THEN
                htp.p('</table>');
        END IF;

	  	htp.p('<p>Total number of staff: <strong>'||l_total ||'</strong></p>');
    
        -- show qualification legend
        IF (l_show_legend_ind = 'Y') THEN
            show_legend;
        END IF;

	END IF;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
	  	htp.p('<p>No data found(this should not occur).</p>');
	WHEN TOO_MANY_ROWS THEN
	    htp.p('<p>More than one row returned (this should not occur).</p>');
	WHEN OTHERS THEN
        show_error_page;
END print_details;

END qv_search_orgunit;
/