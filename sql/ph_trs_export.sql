rem  Program   :  ph_trs_export.sql
rem  Title     :  PH Data Extract
rem  Programmer:  P.Lu
rem  Date      :  14-Aug-98
rem
rem  Purpose   :  
rem		This program produces the PH extract file that is used
rem             for both the PH Server and production of the QUT Phonebook.
rem  
rem
rem                                   Modification History
rem ***************************************************************************
rem   Programmer: J Chapman
rem   Date      : 28 July 1999
rem   Change    : Change to include 'other' staff who are of ip_type 
rem               ''OTH' or 'CCR'
rem   Change    : A Zhang
rem   Date      : 27 July 2001
rem               If preferred name is null, display first name instead
rem   Change    : A Zhang
rem   Date      : 22 Oct 2002
rem               Modify query to suit for new QUT Phonebook
rem   Change    : A Zhang
rem   Date      : 21 Nov 2002
rem               Retrieve email_alias from qv_client_computer_account instead of IP
rem   Change    : A Zhang
rem   Date      : 28 Feb 2002
rem               Modify query to display active org unit only
rem
rem   Change    : T Baisden
rem   Date      : 09 August 2004
rem               Created script based on ph_export3.sql (above mod history refers to earlier script)
rem               Script unchanged except for the inclusion of client_id in the select statement
rem
rem   Change    : T Baisden
rem   Date      : 26 May 2005
rem               Changed to extract org_unit_codes beginning with P
rem
rem   Change    : E Wood
rem   Date      : 07 Jun 2006
rem               Removed the "and   a.print_flag  = 'Y'" from the WHERE
rem               clause to enable export of all data to TRS.
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
spool $DATA/ph_trs_export3.lis

select trs_client_id ||'|'||
       to_char(nvl(c2.sort_order,0),'000') ||'|'||
       rtrim(c2.org_unit_desc)             ||'|'||
       to_char(nvl(c3.sort_order,0),'000') ||'|'||
       rtrim(c3.org_unit_desc)             ||'|'||
       to_char(nvl(c4.sort_order,0),'000') ||'|'||
       rtrim(c4.org_unit_desc)             ||'|'||
       to_char(nvl(gc.print_order,0),'000') ||'|'||
       rtrim(gc.description)                ||'|'||
       rtrim(gc.primary_extn)               ||'|'||
       rtrim(gc.primary_fax) ||'|'||
       to_char(nvl(sc.print_order,0),'000') ||'|'||
       decode(trim(lower(sc.description)), 'undefined', emp.get_role(a.ip_num), trim(sc.description))||'|'||
       rtrim(a.title)                       ||'|'||
       rtrim(nvl(a.preferred_name,a.first_name))              ||'|'||
       rtrim(a.first_name)                  ||'|'||
       rtrim(a.second_name)                 ||'|'||
       rtrim(a.third_name)                  ||'|'||
       rtrim(a.surname)                     ||'|'||
       rtrim(a.primary_extn)                ||'|'||
       rtrim(a.primary_fax)                ||'|'||
       rtrim(a.mobile)                      ||'|'||
       rtrim(a.speed_dial)                  ||'|'||
       rtrim(a.pager)                       ||'|'||
       rtrim(a.primary_campus)              ||'|'||
       rtrim(a.primary_location)            ||'|'||
       decode(qca.email_active_ind,'Y',rtrim(qca.email_alias),'')   ||'|'||
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
select trs_client_id ||'|'||
       to_char(nvl(c2.sort_order,0),'000') ||'|'||
       rtrim(c2.org_unit_desc)             ||'|'||
       to_char(nvl(c3.sort_order,0),'000') ||'|'||
       rtrim(c3.org_unit_desc)             ||'|'||
       to_char(nvl(c4.sort_order,0),'000') ||'|'||
       rtrim(c4.org_unit_desc)             ||'|'||
       to_char(nvl(gc.print_order,0),'000') ||'|'||
       rtrim(gc.description)                ||'|'||
       rtrim(gc.primary_extn)               ||'|'||
       rtrim(gc.primary_fax) ||'|'||
       to_char(nvl(sc.print_order,0),'000') ||'|'||
       decode(trim(lower(sc.description)), 'undefined', emp.get_role(a.ip_num), trim(sc.description)) ||'|'||
       rtrim(a.title)                       ||'|'||
       rtrim(nvl(a.preferred_name,a.first_name))              ||'|'||
       rtrim(a.first_name)                  ||'|'||
       rtrim(a.second_name)                 ||'|'||
       rtrim(a.third_name)                  ||'|'||
       rtrim(a.surname)                     ||'|'||
       rtrim(a.primary_extn)                ||'|'||
       rtrim(a.primary_fax)                ||'|'||
       rtrim(a.mobile)                      ||'|'||
       rtrim(a.speed_dial)                  ||'|'||
       rtrim(a.pager)                       ||'|'||
       rtrim(a.primary_campus)              ||'|'||
       rtrim(a.primary_location)            ||'|'||
       decode(qca.email_active_ind,'Y',rtrim(qca.email_alias),'')   ||'|'||
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
