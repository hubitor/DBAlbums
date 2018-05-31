# correction :  update album
# cd0
SELECT OO.ID_CD,  OO.Typ_Tag, OO.Qty_CD, KK.MAX_DISC, OO.path FROM DBALBUMS AS OO
INNER JOIN (
	SELECT DISTINCT ID_CD, MAX(TAG_Disc) AS  MAX_DISC
	FROM DBTRACKS 
	WHERE LEFT(ODR_Track,3)='cd0'
	GROUP BY ID_CD) KK
 ON KK.ID_CD=OO.ID_CD
WHERE OO.Qty_CD<>KK.MAX_DISC;

# n Reps <> nb CD
SELECT OO.ID_CD, OO.Typ_Tag, OO.Qty_CD, KK.TAG_DISC, OO.path FROM DBALBUMS AS OO
INNER JOIN (
	SELECT ID_CD, MAX(TAG_Disc) AS  TAG_DISC FROM DBTRACKS GROUP BY ID_CD) KK
 ON KK.ID_CD=OO.ID_CD
WHERE OO.Qty_CD<>KK.TAG_DISC AND OO.Qty_CD<>1;

# n Cds dans 1 rep : attention au mauvais TAG_DISC
SELECT OO.ID_CD, OO.Typ_Tag, OO.Qty_CD, KK.TAG_DISC, OO.path FROM DBALBUMS AS OO
INNER JOIN (
	SELECT ID_CD, MAX(TAG_Disc) AS  TAG_DISC FROM DBTRACKS GROUP BY ID_CD) KK
 ON KK.ID_CD=OO.ID_CD
WHERE OO.Qty_CD<>KK.TAG_DISC AND OO.Qty_CD=1 AND KK.TAG_DISC<>0;