CREATE OR REPLACE PACKAGE BODY ph_admin_search IS
/**
* Phone book administrator search
*/
--------------------------------------------------------------------------------------
-- Modification History:
--
-- DD-Mon-YYYY Init   Comment
-- 14-Aug-2007 F.Lee  Added is_account_valid and a check of the print flag to indicate
--                    if the user is currently searchable in QUT Virtual and the QUT
--                    phone book
--
-- Modification History
--------------------------------------------------------------------------------------
--  23-03-2009   Tony Le          SAMS upgrade
--  26-05-2009   Tony Le          Replace references to org_units with emp_org_unit
--  21-09-2009   P.Totagiancaspro Added has_access
-- 16 Oct 2012   Ali Tan  Changed access table from qv_access to access_type_member
--  17-05-2018   S. Kambil        Apply site and service reference to HiQ. [QVPH-41]
--------------------------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
	-- navigation constants
	C_PH_ADM_SRCH01     CONSTANT VARCHAR2(100) := 'Phone Book Administrator Search';

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------
TYPE     ph_admin_type IS RECORD (username         access_type_member.username%TYPE
                                 ,id               qv_client_role.id%TYPE
                                 ,clevel4          occupancy.clevel4%TYPE
                                 ,clevel3          occupancy.clevel3%TYPE
                                 ,clevel2          occupancy.clevel2%TYPE
                                 ,access_cd        access_type_member.access_cd%TYPE);

TYPE     ph_admin_table_type IS TABLE OF ph_admin_type INDEX BY BINARY_INTEGER;

--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------
FUNCTION get_parent_org_unit (p_org_unit_code   emp_org_unit.org_unit_cd%TYPE
                             ,p_hierarchy_level  emp_org_unit.hierarchy_level%TYPE   DEFAULT NULL)
         RETURN emp_org_unit.org_unit_cd%TYPE
IS
--------------------------------------------------------------------------------------
--Purpose: Get the parent org unit code
--------------------------------------------------------------------------------------
    l_org_unit_code     emp_org_unit.org_unit_cd%TYPE;
BEGIN
    IF p_hierarchy_level IS NULL THEN
        BEGIN
            SELECT parent_org_unit_cd
            INTO   l_org_unit_code
            FROM   emp_org_unit
            WHERE  org_unit_cd = p_org_unit_code
            AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
            AND    hierarchy_level IN ('CLEVEL3', 'CLEVEL4', 'CLEVEL5');
        EXCEPTION
            WHEN OTHERS THEN
                l_org_unit_code := NULL;
        END;
    ELSIF p_hierarchy_level = 'CLEVEL4' THEN
        BEGIN
            SELECT parent_org_unit_cd
            INTO   l_org_unit_code
            FROM   emp_org_unit
            WHERE  org_unit_cd = p_org_unit_code
            AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
            AND    hierarchy_level = 'CLEVEL4';
        EXCEPTION
            WHEN OTHERS THEN
                l_org_unit_code := NULL;
        END;
    ELSIF p_hierarchy_level = 'CLEVEL3' THEN
        BEGIN
            SELECT parent_org_unit_cd
            INTO   l_org_unit_code
            FROM   emp_org_unit
            WHERE  org_unit_cd = p_org_unit_code
            AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
            AND    hierarchy_level = 'CLEVEL3';
        EXCEPTION
            WHEN OTHERS THEN
                l_org_unit_code := NULL;
        END;
    END IF;

    RETURN l_org_unit_code;
END get_parent_org_unit;

FUNCTION get_org_unit_desc (p_org_unit_code   emp_org_unit.org_unit_cd%TYPE)
         RETURN VARCHAR2
IS
--------------------------------------------------------------------------------------
--Purpose: Retrieve the Org Unit Description
--------------------------------------------------------------------------------------
    l_org_unit_desc     emp_org_unit.org_unit_desc%TYPE;
BEGIN
    BEGIN
        SELECT org_unit_desc
        INTO   l_org_unit_desc
        FROM   emp_org_unit
        WHERE  org_unit_cd = p_org_unit_code
        AND   (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);
    EXCEPTION
        WHEN OTHERS THEN
            l_org_unit_desc := NULL;
    END;

    RETURN l_org_unit_desc;
END get_org_unit_desc;

FUNCTION sort_pba (p_pba                 ph_admin_table_type
                  ,p_owner_org_cd        ip.owner_org_code%TYPE)
         RETURN ph_admin_table_type
IS
--------------------------------------------------------------------------------------
--Purpose: Attempt to sort the Phone Book Administrators
--------------------------------------------------------------------------------------
l_pba              ph_admin_table_type;
l_pba_tail         ph_admin_table_type;
l_hierarchy_level   emp_org_unit.hierarchy_level%TYPE    DEFAULT NULL;
l_org_unit_code    emp_org_unit.org_unit_cd%TYPE     DEFAULT NULL;
l_pba_cnt          NUMBER                           DEFAULT 0;

BEGIN
    BEGIN
        SELECT hierarchy_level
        INTO   l_hierarchy_level
        FROM   emp_org_unit
        WHERE  org_unit_cd = p_owner_org_cd;
    EXCEPTION
        WHEN OTHERS THEN
            l_hierarchy_level := NULL;
    END;

    IF l_hierarchy_level = 'CLEVEL4' THEN
        l_pba_tail := p_pba;

        FOR i IN 1..l_pba_tail.COUNT LOOP
            IF l_pba_tail(i).clevel4 = p_owner_org_cd THEN
                l_pba(l_pba.COUNT + 1) := l_pba_tail(i);
                l_pba_tail.DELETE(i);
            END IF;
        END LOOP;

        l_org_unit_code := get_parent_org_unit (p_owner_org_cd
                                               ,'CLEVEL4');
        FOR i IN 1..l_pba_tail.COUNT LOOP
            IF l_pba_tail.EXISTS(i) THEN
                IF l_pba_tail(i).clevel3 = l_org_unit_code THEN
                    l_pba(l_pba.COUNT + 1) := p_pba(i);
                    l_pba_tail.DELETE(i);
                END IF;
            END IF;
        END LOOP;

        l_org_unit_code := get_parent_org_unit (l_org_unit_code
                                               ,'CLEVEL3');

        FOR i IN 1..l_pba_tail.COUNT LOOP
            IF l_pba_tail.EXISTS(i) THEN
                IF l_pba_tail(i).clevel2 = l_org_unit_code THEN
                    l_pba(l_pba.COUNT + 1) := l_pba_tail(i);
                    l_pba_tail.DELETE(i);
                END IF;
            END IF;
        END LOOP;

    ELSIF l_hierarchy_level = 'CLEVEL3' THEN
        FOR i IN 1..p_pba.COUNT LOOP
            IF p_pba(i).clevel4 = p_owner_org_cd THEN
                l_pba(l_pba.COUNT + 1) := p_pba(i);
            ELSE
                l_pba_tail(l_pba_tail.COUNT + 1) := p_pba(i);
            END IF;
        END LOOP;

        l_org_unit_code := get_parent_org_unit (p_owner_org_cd
                                               ,'CLEVEL3');
        FOR i IN 1..l_pba_tail.COUNT LOOP
            IF l_pba_tail(i).clevel3 = l_org_unit_code THEN
                l_pba(l_pba.COUNT + 1) := p_pba(i);
                l_pba_tail.DELETE(i);
            END IF;
        END LOOP;
    ELSE
        l_pba := p_pba;
    END IF;

    FOR i IN 1..l_pba_tail.COUNT LOOP
        IF l_pba_tail.EXISTS(i) THEN
            l_pba_cnt := l_pba.COUNT;
            l_pba(l_pba_cnt + 1) := l_pba_tail(i);
        END IF;
    END LOOP;

    RETURN l_pba;
EXCEPTION
    WHEN OTHERS THEN
        RETURN p_pba;
END sort_pba;

FUNCTION is_account_valid (p_username   qv_client_role.username%TYPE)
RETURN BOOLEAN
IS
--------------------------------------------------------------------------------------
--Purpose: return true if the account appears to be valid, false otherwise
--------------------------------------------------------------------------------------
    l_account_active_ind       qv_client_computer_account.account_active_ind%TYPE;
    l_cnt                      NUMBER     DEFAULT 0;

    E_ACCOUNT_INVALID          EXCEPTION;

BEGIN
     BEGIN
          SELECT  account_active_ind
    	  INTO	  l_account_active_ind
    	  FROM	  qv_client_computer_account
    	  WHERE	  username = p_username;
     EXCEPTION
        WHEN OTHERS THEN
            RAISE E_ACCOUNT_INVALID;
     END;

     IF l_account_active_ind = 'Y' THEN
         SELECT  COUNT(*)
         INTO    l_cnt
    	 FROM	 qv_client_role
    	 WHERE	 username = p_username
         AND     role_active_ind = 'Y';

         IF l_cnt = 0 THEN
            RAISE E_ACCOUNT_INVALID;
         END IF;
     ELSE
         RAISE E_ACCOUNT_INVALID;
     END IF;

     RETURN TRUE;
EXCEPTION
    WHEN E_ACCOUNT_INVALID THEN
        RETURN FALSE;
    WHEN OTHERS THEN
        RETURN FALSE;
END is_account_valid;
--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
FUNCTION get_nav_struct (p_location   VARCHAR2   DEFAULT NULL)
		 RETURN owa.vc_arr
IS
--------------------------------------------------------------------------------------
--Purpose: sets and returns the navigation structure
--------------------------------------------------------------------------------------
  		 l_nav_names owa.vc_arr DEFAULT empty_vc_arr;
BEGIN
 	 l_nav_names(1) := C_PH_ADM_SRCH01;
 	 RETURN l_nav_names;
END get_nav_struct;

FUNCTION has_access
RETURN BOOLEAN
IS
------------------------------------------------------------------------------
-- Purpose: checks whether the user has access to view Phone book administrator search
------------------------------------------------------------------------------
BEGIN

	IF qv_common_access.is_user_in_group('EMP') OR
		qv_common_access.is_user_in_group('CCR')
	THEN
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;

END has_access;

--------------------------------------------
--            LOCAL PROCEDURES
--------------------------------------------
--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE show (p_username      VARCHAR2  DEFAULT NULL
               ,p_email_alias   VARCHAR2  DEFAULT NULL
               ,p_surname       VARCHAR2  DEFAULT NULL
               ,p_first_name    VARCHAR2  DEFAULT NULL)
IS
----------------------------------------------------------------------
--  Purpose: Display the Phobe Book Administrator Search
----------------------------------------------------------------------
ph_admin    ph_admin_table_type;

l_owner_org_cd        ip.owner_org_code%TYPE          DEFAULT NULL;
l_emp_owner_org_cd    ip.owner_org_code%TYPE          DEFAULT NULL;
l_cnt                 NUMBER                          DEFAULT 0;
l_clevel4             occupancy.clevel5%TYPE          DEFAULT NULL;
l_employee_num        ip.employee_num%TYPE            DEFAULT NULL;
l_row_color_ind       BOOLEAN                         DEFAULT FALSE;
l_first_row_ind       BOOLEAN                         DEFAULT TRUE;
l_usernames	          owa.vc_arr DEFAULT empty_vc_arr;
l_username	          qv_client_role.username%TYPE;
l_print_flag          ip.print_flag%TYPE;
l_full_preferred_name VARCHAR2(255)                   DEFAULT NULL;


CURSOR c_ph_admin (p_owner_org_cd   access_type_member.access_cd%TYPE) IS
        SELECT DISTINCT  qa.username,
                 qcr.id,
                 o.clevel4,
                 o.clevel3,
                 o.clevel2,
                 qa.access_cd
        FROM     access_type_member qa,
                 occupancy o,
                 qv_client_role qcr
        WHERE    group_cd ='PH'
        AND      access_cd = p_owner_org_cd
        AND      qa.username = qcr.username
        AND      o.employee_num = qcr.ID
        AND      o.clevel2 = SUBSTR(p_owner_org_cd, 1, 3) -- show only admin whose position belongs to the same fac/div
                                                          -- as the user
        ORDER BY o.clevel4, qa.username;

BEGIN
    l_username := p_username;

    common_style.setup_zebra_table;

    htp.p('<h1>Phone Book Administrator Search</h1>');

    IF l_username IS NULL THEN
    
      --DISPLAY SEARCH
      htp.p('<p>You may search for a phone book administrator by entering the person''s '||
            'username, email alias or name below.<br>');
      htp.p('Click SUBMIT when complete, or RESET to clear the form.</p>');
  
      htp.p('<form class="qv_form" name="searchPBA" method="post" action="ph_admin_search_p.process_pba_search">');
      htp.p('<ul>');
      htp.p('<li><label for="p_username">Username:</label>');
      htp.p('<input type="text" name="p_username" value="'||l_username||'" size="20" maxlength="50"></li>');
      htp.p('<li><label for="p_email_alias">Email alias (eg j.smith):</label>');
      htp.p('<input type="text" name="p_email_alias" value="'||p_email_alias||'" size="20" maxlength="50"></li>');
      htp.p('<li><label for="p_surname">Surname:</label>');
      htp.p('<input type="text" name="p_surname" value="'||p_surname||'" size="20" maxlength="50">');
      htp.p('<label for="p_first_name">First name:</label>');
      htp.p('<input type="text" name="p_first_name" value="'||p_first_name||'" size="20" maxlength="50"></li>');
      htp.p('</ul>');
  
      htp.p('<div class="formbuttons">');
      htp.p('<input type="submit" value="SUBMIT" class="submitbutton">');
      htp.p('<input type="reset" value="RESET" class="resetbutton">');
      htp.p('</div>');
      htp.p('</form>');
      htp.p('</p>');

    END IF;

    IF l_username IS NULL THEN
        IF p_email_alias IS NOT NULL OR p_surname IS NOT NULL OR p_first_name IS NOT NULL THEN
    	    l_usernames := emp.get_staff_usernames(p_email_alias => p_email_alias
    					   								 ,p_first_name => p_first_name
        									 			 ,p_surname => p_surname);

    	    IF l_usernames.COUNT > 0 THEN
                -- remove if CCR, this function does not cater for CCR clients at the moment
                FOR r_username IN 1..l_usernames.COUNT LOOP
                    l_employee_num := qv_common.get_id (UPPER(l_usernames(r_username)), 'EMP');

                    IF l_employee_num IS NULL THEN
                        l_usernames.DELETE(r_username);
                    END IF;
                END LOOP;
            END IF;

    		IF l_usernames.COUNT = 0 THEN
                -- provide msg - no matching users
    			htp.p('<p>Your search criteria did not match any employees. Please '
    			    ||'check the details you entered and try again.</p>');
            ELSIF l_usernames.COUNT = 1 THEN
                l_username := l_usernames(1);
            ELSE
                l_row_color_ind := FALSE; -- make first row grey

                htp.p('<p>The data you entered matches the following staff.  Click on the '
                    ||'"select" link beside the relevant staff member.</p>');

                htp.p('<table border="0" cellspacing="0" cellpadding="2px" width="100%" class="zebra">');

                FOR r_username IN 1..l_usernames.COUNT LOOP
                    IF l_usernames.EXISTS(r_username) THEN
            			IF l_row_color_ind THEN
            			   	l_row_color_ind := FALSE;
            				htp.p('<tr class=''even''>');
            			ELSE
            				l_row_color_ind := TRUE;
            				htp.p('<tr class=''odd''>');
            			END IF;  -- if l_row_color_ind

                        htp.p('<td>'||qv_common.get_full_preferred_name(UPPER(l_usernames(r_username)))||'</td>');
                        htp.p('<td><a href="ph_admin_search_p.show'
                            ||'?p_arg_names=p_username&p_arg_values='||l_usernames(r_username)
                            ||'&p_arg_names=p_email_alias&p_arg_values='||p_email_alias
                            ||'&p_arg_names=p_surname&p_arg_values='||p_surname
                            ||'&p_arg_names=p_first_name&p_arg_values='||p_first_name||'">select</a></td>');
                        htp.p('</tr>');

                    END IF;
                END LOOP;

                htp.p('</table>');

                htp.p('<p><a href="ph_admin_search_p.show">Search again</a></p>');
            END IF;
        END IF;
    END IF;



    IF l_username IS NOT NULL THEN
        l_employee_num := qv_common.get_id (UPPER(l_username), 'EMP');

        IF l_employee_num IS NULL THEN
           htp.p('<p><strong>No employee with username '||l_username||' found!</strong></p>');
        ELSE
		    BEGIN
			    SELECT  print_flag,
                        owner_org_code
				INTO	l_print_flag,
                        l_owner_org_cd
				FROM	ip
				WHERE	employee_num = TO_NUMBER(l_employee_num)
				AND	    ip_type = 'EMP';
            EXCEPTION
                WHEN OTHERS THEN
                    htp.p('An error occurred while retrieving data for '||l_employee_num||': '||SQLERRM);
            END;

            l_full_preferred_name := qv_common.get_full_preferred_name(UPPER(l_username));

            IF l_print_flag = 'N' THEN
                htp.p('<p>Note: '||l_full_preferred_name||' is currently '
                    ||'<strong>not</strong> searchable in the '||ph_main.C_STAFF_SERVICE_NAME||' and the QUT phone book.  '
                    ||'If '||l_full_preferred_name||' would like to be searchable in the '||ph_main.C_STAFF_SERVICE_NAME
                    ||' and in the QUT phone book, please advise them to contact a suitable Phone '
                    ||'Book Administrator below.</p>');
            END IF;

            IF NOT is_account_valid (UPPER(l_username)) THEN
                htp.p('<p>Note: If '||l_full_preferred_name||' is currently not searchable in the '
                    ||ph_main.C_STAFF_SERVICE_NAME||' and the QUT phone book, there could be a problem with '
                    ||'the user account.  Please contact HiQ for assistance.</p>');
            END IF;

            l_emp_owner_org_cd := l_owner_org_cd;

            htp.p('<p>'||l_full_preferred_name||' belongs in '
                ||get_org_unit_desc(l_owner_org_cd)||' ('||l_owner_org_cd||')</p>');

            htp.p('<table border="0" cellspacing="0" cellpadding="2px" width="100%" class="zebra">');

            WHILE l_owner_org_cd IS NOT NULL LOOP
                ph_admin.DELETE;
                l_cnt := 0;
                l_row_color_ind := FALSE; -- make first row grey

                IF NOT l_first_row_ind THEN -- leave a space between areas
                    htp.p('<tr><td colspan="3">&nbsp;</td></tr>');
                ELSE
                    l_first_row_ind := FALSE;
                END IF;

                htp.p('<tr><td colspan="3"><strong>Phonebook Administrators for '||get_org_unit_desc(l_owner_org_cd)||' ('
                    ||l_owner_org_cd||'):</strong></td></tr>');

                FOR r_admin IN c_ph_admin (l_owner_org_cd) LOOP
                    l_cnt := l_cnt + 1;

                    ph_admin(l_cnt).username := r_admin.username;
                    ph_admin(l_cnt).id := r_admin.id;
                    ph_admin(l_cnt).clevel4 := r_admin.clevel4;
                    ph_admin(l_cnt).clevel3 := r_admin.clevel3;
                    ph_admin(l_cnt).clevel2 := r_admin.clevel2;
                    ph_admin(l_cnt).access_cd := r_admin.access_cd;
                END LOOP;

                l_owner_org_cd := get_parent_org_unit (l_owner_org_cd);

                IF l_cnt > 0 THEN
                    ph_admin := sort_pba(ph_admin
                                        ,l_emp_owner_org_cd);

                    FOR i IN 1..ph_admin.COUNT LOOP

            			IF l_row_color_ind THEN
            			   	l_row_color_ind := FALSE;
            				htp.p('<tr class=''even''>');
            			ELSE
            				l_row_color_ind := TRUE;
            				htp.p('<tr class=''odd''>');
            			END IF;  -- if l_row_color_ind

                        IF (l_clevel4 IS NULL OR ph_admin(i).clevel4 != l_clevel4) THEN
                            htp.p('<td>'||get_org_unit_desc(ph_admin(i).clevel4)||' ('||ph_admin(i).clevel4||')</td>');
                            l_clevel4 := ph_admin(i).clevel4;
                        ELSE
                            htp.p('<td>&nbsp;</td>');
                        END IF;

                        htp.p('<td><a href="srch_common_people_p.show?p_arg_names=p_id&p_arg_values='||ph_admin(i).id
                            ||'&p_arg_names=p_ip_type&p_arg_values=EMP">'
                            ||qv_common.get_full_preferred_name(ph_admin(i).username)||'</a></td>');
                        htp.p('<td><a href="mailto:'||qv_common.get_email(ph_admin(i).username, 'Y')||'">'
                            ||qv_common.get_email(ph_admin(i).username, 'Y')||'</a></td>');
                        htp.p('</tr>');
                    END LOOP;

                ELSE
                    htp.p('<tr class=''odd''><td colspan="3">No phone book administrators found</td></tr>'); -- only 1 row, so always grey
                END IF;

            END LOOP;
            htp.p('</table>');

            --htp.p('<p><a href="ph_admin_search_p.show">Search again</a></p>');

        END IF;
    END IF;

    htp.p('<br>');

END show;

PROCEDURE help
IS
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
BEGIN
    htp.p('<p>The Phone Book Administrator Search page is a tool to '
        ||'search for a phone book administrator using the person''s username, email alias (eg j.smith) or name.</p>');
    htp.p('<p>If the search is successful, the person''s name, organisational unit, and organisational '
        ||'unit code will be displayed.  Knowing the person''s organisational unit details is helpful '
        ||'in selecting an appropriate phone book administrator for the person.</p>');
    htp.p('<p>If the user is currently set up not to be displayed in the '||ph_main.C_STAFF_SERVICE_NAME ||' search and the QUT phone book, '
        ||'a note will be displayed to indicate this.</p>');
    htp.p('<p>Phone book administrators for the person are grouped into the organisational unit that they '
        ||'are assigned to (in bold text).  Within these groups, they are further grouped into the '
        ||'organisational unit that they are from.</p>');
    htp.p('<p>To search for the most appropriate phone book administrator...</p>');
    htp.p('<ol>');
    htp.p('<li>First, attempt to select a phone book administrator in the same organisational unit as the client.</li>');
    htp.p('<li>If there are no phone book administrators in the same organisational unit as the client then select the first '
        ||'phone book administrator on the list.</li>');
    htp.p('<li>If no phone book administrators are found, please contact HiQ for assistance.</li>');
    htp.p('</ol>');
END help;

END ph_admin_search;
/