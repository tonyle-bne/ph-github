-- Program name: ph_ins_emp_attribute_qv_reference.sql
-- Author:      Sheeja Kambil
-- Created:     09 Aug 2018
-- Purpose:     Query to populate the qv_reference_cd table 
--              with latest values of emp_attribute.attribute_type
--              and emp_attribute.attribute_value
--------------------------------------------------------------------------

DELETE qv_reference_cd
WHERE  code_category_cd = 'ATTRIBUTETYPE';

DELETE qv_reference_cd
WHERE code_category_cd = 'ATTRIBUTEVALUE';

-- Add latest emp_attribute attribute_type values into qv_reference_cd table 
INSERT INTO qv_reference_cd
( REFERENCE_CD, DESCRIPTION, CODE_CATEGORY_CD, ACTIVE_IND, SORT_ORDER )
VALUES
( 'ALLY', 'Ally Network member - trained to understand sexuality and gender issues#fa fa-child#purple', 'ATTRIBUTETYPE', 'Y', NULL );

INSERT INTO qv_reference_cd
( REFERENCE_CD, DESCRIPTION, CODE_CATEGORY_CD, ACTIVE_IND, SORT_ORDER )
VALUES
( 'JPEMP', 'Justice of the Peace (Qualified and Magistrates Court) or Commissioner for Declarations (C. Dec)#fa fa-university#grey', 'ATTRIBUTETYPE', 'Y', NULL );

INSERT INTO qv_reference_cd
( REFERENCE_CD, DESCRIPTION, CODE_CATEGORY_CD, ACTIVE_IND, SORT_ORDER )
VALUES
( 'JPALL', 'Justice of the Peace (Qualified and Magistrates Court) or Commissioner for Declarations (C. Dec)#fa fa-university#grey', 'ATTRIBUTETYPE', 'Y', NULL );

-- Add latest emp_attribute attribute_type values into qv_reference_cd table 
INSERT INTO qv_reference_cd
( REFERENCE_CD, DESCRIPTION, CODE_CATEGORY_CD, ACTIVE_IND, SORT_ORDER )
VALUES
( 'CDEC', 'Commissioner for Declarations (C. dec)', 'ATTRIBUTEVALUE', 'Y', 1 );

INSERT INTO qv_reference_cd
( REFERENCE_CD, DESCRIPTION, CODE_CATEGORY_CD, ACTIVE_IND, SORT_ORDER )
VALUES
( 'SUFFX', 'Employee Suffix', 'ATTRIBUTEVALUE', 'Y', 1 );

INSERT INTO qv_reference_cd
( REFERENCE_CD, DESCRIPTION, CODE_CATEGORY_CD, ACTIVE_IND, SORT_ORDER )
VALUES
( 'QUAL', 'Justice of the Peace (Qualified)', 'ATTRIBUTEVALUE', 'Y', 1 );

INSERT INTO qv_reference_cd
( REFERENCE_CD, DESCRIPTION, CODE_CATEGORY_CD, ACTIVE_IND, SORT_ORDER )
VALUES
( 'STAFF', 'Visible to staff only', 'ATTRIBUTEVALUE', 'Y', 1 );

INSERT INTO qv_reference_cd
( REFERENCE_CD, DESCRIPTION, CODE_CATEGORY_CD, ACTIVE_IND, SORT_ORDER )
VALUES
( 'ALL', 'Visible to all in QUT', 'ATTRIBUTEVALUE', 'Y', 1 );

COMMIT;