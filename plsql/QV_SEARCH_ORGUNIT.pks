create or replace
PACKAGE qv_search_orgunit IS
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
--  29-Jul-2009   D.Jack          SAMS Upgrade
--  07-Sep-2011   L Dorman        Changed p_org_unit in show_lower_orgunit procedure to emp_org_unit.org_unit_desc type
--  13-Sep-2107   Tony Le         QVSEARCH-90: Application refactoring.
----------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
    -- page title

	C_DIV_FAC_BROWSE        CONSTANT VARCHAR2(100) := 'divisions and faculties';
	C_SELECTED_DIV_FAC 		CONSTANT VARCHAR2(100) := 'selected division or faculty';
	C_ALL_CAMPUSES			CONSTANT VARCHAR2(100) := 'staff details - all campuses';
    C_A_CAMPUS				CONSTANT VARCHAR2(100) := 'staff details';
	C_MY_PORTLET			CONSTANT VARCHAR2(100) := 'my portlet';

PROCEDURE show_error_page;

PROCEDURE show_option;
----------------------------------------------------------------------
--	Name.      show_option
--  Purpose:   To show the browser link
--  Pre:	   TRUE
--  Post:	   A browser link is displayed
----------------------------------------------------------------------

PROCEDURE show_orgunit_list
(
     p_browse        BOOLEAN	DEFAULT TRUE
    ,p_org_unit_code VARCHAR2	DEFAULT NULL
);
----------------------------------------------------------------------
--  Name:      show_orgunit_list
--	Author.    Lin Lin
--  Purpose:   Display all organisations either only Clevel 2 or Clevel 3, 4 and all
--			   different phone group sections.
--  Pre:	   TRUE
--  Post:	   If in browser mode, a list of Clevel 2 organisation names is displayed.
--			   If an organisation name is picked, a drill down list of the organisational
--			   hierarchy will be displayed.
----------------------------------------------------------------------

PROCEDURE show_lower_orgunit
(
     p_orgunit 				  emp_org_unit.org_unit_desc%TYPE
    ,p_orgunit_code 		  emp_org_unit.org_unit_cd%TYPE
);
----------------------------------------------------------------------
--  Name:      show_lower_orgunit
--	Author.    Lin Lin
--  Purpose:   Display Clevel 4 organisations and all different phone group sections.
--  Pre:	   TRUE
--  Post:	   A list of Clevel 4 organisations and all different phone group sections
--			   displayed
----------------------------------------------------------------------

PROCEDURE show_all_ally;
----------------------------------------------------------------------
--  Name:      show_ally_list
--	Author.    Tony Le
--  Purpose:   Show all staff within ALLY Network 
--  Pre:	   TRUE
--  Post:	   A list of staff who are qualified to be an Ally within QUT
----------------------------------------------------------------------

PROCEDURE show_details
(
 		 p_start_org_code   VARCHAR2
		,p_campus		    VARCHAR2 DEFAULT NULL
		,p_from		        VARCHAR2 DEFAULT NULL
);
----------------------------------------------------------------------
--  Name:      show_details
--	Author.    Lin Lin
--  Purpose:   Display detailed list of the selected organisation staff members
--  Pre:	   TRUE
--  Post:	   A list of staff brief details and contacts. It is organised in the way of
--			   organizational hierarchy and sorted by their surname in their section
----------------------------------------------------------------------

PROCEDURE print_details
(
 		 p_start_org_code   VARCHAR2
		,p_campus		    VARCHAR2 DEFAULT NULL
);
---------------------------------------------------------------------
--  Name:      print_details
--	Author:	   Lin Lin
--  Purpose:   Display the page with more print friendly format.
--  Pre:	   TRUE
--  Post:	   A printable list of staff brief details and contacts. It is organised in the
--			   way of organizational hierarchy and sorted by their surname in their section.
----------------------------------------------------------------------

PROCEDURE get_org_unit_names 
(
 		 p_org_unit_cd      VARCHAR2
        ,p_local_name       OUT VARCHAR2
        ,p_area_name        OUT VARCHAR2
);
---------------------------------------------------------------------
--  Name:      get_org_unit_names
--	Author:	   Tony Le
--  Purpose:   Retrieve division/faculty name and/or area name.
--  Pre:	   p_org_unit_cd must not be null
--  Post:	   Send back the faculty/division name and if applicable the dep/area name
----------------------------------------------------------------------

FUNCTION get_nav_struct
(
    p_from    VARCHAR2    DEFAULT NULL
)
    RETURN owa.vc_arr;
--------------------------------------------------------------------------------------
-- Name:       get_nav_struct
-- Purpose:    Gets the navigational structure
-- Pre:		   TRUE
-- Post: 	   Navigational structure is returned
--------------------------------------------------------------------------------------

END qv_search_orgunit;
