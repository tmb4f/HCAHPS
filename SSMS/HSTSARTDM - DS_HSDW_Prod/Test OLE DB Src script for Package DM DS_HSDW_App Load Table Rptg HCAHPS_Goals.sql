USE DS_HSDW_Prod

DECLARE @domain_translation TABLE
(
    Goals_Domain VARCHAR(100)
  , DOMAIN VARCHAR(100)
);
INSERT INTO @domain_translation
(
    Goals_Domain,
    DOMAIN
)
VALUES
(   'Communication About Pain', -- Goals_Domain - varchar(100): Value docmented in Goals file
    'Pain Management'  -- DOMAIN - varchar(100)
);	
--DECLARE @unit_translation TABLE
--(
--    Goals_Unit NVARCHAR(500)
--  , Unit NVARCHAR(500)
--);
--INSERT INTO @unit_translation
--(
--    Goals_Unit,
--    Unit
--)
--VALUES
--(   '7Central', -- Goals_Unit - nvarchar(500): Value documented in Goals file
--    '7CENTRAL'  -- Unit - nvarchar(500)
--),
--(	'7N PICU',
--	'PIC N'
--),
--(	'7W ACUTE',
--	'7WEST'
--);	
--DECLARE @unit_department_translation TABLE
--(
--    Goal_Yr INT -- Fiscal year for translation
--  , Goals_Unit NVARCHAR(500) -- Value documented in Goals file
--  , Epic_Department_Id NVARCHAR(500) -- mapped Epic department id
--  , Epic_Department_Name NVARCHAR(500) -- mapped Epic department name
--);
--INSERT INTO @unit_department_translation
--(
--    Goal_Yr,
--	Goals_Unit,
--    Epic_Department_Id,
--    Epic_Department_Name
--)
--VALUES
--(2019,'3CENTRAL','10243051','UVHE 3 CENTRAL'),
--(2019,'3EAST','10243052','UVHE 3 EAST'),
--(2019,'3NMICU','10243089','UVHE 3 NORTH'),
--(2019,'3WEST','10243053','UVHE 3 WEST'),
--(2019,'3WMICU','10243038','UVHE MEDICAL ICU'),
--(2019,'4CEN/4CCV','10243054','UVHE 4 CENTRAL CV'),
--(2019,'4CTXP','10243110','UVHE 4 CENTRAL TXP'),
--(2019,'4EAST','10243055','UVHE 4 EAST'),
--(2019,'4NTCVPO','10243091','UVHE 4 NORTH'),
--(2019,'4WEST','10243057','UVHE 4 WEST'),
--(2019,'4WTCVPO','10243049','UVHE TCV POST OP'),
--(2019,'5 West','10243060','UVHE 5 WEST'),
--(2019,'5CENTRAL','10243058','UVHE 5 CENTRAL'),
--(2019,'5N','10243090','UVHE 5 NORTH'),
--(2019,'6CEN','10243061','UVHE 6 CENTRAL'),
--(2019,'6EAST','10243062','UVHE 6 EAST'),
--(2019,'6NOR','10243092','UVHE 6 NORTH'),
--(2019,'6WEST','10243063','UVHE 6 WEST'),
--(2019,'7NOB','10243113','UVHE 7NOB'),
--(2019,'8COB','10243066','UVHE 8 CENTRAL OB'),
--(2019,'8NOR','10243094','UVHE 8 NORTH OB'),
--(2019,'8WEST','10243068','UVHE 8 WEST'),
--(2019,'8WSC','10243096','UVHE 8 WEST STEM CELL'),
--(2019,'ADMT','10243047','UVHE SHORT STAY UNIT'),
--(2019,'CCU','10243035','UVHE CORONARY CARE'),
--(2019,'NNIC','10243041','UVHE NEUR ICU'),
--(2019,'OBS','10243066','UVHE 8 CENTRAL OB'),
--(2019,'SICU','10243046','UVHE SURG TRAM ICU'),
--(2019,'SSU/SSU ED','10243047','UVHE SHORT STAY UNIT');
--DECLARE @unit_response_unit_translation TABLE
--(
--    Goal_Yr INT NOT NULL -- Fiscal year for translation
--  , Goals_Unit NVARCHAR(500) NOT NULL -- Value documented in Goals file
--  , Response_Unit NVARCHAR(500) NOT NULL -- Value set by extract from response table
--);
--INSERT INTO @unit_response_unit_translation
--(
--    Goal_Yr,
--	Goals_Unit,
--    Response_Unit
--)
--VALUES
--(2019,'3CENTRAL','3CENTRAL'),
--(2019,'3EAST','3EAST'),
--(2019,'3NMICU','3N MICU'),
--(2019,'3WEST','3WEST'),
--(2019,'3WMICU','3W MICU'),
--(2019,'4CEN/4CCV','4CEN'),
--(2019,'4CTXP','4CTXP'),
--(2019,'4EAST','4EAST'),
--(2019,'4NTCVPO','4NTCVICU'),
--(2019,'4WEST','4WEST'),
--(2019,'4WTCVPO','4WTCVICU'),
--(2019,'5 West','5WEST'),
--(2019,'5CENTRAL','5CENTRAL'),
--(2019,'5N','5NOR'),
--(2019,'6CEN','6CEN'),
--(2019,'6EAST','6EAST'),
--(2019,'6NOR','6NOR'),
--(2019,'6WEST','6WEST'),
--(2019,'7NOB','7NOB'),
--(2019,'8COB','8COB'),
--(2019,'8NOR','8NOR'),
--(2019,'8WEST','8WEST'),
--(2019,'8WSC','8WSC'),
--(2019,'ADMT','ADMT'),
--(2019,'CCU','CCU'),
--(2019,'NNIC','NNIC'),
--(2019,'OBS','OBS'),
--(2019,'SICU','STICU'),
--(2019,'SSU/SSU ED','SSU ED');
DECLARE @serviceline_translation TABLE
(
    Goals_ServiceLine NVARCHAR(500) NULL
  , ServiceLine NVARCHAR(500)
);
INSERT INTO @serviceline_translation
(
    Goals_ServiceLine,
    ServiceLine
)
VALUES
(   NULL, -- Goals_ServiceLine - nvarchar(500): Value documented in Goals file
    'All Service Lines'  -- ServiceLine - nvarchar(500)
),
(   'Women''s (and Children''s)', -- Goals_ServiceLine - nvarchar(500): Value documented in Goals file
    'Womens and Childrens'  -- ServiceLine - nvarchar(500)
);
--DECLARE @HCAHPS_PX_Goal_Setting TABLE
--(
--    GOAL_YR INTEGER
--  , SERVICE_LINE VARCHAR(150)
--  , ServiceLine_Goals VARCHAR(150)
--  , Epic_Department_Id VARCHAR(10)
--  , Epic_Department_Name VARCHAR(30)
--  , UNIT VARCHAR(150)
--  --, Unit_Goals VARCHAR(150)
--  , DOMAIN VARCHAR(150)
--  , Domain_Goals VARCHAR(150)
--  , GOAL DECIMAL(4,3)
--);
--INSERT INTO @HCAHPS_PX_Goal_Setting
--SELECT
--	[GOAL_YR]
--	,Goal.SERVICE_LINE
--	,COALESCE([@serviceline_translation].ServiceLine, Goal.SERVICE_LINE) AS ServiceLine_Goals
--	--,Goal.Epic_Department_Id
--	,CASE
--	   WHEN Goal.Epic_Department_Id IS NULL THEN 'All Units'
--	   ELSE Goal.Epic_Department_Id
--	 END AS Epic_Department_Id
--	--,Goal.Epic_Department_Name
--	,CASE
--	   WHEN Goal.Epic_Department_Name IS NULL THEN 'All Units'
--	   ELSE Goal.Epic_Department_Name
--	 END AS Epic_Department_Name
--    ,Goal.[UNIT]
--  --  ,CASE
--	 --  WHEN Goal.Epic_Department_Id IS NULL THEN 'All Units'
--	 --  ELSE TRIM(Goal.Epic_Department_Name) + ' [' + TRIM(Goal.Epic_Department_Id) + ']'
--	 --END AS Unit_Goals
--    --,COALESCE([@unit_translation].Unit, Goal.UNIT) AS Unit_Goals
--    ,Goal.[DOMAIN]
--    ,COALESCE([@domain_translation].DOMAIN, Goal.DOMAIN) AS Domain_Goals
--    ,Goal.[GOAL]
--FROM [DS_HSDW_App].[Rptg].[PX_Goal_Setting] Goal
--LEFT OUTER JOIN @domain_translation
--    ON [@domain_translation].Goals_Domain = Goal.DOMAIN
----LEFT OUTER JOIN @unit_translation
------    ON [@unit_translation].Goals_Unit = CHCAHPS_PX_Goal_Setting.UNIT;
--LEFT OUTER JOIN @serviceline_translation
--    ON (COALESCE([@serviceline_translation].Goals_ServiceLine,'NULL') = COALESCE(Goal.SERVICE_LINE,'NULL'))
--WHERE Goal.Service = 'HCAHPS'
--AND Goal.GOAL_YR = 2020;
DECLARE @HCAHPS_PX_Goal_Setting TABLE
(
    GOAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , ServiceLine_Goals VARCHAR(150)
  , Epic_Department_Id VARCHAR(255)
  , Epic_Department_Name VARCHAR(255)
  , UNIT VARCHAR(150)
  --, Unit_Goals VARCHAR(150)
  , DOMAIN VARCHAR(150)
  , Domain_Goals VARCHAR(150)
  , GOAL DECIMAL(4,3)
);
INSERT INTO @HCAHPS_PX_Goal_Setting
SELECT
	[GOAL_YR]
	,Goal.SERVICE_LINE
	,COALESCE([@serviceline_translation].ServiceLine, Goal.SERVICE_LINE) AS ServiceLine_Goals
	--,Goal.Epic_Department_Id
	,CASE
	   WHEN Goal.Epic_Department_Id IS NULL THEN 'All Units'
	   ELSE Goal.Epic_Department_Id
	 END AS Epic_Department_Id
	,Goal.Epic_Department_Name
	--,CASE
	--   WHEN Goal.Epic_Department_Name IS NULL THEN 'All Units'
	--   ELSE Goal.Epic_Department_Name
	-- END AS Epic_Department_Name
    ,Goal.[UNIT]
  --  ,CASE
	 --  WHEN Goal.Epic_Department_Id IS NULL THEN 'All Units'
	 --  ELSE TRIM(Goal.Epic_Department_Name) + ' [' + TRIM(Goal.Epic_Department_Id) + ']'
	 --END AS Unit_Goals
    --,COALESCE([@unit_translation].Unit, Goal.UNIT) AS Unit_Goals
    ,Goal.[DOMAIN]
    ,COALESCE([@domain_translation].DOMAIN, Goal.DOMAIN) AS Domain_Goals
    ,Goal.[GOAL]
FROM [DS_HSDW_App].[Rptg].[PX_Goal_Setting] Goal
LEFT OUTER JOIN @domain_translation
    ON [@domain_translation].Goals_Domain = Goal.DOMAIN
--LEFT OUTER JOIN @unit_translation
----    ON [@unit_translation].Goals_Unit = CHCAHPS_PX_Goal_Setting.UNIT;
LEFT OUTER JOIN @serviceline_translation
    ON (COALESCE([@serviceline_translation].Goals_ServiceLine,'NULL') = COALESCE(Goal.SERVICE_LINE,'NULL'))
WHERE Goal.Service = 'HCAHPS'
AND Goal.GOAL_YR = 2020;

--SELECT *
--FROM @HCAHPS_PX_Goal_Setting
--ORDER BY SERVICE_LINE
--       , UNIT
--       , Epic_Department_Id
--	   , DOMAIN

--DECLARE @HCAHPS_PX_Goal_Setting_epic_id TABLE
--(
--    GOAL_YR INTEGER
--  , SERVICE_LINE VARCHAR(150)
--  , ServiceLine_Goals VARCHAR(150)
--  , Epic_Department_Id VARCHAR(10)
--  , Epic_Department_Name VARCHAR(30)
--  , UNIT VARCHAR(150)
--  --, Unit_Goals VARCHAR(150)
--  , DOMAIN VARCHAR(150)
--  , Domain_Goals VARCHAR(150)
--  , GOAL DECIMAL(4,3)
--  --, [Epic DEPARTMENT_ID] VARCHAR(50)
--  --, CLINIC VARCHAR(250)
--  --, INDEX IX_HCAHPS_PX_Goal_Setting_epic_id NONCLUSTERED(GOAL_YR, Unit_Goals, Domain_Goals)
--  , INDEX IX_HCAHPS_PX_Goal_Setting_epic_id NONCLUSTERED(GOAL_YR, Epic_Department_Id, Domain_Goals)
--);
--INSERT INTO @HCAHPS_PX_Goal_Setting_epic_id
--SELECT
--     goals.GOAL_YR
--    ,goals.SERVICE_LINE
--	,goals.ServiceLine_Goals
--	,goals.Epic_Department_Id
--	,goals.Epic_Department_Name
--    ,goals.UNIT
--    --,goals.Unit_Goals
--    ,goals.DOMAIN
--    ,goals.Domain_Goals
--    ,goals.GOAL
--	--,goals.Epic_Department_Id AS [Epic DEPARTMENT_ID]
--	--,goals.Unit_Goals AS CLINIC
--FROM @HCAHPS_PX_Goal_Setting goals
----ORDER BY goals.GOAL_YR, goals.Unit_Goals, goals.Domain_Goals;
--ORDER BY goals.GOAL_YR, goals.Epic_Department_Id, goals.Domain_Goals;

DECLARE @HCAHPS_PX_Goal_Setting_epic_id TABLE
(
    GOAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , ServiceLine_Goals VARCHAR(150)
  , Epic_Department_Id VARCHAR(255)
  , Epic_Department_Name VARCHAR(255)
  , UNIT VARCHAR(150)
  --, Unit_Goals VARCHAR(150)
  , DOMAIN VARCHAR(150)
  , Domain_Goals VARCHAR(150)
  , GOAL DECIMAL(4,3)
  --, [Epic DEPARTMENT_ID] VARCHAR(50)
  --, CLINIC VARCHAR(250)
  --, INDEX IX_HCAHPS_PX_Goal_Setting_epic_id NONCLUSTERED(GOAL_YR, Unit_Goals, Domain_Goals)
  , INDEX IX_HCAHPS_PX_Goal_Setting_epic_id NONCLUSTERED(GOAL_YR, Epic_Department_Id, Domain_Goals)
);
INSERT INTO @HCAHPS_PX_Goal_Setting_epic_id
SELECT
     goals.GOAL_YR
    ,goals.SERVICE_LINE
	,goals.ServiceLine_Goals
	,goals.Epic_Department_Id
	,goals.Epic_Department_Name
    ,goals.UNIT
    --,goals.Unit_Goals
    ,goals.DOMAIN
    ,goals.Domain_Goals
    ,goals.GOAL
	--,goals.Epic_Department_Id AS [Epic DEPARTMENT_ID]
	--,goals.Unit_Goals AS CLINIC
FROM @HCAHPS_PX_Goal_Setting goals
--ORDER BY goals.GOAL_YR, goals.Unit_Goals, goals.Domain_Goals;
ORDER BY goals.GOAL_YR, goals.Epic_Department_Id, goals.Domain_Goals;

--SELECT *
--FROM @HCAHPS_PX_Goal_Setting_epic_id
----ORDER BY SERVICE_LINE
----       , Unit_Goals
----       , [Epic DEPARTMENT_ID]
----	   , DOMAIN
--ORDER BY SERVICE_LINE
--       , Epic_Department_Id
--	   , DOMAIN

DECLARE @RptgTbl TABLE
(
    SVC_CDE CHAR(2)
  , GOAL_FISCAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , UNIT VARCHAR(150)
  , EPIC_DEPARTMENT_ID VARCHAR(255)
  , EPIC_DEPARTMENT_NAME VARCHAR(255)
  , DOMAIN VARCHAR(150)
  , GOAL DECIMAL(4,3)
  , Load_Dtm SMALLDATETIME
);

INSERT INTO @RptgTbl
(
    SVC_CDE,
    GOAL_FISCAL_YR,
    SERVICE_LINE,
    UNIT,
	EPIC_DEPARTMENT_ID,
	EPIC_DEPARTMENT_NAME,
    DOMAIN,
    GOAL,
    Load_Dtm
)
SELECT all_goals.SVC_CDE
     , all_goals.GOAL_YR
	 , all_goals.SERVICE_LINE
	 , all_goals.UNIT
	 , all_goals.Epic_Department_Id
	 , all_goals.Epic_Department_Name
	 , all_goals.DOMAIN
	 , all_goals.GOAL
	 , all_goals.Load_Dtm
FROM
(
-- 2020
SELECT DISTINCT
    'IN' AS SVC_CDE
  , CAST(2020 AS INT) AS GOAL_YR
  , CAST(goals.ServiceLine_Goals AS VARCHAR(150)) AS SERVICE_LINE
  --, CAST(goals.CLINIC AS VARCHAR(150)) AS UNIT
  , goals.UNIT
  , goals.Epic_Department_Id
  , goals.Epic_Department_Name
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @HCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.GOAL_YR = 2020
--AND ((goals.Unit_Goals IS NOT NULL) AND (goals.Unit_Goals <> 'All Units'))
AND ((goals.Epic_Department_Id IS NOT NULL) AND (goals.Epic_Department_Id <> 'All Units'))
AND goals.DOMAIN IS NOT NULL
AND goals.GOAL IS NOT NULL
UNION ALL
SELECT DISTINCT
    'IN' AS SVC_CDE
  , CAST(2020 AS INT) AS GOAL_YR
  , CAST(goals.ServiceLine_Goals AS VARCHAR(150)) AS SERVICE_LINE
  --, CAST('All Units' AS VARCHAR(150)) AS UNIT
  , goals.UNIT
  , goals.Epic_Department_Id
  , goals.Epic_Department_Name
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @HCAHPS_PX_Goal_Setting_epic_id goals
--WHERE goals.Unit_Goals = 'All Units' AND goals.GOAL_YR = 2020
WHERE goals.ServiceLine_Goals <> 'All Service Lines' AND goals.Epic_Department_Id = 'All Units' AND goals.GOAL_YR = 2020
AND goals.DOMAIN IS NOT NULL
UNION ALL
SELECT DISTINCT
    'IN' AS SVC_CDE
  , CAST(2020 AS INT) AS GOAL_YR
  --, CAST('All Service Lines' AS VARCHAR(150)) AS SERVICE_LINE
  , goals.ServiceLine_Goals AS SERVICE_LINE
  --, CAST('All Units' AS VARCHAR(150)) AS UNIT
  , goals.UNIT
  , goals.Epic_Department_Id
  , goals.Epic_Department_Name
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @HCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.ServiceLine_Goals = 'All Service Lines' AND GOAL_YR = 2020
AND goals.DOMAIN IS NOT NULL
) all_goals;

SELECT *
FROM @RptgTbl
ORDER BY GOAL_FISCAL_YR
       , SERVICE_LINE
       , EPIC_DEPARTMENT_ID
	   , DOMAIN

--SELECT DISTINCT
--	GOAL_YR
--  , UNIT
--FROM @RptgTbl
--ORDER BY GOAL_YR
--       , UNIT
