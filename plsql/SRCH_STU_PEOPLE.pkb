create or replace
PACKAGE BODY srch_stu_people
/**
* Process search to display results and exception messages
* Show advanced search form
* Increment page hits
* Display People search specific help
* Provides navigation structure for peopel search.
* @version 1.0.0
*/
IS
----------------------------------------------------------------------
--  Modification  History
--  Date          Author           Description
--  -----------  ------------------------------------------------------
--  03-SEP-2002   S Jeong          Created
--  22-SEP-2002   S Jeong          Logic in IF statement in get_nav_sturct
--                                 swaped.
--  18-Jul-2006  S.Jeong           10g Upgrade Modification
--                                 Removed qv_common_style.apply
--                                 Replaced qv_common.page_hits with qv_page_hits_increment.
--                                 <br><br> inserted after RESET button in advance form to cater for
--                                 Mozilla firefox
--  01-NOV-2006 S.Jeong            Modified get_stu_cnt to return right numbers for different cases.
--  02-Nov-2006 E.Wood             Added criteria in SQL to stop print_flag = 'N' Displaying in searches
--  06-Aug-2007  C Wong           IAM Upgrade
--  24-Oct-2008 P.Totagiancaspro   created get_nav_path and reverse IAM changes, QV 1.5 changes
--  18-Nov-2008  C Wong           Fix generate_array: new parameters passed in but never assigned
--  13-JAN-2009  D.Jack           Changed the exception printed text to search results
--  14-May-2009  C.Wong           Replace org_units (deprecated) with emp_org_unit
--  29-Jul-2009  D.Jack           SAMS Upgrade
--  25-Jan-2010  Tony Le          Add 'search type' on student's advanced search screen Staff Search
--  01-Mar-2010  Tony Le          Bring new staff UI across
--  06-04-2010   Tony Le          Fix search people and search staff for staff with student info access to match the first name
--                                as well the surname. Changes made in get_emp_cnt mainly improving the search
--                                cursors to match on first, second and third name etc.
--  09-11-2010   Tony Le          Fix navigation page for JP listing
--  08-02-2010   L.Dorman         Added help text for JP search results page to show_help (different for staff/students)
----------------------------------------------------------------------
--------------------------------------------
--            LOCAL CONSTANTS
--------------------------------------------
    -- page hit title
	C_HIT_STU	      			  CONSTANT VARCHAR2(100) := ' (student access)';
	C_HIT_GEN_STAFF  			  CONSTANT VARCHAR2(100) := ' (general staff access)';
	C_HIT_AUT_STAFF  			  CONSTANT VARCHAR2(100) := ' (authorized staff access)';

	-- student access advanced search hit
	C_HIT_STU_SRCH_STU_PEOPLE	  CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE||C_HIT_STU;
	-- general staff access advanced search hit
	C_HIT_GEN_SRCH_STU_PEOPLE	  CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE||C_HIT_GEN_STAFF;
	-- authorizeds staff access advanced search hit
	C_HIT_AUT_SRCH_STU_PEOPLE	  CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE||C_HIT_AUT_STAFF;

	-- student access search results hit
	C_HIT_STU_SRCH_STU_PEOPLE_2   CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE_2||C_HIT_STU;
	-- general staff access search results hit
	C_HIT_GEN_SRCH_STU_PEOPLE_2   CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE_2||C_HIT_GEN_STAFF;
	-- authorizeds staff access search results hit
	C_HIT_AUT_SRCH_STU_PEOPLE_2	  CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE_2||C_HIT_AUT_STAFF;

	-- student access search contact details hit
	C_HIT_STU_SRCH_STU_PEOPLE_3   CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE_3||C_HIT_STU;
	-- general staff access contact details hit
	C_HIT_GEN_SRCH_STU_PEOPLE_3   CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE_3||C_HIT_GEN_STAFF;
	-- authorizeds staff access contact details hit
	C_HIT_AUT_SRCH_STU_PEOPLE_3	  CONSTANT VARCHAR2(100) := C_SRCH_STU_PEOPLE_3||C_HIT_AUT_STAFF;

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

-- NIL

--------------------------------------------
--            LOCAL FUNCTIONS
--------------------------------------------

FUNCTION get_emp_cnt
(
    p_first_name    IN VARCHAR2    DEFAULT NULL
   ,p_surname		IN VARCHAR2    DEFAULT NULL
   ,p_org_unit_code	IN VARCHAR2    DEFAULT NULL
   ,p_search_type   IN VARCHAR2    DEFAULT NULL
)
    RETURN NUMBER
IS
----------------------------------------------------------------------
--  Purpose: Count a number of people who matches parameters
--			 Return counts
----------------------------------------------------------------------
    -- contains number of employee
	l_emp_cnt      NUMBER := 0;

BEGIN
	IF p_search_type IS NULL THEN

        BEGIN
             SELECT COUNT(*)
             INTO	l_emp_cnt
             FROM   ip i
             WHERE  (UPPER(i.surname) = UPPER(p_surname))
             AND    i.ip_status = 'cur'
             AND    i.print_flag = 'Y';
        EXCEPTION
                 WHEN OTHERS THEN
                      NULL;
        END;

	ELSIF p_search_type = 'EXACT' THEN
	    IF p_first_name IS NOT NULL AND p_surname IS NOT NULL THEN
		    SELECT COUNT(*)
			INTO   l_emp_cnt
		   	FROM   ip i
		    WHERE  ((UPPER(i.preferred_name) = UPPER(p_first_name)
		          OR UPPER(i.first_name) = UPPER(p_first_name)
		          OR UPPER(i.second_name) = UPPER(p_first_name)
		          OR UPPER(i.third_name) = UPPER(p_first_name))
		          AND UPPER(i.surname) = UPPER(p_surname))
		  	AND    i.owner_org_code LIKE p_org_unit_code||'%'
		   	AND    i.ip_status = 'cur'
            AND    i.print_flag = 'Y';
		ELSE
		    SELECT COUNT(*)
			INTO   l_emp_cnt
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
            AND    i.print_flag = 'Y';
		END IF;

	ELSIF p_search_type = 'LIKE' THEN

        BEGIN
            SELECT COUNT(*)
            INTO   l_emp_cnt
            FROM   ip i
            WHERE  ((( UPPER(i.preferred_name) LIKE UPPER(p_first_name)||'%' OR
                       UPPER(i.first_name) LIKE UPPER(p_first_name)||'%' OR
                       UPPER(i.second_name) LIKE UPPER(p_first_name)||'%' OR
                       UPPER(i.third_name) LIKE UPPER(p_first_name)||'%')
                       AND UPPER(i.surname) LIKE UPPER(p_surname||'%'))
                    OR ( UPPER(i.surname)      LIKE DECODE(UPPER(p_first_name),'',UPPER(p_surname)||'%',NULL)
                    OR UPPER(i.preferred_name) LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL)
                    OR UPPER(i.first_name) LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL)
                    OR UPPER(i.second_name) LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL)
                    OR UPPER(i.third_name) LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL)
                       )
                   )
            AND    i.owner_org_code LIKE p_org_unit_code||'%'
            AND    i.ip_status = 'cur'
            AND    i.print_flag = 'Y';
        EXCEPTION
                 WHEN OTHERS THEN
                      NULL;
        END;
	END IF;

    RETURN l_emp_cnt;
END get_emp_cnt;


--------------------------------------------
--            LOCAL PROCEDURES
--------------------------------------------

PROCEDURE get_emp_id
(
    p_first_name    IN  VARCHAR2    DEFAULT NULL
   ,p_surname		IN  VARCHAR2    DEFAULT NULL
   ,p_org_unit_code	IN  VARCHAR2    DEFAULT NULL
   ,p_search_type   IN  VARCHAR2    DEFAULT NULL
   ,p_id			OUT VARCHAR2
   ,p_ip_type		OUT VARCHAR2
)
IS
----------------------------------------------------------------------
--  Purpose: Pass employee number out if found otherwise pass ip
--			 number out
----------------------------------------------------------------------
BEGIN

	IF p_search_type IS NULL THEN

    		    BEGIN
    				SELECT i.employee_num
    				INTO   p_id
    				FROM   ip i
   				    WHERE  (UPPER(i.surname) = UPPER(p_surname))
    				AND    i.ip_status = 'cur'
                    AND    i.print_flag = 'Y';
    			EXCEPTION
    			    WHEN OTHERS THEN
    				    p_id := NULL;
    			END;

				-- if CCR person(no employee number) then return ip number
				IF p_id IS NULL THEN

	    		    BEGIN
	    				SELECT i.ip_num
						      ,i.ip_type
	    				INTO   p_id
						      ,p_ip_type
	    				FROM   ip i
    				    WHERE  (UPPER(i.surname) = UPPER(p_surname))
	    				AND    i.ip_status = 'cur'
                        AND    i.print_flag = 'Y';
	    			EXCEPTION
	    			    WHEN OTHERS THEN
	    				    p_id      := NULL;
	    					p_ip_type := NULL;
	    			END;
				END IF;

	ELSIF p_search_type = 'EXACT' THEN

                BEGIN
                	SELECT i.employee_num
                	INTO   p_id
                	FROM   ip i
                	WHERE  (
                		       (( UPPER(i.preferred_name) = UPPER(p_first_name) OR
								  UPPER(SUBSTR(i.first_name||' '||i.second_name||' '||i.third_name,1,length(p_first_name))) = UPPER(p_first_name)
								)
                				AND UPPER(i.surname) = UPPER(p_surname)
                			   )
                		    OR ( UPPER(i.surname)        = DECODE(UPPER(p_first_name),'',UPPER(p_surname),NULL))
                			OR ( UPPER(i.preferred_name) = DECODE(UPPER(p_surname),'',UPPER(p_first_name),NULL)
							   	 OR
								 UPPER(SUBSTR(i.first_name||' '||i.second_name||' '||i.third_name,1,length(p_first_name)))
								                         = DECODE(UPPER(p_surname),'',UPPER(p_first_name),NULL)
							   )
                		   )
                	AND    i.owner_org_code LIKE p_org_unit_code||'%'
                	AND    i.ip_status = 'cur'
                    AND    i.print_flag = 'Y';
    			EXCEPTION
    			    WHEN OTHERS THEN
    				    p_id := NULL;
    			END;

				-- if CCR person(no employee number) then return ip number
				IF p_id IS NULL THEN

	    		    BEGIN
	    				SELECT i.ip_num
							  ,i.ip_type
	    				INTO   p_id
						      ,p_ip_type
	    				FROM   ip i
                    	WHERE  (
                    		       (( UPPER(i.preferred_name) = UPPER(p_first_name) OR
    								  UPPER(SUBSTR(i.first_name||' '||i.second_name||' '||i.third_name,1,length(p_first_name))) = UPPER(p_first_name)
    								)
                    				AND UPPER(i.surname) = UPPER(p_surname)
                    			   )
                    		    OR ( UPPER(i.surname)        = DECODE(UPPER(p_first_name),'',UPPER(p_surname),NULL))
                    			OR ( UPPER(i.preferred_name) = DECODE(UPPER(p_surname),'',UPPER(p_first_name),NULL)
    							   	 OR
    								 UPPER(SUBSTR(i.first_name||' '||i.second_name||' '||i.third_name,1,length(p_first_name)))
    								                         = DECODE(UPPER(p_surname),'',UPPER(p_first_name),NULL)
    							   )
                    		   )
	    				AND    i.ip_status = 'cur'
                        AND    i.print_flag = 'Y';
	    			EXCEPTION
	    			    WHEN OTHERS THEN
	    				    p_id      := NULL;
	    					p_ip_type := NULL;
	    			END;
				END IF;


	ELSIF p_search_type = 'LIKE' THEN

		  		BEGIN
            	    SELECT i.employee_num
            	    INTO   p_id
                   	FROM   ip i
                   	WHERE  (
                   		       (( UPPER(i.preferred_name) LIKE UPPER(p_first_name)||'%' OR
							      UPPER(SUBSTR(i.first_name||' '||i.second_name||' '||i.third_name,1,length(p_first_name))) LIKE UPPER(p_first_name)||'%'
								)
                   				AND UPPER(i.surname) LIKE UPPER(p_surname||'%')
                   			   )
                   		    OR ( UPPER(i.surname)          LIKE DECODE(UPPER(p_first_name),'',UPPER(p_surname)||'%',NULL))
                   			OR ( UPPER(i.preferred_name)   LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL)
							   	 OR
                   			     UPPER(SUBSTR(i.first_name||' '||i.second_name||' '||i.third_name,1,length(p_first_name)))
								                           LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL)
							   )
                   		   )
                	AND    i.owner_org_code LIKE p_org_unit_code||'%'
                   	AND    i.ip_status = 'cur'
                    AND    i.print_flag = 'Y';
    			EXCEPTION
    			    WHEN OTHERS THEN
    				    p_id := NULL;
    			END;

				-- if CCR person(no employee number) then return ip number
				IF p_id IS NULL THEN

	    		    BEGIN
	    				SELECT i.ip_num
							  ,i.ip_type
	    				INTO   p_id
						      ,p_ip_type
	    				FROM   ip i
                       	WHERE  (
                       		       (( UPPER(i.preferred_name) LIKE UPPER(p_first_name)||'%' OR
    							      UPPER(SUBSTR(i.first_name||' '||i.second_name||' '||i.third_name,1,length(p_first_name))) LIKE UPPER(p_first_name)||'%'
    								)
                       				AND UPPER(i.surname) LIKE UPPER(p_surname||'%')
                       			   )
                       		    OR ( UPPER(i.surname)          LIKE DECODE(UPPER(p_first_name),'',UPPER(p_surname)||'%',NULL))
                       			OR ( UPPER(i.preferred_name)   LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL)
    							   	 OR
                       			     UPPER(SUBSTR(i.first_name||' '||i.second_name||' '||i.third_name,1,length(p_first_name)))
    								                           LIKE DECODE(UPPER(p_surname),'',UPPER(p_first_name)||'%',NULL)
    							   )
                       		   )
	    				AND    i.ip_status = 'cur'
                        AND    i.print_flag = 'Y';
	    			EXCEPTION
	    			    WHEN OTHERS THEN
	    				    p_id      := NULL;
	    					p_ip_type := NULL;
	    			END;
				END IF;
	END IF; -- p_search_type is null...

END get_emp_id;


--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------

FUNCTION get_nav_struct
(
    p_show_mode    IN VARCHAR2    DEFAULT NULL
   ,p_from         IN VARCHAR2    DEFAULT NULL
   ,p_list         IN VARCHAR2    DEFAULT NULL
)
    RETURN owa.vc_arr
IS
----------------------------------------------------------------------
--  Purpose: Build navigations structure
----------------------------------------------------------------------
	 p_nav_names  owa.vc_arr DEFAULT empty_vc_arr;

BEGIN
	-- if search started from submitted a form form a portelt
	IF p_from = C_FROM_ADVANCED THEN

	    -- nav path will start from pp>people search
		p_nav_names(1) := C_SRCH_STU_PEOPLE;

		-- if to show search results
		IF p_show_mode = C_SRCH_STU_PEOPLE_2 THEN
			p_nav_names(2) := C_SRCH_STU_PEOPLE_2;

        -- navigation name for JP search
        ELSIF p_show_mode = C_SRCH_JP_RESULTS THEN
            IF p_list = 'Y' THEN
                -- navigation for staff details page
                p_nav_names(2) := C_SRCH_STU_PEOPLE_2;
                p_nav_names(3) := C_SRCH_JP_RESULTS;
            ELSE
                -- navigation for search results page
                p_nav_names(2) := C_SRCH_JP_RESULTS;
            END IF;
            
		-- if to show contact details
		ELSE
		    -- if list of people displayed previously
	        IF p_list = 'Y' THEN
	 	        p_nav_names(2) := C_SRCH_STU_PEOPLE_2;
	 	        p_nav_names(3) := C_SRCH_STU_PEOPLE_3;
		    ELSE
		        p_nav_names(2) := C_SRCH_STU_PEOPLE_3;
		    END IF;
		END IF;

	-- if advanced search link is clicked on a portlet
	ELSE
	    -- if to show advanced search (people)
	    IF p_show_mode = C_SRCH_STU_PEOPLE OR p_show_mode IS NULL THEN
			p_nav_names(1) := C_SRCH_STU_PEOPLE;

	    -- if to show search results
		ELSIF p_show_mode = C_SRCH_STU_PEOPLE_2 THEN
			p_nav_names(1) := C_SRCH_STU_PEOPLE_2;

        -- navigation name for JP search
        ELSIF p_show_mode = C_SRCH_JP_RESULTS THEN
            IF p_list = 'Y' THEN
                -- navigation for staff details page
                p_nav_names(1) := C_SRCH_JP_RESULTS;
                p_nav_names(2) := C_SRCH_STU_PEOPLE_3;
            ELSE
                -- navigation for search results page
                p_nav_names(2) := C_SRCH_STU_PEOPLE_3;
            END IF;

		-- if to show contact details
		ELSE
		    -- if list of people displayed previously
		     IF p_list = 'Y' THEN
		 	     p_nav_names(1) := C_SRCH_STU_PEOPLE_2;
		 	     p_nav_names(2) := C_SRCH_STU_PEOPLE_3;
			 ELSE
			     p_nav_names(1) := C_SRCH_STU_PEOPLE_3;
			 END IF;
        END IF;
	END IF;

	RETURN p_nav_names;
END get_nav_struct;


--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------

PROCEDURE get_nav_path
(
    p_arg_names   owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values  owa.vc_arr DEFAULT empty_vc_arr
)
IS
----------------------------------------------------------------------
--  Purpose: Prints out breadcrumb navigation
----------------------------------------------------------------------
    l_from          VARCHAR(50);
    l_show_mode     VARCHAR2(50);
    l_list          VARCHAR2(1000);
    l_dad_url       qv_reference_cd.description%TYPE := qv_common.get_reference_description('DAD');
    l_searchby_ppl  NUMBER := 0;
    l_link          VARCHAR2(1000); 

    FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
	IS
    BEGIN
        RETURN common_utils.get_string(p_arg_names, p_arg_values, p_name);
    END get_value;
    
BEGIN

    l_from          := get_value('p_from');
    l_show_mode     := get_value('p_show_mode');
    l_list          := get_value('p_list');
    l_searchby_ppl  := get_value('p_searchby_ppl');

    htp.p('<div class="navpath">');
    htp.p('<a href="' || common_template.C_HOME || '">Home</a> &gt;');

	-- if search started from submitted a form form a portelt
	IF l_from = C_FROM_ADVANCED THEN

	    -- nav path will start from pp>people search
        htp.p('<a href="/' || l_dad_url || get_value(C_SRCH_STU_PEOPLE) || '">' || C_SRCH_STU_PEOPLE || '</a>');

		-- if to show search results
		IF l_show_mode = C_SRCH_STU_PEOPLE_2 THEN
        
            IF (l_searchby_ppl = search.C_SEARCH_PERSON_BY_JP) THEN
                htp.p(' &gt; ' || C_SRCH_JP_RESULTS);

            ELSE
                htp.p(' &gt; ' || C_SRCH_STU_PEOPLE_2);

            END IF;

        ELSIF l_show_mode = C_SRCH_JP_RESULTS THEN
                    
            -- if list of people displayed previously
            -- couldn't get this link appeared correcty using the 'TRADITIONAL METHOD' so this is just a 'get around'
            -- for now. This link will direct the user back to the JP search results list again
            l_link := '/srch_common_people_p.show?p_arg_names=p_show_mode&p_arg_values=' || srch_stu_people.C_SRCH_STU_PEOPLE_2
                ||'&p_arg_names=p_campus&p_arg_values=' || get_value('p_campus')
                ||'&p_arg_names=p_attribute_value&p_arg_values=' || get_value('p_attribute_value')
                ||'&p_arg_names=p_attribute_type&p_arg_values=' || get_value('p_attribute_type')
                ||'&p_arg_names=p_searchby_ppl&p_arg_values=' || get_value('p_searchby_ppl')
                ||'&p_arg_names=p_from&p_arg_values=' || get_value('p_from')
                ||'&amp;p_arg_names='||utl_url.escape(srch_stu_people.C_SRCH_STU_PEOPLE, TRUE)
                ||'&amp;p_arg_values='||utl_url.escape(common_utils.get_string(p_arg_names, p_arg_values, srch_stu_people.C_SRCH_STU_PEOPLE), TRUE);         
            
            IF l_list = 'Y' THEN
                htp.p(' &gt; ' || '<a href="/' || l_dad_url || l_link || '">' || C_SRCH_JP_RESULTS || '</a>');
                htp.p(' &gt; ' || C_SRCH_STU_PEOPLE_3);
            ELSE
                htp.p(' &gt; ' || C_SRCH_STU_PEOPLE_3);
            END IF;

		-- if to show contact details
		ELSE
		    -- if list of people displayed previously
	        IF l_list = 'Y' THEN
                htp.p(' &gt; ' || '<a href="/' || l_dad_url || get_value(C_SRCH_STU_PEOPLE_2) || '">' || C_SRCH_STU_PEOPLE_2 || '</a>');
                htp.p(' &gt; ' || C_SRCH_STU_PEOPLE_3);
		    ELSE
                htp.p(' &gt; ' || C_SRCH_STU_PEOPLE_3);
		    END IF;
		END IF;

	-- if division/faculty search link is selected on a portlet
    ELSIF l_from = C_SRCH_JP_RESULTS THEN
        htp.p(C_SRCH_JP_RESULTS);
	ELSE
	    -- If show node is null then the nav path should be 'Contact Details', not Advanced Search - TL
        IF (l_show_mode IS NULL) THEN
            htp.p(C_SRCH_STU_PEOPLE_3);
        
	    ELSIF l_show_mode = C_SRCH_STU_PEOPLE THEN
            htp.p(C_SRCH_STU_PEOPLE);

	    -- if to show search results
		ELSIF l_show_mode = C_SRCH_STU_PEOPLE_2 THEN
            htp.p(C_SRCH_STU_PEOPLE_2);
            
		-- if to show contact details
		ELSE
		    -- if list of people displayed previously
		     IF l_list = 'Y' THEN
                htp.p('<a href="/' || l_dad_url || get_value(C_SRCH_STU_PEOPLE_2) || '">' || C_SRCH_STU_PEOPLE_2 || '</a>');
                htp.p(' &gt; ' || C_SRCH_STU_PEOPLE_3);
			 ELSE
                htp.p(C_SRCH_STU_PEOPLE_3);
			 END IF;
        END IF;
        
	END IF;

    htp.p('</div>');

END get_nav_path;

PROCEDURE generate_array
(
    p_arg_names  OUT owa.vc_arr
   ,p_arg_values OUT owa.vc_arr
   ,p_name_1     IN VARCHAR2 DEFAULT NULL
   ,p_value_1    IN VARCHAR2 DEFAULT NULL
   ,p_name_2     IN VARCHAR2 DEFAULT NULL
   ,p_value_2    IN VARCHAR2 DEFAULT NULL
   ,p_name_3     IN VARCHAR2 DEFAULT NULL
   ,p_value_3    IN VARCHAR2 DEFAULT NULL
   ,p_name_4     IN VARCHAR2 DEFAULT NULL
   ,p_value_4    IN VARCHAR2 DEFAULT NULL
   ,p_name_5     IN VARCHAR2 DEFAULT NULL
   ,p_value_5    IN VARCHAR2 DEFAULT NULL
   ,p_name_6     IN VARCHAR2 DEFAULT NULL
   ,p_value_6    IN VARCHAR2 DEFAULT NULL
   ,p_name_7     IN VARCHAR2 DEFAULT NULL
   ,p_value_7    IN VARCHAR2 DEFAULT NULL
   ,p_name_8     IN VARCHAR2 DEFAULT NULL
   ,p_value_8    IN VARCHAR2 DEFAULT NULL
   ,p_name_9     IN VARCHAR2 DEFAULT NULL
   ,p_value_9    IN VARCHAR2 DEFAULT NULL
   ,p_name_10    IN VARCHAR2 DEFAULT NULL
   ,p_value_10   IN VARCHAR2 DEFAULT NULL
)
----------------------------------------------------------------------
--  Purpose: Populate array with incomming name and value pairs and
--    		 pass out array
----------------------------------------------------------------------
IS
BEGIN
    p_arg_names.DELETE;
    p_arg_values.DELETE;

    p_arg_names(1) := p_name_1;     p_arg_values(1) := p_value_1;
    p_arg_names(2) := p_name_2;     p_arg_values(2) := p_value_2;
    p_arg_names(3) := p_name_3;     p_arg_values(3) := p_value_3;
    p_arg_names(4) := p_name_4;     p_arg_values(4) := p_value_4;
    p_arg_names(5) := p_name_5;     p_arg_values(5) := p_value_5;
    p_arg_names(6) := p_name_6;     p_arg_values(6) := p_value_6;
    p_arg_names(7) := p_name_7;     p_arg_values(7) := p_value_7;
    p_arg_names(8) := p_name_8;     p_arg_values(8) := p_value_8;
    p_arg_names(9) := p_name_9;     p_arg_values(9) := p_value_9;
    p_arg_names(10) := p_name_10;   p_arg_values(10) := p_value_10;

END generate_array;

PROCEDURE show_advanced_srch
IS
----------------------------------------------------------------------
--  Purpose: Show advanced search form
----------------------------------------------------------------------

-- department/faculty cursor
CURSOR c_department IS
	SELECT org_unit_desc, org_unit_cd
	FROM   emp_org_unit
	WHERE  hierarchy_level = 'CLEVEL2'
    AND    start_dt <= TRUNC(SYSDATE)
    AND   (end_dt IS NULL
    OR     end_dt >= TRUNC(SYSDATE)
          )
	ORDER BY org_unit_cd;


BEGIN

    -- Jquery validation
    htp.p('
    <script type="text/javascript">
    <!--

    $(document).ready(function() {
        $("#enter_search_details").validate({
            messages: {
                p_first_name : {
                    required: "Please enter a first name or surname."
                }
            }
        });
    });

    //-->
    </script>');

    htp.p('<h1>Staff search</h1>');
	htp.p('<p>To search for a staff member you must enter a first name and/or a surname, '
		   ||'and may also select a Department or Faculty.</p>');

	-- start of form
	htp.p('<form class="qv_form" id="enter_search_details" method="get" action="srch_stu_people_p.process_advanced_form">');

		htp.p('<ul>');

		htp.p('    <li><label for="p_first_name" class="customlabel160">First name:</label>');

		htp.p('	     <input type="text" name="p_first_name" maxlength="100" class="{required: function(){return $(''#p_surname'').val() == '''';}}"></li>');

		htp.p('    <li><label for="p_surname" class="customlabel160">Surname:</label>');

		htp.p('	     <input type="text" id="p_surname" name="p_surname" maxlength="100"></li>');

		htp.p('    <li><label for="p_org_unit_code" class="customlabel160">Department or Faculty:</label>');

		htp.p('	     <select name="p_org_unit_code" size="1">');
		htp.p('  	   <option value="1">QUT');

        -- display org units
        FOR r IN c_department LOOP

   		    htp.p('    <option value="'|| r.org_unit_cd ||'">'|| REPLACE(r.org_unit_desc, '&', '&amp;'));
   		END LOOP;
		htp.p('		 </select></li>');
        htp.p('</ul>');

        htp.p('<div class="formbuttons">');
		htp.p('<input class="submitbutton" type="submit" name="p_advanced_submit" value="SUBMIT">');
    	htp.p('<input class="resetbutton" type="reset" value="RESET"><br><br>');
        htp.p('</div>');

		-- hidden fields
        htp.p('<input type="hidden" name="p_search_type"  value="LIKE">');

    	htp.p('<input type="hidden" name="p_arg_names"  value="p_show_mode">');
    	htp.p('<input type="hidden" name="p_arg_values" value="'||C_SRCH_STU_PEOPLE_2||'">');

    	htp.p('<input type="hidden" name="p_arg_names"  value="p_from">');
    	htp.p('<input type="hidden" name="p_arg_values" value="'||C_FROM_ADVANCED||'">');

    	htp.p('<input type="hidden" name="p_arg_names"  value="'||C_SRCH_STU_PEOPLE||'">');
        htp.p('<input type="hidden" name="p_arg_values" value="'|| REPLACE(common_template.set_nav_path_url(C_SRCH_STU_PEOPLE), '&', '&amp;')||'">');

	-- end of form
	htp.p('</form>');

END show_advanced_srch;

PROCEDURE process_search
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: To process search request and call appropriate pages.
----------------------------------------------------------------------
IS

    l_arg_names  owa.vc_arr;
    l_arg_values owa.vc_arr;

	ex_no_surname			EXCEPTION;
	ex_no_details           EXCEPTION;
	ex_no_record            EXCEPTION;


	l_show_mode		   		VARCHAR2(100);
	-- used for navigation path to determine where the page is called from
	l_from		            VARCHAR2(100);

	-- number of employee found
	l_emp_cnt		   		NUMBER(10):=0;
	-- employee_num or ip_num
	l_id 		 	   		VARCHAR2(38);
	-- null or CCR
	l_ip_type	 	   		ip.ip_type%TYPE;

	l_first_name	   		  emp_employee.first_name%TYPE;
	l_surname		   		    emp_employee.surname%TYPE;
	l_search_type	   		  VARCHAR2(50);
	l_org_unit_code	   		qv_org_unit.org_unit_cd%TYPE;
	-- contains value when a form from a portlet is submitted
	l_surname_submit	    VARCHAR2(50);
	-- contains value when advanced form is submitted
	l_advanced_submit  		VARCHAR2(50);

    l_staff_search1    VARCHAR2(2000);
    l_staff_search2    VARCHAR2(2000);
    l_staff_search3    VARCHAR2(2000);
    l_staff_search4    VARCHAR2(2000);

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

	l_show_mode		   := get_value('p_show_mode');
	l_from             := get_value('p_from');
	l_first_name	   := get_value('p_first_name');
	l_surname		   := get_value('p_surname');
	l_org_unit_code	   := get_value('p_org_unit_code');
	l_search_type	   := get_value('p_search_type');
	l_surname_submit   := get_value('p_surname_submit');
	l_advanced_submit  := get_value('p_advanced_submit');

    -- pt testing for staff breadcrumbs
    l_staff_search1    := get_value(C_SRCH_STU_PEOPLE);
    l_staff_search2    := get_value(C_SRCH_STU_PEOPLE_2);
    l_staff_search3    := get_value(C_SRCH_STU_PEOPLE_3);
    l_staff_search4    := get_value(C_SRCH_STU_PEOPLE_4);

    -- /pt testing

    -- catch all exceptions here
    -- if portlet form submitted without a surname
    IF l_surname_submit IS NOT NULL
	    AND l_surname IS NULL
	THEN
        RAISE ex_no_surname;
    END IF;

    -- if advanced form submitted without any details
    IF l_advanced_submit IS NOT NULL
        AND l_first_name IS NULL
        AND l_surname IS NULL
    THEN
        RAISE EX_NO_DETAILS;
    END IF;

    IF (l_search_type IS NULL) THEN
        l_search_type := 'LIKE';
    END IF;

    -- count employee
    l_emp_cnt := srch_stu_people.get_emp_cnt(l_first_name
                                            ,l_surname
                                            ,l_org_unit_code
                                            ,l_search_type);


    -- if no employee and student found catch exception
    IF l_emp_cnt = 0 THEN

        RAISE ex_no_record;

    -- if one person found
    ELSIF l_emp_cnt = 1 THEN

        srch_stu_people.get_emp_id  (l_first_name
									,l_surname
    								,l_org_unit_code
    								,l_search_type
    								,l_id
    								,l_ip_type);

	    -- prepare array to pass array to srch_emp_people_p.show
	    generate_array(   l_arg_names ,l_arg_values
					    ,'p_show_mode',srch_stu_people.C_SRCH_STU_PEOPLE_3
					    ,'p_from'     ,l_from
					    ,'p_id'       ,l_id
					    ,'p_ip_type'  ,l_ip_type
                        ,C_SRCH_STU_PEOPLE, l_staff_search1
                        ,C_SRCH_STU_PEOPLE_2, l_staff_search2
                        ,C_SRCH_STU_PEOPLE_3, l_staff_search3
                        ,C_SRCH_STU_PEOPLE_4, l_staff_search4);

    -- if more than one person found
    ELSE
	    generate_array(   l_arg_names      ,l_arg_values
					    ,'p_show_mode'     ,srch_stu_people.C_SRCH_STU_PEOPLE_2
					    ,'p_from'          ,l_from
					    ,'p_first_name'    ,l_first_name
					    ,'p_surname'       ,l_surname
					    ,'p_org_unit_code' ,l_org_unit_code
					    ,'p_search_type'   ,l_search_type
                        ,C_SRCH_STU_PEOPLE, l_staff_search1
                        ,C_SRCH_STU_PEOPLE_2, l_staff_search2
                        ,C_SRCH_STU_PEOPLE_3, l_staff_search3
                        ,C_SRCH_STU_PEOPLE_4, l_staff_search4);
    END IF;

    -- call this to control access and display appropriate heading, content and footer
    srch_stu_people_p.show(l_arg_names,l_arg_values);

EXCEPTION
    WHEN ex_no_surname THEN
        generate_array(l_arg_names  ,l_arg_values
                      ,'p_show_mode',l_show_mode
                      ,'p_from'     ,l_from
                      ,'p_exception',C_EX_NO_SURNAME
                      ,C_SRCH_STU_PEOPLE, l_staff_search1
                        ,C_SRCH_STU_PEOPLE_2, l_staff_search2
                        ,C_SRCH_STU_PEOPLE_3, l_staff_search3
                        ,C_SRCH_STU_PEOPLE_4, l_staff_search4);
        srch_stu_people_p.show(l_arg_names,l_arg_values);
    WHEN ex_no_details THEN
        generate_array(l_arg_names  ,l_arg_values
                      ,'p_show_mode',l_show_mode
                      ,'p_from'     ,l_from
                      ,'p_exception',C_EX_NO_DETAILS
                      ,C_SRCH_STU_PEOPLE, l_staff_search1
                        ,C_SRCH_STU_PEOPLE_2, l_staff_search2
                        ,C_SRCH_STU_PEOPLE_3, l_staff_search3
                        ,C_SRCH_STU_PEOPLE_4, l_staff_search4);
        srch_stu_people_p.show(l_arg_names,l_arg_values);
    WHEN ex_no_record THEN
        generate_array(l_arg_names  ,l_arg_values
                      ,'p_show_mode',l_show_mode
                      ,'p_from'     ,l_from
                      ,'p_exception',C_EX_NO_RECORD
                      ,C_SRCH_STU_PEOPLE, l_staff_search1
                        ,C_SRCH_STU_PEOPLE_2, l_staff_search2
                        ,C_SRCH_STU_PEOPLE_3, l_staff_search3
                        ,C_SRCH_STU_PEOPLE_4, l_staff_search4);
        srch_stu_people_p.show(l_arg_names,l_arg_values);

    WHEN OTHERS THEN
        generate_array(l_arg_names  ,l_arg_values
                      ,'p_show_mode',l_show_mode
                      ,'p_from'     ,l_from
                      ,'p_exception','OTHERS'
                      ,C_SRCH_STU_PEOPLE, l_staff_search1
                        ,C_SRCH_STU_PEOPLE_2, l_staff_search2
                        ,C_SRCH_STU_PEOPLE_3, l_staff_search3
                        ,C_SRCH_STU_PEOPLE_4, l_staff_search4);
        srch_stu_people_p.show(l_arg_names,l_arg_values);

END process_search;

PROCEDURE show_exceptions
(
    p_exception 	  IN VARCHAR2 DEFAULT NULL
   ,p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
)
----------------------------------------------------------------------
--  Purpose: Show exception messages
----------------------------------------------------------------------
IS
    -- local function to retrieve value
    FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
	IS
    BEGIN
        RETURN common_utils.get_string(p_arg_names, p_arg_values, p_name);
    END get_value;

BEGIN

    IF p_exception = C_EX_NO_SURNAME THEN
	    -- if authorized staff
	    IF qv_common_access.is_user_in_group('EMP_STUDENT_INFO') THEN
            htp.p('<p>You must enter a surname to perform a search for staff and/or '
                   ||'students. To perform an advanced search, click the link beneath '
                   ||'the search text box.</p>');
		-- if student or general staff
		ELSE
   		    htp.p('<p>Please enter a surname to perform a search or you can perform '
                   ||'an advanced search by clicking the link beneath the '
                   ||'search text box.</p>');
		END IF;

	ELSIF p_exception = C_EX_NO_STUDENT_ID THEN
        htp.p('<p>You must enter a student number to perform a search for a student. '
               ||'To perform an advanced search, click the link beneath the '
               ||'search text box.</p>');

	ELSIF p_exception = C_EX_NO_DETAILS THEN
	    -- if authorized staff
	    IF qv_common_access.is_user_in_group('EMP_STUDENT_INFO') THEN
            htp.p('<p>You must enter a first name, surname or student number to '
                   ||'conduct a search for a person at QUT.</p>');
		-- if student or general staff
		ELSE
            htp.p('<p>You must enter a first name or surname to conduct a search '
			       ||'for a staff member at QUT.</p>');
		END IF;

	ELSIF p_exception = C_EX_NOT_NUMERIC THEN
        htp.p('<p>A student number must be numeric.</p>');
	ELSE
        htp.p('<h1>Search results</h1>');
        htp.prn('<p>No records matched your search criteria. Please return to the ');

        IF get_value(C_SRCH_STU_PEOPLE) like '/search_p.show%' THEN
            htp.prn('<a href="/'||qv_common_reference.get_reference_description('DAD')|| get_value(C_SRCH_STU_PEOPLE) || '">advanced search page');
        ELSE
            htp.prn('<a href="'||qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_URL')||'">search page');
        END IF;
        htp.p('</a> and refine your search.</p>');
	END IF;

END show_exceptions;

PROCEDURE show_help
(
    p_help_mode		IN VARCHAR2    DEFAULT NULL
)
IS
----------------------------------------------------------------------
--  Purpose: Show search results specific help
----------------------------------------------------------------------

    l_user_id     qv_client_role.id%TYPE;
    l_user_type   qv_client_role.role_cd%TYPE;   

BEGIN

    qv_common_id.identify_role (p_username        => qv_audit.get_username
                               ,p_user_id         => l_user_id
                               ,p_user_type       => l_user_type
                               ,p_role_active_ind => 'Y');

	CASE
		WHEN p_help_mode = C_SRCH_STU_PEOPLE THEN

			htp.p('<p>The Advanced People Search allows you to perform an '
			       ||'''Exact match'' or ''Starts with'' search to locate staff details. '
			       ||'You can search for staff by indicating a first name, surname, department or faculty, '
			       ||'or a combination of the three. Either a first name or surname must be entered '
			       ||'to begin a search. It is also advisable, where possible, to select a department '
			       ||'or faculty for better search performance.</p>');

		WHEN p_help_mode = C_SRCH_STU_PEOPLE_2 THEN
                   
            --JP search results help text        
            IF (l_user_type = common_client.C_EMP_ROLE_TYPE) THEN
                htp.p('<p>You can search for JPs using the Advanced Search.</p>'
                       ||'<p>This page lists QUT staff members who have identified themselves as a Justice of the Peace (JP), and '
                       ||'are available to assist QUT staff or students with the witnessing of legal documents. '
                       ||'The search results will be refined to a certain campus and/or JP Type if you have selected these in your search. '
                       ||'The list of JPs includes the staff member''s name, their JP type (if not selected), phone number, email address, room location, campus and any relevant comments.</p>'
                       ||'You can search for JPs again by clicking the link at the bottom of the page.  This will take you to the JP section of the Advanced Search page.</p>'
                       ||'<p><strong>Note: </strong>Please observe if the JP is available to assist staff only or staff and students.</p>');

            ELSE
                htp.p('<p>You can also search for JPs using the Advanced Search.</p>'
                       ||'<p>This page lists QUT staff members who have identified themselves as a Justice of the Peace (JP), and '
                       ||'are available to assist with the witnessing of legal documents. '
                       ||'The search results will be refined to a certain campus and/or JP Type if you have selected these in your search. '
                       ||'The list of JPs includes the staff member''s name, their JP type (if not selected), phone number, email address, room location, campus and any relevant comments.</p>'
                       ||'You can search for JPs again by clicking the link at the bottom of the page.  This will take you to the JP section of the Advanced Search page.</p>');
                       
            END IF;
            
		WHEN p_help_mode = C_SRCH_STU_PEOPLE_3 THEN

		    htp.p('<p>People Search displays the staff contact details for a given staff member '
			       ||'at QUT. Details include name, position title, school or department, '
			       ||'location, phone numbers and email address. If the staff member has not '
			       ||'released his or her ID photo, it will not be displayed among the contact details.</p>');
		ELSE
		    NULL;
	END CASE;

END show_help;

END srch_stu_people;