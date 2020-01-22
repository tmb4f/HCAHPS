USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#surveys_ip ') IS NOT NULL
DROP TABLE #surveys_ip

IF OBJECT_ID('tempdb..#surveys_ip_goals ') IS NOT NULL
DROP TABLE #surveys_ip_goals

IF OBJECT_ID('tempdb..#surveys_ip2 ') IS NOT NULL
DROP TABLE #surveys_ip2

IF OBJECT_ID('tempdb..#surveys_ip3 ') IS NOT NULL
DROP TABLE #surveys_ip3

IF OBJECT_ID('tempdb..#HCAHPS_Units ') IS NOT NULL
DROP TABLE #HCAHPS_Units

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

SELECT DISTINCT
	 Resp.SURVEY_ID
	,Resp.sk_Fact_Pt_Acct
	,Resp.RECDATE
	,ddte.Fyear_num AS REC_FY
	,ddte.month_num AS REC_MO
	,Resp.DISDATE
	,phys.DisplayName AS Phys_Name
	,phys.DEPT AS Phys_Dept
	,phys.Division AS Phys_Div
	,CASE WHEN RespUnit.UNIT = 'obs' THEN 'Womens and Childrens'
		  WHEN bcsm.Service_Line IS NULL THEN 'Other'
		  ELSE bcsm.Service_Line
		  END AS Service_Line -- obs appears as both 8nor and 8cob
	,CASE WHEN RespUnit.UNIT IS NULL THEN 'Other' ELSE RespUnit.UNIT END AS UNIT
	,CAST(Resp.VALUE AS NVARCHAR(500)) AS VALUE -- prevents Tableau from erroring out on import data source
	,CASE WHEN Resp.VALUE IS NOT NULL THEN 1 ELSE 0 END AS VAL_COUNT
	,extd.DOMAIN
	,CASE WHEN resp.sk_Dim_PG_Question = '7' THEN 'Quietness' WHEN Resp.sk_Dim_PG_Question = '6' THEN 'Cleanliness' ELSE DOMAIN END AS Domain_Goals
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
	,dep.DEPARTMENT_ID
	,dep.Clrt_DEPt_Nme
	INTO #surveys_ip
	FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses AS Resp
	INNER JOIN DS_HSDW_Prod.dbo.Dim_PG_Question AS qstn
		ON Resp.sk_Dim_PG_Question = qstn.sk_Dim_PG_Question
	INNER JOIN DS_HSDW_Prod.Rptg.vwDim_Date ddte
	    ON Resp.RECDATE = ddte.day_date
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
	WHERE  Resp.Svc_Cde='IN' AND qstn.sk_Dim_PG_Question IN
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

SELECT
	resp.REC_FY
  , resp.REC_MO
  , resp.Service_Line
  , resp.UNIT
  , resp.DEPARTMENT_ID
  , resp.Clrt_DEPt_Nme
  , COUNT(*) AS Resp_Count
FROM
(
SELECT DISTINCT
	REC_FY
  , REC_MO
  , RECDATE
  , Service_Line
  , UNIT
  , DEPARTMENT_ID
  , Clrt_DEPt_Nme
  , SURVEY_ID
FROM #surveys_ip
WHERE DEPARTMENT_ID IN (10243035
,10243049
,10243054
,10243055
,10243057
,10243091
)
--WHERE Service_Line = 'Heart and Vascular'
--AND RECDATE BETWEEN '11/1/2018 00:00 AM' AND '9/30/2019 11:59 PM'
AND RECDATE BETWEEN '7/1/2018 00:00 AM' AND '9/30/2019 11:59 PM'
) resp
GROUP BY
	resp.REC_FY
  , resp.REC_MO
  , resp.Service_Line
  , resp.UNIT
  , resp.DEPARTMENT_ID
  , resp.Clrt_DEPt_Nme
ORDER BY
	REC_FY
  , REC_MO
  , Service_Line
  , UNIT
  , DEPARTMENT_ID
  , Clrt_DEPt_Nme
--ORDER BY
--	resp.REC_FY
--  , resp.DEPARTMENT_ID
--  , resp.Service_Line
--  , resp.Clrt_DEPt_Nme
/*
------------------------------------------------------------------------------------------
--- JOIN TO DIM_DATE


 SELECT
	'Inpatient HCAHPS' AS Event_Type
	,SURVEY_ID
	,sk_Fact_Pt_Acct
	,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
	,rec.day_date AS Event_Date
	,dis.day_date AS Event_Date_Disch
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
	,CASE WHEN #surveys_ip.UNIT = 'SHRTSTAY' THEN 'SSU' ELSE #surveys_ip.UNIT END AS UNIT -- CAN'T MAP SHRTSTAY TO GOALS AND SVC LINE WITHOUT A CHANGE TO BCSM TABLE
	,#surveys_ip.Service_Line
	,VALUE
	,Value_Resp_Grp
	,TOP_BOX
	,VAL_COUNT
	,rec.quarter_name
	,rec.month_short_name
INTO #surveys_ip2
FROM DS_HSDW_Prod.dbo.Dim_Date rec
LEFT OUTER JOIN #surveys_ip
ON rec.day_date = #surveys_ip.RECDATE
FULL OUTER JOIN DS_HSDW_Prod.dbo.Dim_Date dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
ON dis.day_date = #surveys_ip.DISDATE
LEFT OUTER JOIN DS_HSDW_App.Rptg.HCAHPS_Goals goals
ON #surveys_ip.UNIT = goals.unit AND #surveys_ip.Domain_Goals = goals.DOMAIN
ORDER BY Event_Date, SURVEY_ID, sk_Dim_PG_Question

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
	FROM DS_HSDW_Prod.dbo.Dim_Date rec
	LEFT OUTER JOIN #surveys_ip
	ON rec.day_date = #surveys_ip.RECDATE
	FULL OUTER JOIN DS_HSDW_Prod.dbo.Dim_Date dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
	ON dis.day_date = #surveys_ip.DISDATE
	LEFT OUTER JOIN
		(SELECT * FROM DS_HSDW_App.Rptg.HCAHPS_Goals WHERE UNIT = 'All Units' AND SERVICE_LINE = 'All Service Lines') goals
	ON #surveys_ip.Domain_Goals = goals.DOMAIN
)

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
  FROM [#surveys_ip3];
*/
GO


