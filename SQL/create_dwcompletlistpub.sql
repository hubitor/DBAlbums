DROP VIEW VW_DBCOMPLETLIST1;
CREATE VIEW VW_DBCOMPLETLIST1 AS
SELECT DISTINCT ID_CD, TAG_Albumartists FROM DBTRACKS WHERE TAG_Albumartists IS NOT NULL AND TAG_Albumartists<>"" AND TAG_Albumartists<>"Various";

DROP VIEW VW_DBCOMPLETLIST2;
CREATE VIEW VW_DBCOMPLETLIST2 AS
SELECT 
CASE WHEN DBK.TAG_Albumartists IS NULL THEN
	(CASE 
		WHEN INSTR(Name,'[') = 1 THEN SUBSTRING(Name,INSTR(Name,'] ')+2, LOCATE(' - ',REPLACE(Name,'_',' '), INSTR(Name,'] '))-INSTR(Name,'] ')-2)
		WHEN INSTR(Name,'(') = 1 THEN SUBSTRING(Name,INSTR(Name,') ')+2, LOCATE(' - ',REPLACE(Name,'_',' '), INSTR(Name,') '))-INSTR(Name,') ')-2)
		ELSE SUBSTRING(Name,1,LOCATE(' - ',REPLACE(Name,'_',' '),1)-1)
		END)
	ELSE
		DBK.TAG_Albumartists END AS Synthax, 
COUNT(*) AS Score
FROM DBALBUMS
	LEFT JOIN VW_DBCOMPLETLIST1 AS DBK
	ON DBALBUMS.ID_CD=DBK.ID_CD
GROUP BY Synthax
HAVING Synthax<>'VA' AND Synthax<>'Various' AND Synthax<>''
UNION
SELECT Label AS Synthax, COUNT(*) AS Score
FROM DBALBUMS
WHERE Label<>''
GROUP BY Label;

DROP VIEW VW_DBCOMPLETLISTPUB;
CREATE VIEW VW_DBCOMPLETLISTPUB AS
SELECT Synthax 
FROM VW_DBCOMPLETLIST2
ORDER BY Score DESC
LIMIT 1500;



	





