-- Create Database
CREATE DATABASE game_analysis;

-- Use Database
USE game_analysis;

/* IMPORT TABLE 
-- Imported the required tables: player_details and level_details
*/

SELECT *
FROM player_details;

SELECT *
FROM level_details2;

-- DATA CLEANING

/*Data Imputation:
Replace the missing values with suitable substitutes such as mean, median, or mode.
*/

-- calculate the mode for values in the columns L1_Code and L2_Code
SELECT L1_Code, COUNT(*) AS frequency
FROM player_details
GROUP BY L1_Code
ORDER BY frequency DESC
LIMIT 1;

SELECT L2_Code, COUNT(*) AS frequency
FROM player_details
GROUP BY L2_Code
ORDER BY frequency DESC
LIMIT 1;

-- Missing values was replaced with the mode.

UPDATE player_details
SET L1_Code = 'war_zone'
WHERE L1_Code IS NULL OR L1_Code = '';

UPDATE player_details
SET L2_Code = 'splippery_slope'
WHERE L2_Code IS NULL OR L2_Code = '';

-- Correct the misspelt word.

UPDATE player_details
SET L2_Code = REPLACE(L2_Code, 'splippery_slope', 'slippery_slope');

-- Rename the timestamp column to timestamps
ALTER TABLE level_details2
RENAME COLUMN TimeStamp TO Timestamps;

-- Extract the date and time from timestamp column

SELECT 
    SUBSTRING(Timestamps, 1, 10) AS date_only,
    SUBSTRING(Timestamps, 12, 8) AS time_only
FROM level_details2;


ALTER TABLE level_details2
ADD date_only DATE,
ADD time_only TIME;

UPDATE level_details2
SET date_only = CAST(Timestamps AS DATE),
    time_only = CAST(Timestamps AS TIME);

ALTER TABLE level_details2 -- Column no longer needed
DROP COLUMN Timestamps;

-- Rename the timestamp column to timestamps
ALTER TABLE level_details2
RENAME COLUMN Level TO game_level;

-- DATA ANALYSIS

-- 1. Extract `P_ID`, `Dev_ID`, `PName`, and `Difficulty_level` of all players at Level 0.
SELECT DISTINCT pd.P_ID, pd.PName, ld.Dev_ID, ld.Difficulty
FROM player_details AS pd
INNER JOIN level_details2 AS ld ON pd.P_ID = ld.P_ID
WHERE ld.game_level = 0
ORDER BY pd.P_ID;

/* 2. Find `Level1_code`wise average `Kill_Count` where `lives_earned` is 2, and at least 3 
stages are crossed
*/

SELECT pd.L1_Code, ROUND(avg(Kill_Count), 1) AS Avg_Kill_Count
FROM level_details2 AS ld
INNER JOIN player_details AS pd
	ON ld.P_ID = pd.P_ID
WHERE Lives_Earned = 2 AND Stages_crossed >=3
GROUP BY pd.L1_Code
ORDER BY Avg_Kill_Count DESC;

/*3. Find the total number of stages crossed at each difficulty level for Level 2 with players 
using `zm_series` devices. Arrange the result in decreasing order of the total number of 
stages crossed
*/

SELECT ld.Difficulty, SUM(ld.Stages_crossed) AS Total_Stages_Crossed
FROM level_details2 AS ld
WHERE game_level = 2 AND Dev_ID LIKE 'zm\_%'
GROUP BY ld.Difficulty
ORDER BY Total_Stages_Crossed DESC;

/* 4. Extract `P_ID` and the total number of unique dates for those players who have played 
games on multiple days
*/

SELECT P_ID, COUNT(DISTINCT date_only) AS Number_of_Days_Played
FROM level_details2
GROUP BY P_ID
HAVING COUNT(DISTINCT date_only) > 1
ORDER BY Number_of_Days_Played DESC;

/* 5. Find `P_ID` and levelwise sum of `kill_counts` where `kill_count` is greater than the 
average kill count for Medium difficulty.
*/

SELECT P_ID, game_level, SUM(Kill_Count) AS Total_Kill_Counts
FROM level_details2
WHERE Difficulty = 'Medium'
GROUP BY P_ID, game_level
HAVING SUM(Kill_Count) > (SELECT AVG(Kill_Count) FROM level_details2 WHERE Difficulty = 'Medium')
ORDER BY Total_Kill_Counts DESC;

/* 6. Find `Level` and its corresponding `Level_code`wise sum of lives earned, excluding Level 
0. Arrange in ascending order of level.
*/

SELECT ld.game_level, player_details.L1_Code, player_details.L2_Code, SUM(ld.Lives_Earned) AS Total_Lives_Earned
FROM level_details2 AS ld
INNER JOIN player_details ON player_details.P_ID = ld.P_ID
WHERE ld.game_level > 0
GROUP BY ld.game_level, player_details.L1_Code, player_details.L2_Code
ORDER BY Total_Lives_Earned ASC;

/* 7. Find the top 3 scores based on each `Dev_ID` and rank them in increasing order using 
`Row_Number`. Display the difficulty as well
*/

WITH RankedScores AS (
    SELECT Dev_ID, Score, Difficulty, 
           ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY Score DESC) AS Ranked
    FROM level_details2
)
SELECT Dev_ID, Score, Difficulty, Ranked
FROM RankedScores
WHERE Ranked <= 3;

-- 8. Find the `first_login` datetime for each device ID

SELECT Dev_ID, min(date_only) AS Date_of_Login, min(time_only) AS First_Login
FROM level_details2
GROUP BY Dev_ID
ORDER BY First_Login;

/* 9. Find the top 5 scores based on each difficulty level and rank them in increasing order 
using `Rank`. Display `Dev_ID` as well. 
*/

WITH RankedScores AS (
    SELECT Dev_ID, Difficulty, Score,
           RANK() OVER (PARTITION BY Difficulty ORDER BY Score DESC) AS Ranked
    FROM level_details2
)
SELECT Dev_ID, Difficulty, Score, Ranked
FROM RankedScores
WHERE Ranked <= 5;

/* 10. Find the device ID that is first logged in (based on `start_datetime`) for each player 
(`P_ID`). Output should contain player ID, device ID, and first login datetime. 
*/

SELECT P_ID, Dev_ID, min(date_only) AS Date_of_Login, min(time_only) AS First_Login_Time
 FROM level_details2
 GROUP BY P_ID, Dev_ID
 ORDER BY First_Login_Time;

/* 11. For each player and date, determine how many `kill_counts` were played by the player 
so far. 
a) Using window functions 
*/

SELECT DISTINCT P_ID, date_only, SUM(Kill_Count) OVER (PARTITION BY P_ID ORDER BY date_only) AS Total_Kill_Count
FROM level_details2;

-- b) Without window functions 

SELECT DISTINCT
    t1.P_ID,
    t1.date_only,
    (SELECT SUM(t2.Kill_Count) 
     FROM level_details2 t2 
     WHERE t1.P_ID = t2.P_ID AND t1.date_only >= t2.date_only) AS Total_Kill_Count
FROM 
    level_details2 t1
ORDER BY 
    t1.P_ID, t1.date_only;

/* 12. Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, 
excluding the most recent `start_datetime`. 
*/

SELECT 
    t1.P_ID,
    t1.date_only,
    SUM(t2.stages_crossed) AS Cumulative_Stages_Crossed
FROM 
    level_details2 t1
JOIN 
    level_details2 t2 ON t1.P_ID = t2.P_ID AND t1.date_only >= t2.date_only
GROUP BY 
    t1.P_ID, t1.date_only
HAVING 
    t1.date_only < (SELECT MAX(date_only) FROM level_details2 WHERE P_ID = t1.P_ID)
ORDER BY 
    t1.P_ID, t1.date_only;


-- 13. Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`. 

WITH Ranked_Scores AS (
     SELECT P_ID, Dev_ID, sum(Score) AS Total_Scores,
         RANK() OVER (PARTITION BY Dev_ID ORDER BY sum(Score) DESC) AS Ranked
     FROM level_details2
     GROUP BY P_ID, Dev_ID
 )
 SELECT P_ID, Dev_ID, Total_Scores, Ranked
 FROM Ranked_Scores
 WHERE Ranked <= 3;
 
 /* 14. Find players who scored more than 50% of the average score, scored by the sum of 
scores for each `P_ID`. 
*/

SELECT P_ID, SUM(Score) AS Total_Score
 FROM level_details2
 GROUP BY P_ID
 HAVING SUM(Score) > (SELECT AVG(Score) * 0.5 FROM level_details2)
 ORDER BY Total_Score DESC;


/* 15. Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` 
and rank them in increasing order using `Row_Number`. Display the difficulty as well.
*/

DELIMITER $$
CREATE PROCEDURE GetTopHeadshotsCount(IN n INT)
BEGIN
  WITH RankedHeadshots AS
  (
    SELECT Dev_ID, headshots_count, difficulty,
           ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count DESC) AS Row_Numberr
    FROM level_details2
  )
  SELECT Dev_ID, headshots_count, difficulty
  FROM RankedHeadshots
  WHERE Row_Numberr <= n;
END $$
DELIMITER ;

CALL GetTopHeadshotsCount(1);







