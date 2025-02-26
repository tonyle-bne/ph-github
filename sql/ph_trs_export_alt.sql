rem  Program   :  ph_trs_export_alt.sql
rem  Title     :  Alternative PH Data Extract
rem  Programmer:  E.Wood 
rem  Date      :  07-Jun-2006
rem
rem  Purpose   :  
rem		This program produces the PH extract file that is used
rem             for TRS.
rem  
rem
rem                                   Modification History
rem ***************************************************************************
rem   Change    : E Wood
rem   Date      : 07 Jun 2006
rem               Created Script 
rem   Change    : Tony Le 
rem             : 22 Sept 2009
rem               SAMS upgrade
rem   Change    : L Lin
rem   Date      : 08 Nov 2010
rem               Added another condition of ip_status ='cur' to exclude all the non current staffs
rem   Change    : Tony Le
rem   Date:     : 27 Sep 2011
rem             : Remove any references emp_org_unit.local_name with emp_org_unit.org_unit_desc.  
rem   Change    : Tony Le
rem   Date:     : 16 Dec 2011
rem             : If a staff (with EMP or CCR role) member has an 'undefined' position in the phonebook
rem             : then the script will call emp_common.get_role to retrieve the position title as
rem             : recorded in the HR systems
rem   Change:   :Ali Tan
rem   Date:     :04 Sep 2012
rem             :Removed Oracle Portal dependencies by replacing emp_common with emp
rem ***************************************************************************

whenever oserror  exit oscode      rollback
whenever sqlerror exit sql.sqlcode rollback

set feedback off
set termout off
set verify  off
set message off
set showmode off
set echo off
set newpage 0
set space 0
set linesize 512
set pagesize 0
set heading off
set TRIMSPOOL ON
spool $DATA/ph_trs_export3_alt.lis

select trs_client_id ||CHR(255)||
       to_char(nvl(c2.sort_order,0),'FM000') ||CHR(255)||
       rtrim(c2.org_unit_desc)                 ||CHR(255)||
       to_char(nvl(c3.sort_order,0),'FM000') ||CHR(255)||
       rtrim(c3.org_unit_desc)                 ||CHR(255)||
       to_char(nvl(c4.sort_order,0),'FM000') ||CHR(255)||
       rtrim(c4.org_unit_desc)                 ||CHR(255)||
       to_char(nvl(gc.print_order,0),'FM000') ||CHR(255)||
       rtrim(gc.description)                ||CHR(255)||
       rtrim(gc.primary_extn)               ||CHR(255)||
       rtrim(gc.primary_fax) ||CHR(255)||
       to_char(nvl(sc.print_order,0),'FM000') ||CHR(255)||
       decode(trim(lower(sc.description)), 'undefined', emp.get_role(a.ip_num), trim(sc.description)) ||CHR(255)||
       rtrim(a.title)                       ||CHR(255)||
       rtrim(nvl(a.preferred_name,a.first_name))              ||CHR(255)||
       rtrim(a.first_name)                  ||CHR(255)||
       rtrim(a.second_name)                 ||CHR(255)||
       rtrim(a.third_name)                  ||CHR(255)||
       rtrim(a.surname)                     ||CHR(255)||
       rtrim(a.primary_extn)                ||CHR(255)||
       rtrim(a.primary_fax)                ||CHR(255)||
       rtrim(a.mobile)                      ||CHR(255)||
       rtrim(a.speed_dial)                  ||CHR(255)||
       rtrim(a.pager)                       ||CHR(255)||
       rtrim(a.primary_campus)              ||CHR(255)||
       rtrim(a.primary_location)            ||CHR(255)||
       decode(qca.email_active_ind,'Y',rtrim(qca.email_alias),'')   ||CHR(255)||
       rtrim(a.print_flag)
from   group_codes    gc,
       subgroup_codes sc,
       emp_org_unit   c4,
       emp_org_unit   c3,
       emp_org_unit   c2,
       ip              a,
       qv_client_computer_account qca,
       qv_client_role             r
where (a.phone_group    = gc.phone_group (+)
and    a.owner_org_code = gc.owner_org_code (+))
and   (a.phone_subgroup = sc.phone_subgroup (+)
and    a.phone_group    = sc.phone_group (+)
and    a.owner_org_code = sc.owner_org_code (+))
and   (c4.org_unit_cd   = a.owner_org_code
and    c4.hierarchy_level= 'CLEVEL4')
and   (c3.org_unit_cd   = substr(a.owner_org_code,1,5)
and    c3.hierarchy_level= 'CLEVEL3')
and   (c2.org_unit_cd   = substr(a.owner_org_code,1,3)
and    c2.hierarchy_level= 'CLEVEL2')
AND  ((SYSDATE BETWEEN c2.start_dt AND c2.end_dt) OR c2.end_dt IS NULL)
AND  ((SYSDATE BETWEEN c3.start_dt AND c3.end_dt) OR c3.end_dt IS NULL)
AND  ((SYSDATE BETWEEN c4.start_dt AND c4.end_dt) OR c4.end_dt IS NULL)
and   r.id              = a.employee_num
and   r.role_cd         = 'EMP'
and   r.role_active_ind = 'Y'
and   r.username        = qca.username
and   a.ip_status = 'cur'
UNION
select trs_client_id ||CHR(255)||
       to_char(nvl(c2.sort_order,0),'FM000') ||CHR(255)||
       rtrim(c2.org_unit_desc) ||CHR(255)||
       to_char(nvl(c3.sort_order,0),'FM000') ||CHR(255)||
       rtrim(c3.org_unit_desc)                 ||CHR(255)||
       to_char(nvl(c4.sort_order,0),'FM000') ||CHR(255)||
       rtrim(c4.org_unit_desc)                 ||CHR(255)||
       to_char(nvl(gc.print_order,0),'FM000') ||CHR(255)||
       rtrim(gc.description)                ||CHR(255)||
       rtrim(gc.primary_extn)               ||CHR(255)||
       rtrim(gc.primary_fax) ||CHR(255)||
       to_char(nvl(sc.print_order,0),'FM000') ||CHR(255)||
       decode(trim(lower(sc.description)), 'undefined', emp.get_role(a.ip_num), trim(sc.description)) ||CHR(255)||
       rtrim(a.title)                       ||CHR(255)||
       rtrim(nvl(a.preferred_name,a.first_name))              ||CHR(255)||
       rtrim(a.first_name)                  ||CHR(255)||
       rtrim(a.second_name)                 ||CHR(255)||
       rtrim(a.third_name)                  ||CHR(255)||
       rtrim(a.surname)                     ||CHR(255)||
       rtrim(a.primary_extn)                ||CHR(255)||
       rtrim(a.primary_fax)                ||CHR(255)||
       rtrim(a.mobile)                      ||CHR(255)||
       rtrim(a.speed_dial)                  ||CHR(255)||
       rtrim(a.pager)                       ||CHR(255)||
       rtrim(a.primary_campus)              ||CHR(255)||
       rtrim(a.primary_location)            ||CHR(255)||
       decode(qca.email_active_ind,'Y',rtrim(qca.email_alias),'')   ||CHR(255)||
       rtrim(a.print_flag)
from   group_codes    gc,
       subgroup_codes sc,
       emp_org_unit   c4,
       emp_org_unit   c3,
       emp_org_unit   c2,
       ip              a,
       qv_client_computer_account qca,
       qv_client_role             r,
       ccr_clients                cc
where (a.phone_group    = gc.phone_group (+)
and    a.owner_org_code = gc.owner_org_code (+))
and   (a.phone_subgroup = sc.phone_subgroup (+)
and    a.phone_group    = sc.phone_group (+)
and    a.owner_org_code = sc.owner_org_code (+))
and   (c4.org_unit_cd   = a.owner_org_code
and    c4.hierarchy_level= 'CLEVEL4')
and   (c3.org_unit_cd   = substr(a.owner_org_code,1,5)
and    c3.hierarchy_level= 'CLEVEL3')
and   (c2.org_unit_cd   = substr(a.owner_org_code,1,3)
and    c2.hierarchy_level= 'CLEVEL2')
AND  ((SYSDATE BETWEEN c2.start_dt AND c2.end_dt) OR c2.end_dt IS NULL)
AND  ((SYSDATE BETWEEN c3.start_dt AND c3.end_dt) OR c3.end_dt IS NULL)
AND  ((SYSDATE BETWEEN c4.start_dt AND c4.end_dt) OR c4.end_dt IS NULL)
and   r.role_cd         = 'CCR'
and   r.role_active_ind = 'Y'
and   r.username        = qca.username
and   r.id              = cc.ccr_client_id
and   a.ip_num          = cc.ip_num
and   cc.deceased_flag  = 'N' 
and   a.ip_status = 'cur' 
/

spool off
exit success
