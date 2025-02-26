create or replace 
PACKAGE BODY                                                                       srch_common_people
/**
* Display list of employee and contact details
* @author Sophie Jeong
* @version 1.0.0
*/
IS
----------------------------------------------------------------------
--  Modification History
--  Date         Author      Description
--  -----------  ------------------------------------------------------
--  04-SEP-2002	 S Jeong     Created
--  23_SEP-2002  S Jeong     Campus inserted into contact details
--				   			 Reference to removed to when calling qv_search_orgunit_p.show
--  27-SEP-2002  S Jeong     Parameter value for [qv_search_orgunit_p.show] modified
--  02-Oct-2002  M Huth		 Modify all dynamically generated queries. Separate functions
--				   			 into EMP and CCR queries where necessary
--	03-Oct-2002  M Huth		 Add gender/title procedures. Add title into display.
--	18-Oct-2002	 L Lin		 Choose org_units.local_name instead of org_units.org_unit_desc in
--				   			 procedures get_emp_position_and_dept and get_ccr_position_and_dept.
--	24-Mar-2003	 R Arndt	 modified to display staff home address, staff postal address and staff
--				   			 date of birth if the portal user is authorised to view
--							 (i.e. EMP_STAFF_AUTH_INFO - access to staff date of birth,
--							 EMP_STAFF_ADDR - access to staff home and postal address).
--							 Created get_ccr_date_of_birth and get_emp_date_of_birth procedures and
--							 added c_staff_address_and_phone cursor to show_emp_details.
--  12-May-2003 R.Arndt      modified c_staff_address_and_phone cursor included postcode and
--                           changed l_id to p_id.
--                           Modified addresses display added display of postcode
--  22-May-2003 R.arndt      show_emp_details - set l_role_cd to CCR or EMP depending on
--                           p_ip_type and changed paramter call to c_staff_address_and_phone
--                           to include l_role_cd.
--  2-June-2003 R.Arndt      show_emp_details - modified c_staff_address_and_phone cursor to return
--                           multiple address type results.
--  28-Jul-2003 K. Hauville	 Remove local function get_role and point call in show_emp_list to
--				   			 emp.get_role
--  23-May-2005 D.Hunt	 	 Add location notes check, don't display location values and location title
--							 if no location details exist
--  23-May-2005 D.Hunt	 	 If campus equals OC (other) hide it
--  15-Jun-2005 D.Hunt	 	 Removed global constant c_other_campus removed calls to qv_common_style.apply
--							 for location specific code
--  28-Jul-2005 J.Choy       Changed alias to address in show_emp_list
--  01-Nov-2005 F.Lee		 Added Closed User Group
--  09-Nov-2005 F.Lee		 Hide fax, mobile number, speed dial and closed user group if null
--  18-JUL-2006  S.Jeong     10g Upgrade Modification
--                           Removed qv_common_style.apply
--                           Uppder case table name changed to lower case
--                           Repalced <b> with <strong>
--  01-NOV-2006 S.Jeong      EXACT search cursor separated into 2 cursors
--                           Case 1: "c_exact_srch_first_and_surname" is used when both names are entered
--                           Case 1: "c_exact_srch_first_or_surname" is used when one of them is null
--                           Added Local PROCEDRUE write_results
--  02-Nov-2006 E.Wood       Added criteria in SQL to stop print_flag = 'N' Displaying in searches
--  06-Aug-2007  C Wong      IAM Upgrade
--  24-Oct-2008 P.Totagiancaspro
--                           Reverse IAM changes
--  30-Oct-2008 A.McBride    QV 1.5 Upgrade
--                           added show_vcard
--  04-Nov-2008 A.McBride    Fixed vcard functionality with proper code indentation
--  14-May-2009  C.Wong      Replace org_units (deprecated) with emp_org_unit
--  29-Jul-2009  D.Jack      SAMS Upgrade
--  01-03-2010  Tony Le      Bring new staff UI across
--  06-04-2010  Tony Le      Fix search people and search staff for staff with student info access to match the first name
--                           as well the surname. Changes made in show_emp_list mainly improving the search
--                           cursors to match on first and other names
--  08-11-2010  Tony Le      Add new procedure to display JP list as a result of JP search
--                           Show additional position/roles in the contact details page
--  17-12-2010  Tony Le      Remove staff middle name from displaying to students
--  07-09-2011  L Dorman     Changed references to emp_org_unit.local_name to emp_org_unit.org_unit_desc
--  03-10-2011  L Dorman     Adjusted query for cursor c_jps in show_jp_list procedure
--  12-10-2011  Tony Le      Another attempt to fix the JP cursor. The cursor still not return anything
--                           after Loretta's attempt 1.5 weeks ago. Covert ip.employee_num to NUMBER
--                           when comparing it with qcr.id
--  13-10-2011  Tony Le      Change qv_common_id.identify_role to use qv_common_id.get_username instead
--                           Previously it used qv_audit.get_username
--                           Split the JP search into 2 separate parts. One for student and the other for
--                           staff. There are even 2 cursors for this instead of just one.
--                           No fancy coding and it should work in PROD.
--  09-Dec-2011  Tony Le     Moved get_emp_position_and_dept and get_ccr_position_and_dept
--                           into emp and ccr_common
--  13-Dec-2011  Tony Le     As it turns out, the package is no longer required get_emp/ccr_position_and_dept
--                           function. Extend the length of l_position_title to 100 chars. Tidying up codes.
--  23 Feb 2012  J Choy      Show Ihbi memberships if staff's non-primary role has ihbi appointments 
--  01 Jul 2015  M Kaur      Added title to JP staff only image, moved message (indicates Justice of the Peace is available to staff only) 
--                           to the top of the table, ordered JPs by available to staff first then displayed rest of JPs (JIRA : QVJPL-7)
--  27-Oct-2015  Tony Le     Change code to allow staff with access to view all images to see both 
--                           id card and profile image
--  11-Dec-2015  Tony Le     Removed image border (QVEMP-45)
--  14-Aug-2018  S Kambil    Support additional employee attributes in staff directory and search (QVSEARCH-97)
----------------------------------------------------------------------
--------------------------------------------
--            LOCAL CONSTANTS
--------------------------------------------

	-- temporary use for distinguising CCR people
	C_CCR_TYPE       CONSTANT ip.ip_type%TYPE := 'CCR';
	C_EMP_TYPE       CONSTANT ip.ip_type%TYPE := 'EMP';
  
  C_JPALL             CONSTANT VARCHAR2(5)     := 'JPALL';
  C_ATTRIBUTE_TYPE    CONSTANT VARCHAR2(13)    := 'ATTRIBUTETYPE';

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------
--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
--
--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------

FUNCTION get_ccr_client_id
(
    p_id    IN  NUMBER   DEFAULT NULL
)
    RETURN NUMBER
IS
    l_ccr_client_id ccr_clients.ccr_client_id%TYPE;
----------------------------------------------------------------------
--  Purpose: Return ccr_client_id
----------------------------------------------------------------------
BEGIN
    SELECT ccr_client_id
    INTO   l_ccr_client_id
    FROM   ccr_clients
    WHERE  ip_num = p_id
	AND    ROWNUM = 1;

    RETURN l_ccr_client_id;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END get_ccr_client_id;

FUNCTION get_email
(
    p_id            IN  NUMBER      DEFAULT NULL
   ,p_ip_type       IN  VARCHAR2    DEFAULT NULL
)
    RETURN VARCHAR2
IS
----------------------------------------------------------------------
--  Purpose: Return email address
----------------------------------------------------------------------
BEGIN
	IF p_ip_type = C_CCR_TYPE THEN
	    RETURN ccr_common.get_email(get_ccr_client_id(p_id),'Y');
	ELSE
	    RETURN emp.get_email(p_id,'Y');
	END IF;
EXCEPTION
    WHEN OTHERS THEN
		 RETURN NULL;
END get_email;


FUNCTION display_person
(
    p_id		    IN  NUMBER      DEFAULT NULL
   ,p_ip_type	    IN  VARCHAR2    DEFAULT NULL
   ,p_from			IN  VARCHAR2    DEFAULT NULL
   ,p_user_type     IN  VARCHAR2    DEFAULT NULL
   ,p_arg_names  IN owa.vc_arr DEFAULT srch_stu_people.empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT srch_stu_people.empty_vc_arr
)
    RETURN VARCHAR2
IS
    l_all_names     VARCHAR2(255);
----------------------------------------------------------------------
--  Purpose: Get all names and
--			 display a person name with a link
----------------------------------------------------------------------
BEGIN

    IF p_ip_type = C_CCR_TYPE THEN
        IF (p_user_type = common_client.C_STU_ROLE_TYPE) THEN
            l_all_names := ccr_common.get_surname (get_ccr_client_id(p_id)) || ', ' || ccr_common.get_preferred_name (get_ccr_client_id(p_id));
        ELSE
            l_all_names := ccr_common.get_all_names(get_ccr_client_id(p_id));
        END IF;
	ELSE 
        -- if view by students then hide staff middle name from students
        IF (p_user_type = common_client.C_STU_ROLE_TYPE) THEN
            l_all_names := emp.get_surname (p_id) || ', ' || emp.get_preferred_name (p_id);
        ELSE
	        l_all_names := emp.get_all_names(p_id);
        END IF;
    END IF;

    RETURN ('<a href="'||qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_USER_PROFILE')
    		 ||'?id='||p_id
    		 ||'&roleCode='||p_ip_type||'">'
    		 ||UPPER(l_all_names)||'</a>');
         
END display_person;


--------------------------------------------
--            LOCAL PROCEDURES
--------------------------------------------
PROCEDURE get_emp_location_and_phone
(
    p_id          		IN  NUMBER   DEFAULT NULL
   ,p_campus      		OUT VARCHAR2
   ,p_location    		OUT VARCHAR2
   ,p_phone    	  		OUT VARCHAR2
   ,p_fax   	  		OUT VARCHAR2
   ,p_mobile      		OUT VARCHAR2
   ,p_speed_dial  		OUT VARCHAR2
   ,p_pager       		OUT VARCHAR2
   ,p_location_notes 	OUT VARCHAR2
)
IS
----------------------------------------------------------------------
--  Purpose: Retreive location and phone numbers
----------------------------------------------------------------------
BEGIN

    SELECT primary_campus
		   ,primary_location
		   ,primary_extn
		   ,primary_fax
		   ,mobile
		   ,speed_dial
		   ,pager
		   ,location_notes
	INTO   p_campus
		   ,p_location
		   ,p_phone
		   ,p_fax
		   ,p_mobile
		   ,p_speed_dial
		   ,p_pager
		   ,p_location_notes
	FROM   ip
	WHERE  employee_num = p_id;

EXCEPTION
    WHEN OTHERS THEN
        NULL;
END get_emp_location_and_phone;

PROCEDURE get_ccr_location_and_phone
(
    p_id                IN  NUMBER   DEFAULT NULL
   ,p_campus      		OUT VARCHAR2
   ,p_location    		OUT VARCHAR2
   ,p_phone    	  		OUT VARCHAR2
   ,p_fax   	  		OUT VARCHAR2
   ,p_mobile      		OUT VARCHAR2
   ,p_speed_dial  		OUT VARCHAR2
   ,p_pager       		OUT VARCHAR2
   ,p_location_notes 	OUT VARCHAR2
)
IS
----------------------------------------------------------------------
--  Purpose: Retreive location and phone numbers
----------------------------------------------------------------------
BEGIN

    SELECT primary_campus
		   ,primary_location
		   ,primary_extn
		   ,primary_fax
		   ,mobile
		   ,speed_dial
		   ,pager
		   ,location_notes
	INTO   p_campus
		   ,p_location
		   ,p_phone
		   ,p_fax
		   ,p_mobile
		   ,p_speed_dial
		   ,p_pager
		   ,p_location_notes
	FROM   ip
	WHERE  ip_num = p_id;

EXCEPTION
    WHEN OTHERS THEN
        NULL;
END get_ccr_location_and_phone;


PROCEDURE get_emp_gender_title
(
    p_id              IN  NUMBER   DEFAULT NULL
   ,p_gender          OUT VARCHAR2
   ,p_title			  OUT VARCHAR2
)
IS
----------------------------------------------------------------------
--  Purpose: Get gender and title for employee given ip.employee_num
----------------------------------------------------------------------

BEGIN
    SELECT  gender
			,NVL(qv_common.get_reference_description(title), title)
	INTO	p_gender
			,p_title
	FROM	ip
	WHERE	employee_num = p_id;

EXCEPTION
    WHEN OTHERS THEN
	    NULL;
END get_emp_gender_title;

PROCEDURE get_ccr_gender_title
(
    p_id              IN  NUMBER   DEFAULT NULL
   ,p_gender          OUT VARCHAR2
   ,p_title			  OUT VARCHAR2
)
IS
----------------------------------------------------------------------
--  Purpose: Get gender and title for ccr client given ip.ip_num
----------------------------------------------------------------------

BEGIN
    SELECT  gender
			,NVL(qv_common.get_reference_description(title), title)
	INTO	p_gender
			,p_title
	FROM	ip
	WHERE	ip_num = p_id;

EXCEPTION
    WHEN OTHERS THEN
	    NULL;
END get_ccr_gender_title;

PROCEDURE get_id_and_type
(
    p_employee_num  IN  VARCHAR2    DEFAULT NULL
   ,p_ip_num        IN  VARCHAR2    DEFAULT NULL
   ,p_id		    OUT NUMBER
   ,p_ip_type	    OUT VARCHAR2
)
IS
----------------------------------------------------------------------
--  Purpose: Assign employee number if it is not null otherwise
--           assign ip number. If ip number is assigned then set
--           ip type to CCR
----------------------------------------------------------------------
BEGIN

	-- temporarily if CCR staff's employee num is not null then treated as EMP
    IF p_employee_num IS NULL THEN
        p_id := p_ip_num;
    	p_ip_type := C_CCR_TYPE;
    ELSE
    	p_id := p_employee_num;
    	p_ip_type := C_EMP_TYPE;
    END IF;

END get_id_and_type;

PROCEDURE get_url_message
(
    p_id             IN  NUMBER   DEFAULT NULL
   ,p_role_cd    	 IN  VARCHAR2 DEFAULT NULL
   ,p_pers_url   	 OUT VARCHAR2
   ,p_pers_message   OUT VARCHAR2
)
----------------------------------------------------------------------
--  Purpose: Get personal home page url and personal message
----------------------------------------------------------------------
IS
    l_query_str      VARCHAR2(1000);
BEGIN
    SELECT url
		   ,message
	INTO   p_pers_url
		   ,p_pers_message
	FROM   qv_client_role qcr
		   ,qv_pers_details qpd
	WHERE  qcr.id = p_id
	AND    qcr.role_cd = p_role_cd
	AND    qcr.username = qpd.username
	AND    qpd.role_cd = p_role_cd;

EXCEPTION
    WHEN OTHERS THEN
	    p_pers_url := NULL;
		p_pers_message  := NULL;
END get_url_message;

PROCEDURE get_emp_date_of_birth
(
    p_id            IN  NUMBER   DEFAULT NULL
   ,p_date_of_birth OUT ip.date_of_birth%TYPE
)
IS
----------------------------------------------------------------------
--  Purpose: Retreive emp date of birth
----------------------------------------------------------------------
BEGIN

    SELECT TO_CHAR(date_of_birth,'DD MON YYYY')
	INTO   p_date_of_birth
	FROM   ip
	WHERE  employee_num = p_id;

EXCEPTION
    WHEN OTHERS THEN
        NULL;
END get_emp_date_of_birth;

PROCEDURE get_ccr_date_of_birth
(
    p_id            IN  NUMBER   DEFAULT NULL
   ,p_date_of_birth OUT ip.date_of_birth%TYPE
)
IS
----------------------------------------------------------------------
--  Purpose: Retreive ccr date of birth
----------------------------------------------------------------------
BEGIN

    SELECT TO_CHAR(date_of_birth,'DD MON YYYY')
	INTO   p_date_of_birth
	FROM   ip
	WHERE  ip_num = p_id;

EXCEPTION
    WHEN OTHERS THEN
        NULL;
END get_ccr_date_of_birth;

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE show_emp_list
(
    p_first_name    IN VARCHAR2    DEFAULT NULL
   ,p_surname		IN VARCHAR2    DEFAULT NULL
   ,p_org_unit_code	IN VARCHAR2    DEFAULT NULL
   ,p_search_type   IN VARCHAR2    DEFAULT NULL
   ,p_from		    IN VARCHAR2    DEFAULT NULL
   ,p_arg_names  IN owa.vc_arr DEFAULT srch_stu_people_p.empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT srch_stu_people_p.empty_vc_arr
)
IS
----------------------------------------------------------------------
--  Purpose: Display list of employee with name and position description.
----------------------------------------------------------------------

    l_background_shade VARCHAR2(10);
    l_user_id           qv_client_role.id%TYPE;
    l_user_type         qv_client_role.role_cd%TYPE;

-- used when search type is null
CURSOR c_surname (p_name VARCHAR2 DEFAULT NULL)
IS
    SELECT i.employee_num
		  ,i.ip_num
	FROM   ip i
    WHERE  (UPPER(i.surname) = UPPER(p_surname))
	AND    i.ip_status = 'cur'
    AND    i.print_flag = 'Y'
	ORDER BY i.surname,i.first_name;

-- seach exact matching results when @p_firstname and @p_surname are not null
CURSOR c_exact_srch_first_and_surname (p_first_name    VARCHAR2
			                          ,p_surname	   VARCHAR2
			                          ,p_org_unit_code VARCHAR2    DEFAULT NULL)
IS
    SELECT i.employee_num
		  ,i.ip_num
   	FROM   ip i
    WHERE ((UPPER(i.preferred_name) = UPPER(p_first_name)
             OR UPPER(i.first_name) = UPPER(p_first_name)
             OR UPPER(i.second_name) = UPPER(p_first_name)
             OR UPPER(i.third_name) = UPPER(p_first_name))
    AND     UPPER(i.surname) = UPPER(p_surname))
  	AND    i.owner_org_code LIKE p_org_unit_code||'%'
   	AND    i.ip_status = 'cur'
    AND    i.print_flag = 'Y'
	ORDER BY i.surname,i.first_name;

-- seach exact matching results when @p_firstname or @p_surname is null
CURSOR c_exact_srch_first_or_surname (p_first_name    VARCHAR2 DEFAULT NULL
			                         ,p_surname	      VARCHAR2 DEFAULT NULL
			                         ,p_org_unit_code VARCHAR2 DEFAULT NULL
                                     )
IS
    SELECT i.employee_num
		  ,i.ip_num
   	FROM   ip i
    WHERE  ( UPPER(i.surname) = DECODE(UPPER(p_first_name),'',UPPER(p_surname),NULL)
               OR
               (  UPPER(i.preferred_name) = DECODE(UPPER(p_surname),'',UPPER(p_first_name),NULL)
                  OR UPPER(i.first_name) = DECODE(UPPER(p_surname),'',UPPER(p_first_name),NULL)
                  OR UPPER(i.second_name) = DECODE(UPPER(p_surname),'',UPPER(p_first_name),NULL)
                  OR UPPER(i.third_name) = DECODE(UPPER(p_surname),'',UPPER(p_first_name),NULL)
               )
           )
  	AND    i.owner_org_code LIKE p_org_unit_code||'%'
   	AND    i.ip_status = 'cur'
    AND    i.print_flag = 'Y'
	ORDER BY i.surname,i.first_name;

-- used when search type is LIKE
CURSOR c_like  (p_first_name    VARCHAR2    DEFAULT NULL
	           ,p_surname		VARCHAR2    DEFAULT NULL
			   ,p_org_unit_code VARCHAR2    DEFAULT NULL
			   )
IS
    SELECT i.employee_num
		  ,i.ip_num
   	FROM   ip i
    WHERE  (((UPPER(i.preferred_name) LIKE UPPER(p_first_name)||'%' OR
              UPPER(i.first_name) LIKE UPPER (p_first_name)||'%' OR 
              UPPER(i.second_name) LIKE UPPER (p_first_name)||'%' OR
              UPPER(i.third_name) LIKE UPPER(p_first_name)||'%') AND
              UPPER(i.surname) LIKE UPPER(p_surname)||'%')
    OR       (UPPER(i.surname) LIKE DECODE(UPPER(p_first_name),'',UPPER(p_surname)||'%',NULL) OR
              UPPER(i.preferred_name) LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL) OR
              UPPER(i.first_name) LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL) OR
              UPPER(i.second_name) LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL) OR
              UPPER(i.third_name) LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL))
           )
  	AND    i.owner_org_code LIKE p_org_unit_code||'%'
   	AND    i.ip_status = 'cur'
    AND    i.print_flag = 'Y'
	ORDER BY i.surname,i.first_name;


    PROCEDURE write_result
    (
        p_employee_num    ip.employee_num%TYPE DEFAULT NULL
       ,p_ip_num          ip.ip_num%TYPE DEFAULT NULL
       ,p_from            VARCHAR2 DEFAULT NULL
    )
    IS
    ----------------------------------------------------------------------------
    -- Purpose: Write search results as a part of html table
    ----------------------------------------------------------------------------
         -- employee_num or ip_num
       	l_id      		   qv_client_role.id%TYPE;
    	-- identify ip types. if not null then it contains 'CCR'

    	l_ip_type		   ip.ip_type%TYPE;
	    l_email			   VARCHAR2(100);
        l_position_title   VARCHAR2(100);
        l_org_unit_desc    emp_org_unit.org_unit_desc%TYPE;
        l_org_unit_cd      emp_org_unit.org_unit_cd%TYPE;

    BEGIN
        l_background_shade := common_style.get_background_shade(l_background_shade);

        -- temp for CCR
        get_id_and_type(p_employee_num
                       ,p_ip_num
                       ,l_id
                       ,l_ip_type);


        htp.p('<tr valign="top" bgcolor="'||l_background_shade||'">');
        -- name link
        htp.p('  <td width="30%">'||display_person(l_id,l_ip_type,p_from,l_user_type,p_arg_names,p_arg_values)||'</td>');
        -- role
        htp.p('  <td width="40%">'||emp.get_role(p_ip_num)||'</td>');

        -- email
        l_email := get_email(l_id,l_ip_type);
        htp.p('  <td width="30%">');

        IF trim(l_email) IS NULL THEN
        htp.p('&nbsp;');
        ELSE
        htp.p('<a href="mailto:'||l_email||'">'||l_email||'</a>');
        END IF;
        htp.p('  </td>');
        htp.p('</tr>');

    END write_result;

BEGIN

    qv_common_id.identify_role (p_username        => qv_audit.get_username
                               ,p_user_id         => l_user_id
                               ,p_user_type       => l_user_type
                               ,p_role_active_ind => 'Y');

    htp.p('<h1>Staff search results</h1>');

	htp.p('<table class="qv_table" width="100%" border="0" cellpadding="0" cellspacing="0">');
	htp.p('  <tr valign="top">');
	htp.p('    <th scope="col" width="30%">Name</th>');
	htp.p('    <th scope="col" width="40%">Role</th>');
	htp.p('    <th scope="col" width="30%">Email Address</th>');
	htp.p('  </tr>');

	l_background_shade := common_style.C_WHITE_COLOUR;

	IF p_search_type IS NULL THEN

		FOR r_surname IN c_surname(p_surname) LOOP
            write_result(r_surname.employee_num
                        ,r_surname.ip_num
                        ,p_from);
		END LOOP;

	ELSIF p_search_type = 'EXACT' THEN

        IF p_first_name IS NOT NULL AND p_surname IS NOT NULL THEN

    		FOR r_exact IN c_exact_srch_first_and_surname(p_first_name
                                                         ,p_surname
                                                         ,p_org_unit_code) LOOP
                write_result(r_exact.employee_num
                            ,r_exact.ip_num
                            ,p_from);

		    END LOOP;
        ELSE
    		FOR r_exact IN c_exact_srch_first_or_surname(p_first_name
                                                        ,p_surname
                                                        ,p_org_unit_code) LOOP
                write_result(r_exact.employee_num
                            ,r_exact.ip_num
                            ,p_from);
		    END LOOP;
        END IF;

	ELSIF p_search_type = 'LIKE' THEN

		FOR r_like IN c_like(p_first_name
							,p_surname
							,p_org_unit_code) LOOP
            write_result(r_like.employee_num
                        ,r_like.ip_num
                        ,p_from);
		END LOOP;
	END IF; -- IF search_type...

	htp.p('</table>');

END show_emp_list;

PROCEDURE show_jp_list (p_arg_names  IN owa.vc_arr DEFAULT srch_stu_people_p.empty_vc_arr
                       ,p_arg_values IN owa.vc_arr DEFAULT srch_stu_people_p.empty_vc_arr
                       ,p_campus                IN VARCHAR2 DEFAULT NULL
                       ,p_attribute_value       IN VARCHAR2 DEFAULT NULL
                       ,p_attribute_type        IN VARCHAR2 DEFAULT NULL
                       ,p_searchby_ppl          IN VARCHAR2 DEFAULT NULL
                       ,p_from                  IN VARCHAR2 DEFAULT NULL
                       ,p_print_ind             IN VARCHAR2 DEFAULT NULL)
----------------------------------------------------------------------
--  Name.    show_jp
--  Purpose: display a list of JPs who matched the search criteria
--  Pre:     Param not null
--  Post:    JPs and their details displayed
----------------------------------------------------------------------
IS
           
CURSOR  c_stu_jps IS 
    SELECT  ae.*
           ,TRIM(i.surname) || ', ' || (TRIM(NVL(i.preferred_name, i.first_name))) full_name 
           ,i.primary_extn
           ,i.employee_num
           ,NVL(i.primary_location, '-') primary_location
           ,NVL(ls.name, '-') campus
           ,i.ip_type
    FROM    emp_attribute ae
           ,ip i
           ,locn_site ls
           ,qv_client_role qcr
    WHERE   ae.employee_id = qcr.id
    AND     qcr.id = TO_NUMBER(i.employee_num) 
            -- if queried by student, only attribute_type = 'JPALL' return
    AND     ae.attribute_type = C_JPALL
    AND     ae.attribute_value = NVL(TRIM(p_attribute_value), ae.attribute_value)
    AND     i.ip_status = 'cur'
    AND     i.print_flag = 'Y'
            -- To ensure that ALL JPs returned when user did not select campus code
    AND    (i.primary_campus = NVL(p_campus, i.primary_campus) OR (i.primary_campus IS NULL)) 
    AND     ls.site_id(+) = i.primary_campus
    AND     qcr.role_cd = 'EMP'
    AND     qcr.role_active_ind = 'Y'
    ORDER BY campus
           ,primary_location
           ,full_name;

CURSOR  c_emp_jps IS --(p_img_path  IN VARCHAR2 DEFAULT NULL) IS 
    SELECT  ae.*
           ,emp.get_all_names (TO_NUMBER(employee_num)) full_name
           ,i.primary_extn
           ,i.employee_num
           ,NVL(i.primary_location, '-') primary_location
           ,NVL(ls.name, '-') campus
           ,i.ip_type
    FROM    emp_attribute ae
           ,qv_reference_cd qrc
           ,ip i
           ,locn_site ls
           ,qv_client_role qcr
    WHERE   ae.employee_id = qcr.id
    AND     qcr.id = TO_NUMBER(i.employee_num) 
    --      map the employee attribute to the currently active ones
    AND     ae.attribute_type = qrc.reference_cd
    AND     qrc.code_category_cd = C_ATTRIBUTE_TYPE
    AND     qrc.active_ind  = 'Y'    
    AND     ae.attribute_value = NVL(TRIM(p_attribute_value), ae.attribute_value)
    --
    AND     i.ip_status = 'cur'
    AND     i.print_flag = 'Y'
            -- To ensure that ALL JPs returned when user did not select campus code
    AND    (i.primary_campus = NVL(p_campus, i.primary_campus) OR (i.primary_campus IS NULL)) 
    AND     ls.site_id(+) = i.primary_campus
    AND     qcr.role_cd = 'EMP'
    AND     qcr.role_active_ind = 'Y'
    ORDER BY attribute_type DESC, campus
           ,primary_location
           ,full_name;
    
    l_user_id           qv_client_role.id%TYPE;
    l_user_type         qv_client_role.role_cd%TYPE;
    l_cnt               NUMBER := 0;
    l_background_shade  VARCHAR2(10);
    l_type              emp_attribute.description%TYPE;
    l_link_url          VARCHAR2(1000);
    l_img_path          VARCHAR2(300) := '<img src="/images/qut/icons/qv_icon_asterisk.png" alt="Staff Only" title="Available to Staff Only" width="12" height="12" />';
    l_debug             VARCHAR2(300);

BEGIN

    SELECT  count(*)
    INTO    l_debug
    FROM    emp_attribute;

    htp.p('<!-- DEBUG -->');
    htp.p('<!-- '||l_debug||'-->');
    htp.p('<!-- DEBUG -->');


    -- getting user's identity
    qv_common_id.identify_role (p_username        => qv_audit.get_username    
                               ,p_user_id         => l_user_id
                               ,p_user_type       => l_user_type
                               ,p_role_active_ind => 'Y');
           
    BEGIN  
        SELECT  DISTINCT(description)  
        INTO    l_type  
        FROM    emp_attribute  
        WHERE   attribute_value = p_attribute_value;          
    EXCEPTION  
        WHEN OTHERS THEN  
            l_type := NULL;  
    END;
    -- parameters require to show staff details  
    l_link_url := '&p_arg_names=p_list&p_arg_values=Y&p_arg_names=p_from&p_arg_values=' || p_from
        ||'&p_arg_names=p_show_mode&p_arg_values=' || utl_url.escape(srch_stu_people.C_SRCH_JP_RESULTS, TRUE)
        ||'&p_arg_names=p_campus&p_arg_values=' || p_campus
        ||'&p_arg_names=p_attribute_value&p_arg_values=' || p_attribute_value
        ||'&p_arg_names=p_searchby_ppl&p_arg_values=' || search.C_SEARCH_PERSON_BY_JP
        ||'&p_arg_names=p_attribute_type&p_arg_values=' || p_attribute_type;       

    htp.p('<h1>' || srch_stu_people.C_SRCH_JP_RESULTS || '</h1>');
    
    IF (l_user_type = 'STU') THEN
        -- fetching a list of JPs
        FOR r_jp IN c_stu_jps LOOP
        
            l_cnt := l_cnt + 1;

            IF (l_cnt = 1) THEN
                -- show seleced criteria
                IF (l_type IS NOT NULL) THEN
                    htp.p('<strong>Type:</strong> ' || l_type || '<br>');
                END IF;
        
                htp.p('<table class="qv_table" width="100%" border="0" cellpadding="0" cellspacing="0">');
                htp.p('  <tr valign="top">');
                htp.p('    <th scope="col" width="19%">Name</th>');

                IF (l_type IS NULL) THEN
                    htp.p('    <th scope="col" width="20%">Type</th>');
                END IF;

                htp.p('    <th scope="col" nowrap width="10%">Phone</th>');
                IF (p_print_ind = 'Y') THEN
                    htp.p('    <th scope="col" nowrap width="10%">Email Address</th>');
                ELSE
                    htp.p('    <th scope="col" nowrap width="10%">Email Alias</th>');
                END IF;
                htp.p('    <th scope="col" width="15%">Room</th>');
                htp.p('    <th scope="col" nowrap width="10%">Campus</th>');
                htp.p('    <th scope="col" width="15%">Comments</th>');
                htp.p('  </tr>');
            END IF;
            
            l_background_shade := common_style.get_background_shade(l_background_shade);
            htp.p('<tr valign="top" bgcolor="'||l_background_shade||'">');

            -- name link
            IF (p_print_ind = 'Y') THEN
                htp.p('<td>' || UPPER(r_jp.full_name) || '</td>');

            ELSE
                htp.p('<td><a href="'||qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_USER_PROFILE')||'?id='||r_jp.employee_id
                     ||'&p_roleCode='|| r_jp.ip_type||'">'||UPPER(r_jp.full_name)||'</a></td>');
            END IF;
                          
            IF (l_type IS NULL) THEN
                -- role description
                htp.p('  <td>'|| r_jp.description ||'</td>');
            END IF;

            -- contact phone
            htp.p('  <td>'|| r_jp.primary_extn ||'</td>');
            
            -- email alias
            IF (p_print_ind = 'Y') THEN
                htp.p('  <td>' || emp.get_email (r_jp.employee_num, 'Y') || '</td>');
            ELSE
                htp.p('  <td><a href="mailto:'|| emp.get_email (r_jp.employee_num, 'Y') || '">' || emp.get_email (r_jp.employee_num, 'N') || '</a></td>');
            END IF;
            
            -- room/location
            htp.p('  <td>'|| r_jp.primary_location ||'</td>');
            -- campus
            htp.p('  <td>'|| r_jp.campus ||'</td>');
            -- comments
            htp.p('  <td>'|| r_jp.comments ||'</td>');
            htp.p('</tr>');
        END LOOP;
    ELSE
        
         
        FOR r_jp IN c_emp_jps LOOP

            l_cnt := l_cnt + 1;
            
            IF (l_cnt = 1) THEN
                
                 IF (l_user_type <> 'STU') THEN
                  htp.p('<p>' || l_img_path || ' indicates Justice of the Peace is available to <strong>staff only</strong></p>');
                 END IF;
                -- show seleced criteria
                IF (l_type IS NOT NULL) THEN
                    htp.p('<strong>Type:</strong> ' || l_type || '<br>');
                END IF;
        
                htp.p('<table class="qv_table" width="100%" border="0" cellpadding="0" cellspacing="0">');
                htp.p('  <tr valign="top">');
                
                -- show * column to indicate JP is available to staff only
                htp.p('    <th scope="col" width="1%">&nbsp;</th>');
                htp.p('    <th scope="col" width="19%">Name</th>');

                IF (l_type IS NULL) THEN
                    htp.p('    <th scope="col" width="20%">Type</th>');
                END IF;

                htp.p('    <th scope="col" nowrap width="10%">Phone</th>');
                IF (p_print_ind = 'Y') THEN
                    htp.p('    <th scope="col" nowrap width="10%">Email Address</th>');
                ELSE
                    htp.p('    <th scope="col" nowrap width="10%">Email Alias</th>');
                END IF;
                htp.p('    <th scope="col" width="15%">Room</th>');
                htp.p('    <th scope="col" nowrap width="10%">Campus</th>');
                htp.p('    <th scope="col" width="15%">Comments</th>');
                htp.p('  </tr>');
            END IF;
            
            l_background_shade := common_style.get_background_shade(l_background_shade);
            htp.p('<tr valign="top" bgcolor="'||l_background_shade||'">');

            IF (r_jp.attribute_type = 'JPEMP') THEN
                htp.p('<td>' || l_img_path || '</td>');
            ELSE
                htp.p('<td>&nbsp;</td>');
            END IF;
            
            -- name link
            IF (p_print_ind = 'Y') THEN
                htp.p('<td>' || UPPER(r_jp.full_name) || '</td>');

            ELSE
                htp.p('<td><a href="'||qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_USER_PROFILE')||'?id='||r_jp.employee_id
                     ||'&roleCode='|| r_jp.ip_type||'">'||UPPER(r_jp.full_name)||'</a></td>');
            END IF;
                          
            IF (l_type IS NULL) THEN
                -- role description
                htp.p('  <td>'|| r_jp.description ||'</td>');
            END IF;

            -- contact phone
            htp.p('  <td>'|| r_jp.primary_extn ||'</td>');
            
            -- email alias
            IF (p_print_ind = 'Y') THEN
                htp.p('  <td>' || emp.get_email (r_jp.employee_num, 'Y') || '</td>');
            ELSE
                htp.p('  <td><a href="mailto:'|| emp.get_email (r_jp.employee_num, 'Y') || '">' || emp.get_email (r_jp.employee_num, 'N') || '</a></td>');
            END IF;
            
            -- room/location
            htp.p('  <td>'|| r_jp.primary_location ||'</td>');
            -- campus
            htp.p('  <td>'|| r_jp.campus ||'</td>');
            -- comments
            htp.p('  <td>'|| r_jp.comments ||'</td>');
            htp.p('</tr>');
                 
        END LOOP;
    END IF;


    IF (l_cnt > 0) THEN
        htp.p('</table>');

        htp.p('<p><strong>Total number of JP''s:</strong> ' || l_cnt || '</p>');

        IF (p_print_ind IS NULL) THEN
			htp.p('<ul class="linklist_paddingtop">');
            l_link_url := 'srch_common_people_p.show?p_arg_names=p_show_mode&p_arg_values=' || srch_stu_people.C_SRCH_STU_PEOPLE_2
                ||'&p_arg_names=p_campus&p_arg_values=' || p_campus
                ||'&p_arg_names=p_attribute_value&p_arg_values=' || p_attribute_value
                ||'&p_arg_names=p_attribute_type&p_arg_values=' || p_attribute_type
                ||'&p_arg_names=p_searchby_ppl&p_arg_values=' || p_searchby_ppl
                ||'&p_arg_names=p_print_ind&p_arg_values=Y'
                ||'&p_arg_names=p_from&p_arg_values=' || p_from;
            -- show print and search for JP again links
            htp.p('<li><a href="#" onClick="javascript: window.open(''' || l_link_url || ''', ''PrintJPList'', ''width=900, height=900, resizable=yes, scrollbars=yes'');" class="print">View print-friendly Justice of the Peace (JP) list</a></li>');
            htp.p('<li><a href="search_p.show?p_arg_names=p_list&p_arg_values=' 
                ||'&p_arg_names=p_searchby_ppl&p_arg_values=' || p_searchby_ppl || '" class="search">Search again for Justice of the Peace</a></li>');
        	htp.p('</ul>');
        END IF;
    ELSE
        htp.p('<p>No records matched your search criteria. Please return to the <a href="search_p.show?p_arg_names=p_list&p_arg_values=' 
                ||'&p_arg_names=p_searchby_ppl&p_arg_values=' || p_searchby_ppl || '">advanced search page</a> and try again.</p>');
    END IF;


END show_jp_list;


PROCEDURE show_emp_details
(
    p_id              IN NUMBER     DEFAULT NULL
   ,p_ip_type        IN VARCHAR2      DEFAULT NULL
)
IS
----------------------------------------------------------------------
--  Purpose: Display contact details of employee
----------------------------------------------------------------------
BEGIN
    htp.p('<script type="text/javascript">');
    htp.p('    window.location.replace("'||qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_USER_PROFILE')
    		 ||'?id='||p_id||'&roleCode='||NVL(p_ip_type, 'EMP')||'");');
    htp.p('</script>');
    
END show_emp_details;

PROCEDURE show_vcard
(
    p_id  			IN NUMBER     DEFAULT NULL
   ,p_ip_type		IN VARCHAR2	  DEFAULT NULL
)

IS

	-- ip number or employee number
	l_id			         NUMBER := p_id;
	l_role_cd        		 qv_client_role.role_cd%TYPE;

    l_username               qv_client_role.username%TYPE;
--    l_person_detail          common_client.r_person_detail;
   	l_first_name     		 emp_employee.first_name%TYPE;
	l_surname		 		 emp_employee.surname%TYPE;
	l_campus     	 		 ip.primary_campus%TYPE;
	l_location     	 		 ip.primary_location%TYPE;
   	l_phone       	 		 ip.primary_extn%TYPE;
   	l_fax    	 	 		 ip.primary_fax%TYPE;
   	l_mobile    	 		 ip.mobile%TYPE;
   	l_speed_dial  	         ip.speed_dial%TYPE;
   	l_pager  	     		 ip.pager%TYPE;
	l_location_notes 		 ip.location_notes%TYPE;

    -- employee organisational hierarchy
    l_hierarchy              emp.t_org_unit_hierarchy;
	l_position_title 		 VARCHAR2(100);

   	l_pers_url		 		 qv_pers_details.url%TYPE;
	l_pers_message   		 qv_pers_details.message%TYPE;

	l_email			      	 VARCHAR2(100);
	l_full_preferred_name 	 VARCHAR2(255);
	l_img_path		 	  	 VARCHAR2(500);

    -- address display indicators
    l_perm_addr_ind       	 BOOLEAN DEFAULT FALSE;
    l_post_addr_ind       	 BOOLEAN DEFAULT FALSE;

    l_address                common_client.r_person_addr_detail;

----------------------------------------------------------------------
--  Purpose: Show vCard
----------------------------------------------------------------------
BEGIN

    IF p_ip_type = C_CCR_TYPE THEN
        l_role_cd := C_CCR_TYPE;
    ELSE
        l_role_cd := C_EMP_TYPE;
    END IF;

    -- get username
    l_username := qv_common.get_username(l_id, l_role_cd);

    -- get full preferred name
    l_full_preferred_name := qv_common.get_full_preferred_name(l_username);

    -- get surname
    l_surname := qv_common.get_surname(l_username);

    -- get firstname
    l_first_name := qv_common.get_preferred_name(l_username);

    -- get email
    l_email := qv_common.get_email(l_username,'Y');

    IF p_ip_type = C_CCR_TYPE THEN
        -- get location and phone
        get_ccr_location_and_phone(l_id,l_campus,l_location,l_phone,l_fax,l_mobile,l_speed_dial,l_pager, l_location_notes);
        -- get position title and org unit description
        l_position_title := emp.get_role(l_id);
    ELSE
        -- get location and phone
        get_emp_location_and_phone(l_id,l_campus,l_location,l_phone,l_fax,l_mobile,l_speed_dial,l_pager, l_location_notes);
        -- get position title and org unit description
        l_position_title := emp.get_role(common_client.get_ip_num(l_id, 'EMP'));
    END IF;

    -- employee organisational hierarchy
    l_hierarchy := emp.get_org_unit_hierarchy (l_id, p_ip_type);

    -- get image path
    l_img_path := qv_common_image.get_img_path(l_id,l_role_cd);

    -- get personal home url and personal message
    get_url_message (l_id,l_role_cd,l_pers_url,l_pers_message);

    -- Set the MIME type
    owa_util.mime_header( 'text/x-vcard', FALSE );

    -- Set the name of the file
    htp.p('Content-disposition: attachment; filename='||l_surname||'_'||l_first_name||'.vcf');

    -- Close the HTTP Header
    owa_util.http_header_close;

    htp.prn('BEGIN:VCARD' || CHR(10)
        ||  'PRODID:-//qutvirtual.qut.edu.au//EN' || CHR(10)
        ||  'SOURCE:' || CHR(10)
        ||  'NAME:vCard for '||l_first_name||' '||l_surname||'' || CHR(10)
        ||  'VERSION: 3.0'  || CHR(10)
        ||  'N;CHARSET=UTF-8:'||l_surname||';'||l_first_name||';;;'  || CHR(10)
        ||  'FN;CHARSET=UTF-8:'||l_first_name||' '||l_surname||''   || CHR(10)
        ||  'TITLE:'||l_position_title||''  || CHR(10)
        ||  'ORG: Queensland University of Technology'  || CHR(10)
        ||  'EMAIL:'||l_email||''   || CHR(10)
        ||  'ADR;LANGUAGE=en;CHARSET=UTF-8;TYPE=work:;;');

    IF l_hierarchy IS NOT NULL THEN
        FOR i IN l_hierarchy.FIRST .. l_hierarchy.LAST LOOP
            htp.prn(''|| l_hierarchy(i).org_unit_description ||', ');
        END LOOP;
        htp.prn(';' || CHR(10));
    END IF;

    IF TRIM(l_location) IS NOT NULL THEN
        htp.prn(l_location);
        htp.prn(';' || CHR(10));
    END IF;

    IF TRIM(l_campus) IS NOT NULL AND l_campus <> locn_common.C_OTHER_CAMPUS THEN
        htp.prn('Campus: '||l_campus||'' || CHR(10));
    END IF;

    IF TRIM(l_phone) IS NOT NULL THEN
        htp.prn('TEL;TYPE=work:'||l_phone||''   || CHR(10));
    END IF;

    IF TRIM(l_mobile) IS NOT NULL THEN
        htp.prn('TEL;TYPE=cell:'||l_mobile||''  || CHR(10));
    END IF;

    IF TRIM(l_fax) IS NOT NULL THEN
        htp.prn('TEL;TYPE=fax:'||l_fax||''  || CHR(10));
    END IF;

    IF TRIM(l_pager) IS NOT NULL THEN
        htp.prn('TEL;TYPE=pager:'||l_pager||''  || CHR(10));
    END IF;

    IF TRIM(l_pers_url) IS NOT NULL THEN
        htp.prn('URL:'||l_pers_url||''  || CHR(10));
    END IF;

    htp.prn('END:VCARD');

END show_vcard;

END srch_common_people;
/