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
***********************************************************************************************************************/

SET NOCOUNT ON

---------------------------------------------------
---Default date range is the first day of the current month 2 years ago until the last day of the current month
DECLARE @currdate AS DATE;
DECLARE @startdate AS DATE;
DECLARE @enddate AS DATE;

SET @startdate = '7/1/2017 00:00 AM'
SET @enddate = '6/30/2020 11:59 PM'

    SET @currdate=CAST(GETDATE() AS DATE);

    IF @startdate IS NULL
        AND @enddate IS NULL
        BEGIN
            SET @startdate = CAST(DATEADD(MONTH,DATEDIFF(MONTH,0,DATEADD(MONTH,-24,GETDATE())),0) AS DATE); 
            SET @enddate= CAST(EOMONTH(GETDATE()) AS DATE); 
        END; 

----------------------------------------------------

IF OBJECT_ID('tempdb..#surveys_ip ') IS NOT NULL
DROP TABLE #surveys_ip

IF OBJECT_ID('tempdb..#surveys_ip_check ') IS NOT NULL
DROP TABLE #surveys_ip_check

IF OBJECT_ID('tempdb..#surveys_ip2 ') IS NOT NULL
DROP TABLE #surveys_ip2

IF OBJECT_ID('tempdb..#surveys_ip3 ') IS NOT NULL
DROP TABLE #surveys_ip3

IF OBJECT_ID('tempdb..#HCAHPS_Units ') IS NOT NULL
DROP TABLE #HCAHPS_Units

--SELECT *
--FROM Rptg.HCAHPS_Goals_Test
--ORDER BY GOAL_FISCAL_YR
--       , SERVICE_LINE
--	   , UNIT
--	   , DOMAIN

SELECT DISTINCT
	 Resp.SURVEY_ID
	,Resp.sk_Fact_Pt_Acct
	,Resp.RECDATE
	,Resp.DISDATE
	,Resp.FY
	,phys.DisplayName AS Phys_Name
	,phys.DEPT AS Phys_Dept
	,phys.Division AS Phys_Div
	,RespUnit.resp_UNIT
	,RespUnit.trnsf_UNIT
	--,CASE WHEN RespUnit.UNIT = 'obs' THEN 'Womens and Childrens'
	--	  WHEN bcsm.Service_Line IS NULL THEN 'Other'
	--	  ELSE bcsm.Service_Line
	--	  END AS Service_Line -- obs appears as both 8nor and 8cob
	,CASE WHEN RespUnit.trnsf_UNIT = 'obs' THEN 'Womens and Childrens'
		  WHEN bcsm.Service_Line IS NULL THEN 'Other'
		  ELSE bcsm.Service_Line
		  END AS trnsf_Service_Line -- obs appears as both 8nor and 8cob
	--,mdm.service_line AS Service_Line
	--,CASE WHEN RespUnit.UNIT IS NULL THEN 'Other' ELSE RespUnit.UNIT END AS UNIT
	,CASE WHEN RespUnit.trnsf_UNIT IS NULL THEN 'Other' ELSE RespUnit.trnsf_UNIT END AS UNIT
	,Resp.sk_Dim_Clrt_DEPt
	--,bcsm.[Epic DEPARTMENT_ID] AS bcsm_Epic_DEPARTMENT_ID
	--,dep1.Clrt_DEPt_Nme AS bcsm_Clrt_DEPt_Nme
	--,dep2.DEPARTMENT_ID AS dep_DEPARTMENT_ID
	--,dep2.Clrt_DEPt_Nme AS dep_Clrt_DEPt_Nme
	,dep.DEPARTMENT_ID AS dep_DEPARTMENT_ID
	,dep.Clrt_DEPt_Nme AS dep_Clrt_DEPt_Nme
	--,mdm.service_line AS mdm_Service_Line
	,CASE WHEN mdm.service_line = 'Unknown' OR (Resp.FY = 2018 AND mdm.service_line = 'Transplant') THEN
			CASE WHEN RespUnit.trnsf_UNIT = 'obs' THEN 'Womens and Childrens'
				WHEN bcsm.Service_Line IS NULL THEN 'Other'
				ELSE bcsm.Service_Line
			END
		  ELSE mdm.service_line
	 END AS mdm_Service_Line
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
	ON ddte.day_date = Resp.DISDATE
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Fact_Pt_Acct AS fpa -- LEFT OUTER, including -1 or survey counts won't match press ganey
		ON Resp.sk_Fact_Pt_Acct = fpa.sk_Fact_Pt_Acct
	LEFT OUTER JOIN
	(	
		SELECT DISTINCT
		SURVEY_ID
		,VALUE AS resp_UNIT
		,CASE VALUE
			WHEN 'ADMT (Closed)' THEN 'Other'
			WHEN 'ER' THEN 'Other'
			WHEN 'ADMT' THEN 'Other'
			WHEN 'MSIC' THEN 'Other'
			WHEN 'MSICU' THEN 'Other'
			WHEN 'NNICU' THEN 'NNIC'
			ELSE CAST(VALUE AS NVARCHAR(500)) END AS trnsf_UNIT
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
		--ON RespUnit.UNIT = bcsm.PressGaney_name
		ON RespUnit.trnsf_UNIT = bcsm.PressGaney_name
	--LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep1
	--    ON dep1.DEPARTMENT_ID = CAST(bcsm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
	--LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep2
	--    ON dep2.sk_Dim_Clrt_DEPt = Resp.sk_Dim_Clrt_DEPt
	--LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc mdm
	--	ON mdm.epic_department_id = dep2.DEPARTMENT_ID
	LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
	    ON dep.sk_Dim_Clrt_DEPt = Resp.sk_Dim_Clrt_DEPt
	LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc mdm
		ON mdm.epic_department_id = dep.DEPARTMENT_ID
	--WHERE  Resp.Svc_Cde='IN' AND Resp.FY = 2020 AND qstn.sk_Dim_PG_Question IN
	--WHERE  Resp.Svc_Cde='IN' AND Resp.FY = 2019 AND qstn.sk_Dim_PG_Question IN
	WHERE  Resp.Svc_Cde='IN' AND (Resp.FY BETWEEN 2018 AND 2020) AND qstn.sk_Dim_PG_Question IN
	(
		'1','2','4','5','6','7','11','14','16','17','18','24','27','28','29',
		'30','32','33','34','37','38','84','85','86','87','87','88','89',
		'90','92','93','99','101','105','106','108','110','112','113','126','127',
		'130','136','288','482','519','521','526','1238','2412','2414'
	)
	--AND Resp.SURVEY_ID NOT IN -- Remove adjusted internet surveys
	--(
	--	SELECT
	--		SURVEY_ID
	--	FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses ResAdj
	--	INNER JOIN DS_HSDW_Prod.dbo.Dim_PG_Question QuestAdj
	--	ON ResAdj.sk_Dim_PG_Question = QuestAdj.sk_Dim_PG_Question AND ResAdj.Svc_Cde = QuestAdj.Svc_Cde
	--	WHERE QuestAdj.VARNAME = 'ADJSAMP' AND QuestAdj.Svc_Cde = 'IN' AND VALUE = 'NOT INCLUDED'
	--)

--SELECT *
--SELECT DISTINCT
--	FY
--  , resp_UNIT
--  , trnsf_UNIT
--  , UNIT
--  , trnsf_Service_Line
--  , mdm_Service_Line
--  , sk_Dim_Clrt_DEPt
--  , dep_DEPARTMENT_ID
--  , dep_Clrt_DEPt_Nme
SELECT
	resp.FY
  , resp.resp_UNIT
  , resp.trnsf_UNIT
  , resp.UNIT
  , resp.trnsf_Service_Line
  , resp.mdm_Service_Line
  , resp.sk_Dim_Clrt_DEPt
  , resp.dep_DEPARTMENT_ID
  , resp.dep_Clrt_DEPt_Nme
  , resp.Domain_Goals
  , COUNT(resp.SURVEY_ID) AS Domain_Count
INTO #surveys_ip_check
FROM #surveys_ip resp
--WHERE Service_Line = 'Unknown'
GROUP BY
	resp.FY
  , resp.resp_UNIT
  , resp.trnsf_UNIT
  , resp.UNIT
  , resp.trnsf_Service_Line
  , resp.mdm_Service_Line
  , resp.sk_Dim_Clrt_DEPt
  , resp.dep_DEPARTMENT_ID
  , resp.dep_Clrt_DEPt_Nme
  , resp.Domain_Goals
--ORDER BY SURVEY_ID
--       , Service_Line
--	   , UNIT
--	   , sk_Dim_PG_Question
--ORDER BY FY
--       , SURVEY_ID
--       , Service_Line
--	   , dep_DEPARTMENT_ID
--	   , sk_Dim_PG_Question
--ORDER BY FY
--       , Service_Line
--       , SURVEY_ID
--	   , dep_DEPARTMENT_ID
--	   , sk_Dim_PG_Question
--ORDER BY FY
--       , Service_Line
--       , UNIT
--	   , sk_Dim_Clrt_DEPt
--ORDER BY resp.FY
--       , resp.trnsf_Service_Line
--       , resp.UNIT
--	   , resp.dep_Clrt_DEPt_Nme
--	   , resp.Domain_Goals

--SELECT DISTINCT
--	raw_UNIT
--  , dep_DEPARTMENT_ID
--  , dep_Clrt_DEPt_Nme
--FROM #surveys_ip
--ORDER BY raw_UNIT
--       , dep_Clrt_DEPt_Nme

--SELECT DISTINCT
--	FY
--  , Service_Line
--  , UNIT
--  , dep_DEPARTMENT_ID
--  , dep_Clrt_DEPt_Nme
--FROM #surveys_ip
--ORDER BY FY
--       , Service_Line
--	   , UNIT
--       , dep_Clrt_DEPt_Nme

--SELECT
--	raw_UNIT
--  , dep_DEPARTMENT_ID
--  , dep_Clrt_DEPt_Nme
--  , COUNT(*) AS dep_Count
--FROM #surveys_ip
--GROUP BY raw_UNIT
--       , dep_DEPARTMENT_ID
--       , dep_Clrt_DEPt_Nme
--ORDER BY raw_UNIT
--       , dep_DEPARTMENT_ID
--       , dep_Clrt_DEPt_Nme

--SELECT DISTINCT
--	resp.FY
--  , resp.dep_DEPARTMENT_ID
--  , resp.dep_Clrt_DEPt_Nme
--  , goals.Epic_Department_Id
--FROM #surveys_ip resp
--LEFT OUTER JOIN
--(
--SELECT DISTINCT
--	GOAL_YR
--  , CAST(SUBSTRING(UNIT, CHARINDEX('[',UNIT)+1,8) AS NUMERIC(18,0)) AS Epic_Department_Id
--FROM @HCAHPS_Goals
--WHERE UNIT <> 'All Units'
--) goals
--ON goals.GOAL_YR = resp.FY
--AND goals.Epic_Department_Id = resp.dep_DEPARTMENT_ID
--WHERE goals.Epic_Department_Id IS NULL
--ORDER BY resp.FY
--       , resp.dep_DEPARTMENT_ID

--SELECT DISTINCT
--	FY
--  , DOMAIN
--  , Domain_Goals
--  , sk_Dim_PG_Question
--  , QUESTION_TEXT_ALIAS
--FROM #surveys_ip
--ORDER BY sk_Dim_PG_Question

	SELECT DISTINCT
	       resp_UNIT,
           trnsf_UNIT,
           resp.UNIT
	FROM #surveys_ip_check resp
	WHERE resp.FY = 2018
	ORDER BY resp.UNIT

    SELECT DISTINCT
	       UNIT AS goal_UNIT
	FROM Rptg.HCAHPS_Goals_Test
	WHERE GOAL_FISCAL_YR = 2018
	ORDER BY UNIT

--SELECT *
--FROM
--(
--SELECT resp.FY,
--       resp.resp_UNIT,
--       resp.trnsf_UNIT,
--       resp.UNIT,
--       resp.trnsf_Service_Line,
--       resp.mdm_Service_Line,
--       resp.sk_Dim_Clrt_DEPt,
--       resp.dep_DEPARTMENT_ID,
--       resp.dep_Clrt_DEPt_Nme,
--       resp.Domain_Goals,
--       resp.Domain_Count,
--	   goal.GOAL
--FROM
--	(
--	SELECT FY,
--           resp_UNIT,
--           trnsf_UNIT,
--           UNIT,
--           trnsf_Service_Line,
--           mdm_Service_Line,
--           sk_Dim_Clrt_DEPt,
--           dep_DEPARTMENT_ID,
--           dep_Clrt_DEPt_Nme,
--           Domain_Goals,
--           Domain_Count
--	FROM #surveys_ip_check
--	) resp
--	LEFT OUTER JOIN
--	(
--	SELECT GOAL_YR
--	     , UNIT
--	     , DOMAIN
--		 , GOAL
--	FROM @HCAHPS_Goals
--	) goal
--	ON goal.GOAL_YR = resp.FY
--	AND goal.UNIT = resp.UNIT
--	AND goal.DOMAIN = resp.Domain_Goals
--	WHERE resp.FY = 2018
--	AND goal.UNIT IS NOT NULL
--	--ORDER BY resp.FY
--	--	   , resp.trnsf_Service_Line
--	--	   , resp.UNIT
--	--	   , resp.dep_Clrt_DEPt_Nme
--	--	   , resp.Domain_Goals
--UNION ALL
--SELECT resp.FY,
--       resp.resp_UNIT,
--       resp.trnsf_UNIT,
--       resp.UNIT,
--       resp.trnsf_Service_Line,
--       resp.mdm_Service_Line,
--       resp.sk_Dim_Clrt_DEPt,
--       resp.dep_DEPARTMENT_ID,
--       resp.dep_Clrt_DEPt_Nme,
--       resp.Domain_Goals,
--       resp.Domain_Count,
--	   goal.GOAL
--FROM
--	(
--	SELECT FY,
--           resp_UNIT,
--           trnsf_UNIT,
--           UNIT,
--           trnsf_Service_Line,
--           mdm_Service_Line,
--           sk_Dim_Clrt_DEPt,
--           dep_DEPARTMENT_ID,
--           dep_Clrt_DEPt_Nme,
--           Domain_Goals,
--           Domain_Count
--	FROM #surveys_ip_check
--	) resp
--	LEFT OUTER JOIN
--	(
--	SELECT GOAL_YR
--	     , UNIT
--	     , DOMAIN
--		 , GOAL
--	FROM @HCAHPS_Goals
--	) goal
--	ON goal.GOAL_YR = resp.FY
--	AND goal.UNIT = resp.UNIT
--	AND goal.DOMAIN = resp.Domain_Goals
--	WHERE resp.FY = 2018
--	AND goal.UNIT IS NULL
--) goals
--ORDER BY  GOAL
--	    , FY
--		, trnsf_Service_Line
--		, UNIT
--		, dep_Clrt_DEPt_Nme
--		, Domain_Goals

--SELECT [all].FY,
--       [all].resp_UNIT,
--       [all].trnsf_UNIT,
--       [all].UNIT,
--       [all].trnsf_Service_Line,
--       [all].mdm_Service_Line,
--       [all].sk_Dim_Clrt_DEPt,
--       [all].dep_DEPARTMENT_ID,
--       [all].dep_Clrt_DEPt_Nme,
--       [all].Domain_Goals,
--       [all].Domain_Count,
--       [all].GOAL
--FROM
--(
--SELECT resp.FY,
--       resp.resp_UNIT,
--       resp.trnsf_UNIT,
--       resp.UNIT,
--       resp.trnsf_Service_Line,
--       resp.mdm_Service_Line,
--       resp.sk_Dim_Clrt_DEPt,
--       resp.dep_DEPARTMENT_ID,
--       resp.dep_Clrt_DEPt_Nme,
--       resp.Domain_Goals,
--       resp.Domain_Count,
--	   goal.GOAL
--FROM
--	(
--	SELECT FY,
--           resp_UNIT,
--           trnsf_UNIT,
--           UNIT,
--           trnsf_Service_Line,
--           mdm_Service_Line,
--           sk_Dim_Clrt_DEPt,
--           dep_DEPARTMENT_ID,
--           dep_Clrt_DEPt_Nme,
--           Domain_Goals,
--           Domain_Count
--	FROM #surveys_ip_check
--	) resp
--	LEFT OUTER JOIN
--	(
--	SELECT GOAL_YR
--	     , UNIT
--	     , DOMAIN
--		 , GOAL
--	FROM @HCAHPS_Goals
--	) goal
--	ON goal.GOAL_YR = resp.FY
--	AND goal.UNIT = resp.UNIT
--	AND goal.DOMAIN = resp.Domain_Goals
--	WHERE resp.FY = 2018
--	AND goal.UNIT IS NOT NULL
--UNION ALL
--SELECT goals.FY,
--       goals.resp_UNIT,
--       goals.trnsf_UNIT,
--       goals.UNIT,
--       goals.trnsf_Service_Line,
--       goals.mdm_Service_Line,
--       goals.sk_Dim_Clrt_DEPt,
--       goals.dep_DEPARTMENT_ID,
--       goals.dep_Clrt_DEPt_Nme,
--       goals.Domain_Goals,
--       goals.Domain_Count,
--       goal.GOAL
--FROM
--(
--SELECT resp.FY,
--       resp.resp_UNIT,
--       resp.trnsf_UNIT,
--       resp.UNIT,
--       resp.trnsf_Service_Line,
--       resp.mdm_Service_Line,
--       resp.sk_Dim_Clrt_DEPt,
--       resp.dep_DEPARTMENT_ID,
--       resp.dep_Clrt_DEPt_Nme,
--       resp.Domain_Goals,
--       resp.Domain_Count,
--	   goal.GOAL
--FROM
--	(
--	SELECT FY,
--           resp_UNIT,
--           trnsf_UNIT,
--           UNIT,
--           trnsf_Service_Line,
--           mdm_Service_Line,
--           sk_Dim_Clrt_DEPt,
--           dep_DEPARTMENT_ID,
--           dep_Clrt_DEPt_Nme,
--           Domain_Goals,
--           Domain_Count
--	FROM #surveys_ip_check
--	) resp
--	LEFT OUTER JOIN
--	(
--	SELECT GOAL_YR
--	     , UNIT
--	     , DOMAIN
--		 , GOAL
--	FROM @HCAHPS_Goals
--	) goal
--	ON goal.GOAL_YR = resp.FY
--	AND goal.UNIT = resp.UNIT
--	AND goal.DOMAIN = resp.Domain_Goals
--	WHERE resp.FY = 2018
--	AND goal.UNIT IS NULL
--) goals
--LEFT OUTER JOIN
--(
--SELECT GOAL_YR
--     , SERVICE_LINE
--     , UNIT
--	 , DOMAIN
--	 , GOAL
--FROM @HCAHPS_Goals
--WHERE UNIT = 'All Units'
--) goal
--ON goal.GOAL_YR = goals.FY
--AND goal.SERVICE_LINE = goals.mdm_Service_Line
--AND goal.DOMAIN = goals.Domain_Goals
--) [all]
--ORDER BY  GOAL
--	    , FY
--		, trnsf_Service_Line
--		, UNIT
--		, dep_Clrt_DEPt_Nme
--		, Domain_Goals
/*
------------------------------------------------------------------------------------------
--- JOIN TO DIM_DATE

 SELECT
	'Inpatient HCAHPS' AS Event_Type
	,SURVEY_ID
	,sk_Fact_Pt_Acct
	,FY
	,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
	,rec.day_date AS Event_Date
	,dis.day_date AS Event_Date_Disch
	,dis.Fyear_num AS Event_Date_Disch_FY
	,sk_Dim_PG_Question
	,VARNAME
	,QUESTION_TEXT_ALIAS
	--,#surveys_ip.Domain
	,surveys_ip.Domain
	,Domain_Goals
	,RECDATE AS Recvd_Date
	,DISDATE AS Discharge_Date
	--,FY AS Discharge_FY
	,MRN_int AS Patient_ID
	,Pat_Name
	,Pat_Sex
	,Pat_DOB
	,Pat_Age
	,Pat_Age_Survey_Recvd
	,Pat_Age_Survey_Answer
	,CASE WHEN Pat_Age_Survey_Answer < 18 THEN 1 ELSE 0 END AS Peds
	,NPINumber
	,Phys_Name
	,Phys_Dept
	,Phys_Div
	,GOAL
	--,CASE WHEN #surveys_ip.UNIT = 'SHRTSTAY' THEN 'SSU' ELSE #surveys_ip.UNIT END AS UNIT -- CAN'T MAP SHRTSTAY TO GOALS AND SVC LINE WITHOUT A CHANGE TO BCSM TABLE
	--,#surveys_ip.UNIT
	--,#surveys_ip.Service_Line
	,surveys_ip.UNIT
	,surveys_ip.Service_Line
	,VALUE
	,Value_Resp_Grp
	,TOP_BOX
	,VAL_COUNT
	,rec.quarter_name
	,rec.month_short_name
INTO #surveys_ip2
--FROM DS_HSDW_Prod.dbo.Dim_Date rec
FROM
(
SELECT day_date, Fyear_num, quarter_name, month_short_name FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate
) rec
--LEFT OUTER JOIN
--	(SELECT #surveys_ip.*, goals.GOAL
--	 FROM #surveys_ip
--     INNER JOIN
--	     (SELECT DISTINCT
--		      GOAL_YR
--		     ,SERVICE_LINE
--	         ,UNIT
--	      FROM @HCAHPS_Goals) units -- Identify surveys with a valid service line and a unit that has goals documented by Patient Experience
--	 ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ip.UNIT = units.UNIT
--     LEFT OUTER JOIN
--	     (SELECT
--		      GOAL_YR
--	         ,SERVICE_LINE
--	         ,UNIT
--	         ,DOMAIN
--	         ,CASE
--	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
--	            ELSE GOAL
--	          END AS GOAL
--	      FROM @HCAHPS_Goals) goals
--    ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ip.UNIT = goals.UNIT AND #surveys_ip.Domain_Goals = goals.DOMAIN
--	 UNION ALL
--	 SELECT #surveys_ip.*, goals.GOAL
--	 FROM #surveys_ip
--     LEFT OUTER JOIN
--	     (SELECT DISTINCT
--		      GOAL_YR
--		     ,SERVICE_LINE
--	         ,UNIT
--	      FROM @HCAHPS_Goals) units -- Identify surveys with a valid service line and a unit that does not have goals documented by Patient Experience
--	 ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ip.UNIT = units.UNIT
--     LEFT OUTER JOIN
--	     (SELECT
--		      GOAL_YR
--	         ,SERVICE_LINE
--	         ,UNIT
--	         ,DOMAIN
--	         ,CASE
--	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
--	            ELSE GOAL
--	          END AS GOAL
--	      FROM @HCAHPS_Goals
--          WHERE UNIT = 'All Units') goals
--    ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ip.Domain_Goals = goals.DOMAIN
--	WHERE #surveys_ip.Service_Line <> 'Unknown' AND units.UNIT IS NULL
--	UNION ALL
--	SELECT #surveys_ip.*, goals.GOAL
--	 FROM #surveys_ip
--     INNER JOIN
--	     (SELECT DISTINCT
--		      GOAL_YR
--		     ,SERVICE_LINE
--	         ,UNIT
--	      FROM @HCAHPS_Goals) units -- Identify surveys with service line = 'Unknown' and a unit that has goals documented by Patient Experience
--	 --ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ip.UNIT = units.UNIT
--	 ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.UNIT = units.UNIT
--     LEFT OUTER JOIN
--	     (SELECT
--		      GOAL_YR
--	         ,SERVICE_LINE
--	         ,UNIT
--	         ,DOMAIN
--	         ,CASE
--	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
--	            ELSE GOAL
--	          END AS GOAL
--	      FROM @HCAHPS_Goals) goals
--    --ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ip.UNIT = goals.UNIT AND #surveys_ip.Domain_Goals = goals.DOMAIN
--    ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.UNIT = goals.UNIT AND #surveys_ip.Domain_Goals = goals.DOMAIN
--	WHERE #surveys_ip.Service_Line = 'Unknown'
--	 UNION ALL
--	 SELECT #surveys_ip.*, goals.GOAL
--	 FROM #surveys_ip
--     LEFT OUTER JOIN
--	     (SELECT DISTINCT
--		      GOAL_YR
--		     ,SERVICE_LINE
--	         ,UNIT
--	      FROM @HCAHPS_Goals) units -- Identify surveys with service line = 'Unknown' and units that do not have goals documented by Patient Experience
--	 --ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ip.UNIT = units.UNIT
--	 ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.UNIT = units.UNIT
--     LEFT OUTER JOIN
--	     (SELECT
--		      GOAL_YR
--	         ,SERVICE_LINE
--	         ,UNIT
--	         ,DOMAIN
--	         ,CASE
--	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
--	            ELSE GOAL
--	          END AS GOAL
--	      FROM @HCAHPS_Goals
--          WHERE SERVICE_LINE = 'All Service Lines' AND UNIT = 'All Units') goals
--    --ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ip.Domain_Goals = goals.DOMAIN
--    ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.Domain_Goals = goals.DOMAIN
--	WHERE #surveys_ip.Service_Line = 'Unknown' AND units.UNIT IS NULL
--	) surveys_ip
--    ON rec.day_date = surveys_ip.RECDATE
LEFT OUTER JOIN
	(SELECT #surveys_ip.*, goals.GOAL
	 FROM #surveys_ip
     INNER JOIN
	     (SELECT DISTINCT
		      GOAL_YR
		     ,SERVICE_LINE
	         ,UNIT
	      FROM @HCAHPS_Goals) units -- Identify surveys with a valid service line and a unit that has goals documented by Patient Experience
	 ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ip.UNIT = units.UNIT
     LEFT OUTER JOIN
	     (SELECT
		      GOAL_YR
	         ,SERVICE_LINE
	         ,UNIT
	         ,DOMAIN
	         ,CASE
	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	            ELSE GOAL
	          END AS GOAL
	      FROM @HCAHPS_Goals) goals
    ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ip.UNIT = goals.UNIT AND #surveys_ip.Domain_Goals = goals.DOMAIN
	 UNION ALL
	 SELECT #surveys_ip.*, goals.GOAL
	 FROM #surveys_ip
     LEFT OUTER JOIN
	     (SELECT DISTINCT
		      GOAL_YR
		     ,SERVICE_LINE
	         ,UNIT
	      FROM @HCAHPS_Goals) units -- Identify surveys with a valid service line and a unit that does not have goals documented by Patient Experience
	 ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ip.UNIT = units.UNIT
     LEFT OUTER JOIN
	     (SELECT
		      GOAL_YR
	         ,SERVICE_LINE
	         ,UNIT
	         ,DOMAIN
	         ,CASE
	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	            ELSE GOAL
	          END AS GOAL
	      FROM @HCAHPS_Goals
          WHERE UNIT = 'All Units') goals
    ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ip.Domain_Goals = goals.DOMAIN
	WHERE #surveys_ip.Service_Line <> 'Unknown' AND units.UNIT IS NULL
	UNION ALL
	SELECT #surveys_ip.*, goals.GOAL
	 FROM #surveys_ip
     INNER JOIN
	     (SELECT DISTINCT
		      GOAL_YR
		     ,SERVICE_LINE
	         ,UNIT
	      FROM @HCAHPS_Goals) units -- Identify surveys with service line = 'Unknown' and a unit that has goals documented by Patient Experience
	 --ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ip.UNIT = units.UNIT
	 ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.UNIT = units.UNIT
     LEFT OUTER JOIN
	     (SELECT
		      GOAL_YR
	         ,SERVICE_LINE
	         ,UNIT
	         ,DOMAIN
	         ,CASE
	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	            ELSE GOAL
	          END AS GOAL
	      FROM @HCAHPS_Goals) goals
    --ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ip.UNIT = goals.UNIT AND #surveys_ip.Domain_Goals = goals.DOMAIN
    ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.UNIT = goals.UNIT AND #surveys_ip.Domain_Goals = goals.DOMAIN
	WHERE #surveys_ip.Service_Line = 'Unknown'
	 UNION ALL
	 SELECT #surveys_ip.*, goals.GOAL
	 FROM #surveys_ip
     LEFT OUTER JOIN
	     (SELECT DISTINCT
		      GOAL_YR
		     ,SERVICE_LINE
	         ,UNIT
	      FROM @HCAHPS_Goals) units -- Identify surveys with service line = 'Unknown' and units that do not have goals documented by Patient Experience
	 --ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ip.UNIT = units.UNIT
	 ON #surveys_ip.FY = units.GOAL_YR AND #surveys_ip.UNIT = units.UNIT
     LEFT OUTER JOIN
	     (SELECT
		      GOAL_YR
	         ,SERVICE_LINE
	         ,UNIT
	         ,DOMAIN
	         ,CASE
	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	            ELSE GOAL
	          END AS GOAL
	      FROM @HCAHPS_Goals
          WHERE SERVICE_LINE = 'All Service Lines' AND UNIT = 'All Units') goals
    --ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ip.Domain_Goals = goals.DOMAIN
    ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.Domain_Goals = goals.DOMAIN
	WHERE #surveys_ip.Service_Line = 'Unknown' AND units.UNIT IS NULL
	) surveys_ip
    ON rec.day_date = surveys_ip.RECDATE
--LEFT OUTER JOIN #surveys_ip
--ON rec.day_date = #surveys_ip.RECDATE
--FULL OUTER JOIN DS_HSDW_Prod.dbo.Dim_Date dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
FULL OUTER JOIN -- Need to report by both the discharge date on the survey as well as the received date of the survey
(
SELECT day_date, Fyear_num FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate
) dis
ON dis.day_date = surveys_ip.DISDATE
--LEFT OUTER JOIN DS_HSDW_App.Rptg.HCAHPS_Goals goals
--LEFT OUTER JOIN @HCAHPS_Goals goals
--ON #surveys_ip.UNIT = goals.unit AND #surveys_ip.Domain_Goals = goals.DOMAIN
--ORDER BY Event_Date, SURVEY_ID, sk_Dim_PG_Question

----SELECT *
--SELECT Event_Date
--     , GOAL
--	 , DOMAIN
--	 , Domain_Goals
--	 , Service_Line
--	 , UNIT
--	 , SURVEY_ID
--     , sk_Dim_PG_Question
--	 , QUESTION_TEXT_ALIAS
--	 , Event_Date_Disch
--	 , Event_Date_Disch_FY
--FROM #surveys_ip2
----WHERE
----GOAL IS NULL
----AND SURVEY_ID IS NOT NULL
------SURVEY_ID IS NOT NULL
----AND (Domain_Goals IS NOT NULL
----AND Domain_Goals NOT IN ('Additional Questions About Your Care'))
----ORDER BY Event_Date_Disch
----       , SURVEY_ID
----	   , sk_Dim_PG_Question
----ORDER BY Event_Date
----       , SURVEY_ID
----	   , sk_Dim_PG_Question
--ORDER BY Event_Date
--       , Service_Line
--       , UNIT
--       , SURVEY_ID
--	   , sk_Dim_PG_Question
----ORDER BY GOAL ASC
----       , sk_Dim_PG_Question
----	   , Event_Date_Disch
----       , SURVEY_ID

-------------------------------------------------------------------------------------------------------------------------------------
-- SELF UNION TO ADD AN "ALL UNITS" UNIT

SELECT * INTO #surveys_ip3
FROM #surveys_ip2
UNION ALL

(

	 SELECT
		'Inpatient HCAHPS' AS Event_Type
		,SURVEY_ID
		,sk_Fact_Pt_Acct
		,FY
		,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
		,rec.day_date AS Event_Date
		,dis.day_date AS Event_Date_Disch
		,dis.Fyear_num AS Event_Date_Disch_FY
		,sk_Dim_PG_Question
		,VARNAME
		,QUESTION_TEXT_ALIAS
		,#surveys_ip.Domain
		,Domain_Goals
		,RECDATE AS Recvd_Date
		,DISDATE AS Discharge_Date
		,MRN_int AS Patient_ID
		,Pat_Name
		,Pat_Sex
		,Pat_DOB
		,Pat_Age
		,Pat_Age_Survey_Recvd
		,Pat_Age_Survey_Answer
		,CASE WHEN Pat_Age_Survey_Answer < 18 THEN 1 ELSE 0 END AS Peds
		,NPINumber
		,Phys_Name
		,Phys_Dept
		,Phys_Div
		,GOAL
		,CASE WHEN SURVEY_ID IS NULL THEN NULL
			  ELSE 'All Units' END AS UNIT
		,#surveys_ip.Service_Line
		,VALUE
		,Value_Resp_Grp
		,TOP_BOX
		,VAL_COUNT
		,rec.quarter_name
		,rec.month_short_name
	--FROM DS_HSDW_Prod.dbo.Dim_Date rec
	FROM
	(
	SELECT day_date, quarter_name, month_short_name FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate
	) rec
	LEFT OUTER JOIN #surveys_ip
	ON rec.day_date = #surveys_ip.RECDATE
	--FULL OUTER JOIN DS_HSDW_Prod.dbo.Dim_Date dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
	FULL OUTER JOIN -- Need to report by both the discharge date on the survey as well as the received date of the survey
	(
	SELECT day_date, Fyear_num FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate
	) dis
	ON dis.day_date = #surveys_ip.DISDATE
	--LEFT OUTER JOIN
	--	(SELECT * FROM DS_HSDW_App.Rptg.HCAHPS_Goals WHERE UNIT = 'All Units' AND SERVICE_LINE = 'All Service Lines') goals
	--ON #surveys_ip.Domain_Goals = goals.DOMAIN
    LEFT OUTER JOIN
	    (SELECT
		    GOAL_YR
	        ,SERVICE_LINE
	        ,UNIT
	        ,DOMAIN
	        ,CASE
	        WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	        ELSE GOAL
	        END AS GOAL
	    FROM @HCAHPS_Goals
        WHERE SERVICE_LINE = 'All Service Lines' AND UNIT = 'All Units'
		) goals
		ON #surveys_ip.FY = goals.GOAL_YR AND #surveys_ip.Domain_Goals = goals.DOMAIN
	WHERE (dis.day_date >= @startdate AND dis.day_date <= @enddate) AND (rec.day_date >= @startdate AND rec.day_date <= @enddate) -- THIS IS ALL SERVICE LINES TOGETHER, USE "ALL SERVICE LINES" GOALS TO APPLY SAME GOAL DOMAIN GOAL TO ALL SERVICE LINES
)

--SELECT *
----SELECT Event_Date
----     , GOAL
----	 , DOMAIN
----	 , Domain_Goals
----	 , Service_Line
----	 , UNIT
----	 , SURVEY_ID
----     , sk_Dim_PG_Question
----	 , QUESTION_TEXT_ALIAS
----	 , Event_Date_Disch
----	 , Event_Date_Disch_FY
--FROM #surveys_ip3
----WHERE
----GOAL IS NULL
----AND SURVEY_ID IS NOT NULL
------SURVEY_ID IS NOT NULL
----AND (Domain_Goals IS NOT NULL
----AND Domain_Goals NOT IN ('Additional Questions About Your Care'))
----ORDER BY Event_Date_Disch
----       , SURVEY_ID
----	   , sk_Dim_PG_Question
----ORDER BY Event_Date
----       , SURVEY_ID
----	   , sk_Dim_PG_Question
----ORDER BY Event_Date
----       , Service_Line
----       , UNIT
----       , SURVEY_ID
----	   , sk_Dim_PG_Question
--ORDER BY FY
--       , Service_Line
--       , Event_Date
--       , UNIT
--       , SURVEY_ID
--	   , sk_Dim_PG_Question
----ORDER BY GOAL ASC
----       , sk_Dim_PG_Question
----	   , Event_Date_Disch
----       , SURVEY_ID

--SELECT DISTINCT
--	FY
--  , Service_Line
--  , UNIT
--FROM #surveys_ip3
--ORDER BY FY
--       , Service_Line
--	   , UNIT

----------------------------------------------------------------------------------------------------------------------
-- RESULTS
 SELECT [Event_Type]
   ,[SURVEY_ID]
   ,[sk_Fact_Pt_Acct]
   ,[Rpt_Prd]
   ,[Event_Date]
   ,[Event_Date_Disch]
   ,[sk_Dim_PG_Question]
   ,[VARNAME]
   ,[QUESTION_TEXT_ALIAS]
   ,[DOMAIN]
   ,[Domain_Goals]
   ,[Recvd_Date]
   ,[Discharge_Date]
   ,[Patient_ID]
   ,[Pat_Name]
   ,[Pat_Sex]
   ,[Pat_DOB]
   ,[Pat_Age]
   ,[Pat_Age_Survey_Recvd]
   ,[Pat_Age_Survey_Answer]
   ,[Peds]
   ,[NPINumber]
   ,[Phys_Name]
   ,[Phys_Dept]
   ,[Phys_Div]
   ,[GOAL]
   ,[UNIT]
   ,[Service_Line]
   ,[VALUE]
   ,[Value_Resp_Grp]
   ,[TOP_BOX]
   ,[VAL_COUNT]
   ,[quarter_name]
   ,[month_short_name]
  INTO #HCAHPS_Units
  FROM [#surveys_ip3];
*/
GO


