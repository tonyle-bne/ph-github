create or replace
PACKAGE srch_stu_people 
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
--  Specification Modification History
--  Date          Author       Description
--  -----------  ------------------------------------------------------
--  03-SEP-2002   S Jeong      Created
--  22-SEP-2002   S Jeong      Logic in IF statement in get_nav_sturct
--                             swaped.
--  06-Aug-2007  C Wong        IAM Upgrade
--  31-Oct-2008  P Totagiancaspro
--                             Reverse IAM changes
--  18-Nov-2008  C Wong        Reinstate get_emp_cnt,get_emp_id
--                             Fix get_nav_path: incorrectly commented
--  29-Jul-2009  D.Jack        SAMS Upgrade
--  09-Nov-2010  Tony Le       Added new constant for JP search
----------------------------------------------------------------------

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

	-- array structures for navigation path
    empty_vc_arr owa.vc_arr;

--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------

    -- advanced search page title
	C_SRCH_STU_PEOPLE	 CONSTANT VARCHAR2(100) := 'Advanced search';
	-- search results page title
	C_SRCH_STU_PEOPLE_2	 CONSTANT VARCHAR2(100) := 'Person search results';
	-- staff contact details page title
	C_SRCH_STU_PEOPLE_3	 CONSTANT VARCHAR2(100) := 'Contact details';
	-- used to display help for student contact details
	C_SRCH_STU_PEOPLE_4	 CONSTANT VARCHAR2(100) := 'Student contact details';

    -- JP search results page name
    C_SRCH_JP_RESULTS    CONSTANT VARCHAR2(100) := 'Justice of the Peace (JP) search results';


	-- used to determine navigation path
	C_FROM_PORTLET 	 	 CONSTANT VARCHAR2(100) :=  'PORTLET';
	C_FROM_ADVANCED	 	 CONSTANT VARCHAR2(100) :=  'ADVANCED';

	-- used for page hits
	C_STAFF				 CONSTANT VARCHAR2(50)  :=  'Staff';
	C_STUDENT			 CONSTANT VARCHAR2(50)  :=  'Student';

	-- exceptions used to display messages
	C_EX_NO_SURNAME	     CONSTANT VARCHAR2(50)  := 'ex_no_surname';
	C_EX_NO_STUDENT_ID   CONSTANT VARCHAR2(50)  := 'ex_no_student_id';
	C_EX_NO_DETAILS      CONSTANT VARCHAR2(50)  := 'ex_no_details';
	C_EX_NO_RECORD       CONSTANT VARCHAR2(50)  := 'ex_no_record';
	C_EX_NOT_NUMERIC     CONSTANT VARCHAR2(50)  := 'ex_not_numeric';

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------
FUNCTION get_nav_struct
(
    p_show_mode    IN VARCHAR2    DEFAULT NULL
   ,p_from         IN VARCHAR2    DEFAULT NULL
   ,p_list         IN VARCHAR2    DEFAULT NULL
)
    RETURN owa.vc_arr;
----------------------------------------------------------------------
--	NAME:	 get_nav_struct
--  PURPOSE: get navigation path list
--  PRE:	 @p_show_mode, @p_from have been passed in.
--           @p_list has been passed in
--			 when @p_show_mode = Contact Details
--  POST:	 a navigation list returned
----------------------------------------------------------------------

PROCEDURE get_nav_path
(
    p_arg_names   owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values  owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--	NAME:	 get_nav_path
--  Purpose: Prints out breadcrumb navigation
--  Pre:
--  Post:    breadcrumb nav path displayed
----------------------------------------------------------------------

FUNCTION get_emp_cnt
(
    p_first_name        IN VARCHAR2    DEFAULT NULL
   ,p_surname           IN VARCHAR2    DEFAULT NULL
   ,p_org_unit_code     IN VARCHAR2    DEFAULT NULL
   ,p_search_type       IN VARCHAR2    DEFAULT NULL
)
    RETURN NUMBER;
----------------------------------------------------------------------
--      NAME:    get_emp_cnt
--  Purpose: Count a number of people who matches parameters
--                       Return counts
--  PRE:
--  POST:        Count of employee returned
----------------------------------------------------------------------

PROCEDURE get_emp_id
(
    p_first_name        IN  VARCHAR2    DEFAULT NULL
   ,p_surname           IN  VARCHAR2    DEFAULT NULL
   ,p_org_unit_code     IN  VARCHAR2    DEFAULT NULL
   ,p_search_type       IN  VARCHAR2    DEFAULT NULL
   ,p_id                OUT VARCHAR2
   ,p_ip_type           OUT VARCHAR2
);
----------------------------------------------------------------------
--      NAME:    get_emp_id
--  Purpose: Pass employee number out if found, otherwise pass ip
--            number out
--  PRE:
--  POST:    Employee number or ip number has been passed out
----------------------------------------------------------------------

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
);
----------------------------------------------------------------------
--	Name.    generate_array
--  Purpose: Populate array with incomming name and value pairs and
--			 pass out array
--  Pre:
--  Post:    Arrary populated and has been passed out
----------------------------------------------------------------------

PROCEDURE show_advanced_srch;
----------------------------------------------------------------------
--	Name.    show_advanced_srch;
--  Purpose: Show advanced search form
--  Pre:
--  Post:    Advanced search form displayed
----------------------------------------------------------------------

PROCEDURE process_search
(
     p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
    ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--	Name.    process_search
--  Purpose: To process search request and call appropriate pages.
--  Pre:
--  Post:    Search request processed and appropriate page has been called
----------------------------------------------------------------------

PROCEDURE show_exceptions
(
    p_exception  IN VARCHAR2 DEFAULT NULL
   ,p_arg_names  IN owa.vc_arr DEFAULT empty_vc_arr
   ,p_arg_values IN owa.vc_arr DEFAULT empty_vc_arr
);
----------------------------------------------------------------------
--	Name.    show_exceptions
--  Purpose: Show exception messages
--  Pre:
--  Post:    Exception messages displayed
----------------------------------------------------------------------

PROCEDURE show_help
(
    p_help_mode	   IN VARCHAR2    DEFAULT NULL
);
----------------------------------------------------------------------
--	Name.    show_help
--  Purpose: Show search results specific help
--  Pre:
--  Post:    Search result specific help has been displayed
----------------------------------------------------------------------

END srch_stu_people;
