USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @StartDate SMALLDATETIME
       ,@EndDate SMALLDATETIME

--SET @StartDate = NULL
--SET @EndDate = NULL
SET @StartDate = '7/1/2018'
--SET @EndDate = '12/29/2019'
--SET @StartDate = '7/1/2019'
SET @EndDate = '12/31/2019'

DECLARE @in_servLine VARCHAR(MAX)

DECLARE @ServiceLine TABLE (ServiceLine VARCHAR(50))

INSERT INTO @ServiceLine
(
    ServiceLine
)
VALUES
--(1),--Digestive Health
--(2),--Heart and Vascular
--(3),--Medical Subspecialties
--(4),--Musculoskeletal
--(5),--Neurosciences and Behavioral Health
--(6),--Oncology
--(7),--Ophthalmology
--(8),--Primary Care
--(9),--Surgical Subspecialties
--(10),--Transplant
--(11) --Womens and Childrens
--(0)  --(All)
--(1) --Digestive Health
--(1),--Digestive Health
--(2) --Heart and Vascular
--('Digestive Health'),
--('Heart and Vascular'),
--('Medical Subspecialties'),
--('Musculoskeletal'),
--('Neurosciences and Behavioral Health'),
--('Oncology'),
--('Ophthalmology'),
--('Primary Care'),
--('Surgical Subspecialties'),
--('Transplant'),
--('Womens and Childrens')
('Digestive Health'),
('Heart and Vascular')
--('Digestive Health')

SELECT @in_servLine = COALESCE(@in_servLine+',' ,'') + CAST(ServiceLine AS VARCHAR(MAX))
FROM @ServiceLine

--SELECT @in_servLine

--CREATE PROC [Rptg].[uspSrc_Dash_PatExp_HCAHPS_Response_Summary_Dimension]
--    (
--     @StartDate SMALLDATETIME = NULL,
--     @EndDate SMALLDATETIME = NULL,
     --@in_servLine VARCHAR(MAX),
--    )
--AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - HCAHPS (Inpatient) - Response Summary
WHO : Tom Burgan
WHEN: 12/30/2019
WHY : Report survey response summary for patient experience dashboard
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
MODS: 	12/30/2019 - Create stored procedure
***********************************************************************************************************************/

SET NOCOUNT ON

---------------------------------------------------
---Default date range is the first day of FY 19 (7/1/2018) to yesterday's date
DECLARE @currdate AS SMALLDATETIME;
--DECLARE @startdate AS DATE;
--DECLARE @enddate AS DATE;

    SET @currdate=CAST(CAST(GETDATE() AS DATE) AS SMALLDATETIME);

    IF @StartDate IS NULL
        AND @EndDate IS NULL
        BEGIN
            SET @StartDate = CAST(CAST('7/1/2018' AS DATE) AS SMALLDATETIME);
            SET @EndDate= CAST(DATEADD(DAY, -1, CAST(GETDATE() AS DATE)) AS SMALLDATETIME); 
        END; 

----------------------------------------------------
DECLARE @locstartdate SMALLDATETIME,
        @locenddate SMALLDATETIME

SET @locstartdate = @startdate
SET @locenddate   = @enddate

DECLARE @tab_servLine TABLE
(
    Service_Line VARCHAR(50)
);
INSERT INTO @tab_servLine
SELECT Param
FROM DS_HSDW_Prod.ETL.fn_ParmParse(@in_servLine, ',');

IF OBJECT_ID('tempdb..#surveys_ip ') IS NOT NULL
DROP TABLE #surveys_ip

IF OBJECT_ID('tempdb..#surveys_ip2 ') IS NOT NULL
DROP TABLE #surveys_ip2

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
	 ddte.Fyear_num AS REC_FY
	,ddte.quarter_name
	,ddte.month_short_name
	,ddte.month_num
	,ddte.year_num
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
	,extd.DOMAIN
	,CASE WHEN Resp.sk_Dim_PG_Question = '7' THEN 'Quietness' WHEN Resp.sk_Dim_PG_Question = '6' THEN 'Cleanliness' WHEN (Resp.sk_Dim_PG_Question IN ('2412','2414')) THEN 'Pain Management' ELSE DOMAIN END AS Domain_Goals
	,qstn.sk_Dim_PG_Question
	,extd.QUESTION_TEXT_ALIAS -- Short form of question text
	INTO #surveys_ip
	FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses AS Resp
	INNER JOIN DS_HSDW_Prod.dbo.Dim_PG_Question AS qstn
		ON Resp.sk_Dim_PG_Question = qstn.sk_Dim_PG_Question
	INNER JOIN DS_HSDW_Prod.Rptg.vwDim_Date ddte
	ON ddte.day_date = Resp.RECDATE
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
		'1','2','5','6','7','11','14','16','17','18','24','27','28','29',
		'30','32','33','34','37','38','84','85','86','87','87','88','89',
		'90','92','93','99','101','105','106','108','110','112','113','126','127',
		'130','136','288','482','519','521','526','1238','2412','2414'
	)
	AND resp.RECDATE BETWEEN @locstartdate AND @locenddate
	ORDER BY REC_FY, UNIT, Goals_UNIT, Goals_Service_Line, DEPARTMENT_ID, Domain_Goals, qstn.sk_Dim_PG_Question

  -- Create indexes for temp table #surveys_ip
  CREATE NONCLUSTERED INDEX IX_surveysip ON #surveys_ip (REC_FY, UNIT, Goals_UNIT, Domain_Goals, sk_Dim_PG_Question)
  CREATE NONCLUSTERED INDEX IX_surveysip2 ON #surveys_ip (REC_FY, Goals_Service_Line, Domain_Goals, sk_Dim_PG_Question)
  CREATE NONCLUSTERED INDEX IX_surveysip3 ON #surveys_ip (REC_FY, DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question)

--  SELECT *
--  FROM #surveys_ip
--ORDER BY REC_FY
--	   , year_num
--       , month_num
--	   , month_short_name
--	   , Goals_Service_Line
--	   , UNIT
--	   , Goals_UNIT
--	   , DEPARTMENT_ID
--	   , Clrt_DEPt_Nme
--	   , Domain_Goals
--	   , QUESTION_TEXT_ALIAS

------------------------------------------------------------------------------------------
--- JOIN TO DIM_DATE

 SELECT
	'Inpatient HCAHPS' AS Event_Type
	,surveys_ip.REC_FY AS Event_FY
	,QUESTION_TEXT_ALIAS
	,surveys_ip.Domain
	,Domain_Goals
	,surveys_ip.Goals_Service_Line AS Service_Line
	,quarter_name
	,month_short_name
	,month_num
	,year_num
	,surveys_ip.DEPARTMENT_ID
	,surveys_ip.Clrt_DEPt_Nme
INTO #surveys_ip2
FROM
(
SELECT DISTINCT
       surveys_ip.REC_FY,
	   quarter_name,
       month_short_name,
       month_num,
       year_num,
	   surveys_ip.Goals_Service_Line,
       surveys_ip.DOMAIN,
       surveys_ip.Domain_Goals,
       surveys_ip.QUESTION_TEXT_ALIAS
	 , surveys_ip.DEPARTMENT_ID
	 , surveys_ip.Clrt_DEPt_Nme
FROM #surveys_ip surveys_ip
WHERE surveys_ip.REC_FY >= 2019
) surveys_ip

--SELECT *
--FROM #surveys_ip2
--ORDER BY Event_FY
--	   , year_num
--       , month_num
--	   , month_short_name
--	   , Service_Line
--	   , DEPARTMENT_ID
--	   , Clrt_DEPt_Nme
--	   , Domain_Goals
--	   , QUESTION_TEXT_ALIAS

--SELECT Event_Type,
--       Event_FY,
--	   year_num AS Event_CY,
--       month_num AS [Month],
--       month_short_name AS Month_Name,
--       Service_Line,
--       DEPARTMENT_ID,
--       Clrt_DEPt_Nme AS DEPARTMENT_NAME,
--       Domain_Goals,
--       QUESTION_TEXT_ALIAS
--FROM #surveys_ip2
--WHERE (Service_Line IN (SELECT Service_Line FROM @tab_servLine))
--ORDER BY Event_Type
--       , Event_FY
--	   , year_num
--       , month_num
--	   , month_short_name
--	   , Service_Line
--	   , DEPARTMENT_ID
--	   , Clrt_DEPt_Nme
--	   , Domain_Goals
--	   , QUESTION_TEXT_ALIAS

SELECT DISTINCT
       DEPARTMENT_ID,
       Clrt_DEPt_Nme AS DEPARTMENT_NAME,
	   Service_Line
FROM #surveys_ip2
ORDER BY Service_Line
	   , Clrt_DEPt_Nme

GO


