--------------------------------------------------------------------------
-- Program name: ph_update_emp_org_unit.sql
-- Author:      Tony Le
-- Created:     27 May 2009
-- Modify:      Tony Le
-- Purpose:     Script to update local name with local name in org_units
--              If org_unit_cd does not exist in org_units then update the 
--              local name with the org_unit_desc
--------------------------------------------------------------------------
DECLARE
    
    CURSOR      c_emp_org_units IS
    SELECT      *
    FROM        emp_org_unit
    WHERE      (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL)
    ORDER BY    org_unit_cd;

    l_local_name    VARCHAR2(100);
    l_sort_order    NUMBER;

BEGIN

    FOR r_org_unit IN c_emp_org_units LOOP
        
        BEGIN
            SELECT  local_name
                   ,sort_order
            INTO    l_local_name
                   ,l_sort_order
            FROM    org_units@oldqv
            WHERE   org_unit_code = r_org_unit.org_unit_cd;
        EXCEPTION
            WHEN OTHERS THEN
                l_local_name := r_org_unit.org_unit_desc;
                l_sort_order := NULL;
        END; 
     
        IF (l_sort_order IS NULL) THEN
                
            BEGIN
                
                SELECT  MAX(sort_order) + 5
                INTO    l_sort_order
                FROM    org_units@oldqv
                WHERE   parent_org_unit_code = r_org_unit.parent_org_unit_cd
                AND     active_flag = 'Y';
            EXCEPTION
                WHEN OTHERS THEN
                    l_sort_order := 80;
            END;
        
        END IF;
       
        UPDATE  emp_org_unit
        SET     local_name = l_local_name
               ,sort_order = l_sort_order
        WHERE   org_unit_cd = r_org_unit.org_unit_cd
        AND    (SYSDATE BETWEEN start_dt AND end_dt OR end_dt IS NULL);
    
    END LOOP;

    COMMIT;
    
END;
/