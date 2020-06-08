USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

--ALTER PROC [Rptg].[uspSrc_Dash_PatExp_HCAHPS_Units]
--AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - HCAHPS (Inpatient) - By Unit
WHO : Chris Mitchell
WHEN: 11/29/2016
WHY : Produce surveys results for patient experience dashboard
-----------------------------------------------------------------------------------------------------------------------
INFO: 
      INPUTS:	DS_HSDW_Prod.dbo.Fact_PressGaney_Responses
				DS_HSDW_Prod.rptg.Balanced_Scorecard_Mapping
				DS_HSDW_Prod.dbo.Dim_PG_Question
				DS_HSDW_Prod.dbo.Fact_Pt_Acct
				DS_HSDW_Prod.dbo.Dim_Pt
				DS_HSDW_Prod.dbo.Dim_Physcn
				DS_HSDW_Prod.dbo.Dim_Date
				DS_HSDW_App.Rptg.[PG_Extnd_Attr]
                  
      OUTPUTS:  HCAHPS Survey Results
   
------------------------------------------------------------------------------------------------------------------------
MODS: 	12/1/2016 - Mapped to Balanced Scorecard Mapping to pull service line of the unit rather than from service line
		of the physician.  Units OBS, ADMT (Closed), NNICU, MSIC values were never sent to press ganey as a NURSTA
		[HSTSDSSQLDM].[DS_HSDM_Ext_OutPuts].[DwStage].[Press_Ganey_DW_Submission]
		ADMT (Cloased) was sent as ADMT, MSIC was sent as ADMT, NNICU was sent as NNIC, OBS was sent as either 8NOR or 
		8COB (both Womens and Childrens Service Line)...have to handle these manually when mapping to Balanced Scorecard
		Mapping
		12/7/2016 - Rena Morse - SET NOCOUNT ON added; Fixed Tableau import error by casting 
		DS_HSDW_Prod.dbo.Fact_PressGaney_Responses.VALUE data type as NVARCHAR(500) (originally VARCHAR(5500))
		12/12/2016 - changed alias of admit (other) msicu (other) msic (other) er (other)
		1/31/2017 - Per Patient Experience Office, include adjusted removed surveys (all in)
				  - Per Patient Experience Office, send unit "No Unit" to "Other" and include in "All Units"
				  - Per Patient Experience Office, send No Service Line to Other Service Line and include in
				    "All Service Lines"
		06/11/2018 - Add communication about pain domain questions '2412','2414'
		09/23/2019 - TMB - changed logic that assigns targets to domains
		10/08/2019 - TMB - correct logic that assigns the 2020 targets
		10/15/2019 - TMB - use Goal Service Line as the extracted/reported value for a survey
***********************************************************************************************************************/

SET NOCOUNT ON

---------------------------------------------------
---Default date range is the first day of the current month 2 years ago until the last day of the current month
DECLARE @currdate AS DATE;
DECLARE @startdate AS DATE;
DECLARE @enddate AS DATE;

    SET @currdate=CAST(GETDATE() AS DATE);

    IF @startdate IS NULL
        AND @enddate IS NULL
        BEGIN
            SET @startdate = CAST(DATEADD(MONTH,DATEDIFF(MONTH,0,DATEADD(MONTH,-24,GETDATE())),0) AS DATE); 
            SET @enddate= CAST(EOMONTH(GETDATE()) AS DATE); 
        END; 

----------------------------------------------------
DECLARE @locstartdate SMALLDATETIME,
        @locenddate SMALLDATETIME

SET @locstartdate = @startdate
SET @locenddate   = @enddate

IF OBJECT_ID('tempdb..#surveys_ip ') IS NOT NULL
DROP TABLE #surveys_ip
DECLARE @response_department_goal_unit_translation TABLE
(
    Goal_Fiscal_Yr INT NOT NULL -- Fiscal year for translation
  , Response_Epic_Department_Id NVARCHAR(500) NOT NULL -- Epic department id value assigned to survey
  , Response_Epic_Department_Name NVARCHAR(500) NOT NULL -- Epic department name value assigned to survey
  , Goals_Unit NVARCHAR(500) NULL -- Value documented in Goals file
);
INSERT INTO @response_department_goal_unit_translation
(
    Goal_Fiscal_Yr,
    Response_Epic_Department_Id,
    Response_Epic_Department_Name,
    Goals_Unit
)
VALUES
('2018','10243051','UVHE 3 CENTRAL','3CENTRAL'),
('2018','10243052','UVHE 3 EAST','3EAST'),
('2018','10243089','UVHE 3 NORTH','3NOR'),
('2018','10243053','UVHE 3 WEST','3WEST'),
('2018','10243054','UVHE 4 CENTRAL CV','4CEN'),
('2018','10243110','UVHE 4 CENTRAL TXP',NULL),
('2018','10243055','UVHE 4 EAST','4EAST'),
('2018','10243091','UVHE 4 NORTH','4NOR'),
('2018','10243057','UVHE 4 WEST','4WEST'),
('2018','10243058','UVHE 5 CENTRAL','5CENTRAL'),
('2018','10243090','UVHE 5 NORTH','5NOR'),
('2018','10243060','UVHE 5 WEST','5WEST'),
('2018','10243061','UVHE 6 CENTRAL','6CEN'),
('2018','10243062','UVHE 6 EAST','6EAST'),
('2018','10243092','UVHE 6 NORTH',NULL),
('2018','10243063','UVHE 6 WEST','6WEST'),
('2018','10243113','UVHE 7 NORTH OB','OBS'),
('2018','10243065','UVHE 7 WEST',NULL),
('2018','10243066','UVHE 8 CENTRAL OB','8COB'),
('2018','10243094','UVHE 8 NORTH OB','8NOR'),
('2018','10243067','UVHE 8 TEMPORARY','8COB'),
('2018','10243068','UVHE 8 WEST','8WEST'),
('2018','10243096','UVHE 8 WEST STEM CELL','8WSC'),
('2018','10243012','UVHE CARDIAC CATH LAB',NULL),
('2018','10243035','UVHE CORONARY CARE','CCU'),
('2018','10243013','UVHE ELECTROPHYSIOLOGY',NULL),
('2018','10243037','UVHE LABOR & DELIVERY',NULL),
('2018','10243038','UVHE MEDICAL ICU','MICU'),
('2018','10243041','UVHE NEUR ICU','NNIC'),
('2018','10243900','UVHE PERIOP',NULL),
('2018','10243047','UVHE SHORT STAY UNIT','SSU'),
('2018','10243046','UVHE SURG TRAM ICU','SICU'),
('2018','10243049','UVHE TCV POST OP','TCPO'),
('2018','10239020','UVMS SURG TRANSPLANT',NULL),
('2018','10239019','UVMS TRANSPLANT KIDNEY',NULL),
('2018','10239017','UVMS TRANSPLANT LIVER',NULL),
('2018','10239018','UVMS TRANSPLANT LUNG',NULL),
('2019','10243051','UVHE 3 CENTRAL','3CENTRAL'),
('2019','10243052','UVHE 3 EAST','3EAST'),
('2019','10243089','UVHE 3 NORTH','3NMICU'),
('2019','10243053','UVHE 3 WEST','3WEST'),
('2019','10243054','UVHE 4 CENTRAL CV','4CEN/4CCV'),
('2019','10243110','UVHE 4 CENTRAL TXP','4CTXP'),
('2019','10243055','UVHE 4 EAST','4EAST'),
('2019','10243091','UVHE 4 NORTH','4NTCVPO'),
('2019','10243057','UVHE 4 WEST','4WEST'),
('2019','10243058','UVHE 5 CENTRAL','5CENTRAL'),
('2019','10243090','UVHE 5 NORTH','5N'),
('2019','10243060','UVHE 5 WEST','5 West'),
('2019','10243061','UVHE 6 CENTRAL','6CEN'),
('2019','10243062','UVHE 6 EAST','6EAST'),
('2019','10243092','UVHE 6 NORTH','6NOR'),
('2019','10243063','UVHE 6 WEST','6WEST'),
('2019','10243113','UVHE 7 NORTH OB','7NOB'),
('2019','10243065','UVHE 7 WEST',NULL),
('2019','10243066','UVHE 8 CENTRAL OB','8COB'),
('2019','10243094','UVHE 8 NORTH OB','8NOR'),
('2019','10243115','UVHE 8 NORTH ONC',NULL),
('2019','10243068','UVHE 8 WEST','8WEST'),
('2019','10243096','UVHE 8 WEST STEM CELL','8WSC'),
('2019','10243035','UVHE CORONARY CARE','CCU'),
('2019','10243037','UVHE LABOR & DELIVERY',NULL),
('2019','10243038','UVHE MEDICAL ICU','3WMICU'),
('2019','10243041','UVHE NEUR ICU','NNIC'),
('2019','10243100','UVHE PICU 7NORTH',NULL),
('2019','10243047','UVHE SHORT STAY UNIT','SSU/SSU ED'),
('2019','10243046','UVHE SURG TRAM ICU','SICU'),
('2019','10243049','UVHE TCV POST OP','4WTCVPO')
;

SELECT DISTINCT
	 Resp.SURVEY_ID
	,Resp.sk_Fact_Pt_Acct
	,Resp.RECDATE
	,Resp.DISDATE
	,ddte.Fyear_num AS REC_FY
	,phys.DisplayName AS Phys_Name
	,phys.DEPT AS Phys_Dept
	,phys.Division AS Phys_Div
	,CASE WHEN RespUnit.UNIT = 'obs' THEN 'Womens and Childrens'
		  WHEN bcsm.Service_Line IS NULL THEN 'Other'
		  ELSE bcsm.Service_Line
		  END AS Service_Line -- obs appears as both 8nor and 8cob
	,CASE WHEN RespUnit.UNIT IS NULL THEN 'Other' ELSE RespUnit.UNIT END AS UNIT
    ,CAST(COALESCE(unittrns.Goals_Unit,'Unknown') AS VARCHAR(150)) AS Goals_UNIT
	,CAST(COALESCE(dep.DEPARTMENT_ID,'Unknown') AS VARCHAR(255)) AS DEPARTMENT_ID
	,dep.Clrt_DEPt_Nme AS Clrt_DEPt_Nme
	,COALESCE(CASE WHEN mdm.service_line = 'Unknown' OR (ddte.Fyear_num = 2018 AND mdm.service_line = 'Transplant') THEN
			       CASE WHEN RespUnit.UNIT = 'obs' THEN 'Womens and Childrens'
				        WHEN bcsm.Service_Line IS NULL THEN 'Other'
				        ELSE bcsm.Service_Line
			       END
		           ELSE mdm.service_line
	          END, 'Unknown') AS Goals_Service_Line
	,CAST(Resp.VALUE AS NVARCHAR(500)) AS VALUE -- prevents Tableau from erroring out on import data source
	,CASE WHEN Resp.VALUE IS NOT NULL THEN 1 ELSE 0 END AS VAL_COUNT
	,extd.DOMAIN
	,CASE WHEN Resp.sk_Dim_PG_Question = '7' THEN 'Quietness' WHEN Resp.sk_Dim_PG_Question = '6' THEN 'Cleanliness' WHEN (Resp.sk_Dim_PG_Question IN ('2412','2414')) THEN 'Pain Management' ELSE DOMAIN END AS Domain_Goals
	,CASE WHEN Resp.sk_Dim_PG_Question = '17' THEN -- Rate Hospital 0-10
		CASE WHEN Resp.VALUE IN ('10-Best possible','9') THEN 'Very Good'
			WHEN Resp.VALUE IN ('7','8') THEN 'Good'
			WHEN Resp.VALUE IN ('5','6') THEN 'Average'
			WHEN Resp.VALUE IN ('3','4') THEN 'Poor'
			WHEN Resp.VALUE IN ('0-Worst possible','1','2') THEN 'Very Poor'
		END
	 ELSE
		CASE WHEN resp.sk_Dim_PG_Question <> '4' THEN -- Age
			CASE WHEN Resp.VALUE = '5' THEN 'Very Good'
				WHEN Resp.VALUE = '4' THEN 'Good'
				WHEN Resp.VALUE = '3' THEN 'Average'
				WHEN Resp.VALUE = '2' THEN 'Poor'
				WHEN Resp.VALUE = '1' THEN 'Very Poor'
				ELSE CAST(Resp.VALUE AS NVARCHAR(500))
			END
		ELSE CAST(Resp.VALUE AS NVARCHAR(500))
		END
	 END AS Value_Resp_Grp
	,CASE WHEN Resp.sk_Dim_PG_Question IN
	(
		'1','2','37','38','84','85','86','87','88','89','90','92','93','105','106', -- 1-5 scale questions
		'113','126','127','130','136','288','482','519','521','526','1238'
	)
	AND Resp.VALUE = '5' THEN 1 -- Top Answer for a 1-5 question
	ELSE
		CASE WHEN resp.sk_Dim_PG_Question = '17' AND resp.VALUE IN ('10-Best possible','9') THEN 1 -- Rate Hospital 0-10
		ELSE
			CASE WHEN resp.sk_Dim_PG_Question IN
				(
					'5','6','7','11','24','27','32','33','34','99','101','108','110','112','2412','2414' -- Always, Usually, Sometimes, Never scale questions
				)
			AND Resp.VALUE = 'Always' THEN 1  -- Top Answer
			ELSE
				CASE WHEN resp.sk_Dim_PG_Question = '18' AND Resp.VALUE = 'Definitely Yes' THEN 1 -- Recommend Hospital
				ELSE
					CASE WHEN Resp.sk_Dim_PG_Question IN ('28','29','30') AND Resp.VALUE = 'Strongly Agree' THEN 1 -- Str Agree - Strongly disagree scale questions
					ELSE 
						CASE WHEN Resp.sk_Dim_PG_Question IN ('14','16') AND Resp.VALUE = 'Yes' THEN 1 -- Yes/No scale questions
						ELSE 0
						END
					END
				END
			END
		END
	 END AS TOP_BOX
	,qstn.VARNAME
	,qstn.sk_Dim_PG_Question
	,extd.QUESTION_TEXT_ALIAS -- Short form of question text
	,fpa.MRN_int
	,phys.NPINumber
	,ISNULL(pat.PT_LNAME + ', ' + pat.PT_FNAME_MI, NULL) AS Pat_Name
	,pat.BIRTH_DT AS Pat_DOB
	,FLOOR((CAST(GETDATE() AS INTEGER) - CAST(pat.BIRTH_DT AS INTEGER)) / 365.25) AS Pat_Age -- actual age today
	,FLOOR((CAST(Resp.RECDATE AS INTEGER) - CAST(pat.BIRTH_DT AS INTEGER)) / 365.25) AS Pat_Age_Survey_Recvd -- Age when survey received
	,Resp_Age.AGE AS Pat_Age_Survey_Answer -- Age Answered on Survey VARNAME Age
	,CASE WHEN pat.PT_SEX = 'F' THEN 'Female'
		  WHEN pat.pt_sex = 'M' THEN 'Male'
	 ELSE 'Not Specified' END AS Pat_Sex
	INTO #surveys_ip
	FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses AS Resp
	INNER JOIN DS_HSDW_Prod.dbo.Dim_PG_Question AS qstn
		ON Resp.sk_Dim_PG_Question = qstn.sk_Dim_PG_Question
	INNER JOIN DS_HSDW_Prod.Rptg.vwDim_Date ddte
	ON ddte.day_date = Resp.RECDATE
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Fact_Pt_Acct AS fpa -- LEFT OUTER, including -1 or survey counts won't match press ganey
		ON Resp.sk_Fact_Pt_Acct = fpa.sk_Fact_Pt_Acct
	LEFT OUTER JOIN
	(	
		SELECT DISTINCT
		SURVEY_ID
		,CASE VALUE
			WHEN 'ADMT (Closed)' THEN 'Other'
			WHEN 'ER' THEN 'Other'
			WHEN 'ADMT' THEN 'Other'
			WHEN 'MSIC' THEN 'Other'
			WHEN 'MSICU' THEN 'Other'
			WHEN 'NNICU' THEN 'NNIC'
			ELSE CAST(VALUE AS NVARCHAR(500)) END AS UNIT
		FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses WHERE sk_Dim_PG_Question = '96' -- (UNITS in CASE don't have a corresponding match in Balanced Scorecard Mapping, OBS handled separately)
	) AS RespUnit
	ON Resp.SURVEY_ID = RespUnit.SURVEY_ID
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Dim_Pt AS pat
		ON Resp.sk_Dim_Pt = pat.sk_Dim_Pt
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Dim_Physcn AS phys
		ON Resp.sk_Dim_Physcn = phys.sk_Dim_Physcn
	LEFT OUTER JOIN
	(
		SELECT SURVEY_ID, CAST(MAX(VALUE) AS NVARCHAR(500)) AS AGE FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses
		WHERE sk_Fact_Pt_Acct > 0 AND sk_Dim_PG_Question = '4' -- Age question for Inpatient
		GROUP BY SURVEY_ID
	) Resp_Age
		ON Resp.SURVEY_ID = Resp_Age.SURVEY_ID 
	LEFT OUTER JOIN
	(
		SELECT DISTINCT sk_Dim_PG_Question, DOMAIN, QUESTION_TEXT_ALIAS FROM DS_HSDW_App.Rptg.PG_Extnd_Attr
	) extd
		ON RESP.sk_Dim_PG_Question = extd.sk_Dim_PG_Question
	LEFT OUTER JOIN DS_HSDW_Prod.Rptg.Balanced_ScoreCard_Mapping bcsm
		ON RespUnit.UNIT = bcsm.PressGaney_name
	LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
	    ON dep.sk_Dim_Clrt_DEPt = Resp.sk_Dim_Clrt_DEPt
	LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc mdm
		ON mdm.epic_department_id = dep.DEPARTMENT_ID
	LEFT OUTER JOIN @response_department_goal_unit_translation unittrns
		ON unittrns.[Goal_Fiscal_Yr] = ddte.Fyear_num
		AND CAST(unittrns.Response_Epic_Department_Id AS NUMERIC(18,0)) = dep.DEPARTMENT_ID
	WHERE  Resp.Svc_Cde='IN' AND qstn.sk_Dim_PG_Question IN
	(
		'1','2','4','5','6','7','11','14','16','17','18','24','27','28','29',
		'30','32','33','34','37','38','84','85','86','87','87','88','89',
		'90','92','93','99','101','105','106','108','110','112','113','126','127',
		'130','136','288','482','519','521','526','1238','2412','2414'
	)
    AND resp.RECDATE >= '7/1/2019 00:00 AM'
	ORDER BY REC_FY, UNIT, Goals_UNIT, Service_Line, Goals_Service_Line, DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID

  -- Create indexes for temp table #surveys_ip
  CREATE NONCLUSTERED INDEX IX_surveysip ON #surveys_ip (REC_FY, UNIT, Goals_UNIT, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID)
  CREATE NONCLUSTERED INDEX IX_surveysip2 ON #surveys_ip (REC_FY, Service_Line, Goals_Service_Line, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID)
  CREATE NONCLUSTERED INDEX IX_surveysip3 ON #surveys_ip (REC_FY, DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID)

------------------------------------------------------------------------------------------

--SELECT *
--FROM DS_HSDW_App.Rptg.PX_Goal_Setting
--WHERE Service = 'HCAHPS'
----AND GOAL_YR = 2020
----AND ((UNIT IS NULL) OR (UNIT IS NOT NULL AND UNIT <> 'All PEDS Units'))
----AND DOMAIN IS NOT NULL
----AND GOAL IS NOT NULL
--ORDER BY UNIT
--	   , Epic_Department_Id
--	   , DOMAIN

------------------------------------------------------------------------------------------
  
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

DECLARE @HCAHPS_PX_Goal_Setting TABLE
(
    GOAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , ServiceLine_Goals VARCHAR(150)
  , Epic_Department_Id VARCHAR(255)
  , Epic_Department_Name VARCHAR(255)
  , UNIT VARCHAR(150)
  , DOMAIN VARCHAR(150)
  , Domain_Goals VARCHAR(150)
  , GOAL DECIMAL(4,3)
);
INSERT INTO @HCAHPS_PX_Goal_Setting
SELECT
	[GOAL_YR]
	,Goal.SERVICE_LINE
	,COALESCE([@serviceline_translation].ServiceLine, Goal.SERVICE_LINE) AS ServiceLine_Goals
	,CASE
	   WHEN Goal.Epic_Department_Id IS NULL THEN 'All Units'
	   ELSE Goal.Epic_Department_Id
	 END AS Epic_Department_Id
	,Goal.Epic_Department_Name
    ,Goal.[UNIT]
    ,Goal.[DOMAIN]
    ,COALESCE([@domain_translation].DOMAIN, Goal.DOMAIN) AS Domain_Goals
    ,Goal.[GOAL]
FROM [DS_HSDW_App].[Rptg].[PX_Goal_Setting] Goal
LEFT OUTER JOIN @domain_translation
    ON [@domain_translation].Goals_Domain = Goal.DOMAIN
LEFT OUTER JOIN @serviceline_translation
    ON (COALESCE([@serviceline_translation].Goals_ServiceLine,'NULL') = COALESCE(Goal.SERVICE_LINE,'NULL'))
WHERE Goal.Service = 'HCAHPS'
AND Goal.GOAL_YR = 2020;

DECLARE @HCAHPS_PX_Goal_Setting_epic_id TABLE
(
    GOAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , ServiceLine_Goals VARCHAR(150)
  , Epic_Department_Id VARCHAR(255)
  , Epic_Department_Name VARCHAR(255)
  , UNIT VARCHAR(150)
  , DOMAIN VARCHAR(150)
  , Domain_Goals VARCHAR(150)
  , GOAL DECIMAL(4,3)
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
    ,goals.DOMAIN
    ,goals.Domain_Goals
    ,goals.GOAL
FROM @HCAHPS_PX_Goal_Setting goals
ORDER BY goals.GOAL_YR, goals.Epic_Department_Id, goals.Domain_Goals;
/*
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
  , goals.UNIT
  , goals.Epic_Department_Id
  , goals.Epic_Department_Name
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @HCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.ServiceLine_Goals <> 'All Service Lines' AND goals.Epic_Department_Id = 'All Units' AND goals.GOAL_YR = 2020
AND goals.DOMAIN IS NOT NULL
UNION ALL
SELECT DISTINCT
    'IN' AS SVC_CDE
  , CAST(2020 AS INT) AS GOAL_YR
  , goals.ServiceLine_Goals AS SERVICE_LINE
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
*/

SELECT *
FROM @HCAHPS_PX_Goal_Setting_epic_id
--WHERE GOAL_YR = 2020
--AND ((Epic_Department_Id IS NOT NULL) AND (Epic_Department_Id <> 'All Units'))
--AND DOMAIN IS NOT NULL
--AND GOAL IS NOT NULL
--WHERE ServiceLine_Goals <> 'All Service Lines' AND Epic_Department_Id = 'All Units' AND GOAL_YR = 2020
--AND DOMAIN IS NOT NULL
WHERE ServiceLine_Goals = 'All Service Lines' AND GOAL_YR = 2020
AND DOMAIN IS NOT NULL
ORDER BY Epic_Department_Id
       , Domain_Goals
--ORDER BY UNIT
--       , Domain_Goals

------------------------------------------------------------------------------------------
/*
SELECT DISTINCT
    --SERVICE_LINE,
    --UNIT,
    DOMAIN
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'HCAHPS'
AND SERVICE_LINE IS NOT NULL
AND Epic_Department_Id IS NULL
--ORDER BY SERVICE_LINE
--       , UNIT
--	   , DOMAIN
ORDER BY DOMAIN

SELECT DISTINCT
	resp.Domain_Goals
FROM #surveys_ip resp
WHERE resp.Domain_Goals IS NOT NULL
ORDER BY resp.Domain_Goals

------------------------------------------------------------------------------------------

SELECT DISTINCT
    SERVICE_LINE
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'HCAHPS'
AND SERVICE_LINE IS NOT NULL
ORDER BY SERVICE_LINE

SELECT DISTINCT
	resp.SERVICE_LINE
FROM #surveys_ip resp
ORDER BY resp.SERVICE_LINE

------------------------------------------------------------------------------------------

SELECT DISTINCT
    SERVICE_LINE
  , UNIT
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'CHCAHPS'
ORDER BY UNIT

------------------------------------------------------------------------------------------

SELECT DISTINCT
    Epic_Department_Id
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'CHCAHPS'
ORDER BY Epic_Department_Id

SELECT DISTINCT
	resp.EPIC_DEPARTMENT_ID
  , resp.goal_EPIC_DEPARTMENT_ID
FROM #surveys_ch_ip_sl resp
ORDER BY resp.goal_EPIC_DEPARTMENT_ID
*/
GO
