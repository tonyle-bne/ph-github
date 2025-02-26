CREATE OR REPLACE PACKAGE BODY           emp_personal_profile IS

/**
* Staff personal details portlet
* @version 1.0.0
*/

-----------------------------------------------------------------------------------------
--  Purpose:	  Staff personal details
--				  Provide details form to update employee's personal details
--				  If invalid entries are found re-display a form with message otherwise
--				  show success page
--  Modification History
--  Date         Author      Description
--  -----------  ------------------------------------------------------------------------
--  19-SEP-2002  S.Jeong     Created
--  23-SEP-2002  S Jeong     Reference to removed when calling qv_search_orgunit_p.show
--  27-SEP-2002	 S Jeong	 Message textarea removed
--				 S Jeong     Parameter value for [qv_search_orgunit_p.show] modified
--  02-Oct-2002  M Huth		 Converted generic queries to queries - one each for
--				   			 EMP and CCR - for location/phone, posn/dept, gender/title
--							 and url message because they caused a parsing problem
--							 Also added in quick fix so that men stop deleting their title!
--  08-OCT-2002  S Jeong     Proc name changed process_update --> validate_details_form,
--				   			 show_update_form --> show_details_form
--							 Proc process_update modified, update only if form entries are
--							 different from DB value
--	08-OCT-2002  S Jeong     URL starts with 'WWW' is stored as 'http://www...'
--	10-OCT-2002  S Jeong     Women's title info & proc update_emp_details modified
--	19-NOV-2002  S Jeong     Choose org_units.local_name instead of org_units.org_unit_desc in
--				   			 procedures get_emp_position_and_dept and get_ccr_position_and_dept.
--  14-Jan-2002  S Jeong     Added if statement in update_emp_details and update_ccr_details,
--                           where it checks whether form entry fax number is different from a fax number
--                           in a table. Without this statement it fails to update fax number if there is
--                           a change to only fax number.
--  12-May-2003  R.Arndt     show_personal_details - added c_home_post_address cursor and
--                           code to display emp home and postal address.
--  29-May-2003  R.Arndt     show_personal_details - removed nvl from c_home_post_address
--                           cursor
--  30-May-2003  S Jeong     link "Update your equity details" added in show_personal_details
--                           help text added in show_help
--  3-June-2003  R.Arndt     show_personal_details - programmatically populate subject and cc
--                           fields of the HR mailto link.
--  10-June-2003 S Jeong     take comment out equity codings from show_personal_details and show_help
--  24-Oct-2003  R.Arndt     show_details_from - added max lengths to prefered name form field
--                           show_personal_details - replaced Email HR link with link to staff connect
--  27-Oct-2003  R.Arndt     show_personal_details - added select address statement and exception block
--                                                 - modified address display code
--  03-Nov-2003  S Jeong     Exception is placed in 'process_update' procedure in case of user_type(role code)
--                           and username being null
--  11-Nov-2003  S Jeong     Shorten length of url when displaying in show_personal_details
--  11-Jun-2004  M Huth		 Removed display of address from staff personal profile portlet.
--				   			 Modified text advising staff to go to StaffConnect to update addresses.
--  29-Sep-2004  J Choy      Changed wording in link that updates personal details in show_personal_details
--	29-Apr-2005	 D Hunt		 Added code to reference the LOCN set of tables.
--	05-May-2005	 D Hunt		 Corrected view of other in personal details form for employee
--	11-May-2005	 D Hunt		 Changed location javascript so clears subordinate values if function called by another
--				   			 function.  Changed the check for update primary_location so keeps old one if new one is
--							 just spaces
--	13-May-2005	 D Hunt		 Changed location fields so totally dynamic (ie will change automatically depending on
--				   			 the values in the database)
--	16-May-2005	 D Hunt		 Changed label Please Select... to read Please select...  Brought in all names in location
--				   			 dropdowns to uppercase.
--	23-May-2005	 D Hunt		 Added loction notes to personal details screen, changed javascript to made dropdowns unselectable
--				   			 if no values exist or if higher items have not been selected, e.g. don't allow user to select rooms
--							 if floor has not been selected.  Took out display of employee id.
--	02-Jun-2005	 D Hunt		 Took out null test for primary location change, in update emp and ccr details procedures
--	15-Jun-2005	 D Hunt		 Corrected code formatting, added comment about zOther
--	17-Jun-2005	 D Hunt		 Moved a few procedures and functions to locn_common
--	8-Aug-2005	 D Hunt		 Added check for primary_location field for update of emp and ccr details
--  01-Nov-2005	 F Lee		 Added Closed User Group
--				   			 Hide location notes and pager number from personal details portlet if null
--  09-Nov-2005	 F Lee		 Changed maxlength on Closed User Group to 10 characters
--				   			 Changed case of Location Notes to Location notes in show_details_from
-- 							 Hide fax, mobile number, speed dial and closed user group if null
--							 Updated help text
--  18-Apr-2006 K Curliss    Replaced qv_common_links references with generic get_reference_link
--  20-Jul-2006 E Wood       10g UPGRADE - Removed calls to qv_common_style;
--                           Removed deprecated <embed> HTML tag;
--  29-Nov-2006 E Wood		 Updated PROCEDURE show_details_form to reflect changes requested by Sharyn Leeman for
--                           Phone, Fax entries on the form and added the note about data being available externally.
--  03-Dec-2008  C Wong      Removed reference to body onload and replace with call to addLoadEvent javascript function.
--  05-Feb-2009  P.Totagiancaspro
--                           Updated show_personal_details to display details in QV1.5 styles
--  09-Feb-2009  A.McBride   Updated the update_personal_details form in QV1.5 styles, and form validation
--  10-Feb-2009  A.McBride   Further form UI changes
--  16-Feb-2009  A.McBride   Move information messages.
--  17-Feb-2009  A.McBride   Applied initcap to lowercase drop downs.
--                           Removed Closed User Group from update details form
--  19-Feb-2009  A.McBride   Adjusted speed dial validation
--  20-Feb-2009  A.McBride   Added Female title back.
--  01-May-2009  F. Johnston Added field for emergency mobile number
--  15-May-2009  A.McBride   Adjusted phone number validation to allow various formats of phone and mobile numbers.
-- 22-May-2009   C Wong      Modify validation to allow for formats, make title non-mandatory, add askqut link
-- 23 July 2009  T Baisden   Removed link to employee equity data questionnaire
--  28-Jul-2009  A.McBride   Reword links in portlet.
--                           Added ePortfolio link.
--  18-Sep-2009  N.Kays      Updated name of ePortfolio link.
--  18-Feb-2010  A.McBride   Review portlet UI text and links
-- 	13-Jan-2010  A.McBride   Added organisational heirarchy field in staff details display
--  18-Oct-2010  A.McBride   Updated jQuery error placement when next to help tips.
--  23-Nov-2010  A.McBride	 Added update other role link to StaffConnect
--  09-Dec-2011  Tony Le     Moved get_emp_position_and_dept and get_ccr_position_and_dept
--                           into emp and ccr_common
--  13-Dec-2011  Tony Le     As it turns out, the package is no longer required get_emp/ccr_position_and_dept
--                           function. Extend the length of l_position_title to 100 chars. Tidying up codes.

-- 09-Jun-2015  Manjeet Kaur  Removed preferred name field so that users can't edit it, removed position title
--                            text (QVEMP-18, QVEMP-29)
-- 09-09-2015   Jason Wright   Removed, by commenting, emergency phone number field so that users can't edit or view in QV (JIRA: QVEMP-31)
-- 16-09-2015   Manjeet Kaur  Removed fieldset for males, changed fieldset title  (JIRA : QVEMP-33)
-- 16-09-2015   Jason Wright  Removed, by commenting, reference to emergency phone number in the 'Private Data Warning Message'  (JIRA: QVEMP-31)
-- 17-09-2015   Jason Wright  Removed, by commenting, all other references to emergency phone number field (JIRA: QVEMP-31)
-- 28-09-2015   Manjeet Kaur  Added new help tip code for Phone number, Mobile number and Speed dial (JIRA:QVEMP-26)
-- 21-10-2015   Jason Wright  Removed the commented-out code from (JIRA: QVEMP-31)
-- 16-11-2015   Tony Le       1- Worked on Gender-X and Title Mx (JIRA: QVEMP-43)
--                            2- Took away the logic, IF female THEN allow staff to update the Title.
--                            3- Show infos to advise staff to contact HR if they would like to update Title and Surnam
--                            4- Because of point 2 above, there is no logic 'IF female staff THEN update this ELSE do that'
--                               in update_emp_details and update_ccr_details. The update statement is now the same for both male and female staff
-- 22-Mar-2017  Tony Le       QVEMP-51: HiQ changes (removing and replacing any references to
--                            QV,DW,Student Gateway etc. with HiQ, or QUT Students site etc.)
-- 11-Oct-2017  L Lin		  Remove un-wanted code as part of refactoring job QVEMP-53.
-- 09-Nov-2017  Tony Le       QVEMP-54: Fixed broken HR contact link/page in personal details page. Put link into qv_reference_cd after shorten it
-- 18-Dec-2017  Tony Le       QVEMP-56: Rename 'Update Personal Details' to 'Update Contact Details'
-- 21-Dec-2017  Tony Le       QVEMP-57: Remove the blue info bar 'To update your title or surname, please contact your Human Resources Department representative'
-- 14-Nov-2019  N.Shanmugam   QVEMP-65: Fix the p_preferred_name parameter so the name retains even after updating the contact details
----------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------
--            LOCAL CONSTANTS
--------------------------------------------

    -- gold pass holders
    C_GOLD_PASS_HOLDERS CONSTANT VARCHAR2(50) := 'GOLD PASS HOLDERS';
    C_APPLICATION_CD      VARCHAR2(50)        := 'EMP';

    -- undefined role type
    C_ROLE_UNDEFINED    CONSTANT VARCHAR2(20) := 'Undefined';
    C_QUT               CONSTANT VARCHAR2(20) := 'QUT';

    -- user type
    C_EMP_TYPE       CONSTANT ip.ip_type%TYPE := 'EMP';
    C_CCR_TYPE       CONSTANT ip.ip_type%TYPE := 'CCR';

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

    g_arg_names  owa.vc_arr;
    g_arg_values owa.vc_arr;
    g_staff_intranet_name   qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description('STAFF_INTRANET_NAME');

--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------

FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
IS
----------------------------------------------------------------------
--  Purpose: Retrieve value for @p_name
----------------------------------------------------------------------
BEGIN
   RETURN common_utils.get_string(g_arg_names, g_arg_values, p_name);
END get_value;

FUNCTION get_ip_num_for_ccr
(
    p_id    IN  NUMBER   DEFAULT NULL
)
    RETURN VARCHAR2
IS
----------------------------------------------------------------------
--  Purpose: Return ip_num for @p_id (ccr_client_id) OR
--			 Return null if not found
----------------------------------------------------------------------
    l_ip_num ip.ip_num%TYPE;
BEGIN
    SELECT ip_num
    INTO   l_ip_num
    FROM   ccr_clients
    WHERE  ccr_client_id = p_id
	AND    ROWNUM = 1;

    RETURN l_ip_num;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    WHEN OTHERS THEN
        RETURN NULL;
END get_ip_num_for_ccr;

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
FUNCTION get_nav_struct
(
    p_show_mode 	  IN VARCHAR2 DEFAULT NULL
)
    RETURN owa.vc_arr
IS
----------------------------------------------------------------------
--  Purpose: Build navigations structure
----------------------------------------------------------------------
	 p_nav_names  owa.vc_arr DEFAULT empty_vc_arr;

BEGIN
    p_nav_names(1) := C_UPDATE_PROFILE;
	RETURN p_nav_names;
END get_nav_struct;

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
            logger.error(p_application_cd => c_application_cd
                        ,p_log_data => 'An unexpected exception occurred in emp_personal_profile.get_location_id');              
            l_location_id :=  NULL;
    END;

    RETURN l_location_id;
END get_location_id;

--------------------------------------------
--            LOCAL PROCEDURES
--------------------------------------------
PROCEDURE get_emp_location_and_phone
(
    p_id                  IN  NUMBER   DEFAULT NULL
   ,p_campus      		  OUT VARCHAR2
   ,p_primary_location    OUT VARCHAR2
   ,p_location_id 		  OUT VARCHAR2
   ,p_phone    	  		  OUT VARCHAR2
   ,p_fax   	  		  OUT VARCHAR2
   ,p_mobile      		  OUT VARCHAR2
   ,p_speed_dial  		  OUT VARCHAR2
   ,p_closed_user_group	  OUT VARCHAR2
   ,p_pager       		  OUT VARCHAR2
   ,p_location_notes 	  OUT VARCHAR2
)
----------------------------------------------------------------------
--  Purpose: Get location and phone details for employee given ip.employee_num
----------------------------------------------------------------------
IS

BEGIN
    SELECT  primary_campus
			,primary_location
			,location_id
			,primary_extn
			,primary_fax
			,mobile
			,speed_dial
			,closed_user_group
			,pager
			,location_notes
	INTO	p_campus
			,p_primary_location
			,p_location_id
            ,p_phone
            ,p_fax
            ,p_mobile
            ,p_speed_dial
			,p_closed_user_group
            ,p_pager
			,p_location_notes
	FROM    ip
	WHERE	employee_num = p_id;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
    WHEN OTHERS THEN
        NULL;
END get_emp_location_and_phone;

PROCEDURE get_ccr_location_and_phone
(
    p_id                  IN  NUMBER   DEFAULT NULL
   ,p_campus      		  OUT VARCHAR2
   ,p_primary_location    OUT VARCHAR2
   ,p_location_id 		  OUT VARCHAR2
   ,p_phone    	  		  OUT VARCHAR2
   ,p_fax   	  		  OUT VARCHAR2
   ,p_mobile      		  OUT VARCHAR2
   ,p_speed_dial  		  OUT VARCHAR2
   ,p_closed_user_group   OUT VARCHAR2
   ,p_pager       		  OUT VARCHAR2
   ,p_location_notes 	  OUT VARCHAR2
)
----------------------------------------------------------------------
--  Purpose: Get location and phone details for ccr client given ip.ip_num
----------------------------------------------------------------------
IS

BEGIN
    SELECT  primary_campus
			,primary_location
			,location_id
			,primary_extn
			,primary_fax
			,mobile
			,speed_dial
			,closed_user_group
			,pager
			,location_notes
	INTO	p_campus
			,p_primary_location
			,p_location_id
      ,p_phone
      ,p_fax
      ,p_mobile
      ,p_speed_dial
			,p_closed_user_group
      ,p_pager
			,p_location_notes
	FROM    ip
	WHERE	ip_num = p_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
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
			,title
	INTO	p_gender
			,p_title
	FROM	ip
	WHERE	employee_num = p_id;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
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
			,title
	INTO	p_gender
			,p_title
	FROM	ip
	WHERE	ip_num = p_id;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
    WHEN OTHERS THEN
        NULL;
END get_ccr_gender_title;

PROCEDURE display_title
(
    p_title           IN  VARCHAR2 DEFAULT NULL
)
IS
----------------------------------------------------------------------
--  Purpose: Display title drop down menu
----------------------------------------------------------------------
	l_selected            VARCHAR2(10);
	-- kind of title for female
    l_kind_of_title	 	  ip.title%TYPE;
BEGIN

	htp.p('<select name="p_title">');
	htp.p('<option value="">Please select...');

    FOR c IN 1..3 LOOP

		l_selected := NULL;
	    IF c = 1 THEN l_kind_of_title := 'MS';   END IF;
	    IF c = 2 THEN l_kind_of_title := 'MISS'; END IF;
	    IF c = 3 THEN l_kind_of_title := 'MRS';  END IF;

		-- if title matched with current title, select the title
	    IF l_kind_of_title = p_title THEN l_selected := 'SELECTED'; END IF;

		htp.p('<option value="'||l_kind_of_title||'" '||l_selected||'>'
		                       ||l_kind_of_title);
	END LOOP;
	htp.p('  </select>');

END display_title;

PROCEDURE get_emp_url_message
(
    p_id             IN  NUMBER   DEFAULT NULL
   ,p_pers_url   	 OUT VARCHAR2
   ,p_pers_message   OUT VARCHAR2
)
----------------------------------------------------------------------
--  Purpose: Get personal home page url and personal message for employee
--  		 given ip.employee_num
----------------------------------------------------------------------
IS

BEGIN
    SELECT  url
		    ,message
	INTO	p_pers_url
			,p_pers_message
    FROM    qv_client_role qcr
			,qv_pers_details qpd
    WHERE   qcr.id = p_id
    AND     qcr.role_cd = 'EMP'
	AND    	qcr.username = qpd.username
	AND    	qpd.role_cd = 'EMP';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
    WHEN OTHERS THEN
        NULL;

END get_emp_url_message;

PROCEDURE get_ccr_url_message
(
    p_id             IN  NUMBER   DEFAULT NULL
   ,p_pers_url   	 OUT VARCHAR2
   ,p_pers_message   OUT VARCHAR2
)
----------------------------------------------------------------------
--  Purpose: Get personal home page url and personal message for ccr
--			 client given ip.ip_num
----------------------------------------------------------------------
IS

BEGIN
    SELECT  url
		    ,message
	INTO	p_pers_url
			,p_pers_message
    FROM    qv_client_role qcr
			,qv_pers_details qpd
    WHERE   qcr.id = p_id
    AND     qcr.role_cd = 'CCR'
	AND    	qcr.username = qpd.username
	AND    	qpd.role_cd = 'CCR';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
    WHEN OTHERS THEN
        NULL;

END get_ccr_url_message;

PROCEDURE validate_url
(
    p_url         IN  VARCHAR DEFAULT NULL
   ,p_invalid_ind OUT VARCHAR
)
IS
----------------------------------------------------------------------
--  Purpose: Check valid type of url and pass out indicator
----------------------------------------------------------------------
BEGIN

	IF (LOWER(p_url) NOT LIKE 'http://%') AND
	   (LOWER(p_url) NOT LIKE 'https://%') AND
	   (LOWER(p_url) NOT LIKE 'www%') AND
	   (LOWER(p_url) NOT LIKE 'file://%') THEN
        p_invalid_ind := 'Y';
	ELSE
	    p_invalid_ind := 'N';
	END IF;

END validate_url;


PROCEDURE update_emp_details
(
    p_id				  IN NUMBER   DEFAULT NULL
   ,p_preferred_name      IN VARCHAR2 DEFAULT NULL
   ,p_gender	          IN VARCHAR2 DEFAULT NULL
   ,p_title		          IN VARCHAR2 DEFAULT NULL
   ,p_campus		      IN VARCHAR2 DEFAULT NULL
   ,p_location_notes      IN VARCHAR2 DEFAULT NULL
   ,p_phone		          IN VARCHAR2 DEFAULT NULL
   ,p_fax		          IN VARCHAR2 DEFAULT NULL
   ,p_mobile		      IN VARCHAR2 DEFAULT NULL
   ,p_speed_dial		  IN VARCHAR2 DEFAULT NULL
   ,p_closed_user_group	  IN VARCHAR2 DEFAULT NULL
   ,p_pager		          IN VARCHAR2 DEFAULT NULL
   ,p_building		      IN VARCHAR2 DEFAULT NULL
   ,p_floor		          IN VARCHAR2 DEFAULT NULL
   ,p_room		          IN VARCHAR2 DEFAULT NULL
)
----------------------------------------------------------------------
--  Purpose: Update employee's personal details
--			 Update all if at least one change found otherwise do nothing
--			 Title is only updated for female
----------------------------------------------------------------------
IS
    l_preferred_name       					ip.preferred_name%TYPE;
    l_gender			   					ip.gender%TYPE;
    l_title				   					ip.title%TYPE;
   	l_campus			   					ip.primary_campus%TYPE;
   	l_location_id    	   					ip.location_id%TYPE;
   	l_phone        		   					ip.primary_extn%TYPE;
   	l_fax    	 		   					ip.primary_fax%TYPE;
   	l_mobile    	 	   					ip.mobile%TYPE;
   	l_speed_dial  		   					ip.speed_dial%TYPE;
   	l_closed_user_group	   					ip.closed_user_group%TYPE;
   	l_pager		 		   					ip.pager%TYPE;
    l_location_notes	   					ip.location_notes%TYPE;
   	l_primary_location	   					ip.primary_location%TYPE;
   	l_new_primary_location	   				ip.primary_location%TYPE;
    l_new_location_id	   					ip.location_id%TYPE;
	l_location_campus	                    locn_site.name%TYPE 	   			DEFAULT NULL;
	l_location_building	                    locn_building.name%TYPE 	   		DEFAULT NULL;
	l_location_floor	                    locn_floor.name%TYPE 		   		DEFAULT NULL;
	l_location_room		                    locn_room.room_id%TYPE	   			DEFAULT NULL;

BEGIN

    SELECT NVL(preferred_name,'null')
    	  ,NVL(title,'null')
	      ,NVL(primary_campus,'null')
		  ,NVL(location_id, 'null')
		  ,NVL(primary_extn,'null')
		  ,NVL(primary_fax,'null')
		  ,NVL(mobile,'null')
		  ,NVL(speed_dial,'null')
		  ,NVL(closed_user_group,'null')
		  ,NVL(pager,'null')
		  ,NVL(location_notes, 'null')
		  ,NVL(primary_location, 'null')
	INTO   l_preferred_name
	      ,l_title
	      ,l_campus
		  ,l_location_id
		  ,l_phone
		  ,l_fax
		  ,l_mobile
          ,l_speed_dial
		  ,l_closed_user_group
		  ,l_pager
		  ,l_location_notes
		  ,l_primary_location
	FROM   ip
	WHERE  employee_num = p_id;

    l_new_location_id := get_location_id(p_campus, p_building, p_floor, p_room);

    -- Avoid using the locn_common package as there is a bug in there
    locn_common.get_location_name (l_new_location_id
                                  ,l_location_campus
                                  ,l_location_building
                                  ,l_location_floor
                                  ,l_location_room);

    l_new_primary_location := SUBSTR(l_location_building || ' ' || l_location_floor || ' ' || l_location_room, 1, 65);

    -- if at least one of entries have changed, update all except title
    IF l_preferred_name <> NVL(p_preferred_name,'null')
    OR l_campus <> NVL(p_campus,'null')
    OR l_location_id <> NVL(l_new_location_id,'null')
    OR l_phone <> NVL(p_phone,'null')
    OR l_fax <> NVL(p_fax,'null')
    OR l_mobile <> NVL(p_mobile,'null')
    OR l_speed_dial <> NVL(p_speed_dial,'null')
    OR l_closed_user_group <> NVL(p_closed_user_group,'null')
    OR l_location_notes <> NVL(p_location_notes,'null')
    OR l_pager <> NVL(p_pager,'null')
    OR l_primary_location <> NVL(l_new_primary_location, 'null') THEN

        UPDATE   ip
        SET      preferred_name = p_preferred_name
                ,primary_campus = p_campus
                ,primary_location = l_new_primary_location
                ,location_id = l_new_location_id
                ,location_notes = p_location_notes
                ,primary_extn = p_phone
                ,primary_fax = p_fax
                ,mobile = p_mobile
                ,speed_dial = p_speed_dial
                ,closed_user_group = p_closed_user_group
                ,pager = p_pager
        WHERE    employee_num = p_id;

    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
	    NULL;
    WHEN OTHERS THEN
	    NULL;
END update_emp_details;

PROCEDURE update_ccr_details
(
    p_id				  IN NUMBER   DEFAULT NULL
   ,p_preferred_name      IN VARCHAR2 DEFAULT NULL
   ,p_gender	          IN VARCHAR2 DEFAULT NULL
   ,p_title		          IN VARCHAR2 DEFAULT NULL
   ,p_campus		      IN VARCHAR2 DEFAULT NULL
   ,p_location_notes      IN VARCHAR2 DEFAULT NULL
   ,p_phone		          IN VARCHAR2 DEFAULT NULL
   ,p_fax		          IN VARCHAR2 DEFAULT NULL
   ,p_mobile		      IN VARCHAR2 DEFAULT NULL
   ,p_speed_dial		  IN VARCHAR2 DEFAULT NULL
   ,p_closed_user_group	  IN VARCHAR2 DEFAULT NULL
   ,p_pager		          IN VARCHAR2 DEFAULT NULL
   ,p_building		      IN VARCHAR2 DEFAULT NULL
   ,p_floor		          IN VARCHAR2 DEFAULT NULL
   ,p_room		          IN VARCHAR2 DEFAULT NULL
)
----------------------------------------------------------------------
--  Purpose: Update CCR client's personal details
--			 Update all if at least one change found otherwise do nothing
--			 Title only updated for female
----------------------------------------------------------------------
IS
    l_preferred_name       ip.preferred_name%TYPE;
    l_gender			   ip.gender%TYPE;
    l_title				   ip.title%TYPE;
   	l_campus			   ip.primary_campus%TYPE;
   	l_location_id    	   ip.location_id%TYPE;
   	l_phone        		   ip.primary_extn%TYPE;
   	l_fax    	 		   ip.primary_fax%TYPE;
   	l_mobile    	 	   ip.mobile%TYPE;
   	l_speed_dial  		   ip.speed_dial%TYPE;
   	l_closed_user_group	   ip.closed_user_group%TYPE;
   	l_pager		 		   ip.pager%TYPE;
    l_location_notes	   ip.location_notes%TYPE;
   	l_primary_location	   ip.primary_location%TYPE;
    l_new_primary_location ip.primary_location%TYPE;
    l_new_location_id	   ip.location_id%TYPE;
BEGIN

    SELECT NVL(preferred_name,'null')
          ,NVL(title,'null')
          ,NVL(primary_campus,'null')
		  ,NVL(location_id, 'null')
		  ,NVL(primary_extn,'null')
		  ,NVL(primary_fax,'null')
		  ,NVL(mobile,'null')
		  ,NVL(speed_dial,'null')
		  ,NVL(closed_user_group,'null')
		  ,NVL(pager,'null')
		  ,NVL(location_notes, 'null')
		  ,NVL(primary_location, 'null')
	INTO   l_preferred_name
          ,l_title
          ,l_campus
		  ,l_location_id
		  ,l_phone
		  ,l_fax
		  ,l_mobile
		  ,l_speed_dial
		  ,l_closed_user_group
		  ,l_pager
		  ,l_location_notes
		  ,l_primary_location
	FROM   ip
	WHERE  ip_num = p_id;

    l_new_location_id := get_location_id(p_campus, p_building, p_floor, p_room);

    l_new_primary_location := locn_common.get_primary_location (l_new_location_id);

    -- if at least one of entries have changed, update all except title
    IF l_preferred_name <> NVL(p_preferred_name,'null')
    OR l_campus <> NVL(p_campus,'null')
    OR l_location_id <> NVL(l_new_location_id,'null')
    OR l_phone <> NVL(p_phone,'null')
    OR l_fax <> NVL(p_fax,'null')
    OR l_mobile <> NVL(p_mobile,'null')
    OR l_speed_dial <> NVL(p_speed_dial,'null')
    OR l_closed_user_group <> NVL(p_closed_user_group,'null')
    OR l_location_notes <> NVL(p_location_notes,'null')
    OR l_pager <> NVL(p_pager,'null')
    OR l_primary_location <> NVL(l_new_primary_location, 'null') THEN

        UPDATE   ip
        SET      preferred_name = p_preferred_name
                ,primary_campus = p_campus
                ,primary_location = l_new_primary_location
                ,location_id = l_new_location_id
                ,location_notes = p_location_notes
                ,primary_extn = p_phone
                ,primary_fax = p_fax
                ,mobile = p_mobile
                ,speed_dial = p_speed_dial
                ,closed_user_group = p_closed_user_group
                ,pager = p_pager
        WHERE  ip_num = p_id;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
	    NULL;
    WHEN OTHERS THEN
	    NULL;

END update_ccr_details;

PROCEDURE update_pers_details
(
    p_user_type           IN VARCHAR2 DEFAULT NULL
   ,p_username            IN VARCHAR2 DEFAULT NULL
   ,p_pers_url	          IN VARCHAR2 DEFAULT NULL

)
----------------------------------------------------------------------
--  Purpose: If record found, update url and/or emergency mobile, otherwise insert a
--			 new record
--  		 If incoming URL starts with 'WWW' then 'http://' is added
----------------------------------------------------------------------
IS
   	l_pers_url	 		  qv_pers_details.url%TYPE;
   	l_pers_url_in		  qv_pers_details.url%TYPE := p_pers_url;

BEGIN

    --url
    SELECT NVL(url,'null')
	INTO   l_pers_url
	FROM   qv_pers_details
	WHERE  username = p_username
	AND    role_cd = p_user_type;

	IF UPPER(SUBSTR(l_pers_url_in,1,3)) = 'WWW' THEN
		l_pers_url_in := 'http://'||l_pers_url_in;
	END IF;

	IF l_pers_url <> NVL(l_pers_url_in,'null') THEN
		UPDATE  qv_pers_details
		SET     url = l_pers_url_in
		WHERE   username = p_username
		AND     role_cd = p_user_type;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
	    INSERT
		INTO    qv_pers_details
				(username
				,role_cd
				,url
				,message
				,qv_update_on)
		VALUES	(p_username
				,p_user_type
				,DECODE (UPPER(SUBSTR(l_pers_url_in,1,3))
				        ,'WWW','http://'||l_pers_url_in
        ,l_pers_url_in)
				,NULL
				,SYSDATE);

    WHEN OTHERS THEN
	    NULL;

END update_pers_details;

PROCEDURE process_update
IS
----------------------------------------------------------------------
--  Purpose: Update personal details
----------------------------------------------------------------------
    l_ip_num			  ip.ip_num%TYPE;

    l_username			  qv_client_computer_account.username%TYPE
						                                := qv_common_id.get_username;
    l_id			      ip.ip_num%TYPE 				:= get_value('p_id');
    l_user_type			  ip.ip_type%TYPE				:= get_value('p_user_type');
    l_preferred_name      ip.preferred_name%TYPE		:= get_value('p_preferred_name');

    l_gender			  ip.gender%TYPE				:= get_value('p_gender');
    l_title				  ip.title%TYPE					:= get_value('p_title');
   	l_campus			  ip.primary_campus%TYPE		:= get_value('p_campus');
   	l_location_notes	  ip.location_notes%TYPE		:= get_value('p_location_notes');

   	l_phone        		  ip.primary_extn%TYPE			:= get_value('p_phone');
   	l_fax    	 		  ip.primary_fax%TYPE			:= get_value('p_fax');
   	l_mobile    	 	  ip.mobile%TYPE				:= get_value('p_mobile');
   	l_speed_dial  		  ip.speed_dial%TYPE			:= get_value('p_speed_dial');
   	l_closed_user_group	  ip.closed_user_group%TYPE		:= get_value('p_closed_user_group');
   	l_pager		 		  ip.pager%TYPE					:= get_value('p_pager');

    l_building			  locn_building.building_id%TYPE:= get_value('p_building');
    l_floor			  	  locn_floor.floor_id%TYPE		:= get_value('p_floor');
    l_room			  	  locn_room.room_id%TYPE		:= get_value('p_room');


   	l_pers_url		      qv_pers_details.url%TYPE		:= get_value('p_pers_url');
    l_pers_message		  qv_pers_details.message%TYPE	:= get_value('p_pers_message');

    E_USER_TYPE_IS_NULL   EXCEPTION;

BEGIN
	-- set p_show_mode to submitted page
    g_arg_names.DELETE;
    g_arg_values.DELETE;
    g_arg_names(1) := 'p_show_mode';
    g_arg_values(1) := emp_personal_profile.C_SUBMITTED;

	--raise exception if null
    IF l_user_type IS NULL OR l_username IS NULL THEN
	    RAISE E_USER_TYPE_IS_NULL;
	END IF;

    IF l_user_type = C_EMP_TYPE THEN
	    update_emp_details(l_id
		                  ,INITCAP(l_preferred_name)
		                  ,l_gender
		                  ,l_title
		                  ,l_campus
		                  ,l_location_notes
		                  ,l_phone
                          ,l_fax
		                  ,l_mobile
                          ,l_speed_dial
		                  ,l_closed_user_group
		                  ,l_pager
						  ,l_building
						  ,l_floor
						  ,l_room);
	ELSE
	    -- get ip num for ccr_client
	    l_ip_num := get_ip_num_for_ccr(l_id);
	    update_ccr_details(l_ip_num
		                  ,INITCAP(l_preferred_name)
		                  ,l_gender
		                  ,l_title
		                  ,l_campus
		                  ,l_location_notes
		                  ,l_phone
		                  ,l_fax
		                  ,l_mobile
		                  ,l_speed_dial
		                  ,l_closed_user_group
		                  ,l_pager
						  ,l_building
						  ,l_floor
						  ,l_room);
	END IF;
    update_pers_details(l_user_type,l_username,l_pers_url);
    COMMIT;
	g_arg_names(2):= 'p_success_ind';
	g_arg_values(2):= 'Y';
	emp_personal_profile_p.show(g_arg_names,g_arg_values);
EXCEPTION
    WHEN E_USER_TYPE_IS_NULL THEN
		g_arg_names(2):= 'p_success_ind';
		g_arg_values(2):= 'N';
		emp_personal_profile_p.show(g_arg_names,g_arg_values);
END process_update;

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------

PROCEDURE show_personal_details
IS
----------------------------------------------------------------------
--  Purpose: Show personal details
----------------------------------------------------------------------
    -- employee number or ccr client id
    l_id  				  NUMBER;

    -- EMP or CCR
    l_user_type           ip.ip_type%TYPE;
    l_ip_num			  ip.ip_num%TYPE;

    l_gender			  ip.gender%TYPE;
    l_title				  ip.title%TYPE;
    l_position_title 	  VARCHAR2(100);

    -- employee other roles and qualification
    l_emp_role            emp.t_emp_role;
    l_role_cd        		 qv_client_role.role_cd%TYPE;

    -- employee organisational hierarchy
    l_hierarchy           emp.t_org_unit_hierarchy;

    -- used to pass to organizational staff list
   	l_primary_location    		  ip.primary_location%TYPE;
   	l_location_id    	  ip.location_id%TYPE;

    l_location_notes	  ip.location_notes%TYPE;
    l_campus			  ip.primary_campus%TYPE;
   	l_phone        		  ip.primary_extn%TYPE;
   	l_fax    	 		  ip.primary_fax%TYPE;
   	l_mobile    	 	  ip.mobile%TYPE;
    l_speed_dial  		  ip.speed_dial%TYPE;
   	l_closed_user_group   ip.closed_user_group%TYPE;
   	l_pager		 		  ip.pager%TYPE;

   	l_pers_url		      qv_pers_details.url%TYPE;
    l_pers_message		  qv_pers_details.message%TYPE;

    l_surname             VARCHAR2(200);
    l_preferred_name      VARCHAR2(200);
    l_img_path		      VARCHAR2(500);
    l_email			      VARCHAR2(100);

    -- address display variables
    l_street_address      VARCHAR2(500) DEFAULT 'Address not available';
    l_town_address        VARCHAR2(500) DEFAULT NULL;
    l_post_code           VARCHAR2(500) DEFAULT NULL;
    l_street_address_post VARCHAR2(500) DEFAULT 'Address not available';
    l_town_address_post   VARCHAR2(500) DEFAULT NULL;
    l_post_code_post      VARCHAR2(500) DEFAULT NULL;

    l_path                VARCHAR2(100) := REPLACE(owa_util.get_owa_service_path,'//','/');
    l_img_display_width   NUMBER := qv_common_reference.get_reference_description ('IMG_DISPLAY_WDTH', 'QV'); -- in pixels

    FUNCTION get_display_ind
    (
        p_id	          IN NUMBER   DEFAULT NULL
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

BEGIN
    -- employee number or client id
    l_id := qv_common_id.get_user_id;

	-- EMP or CCR
	l_user_type := qv_common_id.get_user_type;

	-- employee organisational hierarchy
    l_hierarchy := emp.get_org_unit_hierarchy (l_id, l_user_type);

    -- if user type EMP
	IF l_user_type = C_EMP_TYPE THEN

        -- get location and phone
        get_emp_location_and_phone(l_id
                                  ,l_campus
                                  ,l_primary_location
                                  ,l_location_id
                                  ,l_phone
                                  ,l_fax
                                  ,l_mobile
                                  ,l_speed_dial
                                  ,l_closed_user_group
                                  ,l_pager
                                  ,l_location_notes);

        -- get position title
        l_position_title := emp.get_role(common_client.get_ip_num (l_id, 'EMP'));

        -- get gender and title
        get_emp_gender_title(l_id,l_gender,l_title);

        -- get url and message
        get_emp_url_message (l_id,l_pers_url,l_pers_message);

        l_img_path := qv_common_image.get_img_path(l_id,C_EMP_TYPE);
        l_surname := emp.get_surname(l_id);
        l_preferred_name := emp.get_preferred_name(l_id);
        l_email := emp.get_email(l_id,'Y');

        -- set role code
        l_role_cd := C_EMP_TYPE;

    -- if user type CCR
    ELSE

        -- get ip num for ccr_client
        l_ip_num := get_ip_num_for_ccr(l_id);

        -- get location and phone
        get_ccr_location_and_phone(l_ip_num
                                      ,l_campus
                                      ,l_primary_location
                                      ,l_location_id
                                      ,l_phone
                                      ,l_fax
                                      ,l_mobile
                                      ,l_speed_dial
                                      ,l_closed_user_group
                                      ,l_pager
                                      ,l_location_notes);

        -- get position title and org unit description
        l_position_title := emp.get_role (l_ip_num);

        -- get gender and title
        get_ccr_gender_title(l_ip_num,l_gender,l_title);

        -- get url and message
        get_ccr_url_message (l_ip_num,l_pers_url,l_pers_message);
        l_img_path := qv_common_image.get_img_path(l_id,C_CCR_TYPE);
        l_surname := ccr_common.get_surname(l_id);
        l_preferred_name := ccr_common.get_preferred_name(l_id);

        -- set role code
        l_role_cd := C_EMP_TYPE;

        -- temp exception,
        -- ccr_common.get_email doesn't catch exception and ccr data doesn't exist currently
        BEGIN
            l_email := ccr_common.get_email(l_id,'Y');
        EXCEPTION
            WHEN OTHERS THEN
                l_email := NULL;
        END;
    END IF;

	IF l_campus = 'OC' THEN
	    l_campus := 'Other';
	END IF;

    	-- not to make a link if it's QUT or Gold Pass Holders
    htp.p('<div class="portlet">');
    htp.p('    <div class="vcard">');
    htp.p('        <div class="pers_details_left">');
    htp.p('            <ul class="pers_details">');

    -- Name
    htp.p('                <li>');
    htp.p('                    <h3>Name:</h3>');
    htp.p('                        <p class="fn">');
    htp.p('                            <span class="title">' || l_title || '</span>');
    htp.p('                            <span class="given-name">' || l_preferred_name || '</span>');
    htp.p('                            <span class="family-name">' || l_surname || '</span>');
    htp.p('                        </p>');
    htp.p('                </li>');

	-- ID Number
    htp.p('                <li>');
    htp.p('                    <h3><abbr title="Identification">ID</abbr> Number:</h3>');
    htp.p('                        <p class="id">' || l_id || '</p>');
    htp.p('                </li>');

    -- Position title
    htp.p('                <li>');
    htp.p('                    <h3>Position Title:</h3>');
    htp.p('                        <p class="pos">' || l_position_title || '</p>');
    htp.p('                </li>');

    -- Other roles
    IF (emp.has_other_roles (l_id)) THEN
        -- get all the roles
        l_emp_role := emp.get_other_roles (l_id);

        htp.p('<li>');
        htp.p('<h3>Other Roles:</h3>');
        htp.p('<p class="other-roles">');

        FOR i IN 1..l_emp_role.LAST LOOP
            IF (l_emp_role(i).code IN ('QUAL', 'CDEC', 'MCRT')) THEN
                htp.p('<span class="staff-jp-right">');
            ELSIF (l_emp_role(i).code IN ('FIRE')) THEN
                htp.p('<span class="staff-firewarden-right">');
            END IF;
            htp.p(l_emp_role(i).description || ' (' || l_emp_role(i).availability || ')</span><br />');
        END LOOP;

        htp.p('</p>');
        htp.p('</li>');
    END IF;

	-- Organisational Area
	htp.p('					<li>');
	htp.p('						<h3>Organisational Area:</h3>');
	htp.p('							<p class="org">');

	FOR i IN l_hierarchy.FIRST .. l_hierarchy.LAST LOOP
        htp.p('<a href="'|| l_hierarchy(i).org_unit_search_url ||'" class="popup">'|| l_hierarchy(i).org_unit_description ||'</a><br>');
    END LOOP;

	htp.p('							</p>');
	htp.p('					</li>');

    -- Campus
    htp.p('				   <li>');
    htp.p('                    <h3>Campus:</h3>');
    htp.p('                        <p class="loc">');
    htp.p('                            <span class="type">campus</span>' || l_campus);
    htp.p('                        </p>');
    htp.p('                </li>');

    -- Location
	IF TRIM(l_primary_location) IS NOT NULL THEN
    	htp.p('                <li>');
    	htp.p('                    <h3>Location:</h3>');
    	htp.p('                        <p class="loc">');
    	htp.p('                            <span class="type">primary</span>' || NVL(l_primary_location, '&nbsp;'));
    	htp.p('                        </p>');
    	htp.p('                </li>');
    END IF;

    -- Location notes
    IF TRIM(l_location_notes) IS NOT NULL THEN
        htp.p('                <li>');
        htp.p('                    <h3>Location Notes:</h3>');
        htp.p('                        <p class="loc-notes">' || l_location_notes || '</p>');
        htp.p('                </li>');
    END IF;

    -- Phone number
    htp.p('                <li>');
    htp.p('                    <h3>Phone Number:</h3>');
    htp.p('                        <p class="tel">');
    htp.p('                            <span class="type">work</span>' || NVL(l_phone, '&nbsp;'));
    htp.p('                        </p>');
    htp.p('                </li>');

    -- Fax number
    IF TRIM(l_fax) IS NOT NULL THEN
        htp.p('                <li>');
        htp.p('                    <h3>Fax Number:</h3>');
        htp.p('                        <p class="tel">');
        htp.p('                            <span class="type">fax</span>' || l_fax);
        htp.p('                        </p>');
        htp.p('                </li>');
    END IF;

    -- Mobile number
    IF TRIM(l_mobile) IS NOT NULL THEN
        htp.p('                <li>');
        htp.p('                    <h3>Mobile Number:</h3>');
        htp.p('                        <p class="tel">');
        htp.p('                            <span class="type">cell</span>' || l_mobile);
        htp.p('                        </p>');
        htp.p('                </li>');
    END IF;

    -- Speed dial number
    IF TRIM(l_speed_dial) IS NOT NULL THEN
        htp.p('                <li>');
        htp.p('                    <h3>Speed Dial:</h3>');
        htp.p('                        <p class="tel">');
        htp.p('                            <span class="type">speed dial</span>' || l_speed_dial);
        htp.p('                        </p>');
        htp.p('                </li>');
    END IF;

    -- Close user group number
    IF TRIM(l_closed_user_group) IS NOT NULL THEN
        htp.p('                <li>');
        htp.p('                    <h3>Closed User Group Number:</h3>');
        htp.p('                        <p class="tel">');
        htp.p('                            <span class="type">closed user group</span>' || l_closed_user_group);
        htp.p('                        </p>');
        htp.p('                </li>');
    END IF;

    -- Pager number
    IF TRIM(l_pager) IS NOT NULL THEN
        htp.p('                <li>');
        htp.p('                    <h3>Pager:</h3>');
        htp.p('                        <p class="tel">');
        htp.p('                            <span class="type">pager</span>' || l_pager);
        htp.p('                        </p>');
        htp.p('                </li>');
    END IF;

    -- Email address
    IF TRIM(l_email) IS NOT NULL THEN
    	htp.p('                <li>');
    	htp.p('                    <h3>Email Address:</h3>');
    	htp.p('                        <a href="mailto:'|| l_email ||'">' || l_email || '</a>');
    	htp.p('                </li>');
	END IF;

    -- Website URL
    IF TRIM(l_pers_url) IS NOT NULL THEN
        htp.p('                <li>');
        htp.p('                    <h3>Website:</h3>');
        htp.p('                        <p class="home_page"><a href="' || l_pers_url || '" class="popup">'
                                                        || CASE WHEN LENGTH(l_pers_url) > 60 THEN
                                                               SUBSTR(l_pers_url, 1, 60) || '...'
                                                           ELSE
                                                               l_pers_url
                                                           END
                                                        ||'</a></p>');
        htp.p('                </li>');
    END IF;
    htp.p('            </ul>');
    htp.p('        </div>');
    htp.p('        <div class="pers_details_right">');

    -- Determine which image to display
    IF  get_display_ind(l_id) = 'Y' THEN
        htp.p('            ' || l_img_path);
    ELSE
        htp.p('<img width="'|| l_img_display_width ||'" class="photo" src="'||l_path||'qv_common_image.display?p_id='||l_id||'&p_role_cd='||l_user_type||'" alt="Personal image not released">');
    END IF;

    -- Drop down and javascript to provide option to hide or show image
    htp.p('            <form id="stu_pers_details_form" action="" method="post">');
    htp.p('                <ul>');
    htp.p('                    <li><label for="release_photo">Make my photo public within QUT:</label> ');
    htp.p('                        <select name="jump" id="release_photo" onchange="nav(this.form);">');

    -- Option to hide image
    htp.p('                            <option value="/'||qv_common_reference.get_reference_description('DAD')||'/emp_personal_profile_p.show'
	                                            ||'?p_arg_names=p_show_mode&amp;p_arg_values=SWITCH'
				                                ||'&amp;p_arg_names=p_id&amp;p_arg_values='||l_id
				                                ||'&amp;p_arg_names=p_photo_flag&amp;p_arg_values=N'
				                                ||'&amp;p_arg_names=p_role_cd&amp;p_arg_values='||l_user_type ||'" '
                                       ||REPLACE(REPLACE(get_display_ind(l_id), 'N', 'SELECTED'),'Y','')
                                       ||'>No</option>');

    -- Option to display image
    htp.p('                            <option value="/'||qv_common_reference.get_reference_description('DAD')||'/emp_personal_profile_p.show'
	                                            ||'?p_arg_names=p_show_mode&amp;p_arg_values=SWITCH'
				                                ||'&amp;p_arg_names=p_id&amp;p_arg_values='||l_id
				                                ||'&amp;p_arg_names=p_photo_flag&amp;p_arg_values=Y'
				                                ||'&amp;p_arg_names=p_role_cd&amp;p_arg_values='||l_user_type ||'" '
                                       ||REPLACE(REPLACE(get_display_ind(l_id), 'Y', 'SELECTED'),'N','')
                                       ||'>Yes</option>');

    htp.p('                        </select>');
    htp.p('                    </li>');
    htp.p('                    <li><a href="srch_common_people_p.show?p_arg_names=p_id&amp;p_arg_values='||l_id||'&amp;p_arg_names=p_ip_type&amp;p_arg_values='||l_user_type||'&amp;p_arg_names=p_show_mode&amp;p_arg_values=vCard" class="vcard">Download my vCard <span>(download vCard file)</span></a></li>');
    htp.p('                </ul>');
    htp.p('            </form>');
    htp.p('        </div>');
    htp.p('        <div style="clear:both"></div>');
    htp.p('    </div>');
    htp.p('    <ul class="linklist_paddingtop">');
    htp.p('        <li><a href="emp_personal_profile_p.show?p_arg_names=p_original_ind&p_arg_values=Y">'
                        || 'Update my contact details</a></li>');
    -- Other roles link
    htp.p('		  <li><a href="'||qv_common_links.get_reference_link('STAFFCONNECT_UPDATE_ROLES')||'" class="popup">Update my Justice of the Peace role details</a></li>');

    htp.p('    </ul>');
    htp.p('</div>');

END show_personal_details;

PROCEDURE show_details_form
(
     p_arg_names 	  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values 	  IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Show personal details update form
--			 If invalid entry found display with message
----------------------------------------------------------------------
IS
	l_id			      NUMBER;
	l_ip_num		 	  ip.ip_num%TYPE;
	l_user_type      	  ip.ip_type%TYPE;
    l_username            qv_pers_details.username%TYPE := qv_common_id.get_username;
	l_full_preferred_name VARCHAR2(255);
	l_preferred_name 	  ip.preferred_name%TYPE;

	l_gender		 	  ip.gender%TYPE;
	l_title			 	  ip.title%TYPE;
	l_campus		 	  ip.primary_campus%TYPE;

    l_phone       	 	  ip.primary_extn%TYPE;
    l_fax    	 	 	  ip.primary_fax%TYPE;
    l_mobile    	 	  ip.mobile%TYPE;
    l_speed_dial  	 	  ip.speed_dial%TYPE;
    l_closed_user_group	  ip.closed_user_group%TYPE;
    l_pager  	     	  ip.pager%TYPE;

    l_pers_url		      qv_pers_details.url%TYPE;
	l_pers_message		  qv_pers_details.message%TYPE;

	l_primary_location 	  ip.primary_location%TYPE     DEFAULT NULL;
	l_location_id   	  ip.location_id%TYPE 		   DEFAULT NULL;
	l_location_campus	  locn_site.name%TYPE   	   DEFAULT NULL;
	l_location_building	  locn_building.name%TYPE 	   DEFAULT NULL;
	l_location_floor	  locn_floor.name%TYPE 		   DEFAULT NULL;
	l_location_room		  locn_room.room_id%TYPE	   DEFAULT NULL;
	l_location_notes	  ip.location_notes%TYPE	   DEFAULT NULL;

	l_kind_of_campus VARCHAR2(20);
    l_campus_code    VARCHAR2(20);
    l_privacy_settings_url qv_reference_link.reference_link%TYPE := qv_common_links.get_reference_link(p_reference_cd => 'PRIVACY_SETTINGS_URL');

    -- Campus cursor
    CURSOR c_campus
	IS
    SELECT *
		FROM 	 locn_site ls
		WHERE	 ls.active_ind = 'Y'
		ORDER BY name;

BEGIN

    g_arg_names.DELETE;
    g_arg_values.DELETE;
    g_arg_names  := p_arg_names;
    g_arg_values := p_arg_values;
    common_utils.normalize(g_arg_names, g_arg_values);


	-- if form is displayed first time, get data from database
	IF NVL(get_value('p_original_ind'), 'Y') = 'Y' THEN

	    l_id := qv_common_id.get_user_id;
        l_user_type := qv_common_id.get_user_type;

	    -- if EMP
		IF l_user_type = C_EMP_TYPE THEN

	        l_full_preferred_name := emp.get_full_preferred_name(l_id);
		    l_preferred_name := emp.get_preferred_name(l_id);
		    get_emp_gender_title(l_id,l_gender,l_title);
			get_emp_url_message (l_id,l_pers_url,l_pers_message);
		    get_emp_location_and_phone(l_id,l_campus,l_primary_location,l_location_id
									  ,l_phone,l_fax,l_mobile,l_speed_dial, l_closed_user_group
									  ,l_pager,l_location_notes);
        -- if CCR
		ELSE
	        l_full_preferred_name := ccr_common.get_full_preferred_name(l_id);
		    l_preferred_name := ccr_common.get_preferred_name(l_id);
		    l_ip_num := get_ip_num_for_ccr(l_id);
		    get_ccr_gender_title(l_ip_num,l_gender,l_title);
			get_ccr_url_message (l_id,l_pers_url,l_pers_message);
		    get_ccr_location_and_phone(l_ip_num,l_campus,l_primary_location,l_location_id
								      ,l_phone,l_fax,l_mobile,l_speed_dial, l_closed_user_group
									  ,l_pager, l_location_notes);
		END IF;


	-- if form is re-displayed, get what was entered.
	ELSE
        l_id				    := get_value('p_id');
        l_user_type				:= get_value('p_user_type');
        l_full_preferred_name   := get_value('p_full_preferred_name');
        l_gender				:= get_value('p_gender');
        l_title				    := get_value('p_title');
        l_preferred_name	  	:= get_value('p_preferred_name');
        l_campus    		  	:= get_value('p_campus');
        l_phone        		  	:= get_value('p_phone');
        l_fax    	 		  	:= get_value('p_fax');
        l_mobile    	 	  	:= get_value('p_mobile');
        l_speed_dial  		  	:= get_value('p_speed_dial');
        l_closed_user_group	  	:= get_value('p_closed_user_group');
        l_pager		 		  	:= get_value('p_pager');
        l_pers_url			    := get_value('p_pers_url');
        l_pers_message		  	:= get_value('p_pers_message');
        l_location_notes		:= get_value('p_location_notes');
        l_location_building		:= get_value('p_building');
        l_location_floor		:= get_value('p_floor');
        l_location_room			:= get_value('p_room');

		-- get id from seperate location id's
		l_location_id := get_location_id
					  	 (
							 l_campus
							 ,l_location_building
							 ,l_location_floor
							 ,l_location_room
						 );
	END IF;

	-- get location names ie the values in the drop down's from the location id
	--   even on refresh we do this as the values passed as parameters are the id's
	--   we need the text equivalent so we can match it against the drop downs
	locn_common.get_location_name
	(
		l_location_id
		,l_location_campus
		,l_location_building
		,l_location_floor
		,l_location_room
	);

    htp.p('<script type="text/javascript">');
    htp.p('<!-- // hide from older browsers');
    htp.p('addLoadEvent(function(){CampusOnSelect(true);});');
    htp.p('
      $(document).ready(function() {
        $("#staff_details_form").validate({
        	errorPlacement: function(error, element) {
        		var foundPlacement = false;

        		// place error after help tips if there are any
				if ($(element).nextAll("span")) {
					if (element.nextAll("span").hasClass("info_note")) {
						error.insertAfter(element.nextAll(".info_note"));
						foundPlacement = true;
					}
				}

				if (!foundPlacement) { // only use this if a custom placement hasn''t already been set
					error.insertAfter(element); //default placement
				}
        	}
        });
      });
    ');
    htp.p('//-->');
    htp.p('</script>');

    locn_common.get_dynamic_javascript();

    -- Page heading
    htp.p('<h1>Update contact details</h1>');

    -- Required fields
    htp.p('<p><strong>Required fields are indicated by an asterisk (*).</strong></p>');

    -- Private data warning message
    htp.p('<p class="important">Do not enter private data in the fields below. Information will be displayed to staff and students. If you have an academic profile, contact details including your phone number and email address will be automatically displayed on your public profile. Refer to <a href="'|| l_privacy_settings_url ||'" target="_blank">privacy settings for academic profiles</a> for more details.</p>');

    htp.p('<form name="details_form" id="staff_details_form" method="get" action="emp_personal_profile_p.process_details_form" class="qv_form">');

	htp.p('<input type="hidden" name="p_action" value="">');
	htp.p('<input id="p_master_campus_id" type="hidden" name="p_master_campus_id">');
	-- Store location details, so javascript can use them (as we need to set values depending on these values)
	htp.p('<input id="p_building_copy" type="hidden" name="p_building_copy" value="' || l_location_building || '">');
	htp.p('<input id="p_floor_copy" type="hidden" name="p_floor_copy" value="'|| l_location_floor ||'">');
	htp.p('<input id="p_room_copy" type="hidden" name="p_room_copy" value="'|| l_location_room ||'">');

    -- Location details
	htp.p('<fieldset><legend>Location details:</legend>');
	htp.p('<ul>');

    -- New campus code
	htp.p('<li><label for="p_campus">Campus *:</label>');
	htp.p('<select id="p_campus" onChange="CampusOnSelect(false);" name="p_campus">');

	FOR r_campus IN c_campus LOOP

		l_kind_of_campus := r_campus.name;
		l_campus_code := r_campus.site_id;

		htp.p('<option value="'|| l_campus_code ||'" '
		|| CASE l_campus
				WHEN l_campus_code THEN
                 ' selected '
				END
		||  '>'|| l_kind_of_campus ||'</option>');

	END LOOP;

  htp.p('</select>');
  htp.p('</li>');
  htp.p('<li><label for="p_building">Building:</label>');
  htp.p('<select id="p_building" onChange="LoadFloors(this, false);" name="p_building" disabled>');
	htp.p('<option value="" selected="selected">Select Campus</option>');
  htp.p('</select>');
  htp.p('</li>');
  htp.p('<li><label for="p_floor">Floor:</label>');
  htp.p('<select id="p_floor" onChange="LoadRooms(this, false);" name="p_floor" disabled>');
	htp.p('<option value="" selected="selected">Select Campus</option>');
  htp.p('</select>');
  htp.p('</li>');
  htp.p('<li><label for="p_room">Room:</label>');
  htp.p('<select id="p_room" name="p_room" disabled>');
	htp.p('<option value="" selected="selected">Select Campus</option>');
	htp.p('</select>');
  htp.p('</li>');
  htp.p('<li><label for="p_location_notes">Location notes:</label>');
  htp.p('<input type="text" id="p_location_notes" name="p_location_notes" value="'|| l_location_notes||'" maxlength="30" size="30">');
  htp.p('</li>');
  htp.p('</ul>');
  htp.p('</fieldset>');

  -- Contact details
  htp.p('<fieldset><legend>Contact details:</legend>');
  htp.p('<ul>');
  htp.p('<li><label for="p_phone">Phone number *:</label>');
  htp.p('<input type="text" id="p_phone" name="p_phone" value="'||l_phone||'" class="required phoneGEN" maxlength="12" minlength="8" size="15">');
  --htp.p('<span class="info_note">e.g. 3138 1000</span>');

  htp.p('<span>');
  htp.p('<span class="tool">');
  htp.p('<img class="tip_pic" width="16px" height="16px" alt="Help tip" src="/images/qut/icons/qv_icon_help.gif"></img>');
  htp.p('<span class="tool_tip">e.g. 3138 1000');
  htp.p('<span class="tool_tip_arrow">');
  htp.p('</span>');
  htp.p('</span>');
  htp.p('</span>');
  htp.p('</span>');

  htp.p('</li>');
  htp.p('<li><label for="p_fax">Fax number:</label>');
  htp.p('<input type="text" id="p_fax" name="p_fax" value="'||l_fax||'" class="phoneGEN" maxlength="12" minlength="8" size="15">');
  htp.p('</li>');
  htp.p('<li><label for="p_mobile">Mobile number:</label>');
  htp.p('<input type="text" id="p_mobile" name="p_mobile" value="'||l_mobile||'" class="phoneGEN" maxlength="12" minlength="8" size="15">');
 -- htp.p('<span class="info_note">e.g. 0400 100 200</span>');

  htp.p('<span>');
  htp.p('<span class="tool">');
  htp.p('<img class="tip_pic" width="16px" height="16px" alt="Help tip" src="/images/qut/icons/qv_icon_help.gif"></img>');
  htp.p('<span class="tool_tip">e.g. 0400 100 200');
  htp.p('<span class="tool_tip_arrow">');
  htp.p('</span>');
  htp.p('</span>');
  htp.p('</span>');
  htp.p('</span>');

  htp.p('</li>');
  htp.p('<li><label for="p_speed_dial">Speed dial:</label>');
  htp.p('<input type="text" id="p_speed_dial" name="p_speed_dial" value="'||l_speed_dial||'" class="speeddialQUT" maxlength="10" size="15">');
  --htp.p('<span class="info_note">e.g. #61234</span>');

  htp.p('<span>');
  htp.p('<span class="tool">');
  htp.p('<img class="tip_pic" width="16px" height="16px" alt="Help tip" src="/images/qut/icons/qv_icon_help.gif"></img>');
  htp.p('<span class="tool_tip">e.g. #61234');
  htp.p('<span class="tool_tip_arrow">');
  htp.p('</span>');
  htp.p('</span>');
  htp.p('</span>');
  htp.p('</span>');

  htp.p('</li>');
  htp.p('</ul>');
  htp.p('</fieldset>');

  -- Update other details information message
  htp.p('<p class="info">To update your private address, personal telephone details and emergency mobile phone number, select the "Personal Contacts" option from the My HR / Personal Details menu in <a href="'||qv_common_links.get_reference_link('STAFFCONNECT_UPDATE_CONTACT')||'">StaffConnect</a>.</p>');

  -- Website details
  htp.p('<fieldset><legend>Website:</legend>');
  htp.p('<ul>');
  htp.p('<li><label for="p_pers_url">URL:</label>');
  htp.p('<input type="text" id="p_pers_url" name="p_pers_url" value="'||l_pers_url||'" class="defaultInvalid url" maxlength="200" size="50">');
  htp.p('</li>');
  htp.p('</ul>');
  htp.p('</fieldset>');

  htp.p('<div class="formbuttons">');
  htp.p('<input type="submit" value="SUBMIT">');
	htp.p('<input type="reset" value="RESET FORM" onClick="location.href=''emp_personal_profile_p.show?p_arg_names=p_original_ind&p_arg_values=Y''">');
  htp.p('</div>');

  -- temporary until textarea problem with long text solved
  htp.p('<input type="hidden" name="p_pers_message" value="">');
  htp.p('<input type="hidden" name="p_arg_names" value="p_id">');
  htp.p('<input type="hidden" name="p_arg_values" value="'||l_id||'">');
  htp.p('<input type="hidden" name="p_arg_names" value="p_user_type">');
  htp.p('<input type="hidden" name="p_arg_values" value="'||l_user_type||'">');
  htp.p('<input type="hidden" name="p_arg_names" value="p_gender">');
  htp.p('<input type="hidden" name="p_arg_values" value="'||l_gender||'">');
  htp.p('<input type="hidden" name="p_arg_names" value="p_preferred_name">');
  htp.p('<input type="hidden" name="p_arg_values" value="'||l_preferred_name||'">');
  htp.p('<input type="hidden" name="p_arg_names" value="p_original_ind">');
  htp.p('<input type="hidden" name="p_arg_values" value="N">');

  htp.p('</form>');

END show_details_form;

PROCEDURE validate_details_form
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Validate details form and call success page if all entries
--			 are valid otherwise re-display a form with message
----------------------------------------------------------------------
IS
	l_url_invalid_ind		  VARCHAR2(1);
BEGIN
    g_arg_names.DELETE;
    g_arg_values.DELETE;
    g_arg_names  := p_arg_names;
    g_arg_values := p_arg_values;
    -- prepare arguments and values
    common_utils.normalize(g_arg_names, g_arg_values);

    -- check validity of url
	validate_url(get_value('p_pers_url'),l_url_invalid_ind);
	g_arg_names (p_arg_names.COUNT+1) := 'p_url_invalid_ind';
	g_arg_values(p_arg_names.COUNT+1) :=   l_url_invalid_ind;

	IF l_url_invalid_ind = 'Y' THEN
	    emp_personal_profile_p.show(g_arg_names,g_arg_values);
	ELSE
	    process_update;
	END IF;

END validate_details_form;

PROCEDURE show_success
(
    p_success_ind   IN VARCHAR2    DEFAULT NULL
)
IS
----------------------------------------------------------------------
--  Purpose: Show success or error message
----------------------------------------------------------------------
BEGIN
    htp.p('<div>');
	IF p_success_ind = 'Y' THEN
	    htp.p('<p>Thank you. Your contact details have been successfully submitted.</p>');
	ELSE
	    htp.p('<p>There has been an error producing this page.</p>');
	END IF;
	htp.p('</div>');
END show_success;

PROCEDURE show_help
(
    p_help_mode		IN VARCHAR2    DEFAULT NULL
)
IS
----------------------------------------------------------------------
--  Purpose: Show personal details specific help
----------------------------------------------------------------------
BEGIN
	-- DO NOT REMOVE
    htp.p('<div>');
	htp.p('<p>This page displays your contact details as stored in QUT''s corporate systems.');
	htp.p('<p>You may change your preferred name and your contact details, or nominate your personal homepage, by clicking on the ''Update my contact details'' link at the bottom of the page. ');
	htp.p('These details, as well as your position title may also be changed by the Phone Book Administrator for your area. This information is available to other staff and students via the '|| g_staff_intranet_name ||' Staff Search.');
	htp.p('<p>You may choose to release your id card image to other staff and students if you wish. To turn image display on or off, simply click the ''Yes'' or ''No'' link below your image.');

	-- DO NOT REMOVE
    htp.p('</div>');
END show_help;

END emp_personal_profile;
/
