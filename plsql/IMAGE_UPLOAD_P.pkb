CREATE OR REPLACE PACKAGE BODY image_upload_p IS
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
--  28-Oct-2015  Tony Le          Added new parameter to procedure show_id_image to allow
--                                staff with permission ALL IMAGES to view staff id card image
--  27-Apr-2016  Tony Le          Fixed access_permitted to allow student to view staff uploaded image,                              
--                                when available (QVEMP-48)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

    -- application code for logging
    g_application_cd VARCHAR2(50) := 'EMP';
    
    -- activity codes for logging
    C_MANAGE_PROFILE_IMAGE CONSTANT VARCHAR2(100) := 'Manage personal profile image';

-------------------------------------------------------------------------------
-- Checks if the currently logged in user is authorised to access function
-- @return TRUE if user is authorised, else FALSE
--------------------------------------------------------------------------------
FUNCTION access_permitted 
RETURN BOOLEAN IS

BEGIN

    RETURN (qv_common_access.is_user_in_group('EMP') OR 
            qv_common_access.is_user_in_group('CCR') OR
            qv_common_access.is_user_in_group('STU') OR
            qv_common_access.is_user_in_group('ALU'));

END access_permitted;

--------------------------------------------------------------------------------
--            LOCAL PROCEDURES
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Purpose: Calculates next function action based on last action and session data
--------------------------------------------------------------------------------
FUNCTION navigation_controller (
    p_function_data     IN varchar_array,
    p_local_data        IN function_data DEFAULT empty_arr)
RETURN VARCHAR2 IS

    l_next_action              VARCHAR2(30);

BEGIN

    CASE p_function_data (C_ACTION)
        -- base on the current action, system will assign what the next action will be
        WHEN C_START THEN
            l_next_action := C_SHOW_EDIT_IMAGE;
        WHEN C_SHOW_EDIT_IMAGE THEN
            l_next_action := C_STORE_IMAGE;
        WHEN C_STORE_IMAGE THEN
            l_next_action := C_REDIRECT_PAGE;
        
    END CASE;

   RETURN l_next_action;

END navigation_controller;


--------------------------------------------------------------------------------
-- Purpose: Telling the system what to execute when the user call start_function
--          If you have any customised system message to show the user then you
--          need to pass the system message code as one of the parameters
-- Pre:     Pre conditions
-- Post:    Post conditions
--------------------------------------------------------------------------------
PROCEDURE start_function (
    p_system_msg        IN VARCHAR2 DEFAULT NULL
) IS

    l_function_data    varchar_array;

BEGIN

    l_function_data (C_ACTION) := C_START;
    l_function_data (C_MAIN_CONTROL_PROC) := C_MAIN_CONTROLLER;

    -- adding more data to function data 
    l_function_data (C_SYSTEM_MSG) := p_system_msg; -- customised message, e.g. after updating the database

    edit_image (p_function_data => l_function_data);

END start_function;

--------------------------------------------------------------------------------
-- Purpose: Telling the system to perform a particular function based on the 
--          action/page returned by the navigation_controller
-- Pre:     Pre conditions
-- Post:    Post conditions
--------------------------------------------------------------------------------
PROCEDURE edit_image (
    p_function_data     IN varchar_array,
    p_local_data        IN function_data DEFAULT empty_arr
) IS

    l_next_action       VARCHAR2(30);
    l_function_data     varchar_array := p_function_data;
    l_local_data        function_data := p_local_data;
    l_portal_url        VARCHAR2(100) DEFAULT qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_URL');

BEGIN

    IF NOT access_permitted THEN
        RAISE E_NO_ACCESS;
    END IF;

    l_function_data(C_ACTION) := navigation_controller (p_function_data => p_function_data
                                                       ,p_local_data    => p_local_data);

    CASE l_function_data(C_ACTION)

        WHEN C_SHOW_EDIT_IMAGE THEN
        
           logger.usage(p_application_cd   => g_application_cd
                        ,p_activity_cd     => C_MANAGE_PROFILE_IMAGE
                        ,p_action_cd       => 'Load edit image screen');           

            common_template.get_full_page_header (p_title => C_PAGE_TITLE
                                                 ,p_version => 2);
                                                 
            image_upload.show_edit_image (p_function_data => l_function_data
                                         ,p_local_data    => l_local_data);
                                                                            
            common_template.get_full_page_footer;
                                                                           
        ELSE
        
           logger.warn(p_application_cd   => g_application_cd
                      ,p_activity_cd     => C_MANAGE_PROFILE_IMAGE
                      ,p_action_cd       => 'outcome="Unexpected error - next action not recognised",next_action="'||l_function_data(C_ACTION) ||'"');   

            common_template.get_full_page_header (p_title => C_PAGE_TITLE
                                                 ,p_version => 2);
            common_template.get_full_page_footer;

    END CASE;

EXCEPTION

    WHEN E_NO_ACCESS THEN
    
       logger.warn(p_application_cd => g_application_cd
                  ,p_activity_cd    => C_MANAGE_PROFILE_IMAGE
                  ,p_action_cd      => 'outcome="Access denied - user attempted to load manage profile image screen but does not have the required access"');       

        qv_access_p.not_permitted;

END edit_image;


--------------------------------------------------------------------------------
-- Purpose: Processes all form data (if required). 
--          Sorts out the common elements from form inputs and put them into l_function_data
--          For all other inputs put them into l_local_data
-- Pre:     Pre conditions
-- Post:    Post conditions
--------------------------------------------------------------------------------
PROCEDURE process_form (name_array  IN owa.vc_arr DEFAULT C_EMPTY_VC_ARR,
                        value_array IN owa.vc_arr DEFAULT C_EMPTY_VC_ARR) IS
BEGIN

    IF NOT access_permitted THEN
        RAISE E_NO_ACCESS;
    END IF;
    
    image_upload.process_image(
        p_arg_names  => name_array,
        p_arg_values => value_array);

EXCEPTION
    WHEN E_NO_ACCESS THEN
        qv_access_p.not_permitted;

END process_form;


--------------------------------------------------------------------------------
--  Purpose:  Retrieve and show image
--------------------------------------------------------------------------------
PROCEDURE show_image (p_username IN VARCHAR2 DEFAULT NULL) IS
    l_uploaded_file     image_uploaded_file%ROWTYPE;
    l_no_photo  BFILE:= BFILENAME('QV_LABELS_DIR', 'dw-user-avatar.png');
    
BEGIN

    BEGIN
        
        SELECT *
          INTO l_uploaded_file
          FROM   image_uploaded_file
         WHERE  username = NVL(p_username, qv_audit.get_username);
  
        image_upload.show_image(l_uploaded_file.image, l_uploaded_file.file_mime_type);
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            image_upload.show_image(l_no_photo, 'image/jpg');
    END;    

END show_image;


--------------------------------------------------------------------------------
--  Purpose:  Retrieve and show QUT id card image
--------------------------------------------------------------------------------
PROCEDURE show_id_image (p_id       IN NUMBER   DEFAULT NULL
                        ,p_role_cd  IN VARCHAR2 DEFAULT NULL) IS

    l_id        NUMBER       := qv_common_id.get_user_id;
    l_role_cd   VARCHAR2(10) := qv_common_id.get_user_type;
    l_ip_num    ccr_clients.ip_num%TYPE;
    l_dir       VARCHAR2(100):= l_role_cd||'_ID_DIR';
    l_name      VARCHAR2(20) := '';
    l_photo     BFILE;
    l_no_photo  BFILE:= BFILENAME('QV_LABELS_DIR','dw-user-avatar.png');

BEGIN
    IF NOT (access_permitted OR (p_id IS NOT NULL AND p_role_cd IS NOT NULL AND qv_common_access.is_user_in_group('ALL_IMAGES'))) THEN
        RAISE E_NO_ACCESS;
    END IF;
      
    -- if the parameters are not null, it means that it it passing in by staff with ALL IMAGES privilege
    -- then replace the id and role code with the parameters
    IF (p_id IS NOT NULL AND p_role_cd IS NOT NULL) THEN
        l_id        := p_id;
        l_role_cd   := p_role_cd;
    END IF;

    IF l_role_cd = 'EMP' THEN
        -- get id card image file name
        l_name := 'S'||LPAD(l_id,8,0)||'.jpg';
    
    ELSIF p_role_cd = 'STU' THEN
        -- return student image name
        l_name := 'N'||LPAD(p_id,8,0)||'.jpg';

    ELSE
        -- get visitor id card image name
        SELECT  trs_client_id
        INTO    l_ip_num
        FROM    qv_client_role
        WHERE   role_cd   = 'CCR'
        AND     id = l_id;

        l_name := 'V'||LPAD(l_ip_num,8,0)||'.jpg';
        
    END IF;
        
    BEGIN
        l_photo := BFILENAME(l_dir,l_name);
        image_upload.show_image(l_photo, 'image/jpg');
        
    EXCEPTION
        WHEN OTHERS THEN
            image_upload.show_image(l_no_photo, 'image/jpg');
    END;
   
EXCEPTION
    WHEN E_NO_ACCESS THEN
        qv_access_p.not_permitted;
    
END show_id_image;

END image_upload_p;
/
