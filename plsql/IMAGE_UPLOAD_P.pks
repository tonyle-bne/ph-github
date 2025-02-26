CREATE OR REPLACE PACKAGE           image_upload_p IS
/**
 * _p package for image_upload
 */
--------------------------------------------------------------------------------
--  Package Name: image_upload_p
--  Purpose:      Allows the staff to select or upload an image and use it as
--                their personal profile
--  Author:       Tony Le
--  Created:      7 Sept 2015
--
--  Specification Modification History
--  Date         Author           Description
--  -----------  ---------------- ----------------------------------------------
--  26-Oct-2015  Tony Le          Added a few constants for error trapping purposes
--  28-Oct-2015  Tony Le          Added new parameter to procedure show_id_image to allow
--                                staff with permission ALL IMAGES to view staff id card image
--------------------------------------------------------------------------------

C_EMPTY_VC_ARR          owa.vc_arr;

--------------------------------------------------------------------------------
-- GLOBAL VARIABLES
--------------------------------------------------------------------------------
E_NO_ACCESS     EXCEPTION;

--------------------------------------------------------------------------------
-- GLOBAL VARIABLES
--------------------------------------------------------------------------------
-- standard constants
C_PAGE_TITLE        CONSTANT VARCHAR2(50)   := 'Change my profile image';
C_MAIN_CONTROLLER   CONSTANT VARCHAR2(50)   := 'image_upload_p.edit_image';
C_START             CONSTANT VARCHAR2(30)   := 'start_process';

-- type of error
C_ERROR             CONSTANT VARCHAR2(30)   := 'error';
C_SAVE_ERROR        CONSTANT VARCHAR2(30)   := 'save_error';
C_OTHER_ERROR       CONSTANT VARCHAR2(50)   := 'other_error';

C_ACTION            CONSTANT VARCHAR2 (30)  := 'action';
C_MAIN_CONTROL_PROC CONSTANT VARCHAR2 (100) := 'package_name';

C_SYSTEM_MSG        CONSTANT VARCHAR2 (50)  := 'system_msg';

-- other constants for the function
C_SHOW_EDIT_IMAGE   CONSTANT VARCHAR2(50)   := 'show_edit_form';
C_STORE_IMAGE       CONSTANT VARCHAR2(50)   := 'store_image';
C_DELIVER_IMAGE     CONSTANT VARCHAR2(50)   := 'deliver_image';
C_REDIRECT_PAGE     CONSTANT VARCHAR2(50)   := 'redirect_page';

TYPE vc_arr IS TABLE OF VARCHAR2 (32767) 
    INDEX BY BINARY_INTEGER;

TYPE array_data IS TABLE OF VARCHAR2 (32767) 
    INDEX BY BINARY_INTEGER;

TYPE function_data IS TABLE OF array_data 
    INDEX BY VARCHAR2 (100);

TYPE varchar_array IS TABLE OF VARCHAR2 (32767) 
    INDEX BY VARCHAR2 (100);

TYPE varchar_table IS TABLE OF VARCHAR2 (30);

empty_arr           function_data;

empty_vc_arr        owa.vc_arr;

--------------------------------------------------------------------------------
--            GLOBAL FUNCTIONS
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--            GLOBAL PROCEDURES
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Purpose: Telling the system what to execute when the user call start_function
--------------------------------------------------------------------------------
PROCEDURE start_function (
    p_system_msg IN VARCHAR2 DEFAULT NULL
);

--------------------------------------------------------------------------------
-- Purpose: Telling the system to perform a particular function for the application
--------------------------------------------------------------------------------
PROCEDURE edit_image (
    p_function_data   IN varchar_array,
    p_local_data      IN function_data DEFAULT empty_arr
);

--------------------------------------------------------------------------------
--  Purpose:  Process all form 
--------------------------------------------------------------------------------
PROCEDURE process_form (name_array  IN owa.vc_arr DEFAULT C_EMPTY_VC_ARR
                        ,value_array IN owa.vc_arr DEFAULT C_EMPTY_VC_ARR);

--------------------------------------------------------------------------------
--  Purpose:  Retrieve and show image
--------------------------------------------------------------------------------
PROCEDURE show_image (p_username IN VARCHAR2 DEFAULT NULL);

--------------------------------------------------------------------------------
--  Purpose:  Retrieve and show QUT id card image
--------------------------------------------------------------------------------
PROCEDURE show_id_image (p_id       IN NUMBER   DEFAULT NULL
                        ,p_role_cd  IN VARCHAR2 DEFAULT NULL);

END image_upload_p;
/
