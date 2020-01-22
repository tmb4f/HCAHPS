USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

--ALTER PROC [Rptg].[uspSrc_Dash_PatExp_HCAHPS_Units_Test]
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

IF OBJECT_ID('tempdb..#surveys_ip_sum ') IS NOT NULL
DROP TABLE #surveys_ip_sum

IF OBJECT_ID('tempdb..#surveys_ip_sum2 ') IS NOT NULL
DROP TABLE #surveys_ip_sum2

IF OBJECT_ID('tempdb..#surveys_ip_sum3 ') IS NOT NULL
DROP TABLE #surveys_ip_sum3

IF OBJECT_ID('tempdb..#surveys_ip_goals ') IS NOT NULL
DROP TABLE #surveys_ip_goals

IF OBJECT_ID('tempdb..#surveys_ip2_sum ') IS NOT NULL
DROP TABLE #surveys_ip2_sum

IF OBJECT_ID('tempdb..#surveys_ip2 ') IS NOT NULL
DROP TABLE #surveys_ip2

IF OBJECT_ID('tempdb..#surveys_ip3 ') IS NOT NULL
DROP TABLE #surveys_ip3

IF OBJECT_ID('tempdb..#HCAHPS_Units ') IS NOT NULL
DROP TABLE #HCAHPS_Units

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
	,CAST(COALESCE(RespUnit.UNIT,'Unknown') AS VARCHAR(150)) AS Survey_Unit
	,CASE WHEN RespUnit.UNIT = 'obs' THEN 'Womens and Childrens'
		  WHEN bcsm.Service_Line IS NULL THEN 'Other'
		  ELSE bcsm.Service_Line
		  END AS Survey_Service_Line -- obs appears as both 8nor and 8cob
	,CASE WHEN RespUnit.UNIT = 'obs' THEN 'Womens and Childrens'
		  WHEN bcsm.Service_Line IS NULL THEN 'Other'
		  ELSE bcsm.Service_Line
		  END AS Service_Line -- obs appears as both 8nor and 8cob
	,CASE WHEN RespUnit.UNIT IS NULL THEN 'Other' ELSE RespUnit.UNIT END AS UNIT
    ,CAST(COALESCE(unittrns.Goals_Unit,'Unknown') AS VARCHAR(150)) AS Goals_UNIT
	,CAST(COALESCE(dep.DEPARTMENT_ID,'Unknown') AS VARCHAR(255)) AS Survey_Department_Id
	,dep.Clrt_DEPt_Nme AS Survey_Department_Name
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
	,ddte.month_num
	,ddte.month_short_name
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
	ORDER BY REC_FY, UNIT, Goals_UNIT, Service_Line, Goals_Service_Line, DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID

  -- Create indexes for temp table #surveys_ip
  CREATE NONCLUSTERED INDEX IX_surveysip ON #surveys_ip (REC_FY, UNIT, Goals_UNIT, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID)
  CREATE NONCLUSTERED INDEX IX_surveysip2 ON #surveys_ip (REC_FY, Service_Line, Goals_Service_Line, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID)
  CREATE NONCLUSTERED INDEX IX_surveysip3 ON #surveys_ip (REC_FY, DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID)

--SELECT *
--FROM #surveys_ip
----WHERE DOMAIN = 'Overall Assessment'
--WHERE DOMAIN = 'Care Transitions'
----AND Survey_Department_Name = 'UVHE 3 EAST'
--AND Survey_Department_Name = 'UVHE 3 CENTRAL'
--AND REC_FY = 2020
--ORDER BY REC_FY
--       , month_num
--	   , month_short_name
--	   , VARNAME

--SELECT  REC_FY
--      , month_num
--	  , month_short_name
--	  , Survey_Department_Name
--	  , DOMAIN
--	  , VARNAME
--	  , QUESTION_TEXT_ALIAS
--	  ,SUM(TOP_BOX) AS TOP_BOX
--	  ,SUM(VAL_COUNT) AS VAL_COUNT
--	  ,COUNT(*) AS N
--FROM #surveys_ip
----WHERE DOMAIN = 'Overall Assessment'
--WHERE DOMAIN = 'Care Transitions'
----AND Survey_Department_Name = 'UVHE 3 EAST'
--AND Survey_Department_Name = 'UVHE 3 CENTRAL'
--AND REC_FY = 2020
--GROUP BY REC_FY
--       , month_num
--	   , month_short_name
--	   , Survey_Department_Name
--	   , DOMAIN
--	   , VARNAME
--	   , QUESTION_TEXT_ALIAS
--ORDER BY REC_FY
--       , month_num
--	   , month_short_name
--	   , Survey_Department_Name
--	   , DOMAIN
--	   , VARNAME
--	   , QUESTION_TEXT_ALIAS

------------------------------------------------------------------------------------------
--- GENERATE SUMMARY FOR TESTING

--SELECT DISTINCT
--	REC_FY,
--	month_num,
--	month_short_name,
--    Survey_Unit,
--    Survey_Service_Line,
--    Service_Line,
--    UNIT,
--    Goals_UNIT,
--    Survey_Department_Id,
--    Survey_Department_Name,
--    DEPARTMENT_ID,
--    Clrt_DEPt_Nme,
--    Goals_Service_Line,
--    VALUE,
--	TOP_BOX,
--    VAL_COUNT,
--    DOMAIN,
--    Domain_Goals
----INTO #surveys_ip_sum
--FROM #surveys_ip resp
--WHERE REC_FY = 2020
--AND sk_Dim_PG_Question = 17 -- Rate Hospital 0-10
--AND (Domain_Goals IS NOT NULL
--AND Domain_Goals <> 'Additional Questions About Your Care')
--ORDER BY resp.REC_FY
--       , resp.month_num
--	   , resp.month_short_name
--	   , resp.Survey_Unit
--	   , resp.Survey_Service_Line
--	   , resp.Survey_Department_Id
--	   , resp.Survey_Department_Name
--	   , resp.Domain_Goals
--	   , resp.Goals_UNIT
--	   , resp.Goals_Service_Line
--	   , resp.DEPARTMENT_ID
--	   , resp.Clrt_DEPt_Nme

SELECT resp.REC_FY,
       resp.month_num,
       resp.month_short_name,
       resp.Survey_Unit,
       resp.Survey_Service_Line,
       resp.Survey_Department_Id,
       resp.Survey_Department_Name,
       resp.Domain_Goals,
       resp.Goals_UNIT,
       resp.Goals_Service_Line,
       resp.DEPARTMENT_ID,
       resp.Clrt_DEPt_Nme,
       SUM(resp.TOP_BOX) AS TOP_BOX,
       SUM(resp.VAL_COUNT) AS VAL_COUNT,
	   CAST(CAST(SUM(resp.TOP_BOX) AS NUMERIC(6,3)) / CAST(SUM(resp.VAL_COUNT) AS NUMERIC(6,3)) AS NUMERIC(4,3)) AS SCORE,
	   COUNT(*) AS N
INTO #surveys_ip_sum
FROM
(
--SELECT DISTINCT
SELECT
	REC_FY,
	month_num,
	month_short_name,
    Survey_Unit,
    Survey_Service_Line,
    Service_Line,
    UNIT,
    Goals_UNIT,
    Survey_Department_Id,
    Survey_Department_Name,
    DEPARTMENT_ID,
    Clrt_DEPt_Nme,
    Goals_Service_Line,
    VALUE,
	TOP_BOX,
    VAL_COUNT,
    DOMAIN,
    Domain_Goals
--INTO #surveys_ip_sum
FROM #surveys_ip
--WHERE REC_FY = 2020
WHERE REC_FY IN (2019,2020)
--AND sk_Dim_PG_Question = 17 -- Rate Hospital 0-10
AND (Domain_Goals IS NOT NULL
AND Domain_Goals <> 'Additional Questions About Your Care')
) resp
GROUP BY resp.REC_FY
       , resp.month_num
	   , resp.month_short_name
	   , resp.Survey_Unit
	   , resp.Survey_Service_Line
	   , resp.Survey_Department_Id
	   , resp.Survey_Department_Name
	   , resp.Domain_Goals
	   , resp.Goals_UNIT
	   , resp.Goals_Service_Line
	   , resp.DEPARTMENT_ID
	   , resp.Clrt_DEPt_Nme

--SELECT REC_FY,
--       Survey_Unit,
--       Survey_Service_Line,
--       Survey_Department_Id,
--       Survey_Department_Name,
--       Domain_Goals,
--       Goals_UNIT,
--       Goals_Service_Line,
--       DEPARTMENT_ID,
--       Clrt_DEPt_Nme,
--       month_num,
--       month_short_name,
--       TOP_BOX,
--       VAL_COUNT,
--       SCORE,
--       N
--FROM #surveys_ip_sum
----WHERE Survey_Service_Line = 'Heart and Vascular'
----WHERE Goals_Service_Line = 'Heart and Vascular'
----ORDER BY REC_FY
----       , month_num
----	   , month_short_name
----	   , Survey_Unit
----	   , Survey_Service_Line
----	   , Survey_Department_Id
----	   , Survey_Department_Name
----	   , Domain_Goals
----	   , Goals_UNIT
----	   , Goals_Service_Line
----	   , DEPARTMENT_ID
----	   , Clrt_DEPt_Nme
----ORDER BY Survey_Service_Line
----	   , Domain_Goals
----       , REC_FY
----       , month_num
----	   , month_short_name
----	   , Survey_Unit
----	   , Survey_Department_Id
----	   , Survey_Department_Name
----	   , Goals_UNIT
----	   , Goals_Service_Line
----	   , DEPARTMENT_ID
----	   , Clrt_DEPt_Nme
----ORDER BY REC_FY
----       , month_num
----	   , month_short_name
----	   , Survey_Unit
----	   , Survey_Service_Line
----	   , Survey_Department_Id
----	   , Survey_Department_Name
----	   , Domain_Goals
----	   , Goals_UNIT
----	   , Goals_Service_Line
----	   , DEPARTMENT_ID
----	   , Clrt_DEPt_Nme
--ORDER BY REC_FY
--	   , Survey_Unit
--	   , Survey_Service_Line
--	   , Survey_Department_Id
--	   , Survey_Department_Name
--	   , Domain_Goals
--	   , Goals_UNIT
--	   , Goals_Service_Line
--	   , DEPARTMENT_ID
--	   , Clrt_DEPt_Nme
--       , month_num
--	   , month_short_name

SELECT resp.REC_FY,
       resp.month_num,
       resp.month_short_name,
       resp.Survey_Unit,
       resp.Survey_Service_Line,
       resp.Survey_Department_Id,
       resp.Survey_Department_Name,
       resp.Domain_Goals,
       resp.Goals_UNIT,
       resp.Goals_Service_Line,
       resp.DEPARTMENT_ID,
       resp.Clrt_DEPt_Nme,
       --SUM(resp.TOP_BOX) AS TOP_BOX,
       --SUM(resp.VAL_COUNT) AS VAL_COUNT,
	   --CAST(CAST(SUM(resp.TOP_BOX) AS NUMERIC(6,3)) / CAST(SUM(resp.VAL_COUNT) AS NUMERIC(6,3)) AS NUMERIC(4,3)) AS SCORE,
	   AVG(resp.SCORE) AS SCORE,
	   MAX(resp.Survey_Id_Count) AS N
INTO #surveys_ip_sum2
FROM
(
SELECT
	REC_FY,
	month_num,
	month_short_name,
    Survey_Unit,
    Survey_Service_Line,
    Service_Line,
    UNIT,
    Goals_UNIT,
    Survey_Department_Id,
    Survey_Department_Name,
    DEPARTMENT_ID,
    Clrt_DEPt_Nme,
    Goals_Service_Line,
    --VALUE,
	SUM(TOP_BOX) AS TOP_BOX,
    SUM(VAL_COUNT) AS VAL_COUNT,
	CAST(CAST(SUM(TOP_BOX) AS NUMERIC(6,3)) / CAST(SUM(VAL_COUNT) AS NUMERIC(6,3)) AS NUMERIC(4,3)) AS SCORE,
	COUNT(*) AS N,
    DOMAIN,
    Domain_Goals,
	sk_Dim_PG_Question,
	COUNT(DISTINCT SURVEY_ID) AS Survey_Id_Count
--INTO #surveys_ip_sum2
FROM #surveys_ip
--WHERE REC_FY = 2020
WHERE REC_FY IN (2019,2020)
--AND sk_Dim_PG_Question = 17 -- Rate Hospital 0-10
AND (Domain_Goals IS NOT NULL
AND Domain_Goals <> 'Additional Questions About Your Care')
GROUP BY REC_FY
       , month_num
	   , month_short_name
	   , Survey_Unit
	   , Survey_Service_Line
       , Service_Line
	   , UNIT
	   , Survey_Department_Id
	   , Survey_Department_Name
       , DOMAIN
	   , Domain_Goals
	   , sk_Dim_PG_Question
	   , Goals_UNIT
	   , Goals_Service_Line
	   , DEPARTMENT_ID
       , Clrt_DEPt_Nme
) resp
GROUP BY resp.REC_FY
       , resp.month_num
	   , resp.month_short_name
	   , resp.Survey_Unit
	   , resp.Survey_Service_Line
	   , resp.Survey_Department_Id
	   , resp.Survey_Department_Name
	   , resp.Domain_Goals
	   , resp.Goals_UNIT
	   , resp.Goals_Service_Line
	   , resp.DEPARTMENT_ID
	   , resp.Clrt_DEPt_Nme

SELECT resp.REC_FY,
       resp.month_num,
       resp.month_short_name,
       resp.Survey_Unit,
       resp.Survey_Service_Line,
       resp.Survey_Department_Id,
       resp.Survey_Department_Name,
       resp.Domain_Goals,
       resp.Goals_UNIT,
       resp.Goals_Service_Line,
       resp.DEPARTMENT_ID,
       resp.Clrt_DEPt_Nme,
	   resp.TOP_BOX,
	   resp.VAL_COUNT,
	   resp.SCORE,
	   resp.N,
	   resp.PG_SCORE,
	   resp.PG_N
INTO #surveys_ip_sum3
FROM
(
SELECT aggr.REC_FY,
       aggr.month_num,
       aggr.month_short_name,
       aggr.Survey_Unit,
       aggr.Survey_Service_Line,
       aggr.Survey_Department_Id,
       aggr.Survey_Department_Name,
       aggr.Domain_Goals,
       aggr.Goals_UNIT,
       aggr.Goals_Service_Line,
       aggr.DEPARTMENT_ID,
       aggr.Clrt_DEPt_Nme,
       aggr.TOP_BOX,
       aggr.VAL_COUNT,
       aggr.SCORE,
       aggr.N,
	   aggr2.SCORE AS PG_SCORE,
	   aggr2.N AS PG_N
FROM #surveys_ip_sum aggr
LEFT OUTER JOIN #surveys_ip_sum2 aggr2
ON aggr2.REC_FY = aggr.REC_FY
AND aggr2.month_num = aggr.month_num
AND aggr2.month_short_name = aggr.month_short_name
AND aggr2.Survey_Unit = aggr.Survey_Unit
AND aggr2.Survey_Service_Line = aggr2.Survey_Service_Line
AND aggr2.Survey_Department_Id = aggr.Survey_Department_Id
AND aggr2.Survey_Department_Name = aggr.Survey_Department_Name
AND aggr2.Domain_Goals = aggr.Domain_Goals
AND aggr2.Goals_UNIT = aggr.Goals_UNIT
AND aggr2.Goals_Service_Line = aggr.Goals_Service_Line
AND aggr2.DEPARTMENT_ID = aggr.DEPARTMENT_ID
AND aggr2.Clrt_DEPt_Nme = aggr.Clrt_DEPt_Nme
) resp

SELECT REC_FY,
       month_num,
       month_short_name,
       Survey_Unit,
       Survey_Service_Line,
       Survey_Department_Id,
       Survey_Department_Name,
       Domain_Goals,
       Goals_UNIT,
       Goals_Service_Line,
       DEPARTMENT_ID,
       Clrt_DEPt_Nme,
       TOP_BOX,
       VAL_COUNT,
       SCORE,
       N,
       PG_SCORE,
       PG_N
FROM #surveys_ip_sum3
--ORDER BY REC_FY
--       , month_num
--	   , month_short_name
--	   , Survey_Unit
--	   , Survey_Service_Line
--	   , Survey_Department_Id
--	   , Survey_Department_Name
--	   , Domain_Goals
--	   , Goals_UNIT
--	   , Goals_Service_Line
--	   , DEPARTMENT_ID
--	   , Clrt_DEPt_Nme
ORDER BY REC_FY
	   , Survey_Department_Id
	   , Survey_Department_Name
	   , Domain_Goals
       , month_num
	   , month_short_name
	   , Survey_Unit
	   , Survey_Service_Line
	   , Goals_UNIT
	   , Goals_Service_Line
	   , DEPARTMENT_ID
	   , Clrt_DEPt_Nme

/*
------------------------------------------------------------------------------------------
--- GENERATE GOALS

SELECT
       all_goals.REC_FY,
       all_goals.UNIT,
       all_goals.Goals_UNIT,
	   all_goals.Service_Line,
	   all_goals.Goals_Service_Line,
       all_goals.DEPARTMENT_ID,
       all_goals.Domain_Goals,
       all_goals.GOAL
INTO #surveys_ip_goals
FROM
(
SELECT -- Received FYs 2018, 2019 
       resp.REC_FY,
       resp.UNIT,
	   resp.Goals_UNIT,
       resp.Service_Line,
	   resp.Goals_Service_Line,
       resp.DEPARTMENT_ID,
       resp.Domain_Goals,
	   goal.GOAL
FROM -- Goals_UNIT values with matching UNIT values in goals table
	(
	SELECT DISTINCT
	       REC_FY,
           Survey_Unit AS UNIT,
		   Goals_UNIT,
           Survey_Service_Line AS Service_Line,
		   Goals_Service_Line,
           DEPARTMENT_ID,
           Domain_Goals
	FROM #surveys_ip_sum
	WHERE REC_FY IN (2018,2019)
	) resp
	LEFT OUTER JOIN
	(
	SELECT goals.GOAL_FISCAL_YR
	     , goals.UNIT
	     , goals.DOMAIN
		 , goals.GOAL
	FROM Rptg.HCAHPS_Goals_Test goals
	) goal
	ON goal.GOAL_FISCAL_YR = resp.REC_FY -- 2018, 2019
	AND goal.UNIT = resp.Goals_UNIT -- 2018, 2019
	AND goal.DOMAIN = resp.Domain_Goals -- 2018, 2019
	WHERE goal.UNIT IS NOT NULL
UNION ALL -- Goals_UNIT values without matching UNIT values in goals table: use 'All Units' goals for respective service line
SELECT
       goals.REC_FY,
       goals.UNIT,
	   goals.Goals_UNIT,
       goals.Service_Line,
	   goals.Goals_Service_Line,
       goals.DEPARTMENT_ID,
       goals.Domain_Goals,
       goal.GOAL
FROM
(
SELECT
	   resp.REC_FY,
       resp.UNIT,
	   resp.Goals_UNIT,
       resp.Service_Line,
	   resp.Goals_Service_Line,
       resp.DEPARTMENT_ID,
       resp.Domain_Goals,
	   goal.GOAL
FROM
	(
	SELECT DISTINCT
	       REC_FY,
           Survey_Unit AS UNIT,
	       Goals_UNIT,
           Survey_Service_Line AS Service_Line,
		   Goals_Service_Line,
           DEPARTMENT_ID,
           Domain_Goals
	FROM #surveys_ip_sum
	WHERE REC_FY IN (2018,2019)
	) resp
	LEFT OUTER JOIN
	(
	SELECT GOAL_FISCAL_YR
	     , UNIT
	     , DOMAIN
		 , GOAL
	FROM Rptg.HCAHPS_Goals_Test
	) goal
	ON goal.GOAL_FISCAL_YR = resp.REC_FY
	AND goal.UNIT = resp.Goals_UNIT
	AND goal.DOMAIN = resp.Domain_Goals
	WHERE goal.UNIT IS NULL
) goals
LEFT OUTER JOIN
(
SELECT GOAL_FISCAL_YR
     , SERVICE_LINE
     , UNIT
	 , DOMAIN
	 , GOAL
FROM Rptg.HCAHPS_Goals_Test
WHERE UNIT = 'All Units'
) goal
ON goal.GOAL_FISCAL_YR = goals.REC_FY
AND goal.SERVICE_LINE = goals.Goals_Service_Line
AND goal.DOMAIN = goals.Domain_Goals
--UNION ALL -- UNIT = 'All Units' goals by service line
--  SELECT -- Received FYs 2018, 2019 
--       resp.REC_FY,
--       'All Units' AS UNIT,
--	   NULL AS Goals_UNIT,
--       NULL AS Service_Line,
--	   resp.Goals_Service_Line,
--       NULL AS DEPARTMENT_ID,
--       resp.Domain_Goals,
--	   goal.GOAL
--FROM
--	(
--	SELECT DISTINCT
--	       REC_FY,
--		   Goals_Service_Line,
--           Domain_Goals
--	FROM #surveys_ip_sum
--	WHERE REC_FY IN (2018,2019)
--	) resp
--	LEFT OUTER JOIN
--	(
--	SELECT goals.GOAL_FISCAL_YR
--	     , goals.UNIT
--		 , goals.SERVICE_LINE
--	     , goals.DOMAIN
--		 , goals.GOAL
--	FROM Rptg.HCAHPS_Goals_Test goals
--	WHERE goals.UNIT = 'All Units'
--	) goal
--	ON goal.GOAL_FISCAL_YR = resp.REC_FY -- 2018, 2019
--	AND goal.SERVICE_LINE = resp.Goals_Service_Line -- 2018, 2019
--	AND goal.DOMAIN = resp.Domain_Goals -- 2018, 2019
--UNION ALL -- UNIT = 'All Units' goals for Service_Line = 'All Service Lines'
--  SELECT -- Received FYs 2018, 2019 
--       goal.GOAL_FISCAL_YR AS REC_FY,
--       'All Units' AS UNIT,
--	   NULL AS Goals_UNIT,
--       NULL AS Service_Line,
--	   'All Service Lines' AS Goals_Service_Line,
--       NULL AS DEPARTMENT_ID,
--       goal.DOMAIN AS Domain_Goals,
--	   goal.GOAL
--FROM
--	(
--	SELECT goals.GOAL_FISCAL_YR
--	     , goals.UNIT
--		 , goals.SERVICE_LINE
--	     , goals.DOMAIN
--		 , goals.GOAL
--	FROM Rptg.HCAHPS_Goals_Test goals
--	WHERE goals.GOAL_FISCAL_YR IN (2018,2019)
--	AND goals.UNIT = 'All Units' AND goals.SERVICE_LINE = 'All Service Lines'
--	) goal
UNION ALL
SELECT-- Received FYs 2020
       resp.REC_FY,
       resp.UNIT,
	   resp.Goals_UNIT,
       resp.Service_Line,
	   resp.Goals_Service_Line,
       resp.DEPARTMENT_ID,
       resp.Domain_Goals,
	   goal.GOAL
FROM -- DEPARTMENT_ID values with matching EPIC_DEPARTMENT_ID values in goals table
	(
	SELECT DISTINCT
	       REC_FY,
           Survey_Unit AS UNIT,
		   Goals_UNIT,
           Survey_Service_Line AS Service_Line,
		   Goals_Service_Line,
           DEPARTMENT_ID,
           Domain_Goals
	FROM #surveys_ip_sum
	WHERE REC_FY = 2020
	) resp
	LEFT OUTER JOIN
	(
	SELECT goals.GOAL_FISCAL_YR
	     , goals.UNIT
		 , goals.EPIC_DEPARTMENT_ID
		 , goals.EPIC_DEPARTMENT_NAME
	     , goals.DOMAIN
		 , goals.GOAL
	FROM Rptg.HCAHPS_Goals_Test goals
	WHERE goals.EPIC_DEPARTMENT_ID <> 'All Units'
	) goal
	ON goal.GOAL_FISCAL_YR = resp.REC_FY -- 2020
	AND goal.EPIC_DEPARTMENT_ID = resp.DEPARTMENT_ID -- 2020
	AND goal.DOMAIN = resp.Domain_Goals -- 2020
	WHERE goal.EPIC_DEPARTMENT_ID IS NOT NULL
UNION ALL -- DEPARTMENT_ID values without matching EPIC_DEPARTMENT_ID values in goals table: use 'All Units' goals for respective service line
SELECT
       goals.REC_FY,
       goals.UNIT,
	   goals.Goals_UNIT,
       goals.Service_Line,
	   goals.Goals_Service_Line,
       goals.DEPARTMENT_ID,
       goals.Domain_Goals,
       goal.GOAL
FROM
(
SELECT
	   resp.REC_FY,
       resp.UNIT,
	   resp.Goals_UNIT,
       resp.Service_Line,
	   resp.Goals_Service_Line,
       resp.DEPARTMENT_ID,
       resp.Domain_Goals,
	   goal.GOAL
FROM
	(
	SELECT DISTINCT
	       REC_FY,
           Survey_Unit AS UNIT,
	       Goals_UNIT,
           Survey_Service_Line AS Service_Line,
		   Goals_Service_Line,
           DEPARTMENT_ID,
           Domain_Goals
	FROM #surveys_ip_sum
	WHERE REC_FY = 2020
	) resp
	LEFT OUTER JOIN
	(
	SELECT GOAL_FISCAL_YR
	     , UNIT
		 , EPIC_DEPARTMENT_ID
		 , EPIC_DEPARTMENT_NAME
	     , DOMAIN
		 , GOAL
	FROM Rptg.HCAHPS_Goals_Test
	WHERE EPIC_DEPARTMENT_ID <> 'All Units'
	) goal
	ON goal.GOAL_FISCAL_YR = resp.REC_FY
	AND goal.EPIC_DEPARTMENT_ID = resp.DEPARTMENT_ID
	AND goal.DOMAIN = resp.Domain_Goals
	WHERE goal.EPIC_DEPARTMENT_ID IS NULL
) goals
LEFT OUTER JOIN
(
SELECT GOAL_FISCAL_YR
     , SERVICE_LINE
     , UNIT
	 , EPIC_DEPARTMENT_ID
	 , EPIC_DEPARTMENT_NAME
	 , DOMAIN
	 , GOAL
FROM Rptg.HCAHPS_Goals_Test
WHERE EPIC_DEPARTMENT_ID = 'All Units'
) goal
ON goal.GOAL_FISCAL_YR = goals.REC_FY
AND goal.SERVICE_LINE = goals.Goals_Service_Line
AND goal.DOMAIN = goals.Domain_Goals
--UNION ALL -- EPIC_DEPARTMENT_ID = 'All Units' goals by service line
--  SELECT -- Received FYs 2020 
--       resp.REC_FY,
--       NULL AS UNIT,
--	   NULL AS Goals_UNIT,
--       NULL AS Service_Line,
--	   resp.Goals_Service_Line,
--       'All Units' AS DEPARTMENT_ID,
--       resp.Domain_Goals,
--	   goal.GOAL
--FROM
--	(
--	SELECT DISTINCT
--	       REC_FY,
--		   Goals_Service_Line,
--           Domain_Goals
--	FROM #surveys_ip_sum
--	WHERE REC_FY = 2020
--	) resp
--	LEFT OUTER JOIN
--	(
--	SELECT goals.GOAL_FISCAL_YR
--	     , goals.UNIT
--		 , goals.EPIC_DEPARTMENT_ID
--		 , goals.EPIC_DEPARTMENT_NAME
--		 , goals.SERVICE_LINE
--	     , goals.DOMAIN
--		 , goals.GOAL
--	FROM Rptg.HCAHPS_Goals_Test goals
--	WHERE goals.EPIC_DEPARTMENT_ID = 'All Units'
--	) goal
--	ON goal.GOAL_FISCAL_YR = resp.REC_FY -- 2020
--	AND goal.SERVICE_LINE = resp.Goals_Service_Line -- 2020
--	AND goal.DOMAIN = resp.Domain_Goals -- 2020
--UNION ALL -- EPIC_DEPARTMENT_ID = 'All Units' goals for Service_Line = 'All Service Lines'
--  SELECT -- Received FYs 2020 
--       goal.GOAL_FISCAL_YR AS REC_FY,
--       NULL AS UNIT,
--	   NULL AS Goals_UNIT,
--       NULL AS Service_Line,
--	   'All Service Lines' AS Goals_Service_Line,
--       'All Units' AS DEPARTMENT_ID,
--       goal.DOMAIN AS Domain_Goals,
--	   goal.GOAL
--FROM
--	(
--	SELECT goals.GOAL_FISCAL_YR
--	     , goals.UNIT
--		 , goals.EPIC_DEPARTMENT_ID
--		 , goals.EPIC_DEPARTMENT_NAME
--		 , goals.SERVICE_LINE
--	     , goals.DOMAIN
--		 , goals.GOAL
--	FROM Rptg.HCAHPS_Goals_Test goals
--	WHERE goals.GOAL_FISCAL_YR = 2020
--	AND goals.EPIC_DEPARTMENT_ID = 'All Units' AND goals.SERVICE_LINE = 'All Service Lines'
--	) goal
) all_goals
ORDER BY REC_FY, UNIT, Goals_UNIT, DEPARTMENT_ID, Service_Line, Goals_Service_Line, Domain_Goals

  -- Create indexes for temp table #surveys_ip_goals
  CREATE NONCLUSTERED INDEX IX_surveysipgoals ON #surveys_ip_goals (REC_FY, UNIT, Goals_UNIT, Service_Line, Goals_Service_Line, Domain_Goals)
  CREATE NONCLUSTERED INDEX IX_ssurveysipgoals2 ON #surveys_ip_goals (REC_FY, DEPARTMENT_ID, Service_Line, Goals_Service_Line, Domain_Goals)

--SELECT REC_FY,
--       UNIT,
--       Goals_UNIT,
--       Service_Line,
--       Goals_Service_Line,
--       DEPARTMENT_ID,
--       Domain_Goals,
--       GOAL
--FROM #surveys_ip_goals
--ORDER BY REC_FY
--       , UNIT

------------------------------------------------------------------------------------------
--- JOIN TO DIM_DATE

 SELECT
	'Inpatient HCAHPS' AS Event_Type
	,rec.Fyear_num AS Event_FY
	,surveys_ip_sum.Survey_Unit
	,surveys_ip_sum.Survey_Service_Line
	,surveys_ip_sum.Survey_Department_Id
	,surveys_ip_sum.Survey_Department_Name
	,surveys_ip_sum.Domain_Goals
	,surveys_ip_sum.Goals_UNIT
	,surveys_ip_sum.Goals_Service_Line
	--,surveys_ip_sum.DEPARTMENT_ID
	--,surveys_ip_sum.Clrt_DEPt_Nme
	,surveys_ip_sum.Goals_Department_Id
	,surveys_ip_sum.Goals_Department_Name
	,surveys_ip_sum.month_num
	,surveys_ip_sum.month_short_name
	,surveys_ip_sum.TOP_BOX
	,surveys_ip_sum.VAL_COUNT
	,surveys_ip_sum.SCORE
	,surveys_ip_sum.N
	,surveys_ip_sum.GOAL
INTO #surveys_ip2_sum
FROM
(
SELECT surveys_ip_sum.REC_FY,
       surveys_ip_sum.Survey_Unit,
       surveys_ip_sum.Survey_Service_Line,
       surveys_ip_sum.Survey_Department_Id,
       surveys_ip_sum.Survey_Department_Name,
       surveys_ip_sum.Domain_Goals,
       surveys_ip_sum.Goals_UNIT,
       surveys_ip_sum.Goals_Service_Line,
       --surveys_ip_sum.DEPARTMENT_ID,
       --surveys_ip_sum.Clrt_DEPt_Nme,
	   'Unknown' AS Goals_Department_Id,
	   'Unknown' AS Goals_Department_Name,
       surveys_ip_sum.month_num,
       surveys_ip_sum.month_short_name,
       surveys_ip_sum.TOP_BOX,
       surveys_ip_sum.VAL_COUNT,
       surveys_ip_sum.SCORE,
       surveys_ip_sum.N,
	   surveys_ip_goals.GOAL
FROM #surveys_ip_sum surveys_ip_sum
LEFT OUTER JOIN
(
SELECT DISTINCT
	REC_FY
  , UNIT
  , Goals_Unit
  , Service_Line
  , Goals_Service_Line
  , Domain_Goals
  , GOAL
FROM #surveys_ip_goals
WHERE UNIT <> 'All Units'
) surveys_ip_goals
ON surveys_ip_goals.REC_FY = surveys_ip_sum.REC_FY
AND surveys_ip_goals.UNIT = surveys_ip_sum.Survey_Unit
AND surveys_ip_goals.Goals_UNIT = surveys_ip_sum.Goals_UNIT
AND surveys_ip_goals.Service_Line = surveys_ip_sum.Survey_Service_Line
AND surveys_ip_goals.Goals_Service_Line = surveys_ip_sum.Goals_Service_Line
AND surveys_ip_goals.Domain_Goals = surveys_ip_sum.Domain_Goals
WHERE surveys_ip_sum.REC_FY IN (2018,2019)
UNION ALL
SELECT surveys_ip_sum.REC_FY,
       surveys_ip_sum.Survey_Unit,
       surveys_ip_sum.Survey_Service_Line,
       surveys_ip_sum.Survey_Department_Id,
       surveys_ip_sum.Survey_Department_Name,
       surveys_ip_sum.Domain_Goals,
       surveys_ip_sum.Goals_UNIT,
       surveys_ip_sum.Goals_Service_Line,
       --surveys_ip_sum.DEPARTMENT_ID,
       --surveys_ip_sum.Clrt_DEPt_Nme,
	   surveys_ip_goals.DEPARTMENT_ID AS Goals_Department_Id,
	   dep.Clrt_DEPt_Nme AS Goals_Department_Name,
       surveys_ip_sum.month_num,
       surveys_ip_sum.month_short_name,
       surveys_ip_sum.TOP_BOX,
       surveys_ip_sum.VAL_COUNT,
       surveys_ip_sum.SCORE,
       surveys_ip_sum.N
     , surveys_ip_goals.GOAL
FROM #surveys_ip_sum surveys_ip_sum
INNER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
ON CAST(surveys_ip_sum.DEPARTMENT_ID AS NUMERIC(18,0)) = dep.DEPARTMENT_ID
LEFT OUTER JOIN
(
SELECT DISTINCT
	REC_FY
  , DEPARTMENT_ID
  , Service_Line
  , Goals_Service_Line
  , Domain_Goals
  , GOAL
FROM #surveys_ip_goals
WHERE DEPARTMENT_ID <> 'All Units'
) surveys_ip_goals
ON surveys_ip_goals.REC_FY = surveys_ip_sum.REC_FY
AND surveys_ip_goals.DEPARTMENT_ID = surveys_ip_sum.DEPARTMENT_ID
AND surveys_ip_goals.Service_Line = surveys_ip_sum.Survey_Service_Line
AND surveys_ip_goals.Goals_Service_Line = surveys_ip_sum.Goals_Service_Line
AND surveys_ip_goals.Domain_Goals = surveys_ip_sum.Domain_Goals
WHERE surveys_ip_sum.REC_FY = 2020
) surveys_ip_sum
INNER JOIN
(
SELECT DISTINCT
	Fyear_num
FROM DS_HSDW_Prod.dbo.Dim_Date
WHERE day_date BETWEEN @locstartdate and @locenddate
) rec
ON rec.Fyear_num = surveys_ip_sum.REC_FY

SELECT Event_Type,
       Event_FY,
       Survey_Unit,
       Survey_Service_Line,
       Survey_Department_Id,
       Survey_Department_Name,
       Domain_Goals,
       Goals_UNIT,
       Goals_Service_Line,
       --DEPARTMENT_ID,
       --Clrt_DEPt_Nme,
	   Goals_Department_Id,
	   Goals_Department_Name,
       month_num,
       month_short_name,
       TOP_BOX,
       VAL_COUNT,
       SCORE,
       N,
       GOAL
FROM #surveys_ip2_sum
ORDER BY Event_FY
	   , Survey_Unit
	   , Survey_Service_Line
	   , Survey_Department_Id
	   , Survey_Department_Name
	   , Domain_Goals
	   , Goals_UNIT
	   , Goals_Service_Line
	   --, DEPARTMENT_ID
	   --, Clrt_DEPt_Nme
	   , Goals_Department_Id
	   , Goals_Department_Name
       , month_num
	   , month_short_name
*/
/*
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
		,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
		,rec.day_date AS Event_Date
		,dis.day_date AS Event_Date_Disch
	    ,rec.Fyear_num AS Event_FY
		,sk_Dim_PG_Question
		,VARNAME
		,QUESTION_TEXT_ALIAS
		,surveys_ip.Domain
		,surveys_ip.Domain_Goals
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
	    ,surveys_ip.Goals_Service_Line AS Service_Line
		,VALUE
		,Value_Resp_Grp
		,TOP_BOX
		,VAL_COUNT
		,rec.quarter_name
		,rec.month_short_name
	FROM
		(SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @locstartdate AND day_date <= @locenddate) rec
	LEFT OUTER JOIN #surveys_ip surveys_ip
	ON rec.day_date = surveys_ip.RECDATE
	FULL OUTER JOIN DS_HSDW_Prod.dbo.Dim_Date dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
	ON dis.day_date = surveys_ip.DISDATE
	LEFT OUTER JOIN
		(SELECT * FROM #surveys_ip_goals WHERE (UNIT = 'All Units' OR DEPARTMENT_ID = 'All Units') AND Goals_Service_Line = 'All Service Lines') goals
	ON surveys_ip.REC_FY = goals.REC_FY AND surveys_ip.Domain_Goals = goals.Domain_Goals
)

----------------------------------------------------------------------------------------------------------------------
-- RESULTS
 SELECT [Event_Type]
   ,[SURVEY_ID]
   ,[sk_Fact_Pt_Acct]
   ,[Rpt_Prd]
   ,[Event_Date]
   ,[Event_Date_Disch]
   ,[Event_FY]
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
  FROM [#surveys_ip3]
*/
GO


