-- 13401
SELECT * FROM ALBUMS;

-- jointure 13401 - 13382 = 19
SELECT * FROM ALBUMS
INNER JOIN DBALBUMS
ON ALBUMS.PATHNAME = DBALBUMS.Path
WHERE ALBUMS.ADD <> DBALBUMS.Date_Insert;

-- update date add 13401 - 13378 = 23 missing
UPDATE ALBUMS
INNER JOIN DBALBUMS
ON ALBUMS.PATHNAME = DBALBUMS.Path
SET ALBUMS.ADD = DBALBUMS.Date_Insert,
ALBUMS.SCORE = DBALBUMS.Score;

-- 23 missing
SELECT * FROM ALBUMS
LEFT JOIN DBALBUMS
ON ALBUMS.PATHNAME = DBALBUMS.Path
WHERE DBALBUMS.ID_CD IS NULL;

-- 2964
UPDATE TRACKS
INNER JOIN DBTRACKS
ON TRACKS.FILENAME = DBTRACKS.FIL_Track
SET TRACKS.SCORE = DBTRACKS.Score
WHERE DBTRACKS.Score <> 0;
