CREATE OR REPLACE PACKAGE ph_main IS
----------------------------------------------------------------------
--  Package name: ph_main
--  Author:
--  Created:      05 Sep 2002
--
--  Specification Modification History
--  Date         Author           Description
--  -----------  ------------------------------------------------------
--  29-Apr-2004  L Chang          Added QV standard style for package specifications
--  24-03-2009   Tony Le          SAMS upgrade
----------------------------------------------------------------------

--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------

    C_STAFF_SERVICE_NAME CONSTANT VARCHAR2(100) := 'Digital Workplace'; -- todo replace with ref code
    -- NIL

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------

    -- NIL

--------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------

    -- NIL

--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE main_menu;
----------------------------------------------------------------------
--	Name.    main_menu
--  Purpose: Provide links for phone book
--  Pre:     TRUE
--  Post:    links are displayed
----------------------------------------------------------------------

END ph_main;
/
