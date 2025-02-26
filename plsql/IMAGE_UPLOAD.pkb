CREATE OR REPLACE PACKAGE BODY           image_upload IS
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
--  26-Oct-2015  Tony Le          Fixed ORA-29400: data cartridge error
--                                      IMG-00002: unrecoverable error. I was using
--                                ROUND instead of CEIL and FLOOR when recalculating x, y, w, h
--                                Added 'waiting circle - Processing image...' on the modal window
--                                Redirected the user back to the image page and advise them to try
--                                again with a different image
--                                Improved logging and error messages in image_admin_log table
--  05-Nov-2015  Tony Le          Took another 1 pixel away from width and height when recalculating width
--                                and height again for scaled images
--  11-Dec-2015  Tony Le          Remove the white border around the image (QVEMP-45)
--  22-Mar-2017  Tony Le          QVEMP-51: Replaced reference code 'INTRANET_NAME' with 'STAFF_INTRANET_NAME'
--  04-Jun-2018  Tony Le          QVPH-44: Vertically aligned thumbnail image to middle
--------------------------------------------------------------------------------

--------------------------------------------
--            LOCAL CONSTANTS
--------------------------------------------

C_BUFFER_LENGTH CONSTANT PLS_INTEGER := 12000;

--------------------------------------------
--            GLOBAL VARIABLES
--------------------------------------------
    g_image_size_limit      NUMBER := qv_common_reference.get_reference_description ('IMG_SIZE_LIMIT_BYTES', 'QV'); -- in bytes
    g_display_max_width     NUMBER := qv_common_reference.get_reference_description ('IMG_MAX_DSP_WDTH_PIX', 'QV'); -- in pixels
    g_image_min_width_pix   NUMBER := qv_common_reference.get_reference_description ('IMG_MIN_WDTH_PIX', 'QV'); -- in pixels
    g_image_min_height_pix  NUMBER := qv_common_reference.get_reference_description ('IMG_MIN_HGHT_PIX', 'QV'); -- in pixels
    g_staff_intranet_name   qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('STAFF_INTRANET_NAME', 'QV');

--------------------------------------------
--            GLOBAL EXCEPTIONS
--------------------------------------------
    E_SAVE_FILE_ERR     EXCEPTION;
    

--------------------------------------------------------------------------------
-- LOCAL FUNCTION
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Purpose: Convert CLOB to BLOB
-- Pre:     CLOB exists
-- Post:    BLOB representation of the CLOB returned
-- Param:   p_blob - BLOB content
-- Return:  BLOB conversion of CLOB
--------------------------------------------------------------------------------
FUNCTION clob_to_blob(p_clob IN CLOB) RETURN BLOB IS
  l_result        BLOB;
  l_buffer_offset NUMBER DEFAULT 1;
  l_buffer_size   NUMBER DEFAULT C_BUFFER_LENGTH;
  l_write_length  NUMBER DEFAULT 1;
  l_read_length   NUMBER;
  l_buffer        VARCHAR2(C_BUFFER_LENGTH);
  
BEGIN
    dbms_lob.createtemporary(l_result, TRUE);
  
    BEGIN
        
        LOOP
            dbms_lob.read(p_clob, l_buffer_size, l_buffer_offset, l_buffer);
            l_read_length := utl_raw.length(utl_raw.cast_to_raw(l_buffer));

            dbms_lob.write(l_result, l_read_length, l_write_length, utl_raw.cast_to_raw(l_buffer));
            l_write_length := l_write_length + l_read_length;

            l_buffer_offset := l_buffer_offset + l_buffer_size;
      
        END LOOP;
    
    EXCEPTION
        WHEN no_data_found THEN
            NULL;
    END;
  
  RETURN l_result;
  
END clob_to_blob;    

--------------------------------------------------------------------------------
-- Purpose: Decode base64
-- Pre:     Base 64 encoded CLOB exists
-- Post:    Base 64 decoded representation of the CLOB returned
-- Param:   p_encoded - Base 64 encoded CLOB content
-- Return:  CLOB base 64 decoded
-------------------------------------------------------------------------------
FUNCTION base64_decode(p_encoded IN OUT NOCOPY CLOB) RETURN CLOB IS

    l_encoded_clean        CLOB;
	l_decoded_temp         BLOB;
    l_decoded              CLOB;

    l_encoded_length       INTEGER := dbms_lob.getlength(p_encoded);
    l_decoded_offset       INTEGER := 1;
    l_encoded_offset       INTEGER := 1;
    l_read_offset          INTEGER := 1;
    l_warning_message      INTEGER;
    l_default_lang_context INTEGER := dbms_lob.default_lang_ctx;
  
    l_raw_buffer           RAW(C_BUFFER_LENGTH);
    l_char_buffer          VARCHAR2(C_BUFFER_LENGTH);
    
BEGIN

    IF p_encoded IS NULL OR NVL(l_encoded_length, 0) = 0 THEN 
        RETURN NULL;
    
    ELSIF l_encoded_length <= 32000 THEN
        RETURN utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw(p_encoded)));
        
    END IF;        
        
    -- Remove new lines
    l_encoded_length := dbms_lob.getlength(p_encoded);
    dbms_lob.createtemporary(l_encoded_clean, TRUE);
    
    LOOP
        EXIT WHEN l_read_offset > l_encoded_length;
        l_char_buffer := REPLACE(REPLACE(dbms_lob.substr(p_encoded, C_BUFFER_LENGTH, l_read_offset), CHR(13), NULL), CHR(10), NULL);
        dbms_lob.writeappend(l_encoded_clean, LENGTH(l_char_buffer), l_char_buffer);
        l_read_offset := l_read_offset + C_BUFFER_LENGTH;
        
    END LOOP;

    l_read_offset := 1;
    l_encoded_length := dbms_lob.getlength(l_encoded_clean);
    dbms_lob.createtemporary(l_decoded_temp, TRUE);
    
    LOOP
        EXIT WHEN l_read_offset > l_encoded_length;
        l_raw_buffer := utl_encode.base64_decode(utl_raw.cast_to_raw(dbms_lob.substr(l_encoded_clean, C_BUFFER_LENGTH, l_read_offset)));
        dbms_lob.writeappend(l_decoded_temp, dbms_lob.getlength(l_raw_buffer), l_raw_buffer);
        l_read_offset := l_read_offset + C_BUFFER_LENGTH;
        
    END LOOP;

    dbms_lob.createtemporary(l_decoded, TRUE);
    dbms_lob.converttoclob(l_decoded, l_decoded_temp, dbms_lob.lobmaxsize, l_decoded_offset, l_encoded_offset,  dbms_lob.default_csid, l_default_lang_context, l_warning_message);

    dbms_lob.freetemporary(l_decoded_temp);
    dbms_lob.freetemporary(l_encoded_clean);
    
    RETURN l_decoded;    

END base64_decode;

--------------------------------------------------------------------------------
-- Get file details from the portal web_documents table
-- Param p_file_name must not be null
-- Return the file details and content
--------------------------------------------------------------------------------
FUNCTION get_web_documents (p_file_name VARCHAR2)
RETURN web_documents%ROWTYPE IS
    l_file              web_documents%ROWTYPE;
    l_file_name         VARCHAR2(500);

BEGIN

    BEGIN           
        SELECT name
              ,mime_type
              ,doc_size
              ,dad_charset
              ,last_updated 
              ,content_type
              ,blob_content
          INTO l_file   
          FROM (
               SELECT name
                     ,mime_type
                     ,doc_size
                     ,dad_charset
                     ,last_updated
                     ,content_type
                     ,blob_content
                     ,DENSE_RANK() OVER (PARTITION BY regexp_replace(name, '([^/]*[/])?(.*)$', '\2') ORDER BY last_updated DESC) AS last_updated_rank 
                 FROM web_documents 
                WHERE name = p_file_name
               ) 
         WHERE last_updated_rank = 1;
            
            
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_file := NULL;
        WHEN OTHERS THEN
            l_file := NULL;
    END;

    RETURN l_file;

END get_web_documents;


--------------------------------------------------------------------------------
-- LOCAL PROCEDURE
--------------------------------------------------------------------------------

PROCEDURE show_filestyle_js IS

BEGIN

    htp.p('
    
    <script type="text/javascript">
    <!--
    /*
     * bootstrap-filestyle
     * doc: http://markusslima.github.io/bootstrap-filestyle/
     * github: https://github.com/markusslima/bootstrap-filestyle
     *
     * Copyright (c) 2014 Markus Vinicius da Silva Lima
     * Version 1.2.1
     * Licensed under the MIT license.
     */
    (function($) {"use strict";

        var nextId = 0;

        var Filestyle = function(element, options) {
            this.options = options;
            this.$elementFilestyle = [];
            this.$element = $(element);
        };

        Filestyle.prototype = {
            clear : function() {
                this.$element.val("");
                this.$elementFilestyle.find(":text").val("");
                this.$elementFilestyle.find(".badge").remove();
            },

            destroy : function() {
                this.$element.removeAttr("style").removeData("filestyle");
                this.$elementFilestyle.remove();
            },

            disabled : function(value) {
                if (value === true) {
                    if (!this.options.disabled) {
                        this.$element.attr("disabled", "true");
                        this.$elementFilestyle.find("label").attr("disabled", "true");
                        this.options.disabled = true;
                    }
                } else if (value === false) {
                    if (this.options.disabled) {
                        this.$element.removeAttr("disabled");
                        this.$elementFilestyle.find("label").removeAttr("disabled");
                        this.options.disabled = false;
                    }
                } else {
                    return this.options.disabled;
                }
            },

            buttonBefore : function(value) {
                if (value === true) {
                    if (!this.options.buttonBefore) {
                        this.options.buttonBefore = true;
                        if (this.options.input) {
                            this.$elementFilestyle.remove();
                            this.constructor();
                            this.pushNameFiles();
                        }
                    }
                } else if (value === false) {
                    if (this.options.buttonBefore) {
                        this.options.buttonBefore = false;
                        if (this.options.input) {
                            this.$elementFilestyle.remove();
                            this.constructor();
                            this.pushNameFiles();
                        }
                    }
                } else {
                    return this.options.buttonBefore;
                }
            },

            icon : function(value) {
                if (value === true) {
                    if (!this.options.icon) {
                        this.options.icon = true;
                        this.$elementFilestyle.find("label").prepend(this.htmlIcon());
                    }
                } else if (value === false) {
                    if (this.options.icon) {
                        this.options.icon = false;
                        this.$elementFilestyle.find(".icon-span-filestyle").remove();
                    }
                } else {
                    return this.options.icon;
                }
            },
            
            input : function(value) {
                if (value === true) {
                    if (!this.options.input) {
                        this.options.input = true;

                        if (this.options.buttonBefore) {
                            this.$elementFilestyle.append(this.htmlInput());
                        } else {
                            this.$elementFilestyle.prepend(this.htmlInput());
                        }

                        this.$elementFilestyle.find(".badge").remove();

                        this.pushNameFiles();

                        this.$elementFilestyle.find(".group-span-filestyle").addClass("input-group-btn");
                    }
                } else if (value === false) {
                    if (this.options.input) {
                        this.options.input = false;
                        this.$elementFilestyle.find(":text").remove();
                        var files = this.pushNameFiles();
                        if (files.length > 0 && this.options.badge) {
                            this.$elementFilestyle.find("label").append(" <span class=\"badge\">" + files.length + "</span>");
                        }
                        this.$elementFilestyle.find(".group-span-filestyle").removeClass("input-group-btn");
                    }
                } else {
                    return this.options.input;
                }
            },

            size : function(value) {
                if (value !== undefined) {
                    var btn = this.$elementFilestyle.find("label"), input = this.$elementFilestyle.find("input");

                    btn.removeClass("btn-lg btn-sm");
                    input.removeClass("input-lg input-sm");
                    if (value != "nr") {
                        btn.addClass("btn-" + value);
                        input.addClass("input-" + value);
                    }
                } else {
                    return this.options.size;
                }
            },
            
            placeholder : function(value) {
                if (value !== undefined) {
                    this.options.placeholder = value;
                    this.$elementFilestyle.find("input").attr("placeholder", value);
                } else {
                    return this.options.placeholder;
                }
            },        

            buttonText : function(value) {
                if (value !== undefined) {
                    this.options.buttonText = value;
                    this.$elementFilestyle.find("label .buttonText").html(this.options.buttonText);
                } else {
                    return this.options.buttonText;
                }
            },
            
            buttonName : function(value) {
                if (value !== undefined) {
                    this.options.buttonName = value;
                    this.$elementFilestyle.find("label").attr({
                        "class" : "btn " + this.options.buttonName
                    });
                } else {
                    return this.options.buttonName;
                }
            },

            iconName : function(value) {
                if (value !== undefined) {
                    this.$elementFilestyle.find(".icon-span-filestyle").attr({
                        "class" : "icon-span-filestyle " + this.options.iconName
                    });
                } else {
                    return this.options.iconName;
                }
            },

            htmlIcon : function() {
                if (this.options.icon) {
                    return "<span class=\"icon-span-filestyle " + this.options.iconName + "\"></span> ";
                } else {
                    return "";
                }
            },

            htmlInput : function() {
                if (this.options.input) {
                    return "<input type=\"text\" class=\"form-control " + (this.options.size == "nr" ? "" : "input-" + this.options.size) + " placeholder=\"" + this.options.placeholder + "\" disabled> ";
                } else {
                    return "";
                }
            },

            // puts the name of the input files
            // return files
            pushNameFiles : function() {
                var content = "", files = [];
                if (this.$element[0].files === undefined) {
                    files[0] = {
                        "name" : this.$element[0] && this.$element[0].value
                    };
                } else {
                    files = this.$element[0].files;
                }

                for (var i = 0; i < files.length; i++) {
                    content += files[i].name.split("\\").pop() + ", ";
                }

                if (content !== "") {
                    this.$elementFilestyle.find(":text").val(content.replace(/\, $/g, ""));
                } else {
                    this.$elementFilestyle.find(":text").val("");
                }
                
                return files;
            },

            constructor : function() {
                var _self = this, 
                    html = "", 
                    id = _self.$element.attr("id"), 
                    files = [], 
                    btn = "", 
                    $label;

                if (id === "" || !id) {
                    id = "filestyle-" + nextId;
                    _self.$element.attr({
                        "id" : id
                    });
                    nextId++;
                }

                btn = "<span class=\"group-span-filestyle " + (_self.options.input ? "input-group-btn" : "") + "\">" + "<label for=\"" + id + "\" class=\"btn " + _self.options.buttonName + " " +  (_self.options.size == "nr" ? "" : "btn-" + _self.options.size) + "\" " + (_self.options.disabled ? "disabled=\"true\"" : "") + ">" + _self.htmlIcon() + "<span class=\"buttonText\">" + _self.options.buttonText + "</span>" + "</label>" + "</span>";
                
                html = _self.options.buttonBefore ? btn + _self.htmlInput() : _self.htmlInput() + btn;
                
                _self.$elementFilestyle = $("<div class=\"bootstrap-filestyle input-group\">" + html + "</div>");
                _self.$elementFilestyle.find(".group-span-filestyle").attr("tabindex", "0").keypress(function(e) {
                if (e.keyCode === 13 || e.charCode === 32) {
                    _self.$elementFilestyle.find("label").click();
                        return false;
                    }
                });

                // hidding input file and add filestyle
                _self.$element.css({
                    position : "absolute",
                    clip : "rect(0px 0px 0px 0px)" 
                }).attr("tabindex", "-1").after(_self.$elementFilestyle);

                if (_self.options.disabled) {
                    _self.$element.attr("disabled", "true");
                }

                // Getting input file value
                _self.$element.change(function() {
                    var files = _self.pushNameFiles();

                    if (_self.options.input == false && _self.options.badge) {
                        if (_self.$elementFilestyle.find(".badge").length == 0) {
                            _self.$elementFilestyle.find("label").append(" <span class=\"badge\">" + files.length + "</span>");
                        } else if (files.length == 0) {
                            _self.$elementFilestyle.find(".badge").remove();
                        } else {
                            _self.$elementFilestyle.find(".badge").html(files.length);
                        }
                    } else {
                        _self.$elementFilestyle.find(".badge").remove();
                    }
                });

                // Check if browser is Firefox
                if (window.navigator.userAgent.search(/firefox/i) > -1) {
                    // Simulating choose file for firefox
                    _self.$elementFilestyle.find("label").click(function() {
                        _self.$element.click();
                        return false;
                    });
                }
            }
        };

        var old = $.fn.filestyle;

        $.fn.filestyle = function(option, value) {
            var get = "", element = this.each(function() {
                if ($(this).attr("type") === "file") {
                    var $this = $(this), data = $this.data("filestyle"), options = $.extend({}, $.fn.filestyle.defaults, option, typeof option === "object" && option);

                    if (!data) {
                        $this.data("filestyle", ( data = new Filestyle(this, options)));
                        data.constructor();
                    }

                    if ( typeof option === "string") {
                        get = data[option](value);
                    }
                }
            });

            if ( typeof get !== undefined) {
                return get;
            } else {
                return element;
            }
        };

        $.fn.filestyle.defaults = {
            buttonText : "Choose file",
            iconName : "glyphicon glyphicon-folder-open",
            buttonName : "btn-default",
            size : "nr",
            input : true,
            badge : true,
            icon : true,
            buttonBefore : false,
            disabled : false,
            placeholder: "File name"
        };

        $.fn.filestyle.noConflict = function() {
            $.fn.filestyle = old;
            return this;
        };

        $(function() {
            $(".filestyle").each(function() {
                var $this = $(this), options = {

                    input : $this.attr("data-input") === "false" ? false : true,
                    icon : $this.attr("data-icon") === "false" ? false : true,
                    buttonBefore : $this.attr("data-buttonBefore") === "true" ? true : false,
                    disabled : $this.attr("data-disabled") === "true" ? true : false,
                    size : $this.attr("data-size"),
                    buttonText : $this.attr("data-buttonText"),
                    buttonName : $this.attr("data-buttonName"),
                    iconName : $this.attr("data-iconName"),
                    badge : $this.attr("data-badge") === "false" ? false : true,
                    placeholder: $this.attr("data-placeholder")
                };

                $this.filestyle(options);
            });
        });
    })(window.jQuery);
        -->
        </script>
    
    
    ');

END show_filestyle_js;


PROCEDURE show_local_js (p_form_name    IN VARCHAR2) IS

    l_img_review_width      qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_REVIEW_WDTH', 'QV');

BEGIN

    
    htp.p('
    
    <script type="text/javascript">
    <!--
    $(document).ready(function () {');

    -- enforce checked property on the radio button
    IF (qv_common_image.get_display_image_type = qv_common_image.C_UPLOADED_IMAGE) THEN
        htp.p('$("#prev_image").prop("checked", true);');
    ELSE
        htp.p('$("#id_card_image").prop("checked", true);');    
    END IF;
    
        
    htp.p(' // disabled Submit button when the form first loaded
        $("#submit_button").prop("disabled",true);
        $("#imageConditions").hide();
        $("#agree").prop("disabled",false);
        
        // reset review and edit area
        showHideImageReview ();
             
        highlightSelection ();
        
        function readURL(file) {
            var reader = new FileReader();                
            var image = new Image();
            var errMsg = "";
            var fileType = file["type"];
            var validFileTypes = ["image/jpg", "image/jpeg", "image/png"];
            reader.readAsDataURL(file);

            if ($.inArray(fileType, validFileTypes) < 0) {
            
                // those two lines below will clear all the previous selection
                // before a new photo is selected
                $(".imgareaselect-selection").parent().remove();
                $(".imgareaselect-outer").remove();
                
                // if file type is not jpg and png then display error message
                $("#errormsg").html("<div class=\"alert warning-msg warning-msg-background\">The file you have selected is invalid. Only image with extension <em>.jpg</em>, <em>.jpeg</em> or <em>.png</em> (e.g. myimage.jpg) is allowed.</div>");
                $("#photoframe").empty();
                $("#cropinstruction").hide();
                $("#submit_button").prop("disabled",true);

            } else {
                reader.onload = function (_file) {
                    image.src = _file.target.result;
                    image.onload = function () {
                        // those two lines below will clear all the previous selection
                        // before a new photo is selected
                        $(".imgareaselect-selection").parent().remove();
                        $(".imgareaselect-outer").remove();
              
                        var originalImage = $("#original-image");
                        originalImage.attr("src", image.src);
                        originalImage.attr("width", image.width);
                        originalImage.attr("height", image.height);
            
                        if ((image.width <= '|| g_display_max_width ||') && (file.size <= '|| g_image_size_limit ||') && (image.width >= '|| g_image_min_width_pix || ') && (image.height >= '|| g_image_min_height_pix ||')) {
                            // if image is less than the displaying frame allowed and file size is less the limit,
                            // and both width and height is greater than the minimum width and height, then show the photos without compression
                                                       
                            $("#errormsg").html("");   // clear any error message
                            $("<img id=\"photo\" alt=\"New profile image\" src=\"\" width=\"0\"/>").appendTo("#photoframe");  // add img html tag      
                            $("#photo").attr("width", image.width); // assign width = real size image width
                            $("#photo").attr("src", image.src);  // give image tag a src
                            

                            $("#submit_button").prop("disabled",false); // turn the submit button on

                            // defining image area select
                            $("#photo").imgAreaSelect({
                                aspectRatio: ''1:1'',
                                fadeSpeed: 200, 
                                handles: true,
                                minHeight: '|| g_image_min_height_pix ||',  // minimum height of the cropping photo
                                minWidth: '|| g_image_min_width_pix ||',    // minimum width of the cropping photo
                                movable: true, // move the cropping selection around on the photo
                                remove: false, // turn plugin back on again
                                show: true,
                                x1: 0,
                                y1: 0,
                                x2: '|| g_image_min_width_pix ||',
                                y2: '|| g_image_min_height_pix ||',
                                onSelectChange: getCoordinates,
                                onInit: getCoordinates
                            });

                              

                        } else if ((image.width > '|| g_display_max_width ||') && (file.size <= '|| g_image_size_limit ||') && (image.width >= '|| g_image_min_width_pix || ') && (image.height >= '|| g_image_min_height_pix ||')) {
                            // if image is greater than the frame allowed and the size is less than size limit, 
                            // and both image width and height is greater than the minimum width and height, then show the compressed version of it
                            $("#errormsg").html("");            // clear the error message first
                            $(''<img id="photo" alt="New profile image" src="" width="0"/>'').appendTo("#photoframe");        
                            $("#photo").attr("width", '|| g_display_max_width ||'); // assign width = allowable display frame (in pixels) 
                            $("#photo").attr("src", image.src); // show image
                            $("#submit_button").prop("disabled",false);

                            // defining image area select
                            $("#photo").imgAreaSelect({
                                aspectRatio: ''1:1'',
                                fadeSpeed: 200, 
                                handles: true,
                                minHeight: '|| g_image_min_height_pix ||',  // minimum height of the cropping photo
                                minWidth: '|| g_image_min_width_pix ||',    // minimum width of the cropping photo
                                movable: true, // move the cropping selection around on the photo
                                remove: false, // turn plugin back on again
                                show: true,
                                x1: 0,
                                y1: 0,
                                x2: '|| g_image_min_width_pix ||',
                                y2: '|| g_image_min_height_pix ||',
                                onSelectChange: getCoordinates,
                                onInit: getCoordinates
                            });

                        } else {
                            if (file.size > '|| g_image_size_limit ||') {
                                errMsg += "<div class=\"alert warning-msg warning-msg-background\">Your image is too big. Only image with '|| (g_image_size_limit/1024)/1024 ||'Mb (or '|| (g_image_size_limit/1024) ||'Kb) or less in size is allowed.</div>";
                            } else if ((image.width < '|| g_image_min_width_pix ||') || (image.height < '|| g_image_min_height_pix ||')) {
                                errMsg += "<div class=\"alert warning-msg warning-msg-background\">Your image is too small. The minimum recommended dimensions are '|| g_image_min_width_pix ||' pixels in width and '|| g_image_min_height_pix || ' pixel in height. Please try again with a larger image.</div>";
                            } else {
                                errMsg += "<div class=\"alert warning-msg warning-msg-background\">There was an error while processing your image. Please try again with a different image.</div>";
                            }
                            $("#photoframe").empty();
                            $("#cropinstruction").hide();
                            $("#errormsg").html(errMsg);
                            $("#submit_button").prop("disabled",true);
                        }
                        
                    }
                }
            }
        }

        // clear all image edit selection area
        $("#id_card_image, #prev_image").change(function(){
            $("#photoframe").empty();
            $("#cropinstruction").hide();
            // those two lines below will clear all the previous selection
            // before a new photo is selected
            showHideImageReview();
            highlightSelection ();
            $(".imgareaselect-selection").parent().remove();
            $(".imgareaselect-outer").remove();
            $("#imgInp").val("");
            $("#errormsg").html("");            // clear the error message first
        });

        $("#new_image, #prev_image").change(function(){
            highlightSelection ();
        });

        $("#imgInp").change(function() {            
            $("#photoframe").empty();
            $("#cropinstruction").show();

            // set radio button to checked
            $("#new_image").prop("checked", true);

                
            if(this.disabled) return alert("Image upload not supported!");
            var fle = this.files;
            if (fle && fle[0]) {
                for (var i=0; i<fle.length; i++) { 
                    readURL( fle[i] );
                }
            } else {

                //for the nuisance of IE9
                var errMsg = "";
                var image = new Image();
                image.src = document.getElementById("imgInp").value;
                var ext = $("#imgInp").val().split(".").pop().toLowerCase();
                $(''<img id="photo" alt="New profile image" src="" width="0"/>'').appendTo("#photoframe");        

                image.onload = function () {
                    // those two lines below will clear all the previous selection
                    // before a new photo is selected
                    $(".imgareaselect-selection").parent().remove();
                    $(".imgareaselect-outer").remove();
                    var imageWidth  = this.width;
                    var imageHeight = this.height;
                    
                    

                    if ((ext == "jpg") || (ext == "png") || (ext == "jpeg")) {
                  

                        if ((imageWidth <= '|| g_display_max_width ||') && (image.fileSize <= '|| g_image_size_limit ||') && (imageWidth >= '|| g_image_min_width_pix || ') && (imageHeight >= '|| g_image_min_height_pix ||')) {
                            // if image is less than the displaying frame allowed and file size is less the limit,
                            // and both width and height is greater than the minimum width and height, then show the photos without compression
                            $("#errormsg").html("");   // clear any error message
                            $("<img id=\"photo\" alt=\"New profile image\" src=\"\" width=\"0\"/>").appendTo("#photoframe");  // add img html tag      
                            $("#photo").attr("width", imageWidth); // assign width = real size image width
                            $("#photo").attr("src", image.src);  // give image tag a src
                            $("#submit_button").prop("disabled",false); // turn the submit button on

                            // defining image area select
                            $("#photo").imgAreaSelect({
                                aspectRatio: ''1:1'',
                                fadeSpeed: 200, 
                                handles: true,
                                minHeight: '|| g_image_min_height_pix ||',  // minimum height of the cropping photo
                                minWidth: '|| g_image_min_width_pix ||',    // minimum width of the cropping photo
                                movable: true, // move the cropping selection around on the photo
                                remove: false, // turn plugin back on again
                                show: true,
                                x1: 0,
                                y1: 0,
                                x2: '|| g_image_min_width_pix ||',
                                y2: '|| g_image_min_height_pix ||',
                                onSelectChange: getCoordinates,
                                onInit: getCoordinates
                            });
                            
                

                        } else if ((imageWidth > '|| g_display_max_width ||') && (this.fileSize <= '|| g_image_size_limit ||') && (imageWidth >= '|| g_image_min_width_pix || ') && (imageHeight >= '|| g_image_min_height_pix ||')) {
                            // if image is greater than the frame allowed and the size is less than size limit, 
                            // and both image width and height is greater than the minimum width and height, then show the compressed version of it
                            $("#errormsg").html("");            // clear the error message first
                            $(''<img id="photo" alt="New profile image" src="" width="0"/>'').appendTo("#photoframe");        
                            $("#photo").attr("width", '|| g_display_max_width ||'); // assign width = allowable display frame (in pixels) 
                            $("#photo").attr("src", image.src); // show image
                            $("#submit_button").prop("disabled",false);

                            // defining image area select
                            $("#photo").imgAreaSelect({
                                aspectRatio: ''1:1'',
                                fadeSpeed: 200, 
                                handles: true,
                                minHeight: '|| g_image_min_height_pix ||',  // minimum height of the cropping photo
                                minWidth: '|| g_image_min_width_pix ||',    // minimum width of the cropping photo
                                movable: true, // move the cropping selection around on the photo
                                remove: false, // turn plugin back on again
                                show: true,
                                x1: 0,
                                y1: 0,
                                x2: '|| g_image_min_width_pix ||',
                                y2: '|| g_image_min_height_pix ||',
                                onSelectChange: getCoordinates,
                                onInit: getCoordinates
                            });
                        } else {                     

                            if (image.fileSize > '|| g_image_size_limit ||') {
                                errMsg += "<div class=\"alert warning-msg warning-msg-background\">Your image is too big. Only image with '|| (g_image_size_limit/1024)/1024 ||'Mb (or '|| (g_image_size_limit/1024) ||'Kb) or less in size is allowed.</div>";
                            } else if ((imageWidth < '|| g_image_min_width_pix ||') || (imageHeight < '|| g_image_min_height_pix ||')) {
                                errMsg += "<div class=\"alert warning-msg warning-msg-background\">Your image is too small. The minimum recommended dimensions are '|| g_image_min_width_pix ||' pixels in width and '|| g_image_min_height_pix || ' pixel in height. Please try again with a larger image.</div>";
                            } else {
                                errMsg += "<div class=\"alert warning-msg warning-msg-background\">There was an error while processing your image. Please try again with a different image.</div>";
                            }
                            $("#photoframe").empty();
                            $("#cropinstruction").hide();
                            $("#errormsg").html(errMsg);
                            $("#submit_button").prop("disabled",true);
                        }

                    } else {
                                    
                        // those two lines below will clear all the previous selection
                        // before a new photo is selected
                        $(".imgareaselect-selection").parent().remove();
                        $(".imgareaselect-outer").remove();
                        
                        // if file type is not jpg and png then display error message
                        $("#errormsg").html("<div class=\"alert warning-msg warning-msg-background\">The file you have selected is invalid. Only image with extension <em>.jpg</em>, <em>.jpeg</em> or <em>.png</em> (e.g. myimage.jpg) is allowed.</div>");
                        $("#photoframe").empty();
                        $("#cropinstruction").hide();
                        $("#submit_button").prop("disabled",true);
                
                    }
                } 
            }
            
        });

        // the timeout is required otherwise safari and delay everything once submit is called
        $( "#agree" ).click(function() {
            $("#search_overlay").show(); 
            $("#agree").prop("disabled",true);
            setTimeout(function() {
                saveForm();
            }, 100); 
        });

        $( "#disagree, .close").click(function() {
            $("#search_overlay").hide(); 
            $("#agree").prop("disabled",false);
        });

        $("#imgInp").click(function(){
            // set radio button to checked
            $("#new_image").prop("checked", true);
            showHideImageReview ();            
        });

        $( "#submit_button" ).click(function(e) {
            e.preventDefault();
            if ($("#'|| p_form_name ||'").valid()) {
                if($("input[name=''p_image_type'']:checked").val() == "new_image") {
                    $("#condsAcceptance").modal("show");
                } else {
                    saveForm();
                }                
            } 
        });

        $( "#condsOfUse" ).click(function() {
            $("#imageConditions").toggle();
        });
        
        function cropImage(img, selection) {
            var originalImage = document.getElementById("original-image");

            var canvas=document.createElement("canvas");
            var context=canvas.getContext("2d");
            canvas.width = selection.width;
            canvas.height = selection.height;
            context.drawImage(originalImage,
                              originalImage.width / img.width * selection.x1,
                              originalImage.height / img.height * selection.y1,
                              originalImage.width / img.width * selection.width,
                              originalImage.height / img.height * selection.height,                
                              0,
                              0,
                              selection.width,
                              selection.height
                              );           
                       
            $("#p_image").val(canvas.toDataURL());                       
        }
        
        function saveForm() {
            var formData = new FormData();
            var imageType = $("input[name=p_image_type]:checked").val();
            formData.append("p_image_type", imageType);

            if(imageType == "new_image") {
                var mimeType = document.getElementById("photo").src.split(/[;:]/)[1];
                formData.append("p_mime_type", mimeType);
                formData.append("p_image", new Blob([document.getElementById("p_image").value.split("base64,")[1]]), "profile." + mimeType);
            }
                        
            var url = "'|| common_template.C_HOME || '!image_upload_p.process_form";
            var xhr = new XMLHttpRequest();
            xhr.open("POST", url, true);            
            xhr.onload = () => { window.location.href = "'|| qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_URL') ||'/group/staff/personal-profile"; }
            xhr.send(formData);        
        }

        function getCoordinates(img, selection) {        
            if (!selection.width || !selection.height) {            
                // disable submit button if no selection has been made
                $("#submit_button").prop("disabled",true);
                return;

            } else {             
                cropImage(img, selection); 
            }
        }
        
    });
    
    
    function showHideImageReview () {
        // show image frame based on what option the user is selecting
        if ($("input[name=''p_image_type'']:checked").val() == "new_image") {
            $("#editarea").show();        
            $("#submit_button").prop("disabled",true);

       } else if (($("input[name=''p_image_type'']:checked").val() == "id_card_image") || ($("input[name=''p_image_type'']:checked").val() == "prev_image")){
            $("#editarea").hide();        
            $("#cropinstruction").hide();
            $("#submit_button").prop("disabled",false);

       } else { 
            $("#editarea").hide();        
            $("#cropinstruction").hide();
            $("#submit_button").prop("disabled",true);
        }
    }

    function highlightSelection () {
        // highlight the selection
        if ($("input[name=''p_image_type'']:checked").val() == "new_image") {
            $("#cell1").css("background-color", "transparent");       
            $("#cell2").css("background-color", "transparent");       
            $("#cell3").css("background-color", "#F2F6F9");       

       } else if ($("input[name=''p_image_type'']:checked").val() == "id_card_image") {
            $("#cell1").css("background-color", "transparent");       
            $("#cell2").css("background-color", "#F2F6F9");       
            $("#cell3").css("background-color", "transparent");       

       } else if ($("input[name=''p_image_type'']:checked").val() == "prev_image") { 
            $("#cell1").css("background-color", "#F2F6F9");       
            $("#cell2").css("background-color", "transparent");       
            $("#cell3").css("background-color", "transparent");       
        }
    }

    -->
    </script>
    ');
    
    htp.p('
    <style type="text/css">
    <!--
    .reviewimage {
        padding:3px;
    }
    .valignmiddle {
        display: inline-block;
        vertical-align: middle;
    }    
    #show_edit_form .fa-upload {
      color: #333;
      padding: 13px 15px !important;
    }
    #show_edit_form label {
        margin-bottom: 0;
    }
    #show_edit_form .controls input {
        margin-left: 10px;
        margin-right: 10px;
    }
    #show_edit_form .reviewimage {
        margin-right: 10px;
    }
    #show_edit_form #editarea {
        margin: 0 35px 25px;
    }
    #show_edit_form .group-span-filestyle.input-group-btn {
        margin-left: 0;
    }
    #show_edit_form #editarea .alert {
          margin-bottom: 10px;
    }
    #show_edit_form #editarea ul {
        margin-left: 0;
    }
    #show_edit_form #condsAcceptance #imageConditions {
        margin: 0px 15px 15px;
    }
    #show_edit_form #condsAcceptance ul {
        margin-left: 0;
    }
    #search_overlay {
        display: none;
        margin-top: 5px;
        margin-bottom: 5px;
    }
    #search_overlay_text {
        color: #1C5B8A;
        font: bold 12px Verdana, Arial, sans-serif;
        margin-left: 5px;
    }
    -->
    </style>
    ');
    

END show_local_js;


--------------------------------------------------------------------------------
-- Delete files from the portal web_documents table
-- Param p_file_name must not be null
-- Return file with p_file_name deleted
--------------------------------------------------------------------------------
PROCEDURE delete_web_document_file (p_file_name     VARCHAR2)
IS

    l_file_name         VARCHAR2(500);

BEGIN

    l_file_name := LOWER(p_file_name);

    BEGIN
        DELETE  web_documents
        WHERE  (TRIM(LOWER(SUBSTR(name, INSTR(name, '/') + 1))) = l_file_name
            OR  TRIM(LOWER(name)) = l_file_name);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
        WHEN OTHERS THEN
            NULL;
    END;

--    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        NULL; -- it doesn't matter if the file could not be deleted from web_documents table
              -- as this will be cleaned out periodically
END delete_web_document_file;


--------------------------------------------------------------------------------
-- GLOBAL PROCEDURE
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Purpose: Render image in HTML from BFILE
-- Pre:     BFILE exists
-- Post:    BFILE content rendered in HTML
-- Param:   p_file - BFILE object
-- Param:   p_mime_type - Image MIME type
--------------------------------------------------------------------------------
PROCEDURE show_image(p_file IN OUT BFILE, p_mime_type VARCHAR2) IS
BEGIN

    htp.init;
    htp.p('Content-Length: ' || dbms_lob.getlength(p_file));
    owa_util.mime_header(p_mime_type, FALSE);
    wpg_docload.download_file(p_file);
    owa_util.http_header_close;

END;

--------------------------------------------------------------------------------
-- Purpose: Render image in HTML from BLOB
-- Pre:     BLOB exists
-- Post:    BLOB content rendered in HTML
-- Param:   p_file - BLOB object
-- Param:   p_mime_type - Image MIME type
--------------------------------------------------------------------------------
PROCEDURE show_image(p_blob IN OUT BLOB, p_mime_type VARCHAR2) IS
BEGIN

    htp.init;
    htp.p('Content-Length: ' || dbms_lob.getlength(p_blob));
    owa_util.mime_header(p_mime_type, FALSE);
    wpg_docload.download_file(p_blob);
    owa_util.http_header_close;

END;


PROCEDURE log_tracking_details (p_id_type      image_admin_log.id_type%TYPE DEFAULT NULL
                               ,p_id_value     image_admin_log.id_value%TYPE DEFAULT NULL
                               ,p_event_type   VARCHAR2
                               ,p_location     VARCHAR2
                               ,p_details      VARCHAR2)
IS    
    -- Make this procedure's updates independent of the calling function's / procedure's commit / rollback.
    PRAGMA          AUTONOMOUS_TRANSACTION;    
    l_username      image_admin_log.create_who%TYPE  := qv_common_id.get_username;
    l_full_desc     VARCHAR2(4000);

BEGIN 
    
    IF l_username IS NULL THEN
        l_username := USER; -- for automated processes 
    END IF;
    
    IF p_event_type = C_ERROR THEN
    
        l_full_desc := SUBSTR(p_details ||' | SQLCODE=' || SQLCODE ||' | SQLERRM=' || SQLERRM || ' |  Error Stack=' || DBMS_UTILITY.format_error_stack  ||' | Error Trace=' || DBMS_UTILITY.format_error_backtrace ,1,4000); 

    ELSE
    
        l_full_desc := p_details;
   
    END IF;
    
    INSERT INTO image_admin_log
               (event_timestamp
               ,id_type
               ,id_value
               ,event_type
               ,sys_location
               ,details
               ,create_who
               ,create_dt)
        VALUES (SYSTIMESTAMP
               ,p_id_type
               ,p_id_value
               ,p_event_type
               ,p_location
               ,SUBSTR(l_full_desc,1,4000)
               ,l_username
               ,SYSDATE);
                   
     COMMIT;
    
EXCEPTION

    WHEN OTHERS THEN
        ROLLBACK; 

END log_tracking_details; 

--------------------------------------------------------------------------------
-- Purpose: Show some data input form
-- Pre:     Pre conditions
-- Post:    Post conditions
--------------------------------------------------------------------------------
PROCEDURE show_edit_image (p_function_data    IN image_upload_p.varchar_array
                          ,p_local_data       IN image_upload_p.function_data DEFAULT image_upload_p.empty_arr)
IS

    l_system_msg            VARCHAR2(100) := p_function_data (image_upload_p.C_SYSTEM_MSG);
    l_site_url              VARCHAR2(100) DEFAULT qv_common_links.get_reference_link('QUTVIRTUAL_URL');
    l_img_conditions_1      qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_CONDITIONS_1', 'QV');
    l_img_conditions_2_p1   qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_CONDITIONS_2_P1', 'QV');
    l_img_conditions_2_p2   qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_CONDITIONS_2_P2', 'QV');
    l_img_conditions_2_p3   qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_CONDITIONS_2_P3', 'QV');
    l_img_conditions_2_p4   qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_CONDITIONS_2_P4', 'QV');
    l_img_conditions_3      qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_CONDITIONS_3', 'QV');
    l_img_conditions_4      qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_CONDITIONS_4', 'QV');
    l_img_review_width      qv_reference_cd.description%TYPE := qv_common_reference.get_reference_description ('IMG_REVIEW_WDTH', 'QV');
    l_portal_url            VARCHAR2(100) DEFAULT qv_common_links.get_reference_link('QUTVIRTUAL_PORTAL_URL');
    
BEGIN


    htp.p('<link rel="stylesheet" href="/css/qut/imgareaselect.css" type="text/css"/>');
    htp.p('<script type="text/javascript" src="/js/qut/imgareaselect.js"></script>');
    show_filestyle_js;
    show_local_js (p_form_name => image_upload_p.C_SHOW_EDIT_IMAGE);  -- required locally
    
    htp.p('<h1>'|| image_upload_p.C_PAGE_TITLE ||'</h1>');
    
    IF (l_system_msg IS NOT NULL) THEN
        htp.p('          <div id="othererrormsg"><div class="alert warning-msg warning-msg-background">');
        htp.p('          The system has encountered an issue while processing your image. Please try again with a different image.');
        htp.p('          </div></div>');
    
    END IF;

    htp.p('<p>Select which profile image you would like to use within the '|| g_staff_intranet_name ||':</p>');
    htp.p('<table class="table table-bordered">'); 
    htp.p('  <tbody>');

    IF (qv_common_image.has_uploaded_image) THEN
        htp.p('    <tr>');
        htp.p('      <td id="cell1">');
        htp.p('        <div class="controls"><label for="prev_image">');
        htp.p('          <input type="radio" name="p_image_type" id="prev_image" value="prev_image">');
        htp.p('          <img src="image_upload_p.show_image" alt="" width="'|| l_img_review_width ||'" class="reviewimage valignmiddle">');
        htp.p(           g_staff_intranet_name ||' profile image');
        
        IF (qv_common_image.get_display_image_type = qv_common_image.C_UPLOADED_IMAGE) THEN
            htp.p(' <strong>(your current profile image)</strong>');
        END IF;
        
        htp.p('        </label></div>');
        htp.p('      </td>');
        htp.p('    </tr>');
    END IF;
    htp.p('    <tr>');
    htp.p('      <td id="cell2">');
    htp.p('        <div class="controls"><label for="id_card_image">');
    htp.p('          <input type="radio" name="p_image_type" id="id_card_image" value="id_card_image"><br>');
    htp.p('          <img src="image_upload_p.show_id_image" alt="" width="'|| l_img_review_width ||'" class="reviewimage valignmiddle">');
    htp.p('          QUT ID card image');
    IF (qv_common_image.get_display_image_type = qv_common_image.C_ID_CARD_IMAGE) THEN
        htp.p(' <strong>(your current profile image)</strong>');
    END IF;
    htp.p('        </label></div>');
    htp.p('      </td>');
    htp.p('    </tr>');
    htp.p('    <tr>');
    htp.p('      <td id="cell3">');
    htp.p('        <div class="controls">');
    htp.p('          <input type="radio" name="p_image_type" id="new_image" value="new_image" onChange="showHideImageReview();"><br>');
    htp.p('          <span class="valignmiddle"><i class="fa fa-upload fa-3x reviewimage"></i></span>');
    htp.p('          <label for="new_image">Upload a new profile image');
    htp.p('        </label></div>');
    htp.p('        </div>');

    htp.p('        <div id="editarea">');
    htp.p('          <p></p>');
    htp.p('          <div id="errormsg"></div>');
    htp.p('          <div class="alert important-msg important-msg-background">' 
                     || l_img_conditions_1 || ' ' 
                     || l_img_conditions_2_p1 || ' ' || l_img_conditions_2_p2 || ' ' || l_img_conditions_2_p3 || ' ' || l_img_conditions_2_p4 || '</div>');
    htp.p('          <input type="file" id="imgInp" name="image_file_upload" accept="image/*" class="filestyle"  data-icon="false" data-buttonText="Select image">');
    htp.p('          <p></p>');

    htp.p('          <p id="cropinstruction">To crop your profile image, drag the highlighted box below and click ''Save''.</p>');
    htp.p('          <div id="photoframe"></div>');
    htp.p('        </div>');
    htp.p('        </form>');
    
    htp.p('      </td>');
    htp.p('    </tr>');
    htp.p('  </tbody>');
    htp.p('</table>');
    -- Form isn't submitted just used as a place holder. Image is submitted using AJAX (saveForm)
    htp.p('<form name="'|| image_upload_p.C_SHOW_EDIT_IMAGE ||'" id="'|| image_upload_p.C_SHOW_EDIT_IMAGE ||'" method="get" action="'||get_schema_link||'image_upload_p.start_function">');
    htp.p('<div class="form-actions"><button class="btn btn-custom" id="submit_button">Save</button>');
    htp.p('<button type="button" class="btn" onClick="location.href='''||l_portal_url||'/group/staff/personal-profile''">Cancel</button></div>');
    htp.p('</form>');

    htp.p('<input type="hidden" name="p_image" id="p_image" value="">');
    htp.p('<div id="condsAcceptance" class="modal hide fade" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">');
    htp.p('  <div class="modal-header">');
    htp.p('    <button aria-hidden="true" data-dismiss="modal" class="close" type="button">&times;</button>');
    htp.p('    <h3 id="myModalLabel">Profile image upload conditions.</h3>');
    htp.p('  </div>');
    htp.p('  <div class="modal-body">');
    htp.p('    <p>'|| l_img_conditions_4 ||'</p>'); 
    htp.p('    <p>'|| l_img_conditions_3 ||'</p>'); 
    htp.p('  </div>');
    htp.p('  <div class="alert important-msg important-msg-background" id="imageConditions">' 
             || l_img_conditions_1 || ' ' 
             || l_img_conditions_2_p1 || ' ' || l_img_conditions_2_p2 || ' ' || l_img_conditions_2_p3 || ' ' || l_img_conditions_2_p4 || '</div>');

     -- Submitting form  overlay
    htp.p('  <div class="modal-footer">');
    htp.p('  <div id="search_overlay"><i class="fa fa-spinner fa-spin"></i><span id="search_overlay_text">Processing image...</span></div>');
    htp.p('    <button class="btn btn-custom" id="agree">I agree</button>');
    htp.p('    <button class="btn" data-dismiss="modal" aria-hidden="true" id="disagree">I don''t agree</button>'); 
    htp.p('  </div>');
    htp.p('</div>');   
    
    htp.p('<img id="original-image" style="display: none"/>');
    
EXCEPTION    
    WHEN OTHERS THEN
        -- log exception
        -- it highly recommended that you should log all exception into
        -- a log admin error for the application using similar method as below
        log_tracking_details(p_id_type    => 'USERNAME'
                            ,p_id_value   =>  qv_audit.get_username
                            ,p_event_type =>  C_ERROR
                            ,p_location   => 'image_upload.show_edit_image'
                            ,p_details    => 'Unexpected exception raised ' || SQLERRM);
                                    
END show_edit_image;


PROCEDURE process_image (p_arg_names  IN owa.vc_arr DEFAULT C_EMPTY_VC_ARR
                        ,p_arg_values IN owa.vc_arr DEFAULT C_EMPTY_VC_ARR)
IS
    l_image_type          VARCHAR2(50);
    l_image_file_name     VARCHAR2(200);
    l_success             VARCHAR2(1000) := '';
    l_function_data       image_upload_p.varchar_array;
    l_local_data          image_upload_p.function_data;
    l_username            qv_client_role.username%TYPE := qv_audit.get_username;
    l_tracking_detail_msg VARCHAR2(200);
    l_display_ind         CHAR(1);
    
    
    -- local function to retrieve value
    FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        RETURN common_utils.get_string(p_arg_names, p_arg_values, p_name);
    END get_value;

    PROCEDURE save_file (p_file_name        VARCHAR2
                        ,p_mime_type VARCHAR2
                        ,p_success      OUT VARCHAR2)
    IS

        l_file              web_documents%ROWTYPE;
        l_value             VARCHAR2(1000);
        l_file_name         VARCHAR2(500);
        l_image CLOB;
        l_image_blob BLOB;
        

    BEGIN
    
        -- Delete the old image first
        DELETE  image_uploaded_file
        WHERE   username = l_username;
        
        l_file := get_web_documents (p_file_name);
        l_image := apex_web_service.blob2clobbase64(l_file.blob_content);
        l_image := base64_decode(l_image);
        l_image := base64_decode(l_image);
        l_image_blob := clob_to_blob(l_image);
        
        INSERT 
        INTO image_uploaded_file 
               (username
               ,file_name
               ,file_content
               ,file_mime_type
               ,accept_ind
               ,display_ind
               ,image)
        VALUES (l_username
               ,p_file_name
               ,NULL
               ,p_mime_type
               ,'Y'
               ,'Y'
               ,l_image_blob);
               
        -- clean up file in web_documents after transferring the file across
        delete_web_document_file (l_file.name);

        p_success := 'Y';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_success := SUBSTR(SQLERRM, 1, 1000);
    END save_file;
    
    PROCEDURE delete_opting_out IS
    
    BEGIN
    
        DELETE qv_image_display
        WHERE  ID = qv_common_id.get_user_id
        AND    role_cd = qv_common_id.get_user_type;    

    END delete_opting_out;

BEGIN

    l_image_type := LOWER(get_value('p_image_type'));
    
    delete_opting_out;

    IF l_image_type = 'new_image' THEN
        BEGIN
            l_image_file_name := get_value('p_image');
            save_file (l_image_file_name, get_value('p_mime_type'), l_success);                                 
            l_tracking_detail_msg := 'User successfully uploaded an image (' || l_image_file_name || ')';                                                        

        EXCEPTION
            WHEN OTHERS THEN    
                RAISE E_SAVE_FILE_ERR;
        END;

    ELSE
        
        CASE l_image_type
            WHEN 'prev_image' THEN
                l_display_ind:= 'Y';
                l_tracking_detail_msg := 'User successfully selected previous uploaded image to use as their personal profile';
            
            WHEN 'id_card_image' THEN
                l_display_ind := 'N';
                l_tracking_detail_msg := 'User successfully selected id card image to use as their personal profile';
                
            END CASE;
            
            UPDATE  image_uploaded_file
            SET     display_ind = l_display_ind 
            WHERE   username = l_username;
                        
    END IF;
    
    IF l_tracking_detail_msg IS NOT NULL THEN
        log_tracking_details (p_id_type    =>  'USERNAME'
                             ,p_id_value   =>  l_username
                             ,p_event_type =>  C_ACTIVITY
                             ,p_location   => 'image_upload.process_image'
                             ,p_details    => l_tracking_detail_msg);
    END IF;
        

    l_function_data(image_upload_p.C_ACTION) := image_upload_p.C_STORE_IMAGE;

    image_upload_p.edit_image (p_function_data => l_function_data
                              ,p_local_data    => l_local_data);
    
EXCEPTION

    WHEN E_SAVE_FILE_ERR THEN
        ROLLBACK;
        COMMIT;
        log_tracking_details (p_id_type    =>  'USERNAME'
                             ,p_id_value   =>  l_username
                             ,p_event_type =>  C_ERROR
                             ,p_location   => 'image_upload.process_image'
                             ,p_details    => 'E_SAVE_FILE_ERR EXCEPTION RAISED: Errors found when saving image file for username = '|| l_username ||' '||SQLERRM);

        image_upload_p.start_function (p_system_msg => image_upload_p.C_SAVE_ERROR);

    WHEN OTHERS THEN
        ROLLBACK;
        COMMIT;
        log_tracking_details (p_id_type    =>  'USERNAME'
                             ,p_id_value   =>  l_username
                             ,p_event_type =>  C_ERROR
                             ,p_location   => 'image_upload.process_image'
                             ,p_details    => 'OTHERS EXCEPTION RAISED: Other errors found for username = '|| l_username ||' '||SQLERRM);

        image_upload_p.start_function (p_system_msg => image_upload_p.C_OTHER_ERROR);

END process_image;

END image_upload;
/
