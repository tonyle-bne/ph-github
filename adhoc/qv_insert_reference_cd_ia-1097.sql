SET DEFINE OFF
     
INSERT 
INTO    qv_reference_cd
VALUES ('ITSEC', 'Volunteers delivering information security message#fa fa-user-shield#blue', 'ATTRIBUTETYPE', 'Y', '', SYSDATE, user);

INSERT 
INTO    qv_reference_cd
VALUES ('ITMSG', 'Information Security Champion delivering information security message', 'ATTRIBUTEVALUE', 'Y', 3, SYSDATE, user);

UPDATE  qv_reference_cd
SET     sort_order = 4
WHERE   reference_cd = 'SUFFX'
AND     code_category_cd = 'ATTRIBUTEVALUE';

UPDATE  qv_reference_cd
SET     sort_order = 2
WHERE   reference_cd = 'ALL'
AND     code_category_cd = 'ATTRIBUTEVALUE';

INSERT INTO qv_reference_cd (reference_cd,description,code_category_cd,active_ind,sort_order,update_dt,update_who) 
VALUES ('135','CHANCELLERY DIVISION','ALLY_FAC_DIV','Y',1,SYSDATE,user);

INSERT INTO qv_reference_cd (reference_cd,description,code_category_cd,active_ind,sort_order,update_dt,update_who) 
VALUES ('136','ADMINISTRATIVE DIVISION','ALLY_FAC_DIV','Y',2,SYSDATE,user);

INSERT INTO qv_reference_cd (reference_cd,description,code_category_cd,active_ind,sort_order,update_dt,update_who) 
VALUES ('137','ACADEMIC DIVISION','ALLY_FAC_DIV','Y',3,SYSDATE,user);

INSERT INTO qv_reference_cd (reference_cd,description,code_category_cd,active_ind,sort_order,update_dt,update_who) 
VALUES ('145','FACULTY OF BUSINESS & LAW','ALLY_FAC_DIV','Y',4,SYSDATE,user);

INSERT INTO qv_reference_cd (reference_cd,description,code_category_cd,active_ind,sort_order,update_dt,update_who) 
VALUES ('146','FACULTY OF SCIENCE','ALLY_FAC_DIV','Y',5,SYSDATE,user);

INSERT INTO qv_reference_cd (reference_cd,description,code_category_cd,active_ind,sort_order,update_dt,update_who) 
VALUES ('147','FACULTY OF ENGINEERING','ALLY_FAC_DIV','Y',6,SYSDATE,user);

INSERT INTO qv_reference_cd (reference_cd,description,code_category_cd,active_ind,sort_order,update_dt,update_who) 
VALUES ('148','FACULTY OF CI, EDUCATION & SOCIAL JUSTICE','ALLY_FAC_DIV','Y',7,SYSDATE,user);

INSERT INTO qv_reference_cd (reference_cd,description,code_category_cd,active_ind,sort_order,update_dt,update_who) 
VALUES ('149','FACULTY OF HEALTH','ALLY_FAC_DIV','Y',8,SYSDATE,user);

INSERT INTO qv_reference_link (reference_cd, reference_type, reference_link, update_who, update_on)
VALUES ('ALLY_NETWORK_URL', 'URL', 'https://qutvirtual4.qut.edu.au/group/staff/people/equity/lgbtiqa/ally-network', 'LETL', SYSDATE);

COMMIT;


