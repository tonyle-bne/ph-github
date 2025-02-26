create or replace
PACKAGE BODY ph_main IS
----------------------------------------------------------------------
--  Purpose:     Provide links for phone book
--  Modification History
--  Date         Author           Description
--  -----------  ------------------------------------------------------
--  29-Apr-2004  L Chang         Fixed mailto format and applied for QV
--                               standard style
--  01-Aug-2006  E Wood			 10g UPGRADE - Removed calls to qv_common_style;
--                               Corrected qv_common_links references to use the qv_common_links.get_reference_link;
--                               Replaced Phone Book Administration email referece to appropriate qv_common_links.get_reference_link call;
--								 Corrected text from "phonebook" to "phone book"
--  01-Mar-2007  F.Lee           Added link to phone book administrator search
--  26-Mar-2007  E.Wood          Changed how access is checked for update org_unit name and manage Phonebook admin access.
--                               Also simplified logic to remove duplication of content in the code.
--  24-03-2009   Tony Le          SAMS upgrade
--  03-08-2009   A.McBride       Updated portlet UI and text
--  02-09-2009   A.Patman        Moved 'Search phone book administrators' link outside of unreachable block so it appears again
--  24-02-2010   A.McBride		 Reviewed portlet UI text and links for SAMS go-live.
--  19-10-2010   K.Farlow        Removed Update organisational unit names link (commented out for now) 
--  17-05-2018   S. Kambil       Apply site and service reference to HiQ. [QVPH-41]
--  18-05-2018   Tony LE         QVPH-41: Removed unnecessary <div> in some pages.
----------------------------------------------------------------------
--------------------------------------------
--            GLOBAL CONSTANTS
--------------------------------------------
    -- comment
    C_CONSTANT_VARIABLE VARCHAR2(20) := 'Default Value';

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------
    -- comment
    g_global_variable VARCHAR2(20) := 'Default Value';
    g_restrict_access    EXCEPTION;

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

    --NIL
--------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------
PROCEDURE main_menu
----------------------------------------------------------------------
--  Purpose:
----------------------------------------------------------------------
IS

l_username qv_client_role.username%TYPE := qv_common_id.get_username;

BEGIN
    htp.p('<div class="portlet">');
    
    htp.p('<ul class="linklist">');
    
    IF qv_common_access.is_user_in_group('PH') THEN
       IF ph_admin_p.get_access_cd_length = 0 THEN
           RAISE g_restrict_access;
       END IF;
  
       IF ph_admin_p.has_qut_access(l_username) THEN
           --htp.p('<li><a href="ph_admin_p.local_name">Update organisational unit names</a></li>');-- [QVPH-11]
           htp.p('<li><a href="ph_admin_p.admin_person">Manage phone book administrator access</a></li>');
       END IF;

       htp.p('<li><a href="ph_updt_p.main_menu">Manage workgroup structure</a></li>');
       htp.p('<li><a href="ph_admin_p.staff_group">Perform staff updates</a></li>');
    
    END IF;
    htp.p('<li><a href="ph_admin_search_p.show" class="search">Search for a phone book administrator</a></li>');
    htp.p('</ul>');
    
    htp.p('</div>');
    
EXCEPTION
    WHEN g_restrict_access THEN
        htp.p('<p class="important">You do not have the correct authorisation to access this page. Please contact '
            ||'<a href="mailto:'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'">'||qv_common_links.get_reference_link('PHONEBOOK_EMAIL')||'</a> for access.</p>');
        htp.p('</div>');
    WHEN OTHERS THEN
        htp.p('<p class="smallpad">There was an error producing this page. Please contact HiQ for assistance.</p>');
        htp.p('</div>');
END main_menu;

END ph_main;
