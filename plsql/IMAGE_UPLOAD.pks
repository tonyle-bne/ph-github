CREATE OR REPLACE PACKAGE           image_upload IS
/**
 * Business logic package for image_upload
 */
--------------------------------------------------------------------------------
--  Package Name: image_upload
--  Purpose:      Allows the staff to select or upload an image and use it as
--                their personal profile
--  Author:       Tony Le
--  Created:      7 Sept 2015
--
--  Specification Modification History
--  Date         Author           Description
--  -----------  ---------------- ----------------------------------------------
--
--------------------------------------------------------------------------------

C_VALID                 CONSTANT VARCHAR2(1)  := 'Y';
C_INVALID               CONSTANT VARCHAR2(1)  := 'N';
C_VALIDATE_INPUT        CONSTANT VARCHAR2(50) := 'validate_input';
C_EMPTY_VC_ARR          owa.vc_arr;

-- event types for logging      
C_ACTIVITY              CONSTANT VARCHAR2(15) := 'ACTIVITY'; 
C_ERROR                 CONSTANT VARCHAR2(15) := 'ERROR';
C_ALERT                 CONSTANT VARCHAR2(15) := 'ALERT';   


--------------------------------------------------------------------------------
-- Purpose: Render image in HTML from BFILE
-- Pre:     BFILE exists
-- Post:    BFILE content rendered in HTML
-- Param:   p_file - BFILE object
-- Param:   p_mime_type - Image MIME type
--------------------------------------------------------------------------------
PROCEDURE show_image(p_file IN OUT BFILE, p_mime_type VARCHAR2);

--------------------------------------------------------------------------------
-- Purpose: Render image in HTML from BLOB
-- Pre:     BLOB exists
-- Post:    BLOB content rendered in HTML
-- Param:   p_file - BLOB object
-- Param:   p_mime_type - Image MIME type
--------------------------------------------------------------------------------
PROCEDURE show_image(p_blob IN OUT BLOB, p_mime_type VARCHAR2);

PROCEDURE log_tracking_details (p_id_type      image_admin_log.id_type%TYPE DEFAULT NULL
                               ,p_id_value     image_admin_log.id_value%TYPE DEFAULT NULL
                               ,p_event_type   VARCHAR2
                               ,p_location     VARCHAR2
                               ,p_details      VARCHAR2);

--------------------------------------------------------------------------------
-- Purpose: Show image selection page
-- Pre:     None
-- Post:    None
--------------------------------------------------------------------------------
PROCEDURE show_edit_image (p_function_data    IN image_upload_p.varchar_array
                          ,p_local_data       IN image_upload_p.function_data DEFAULT image_upload_p.empty_arr);

--------------------------------------------------------------------------------
-- Purpose: Process and store image using the old method, as opposed to using p_function_data
-- Pre:     None
-- Post:    Image saved
--------------------------------------------------------------------------------
PROCEDURE process_image (p_arg_names  IN owa.vc_arr DEFAULT C_EMPTY_VC_ARR
                        ,p_arg_values IN owa.vc_arr DEFAULT C_EMPTY_VC_ARR);
                             
END image_upload;
/
