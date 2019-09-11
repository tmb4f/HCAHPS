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

BEGIN
DECLARE @HCAHPS_Goals_FY18 TABLE
(
	[SVC_CDE] [VARCHAR](2) NULL,
	[GOAL_YR] [INT] NULL,
	[SERVICE_LINE] [VARCHAR](150) NULL,
	[UNIT] [VARCHAR](150) NULL,
	[EPIC_DEPARTMENT_ID] [VARCHAR](10) NULL,
	[EPIC_DEPARTMENT_NAME] [VARCHAR](30) NULL,
	[DOMAIN] [VARCHAR](150) NULL,
	[GOAL] [DECIMAL](4, 3) NULL,
	[Load_Dtm] [SMALLDATETIME] NULL
);

INSERT INTO @HCAHPS_Goals_FY18
(
    SVC_CDE,
    GOAL_YR,
    SERVICE_LINE,
    UNIT,
	EPIC_DEPARTMENT_ID,
	EPIC_DEPARTMENT_NAME,
    DOMAIN,
    GOAL,
    Load_Dtm
)
VALUES
('IN','2018','All Service Lines','All Units',NULL,NULL,'Care Transitions','0.606','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Cleanliness','0.749','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Communication About Medicines','0.652','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Communication with Doctors','0.838','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Communication with Nurses','0.822','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Discharge Information','0.919','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Overall Assessment','0.762','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Pain Management','0.706','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Quietness','0.505','8/10/2017 14:13'),
('IN','2018','All Service Lines','All Units',NULL,NULL,'Response of Hospital Staff','0.664','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Care Transitions','0.631','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Cleanliness','0.763','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Communication About Medicines','0.639','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Communication with Doctors','0.847','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Communication with Nurses','0.816','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Discharge Information','0.941','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Overall Assessment','0.766','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Pain Management','0.732','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Quietness','0.493','8/10/2017 14:13'),
('IN','2018','Digestive Health','5CENTRAL',NULL,NULL,'Response of Hospital Staff','0.61','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Care Transitions','0.631','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Cleanliness','0.763','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Communication About Medicines','0.639','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Communication with Doctors','0.847','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Communication with Nurses','0.816','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Discharge Information','0.941','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Overall Assessment','0.766','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Pain Management','0.732','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Quietness','0.493','8/10/2017 14:13'),
('IN','2018','Digestive Health','All Units',NULL,NULL,'Response of Hospital Staff','0.61','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Care Transitions','0.574','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Cleanliness','0.736','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Communication About Medicines','0.637','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Communication with Doctors','0.78','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Communication with Nurses','0.792','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Discharge Information','0.884','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Overall Assessment','0.742','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Pain Management','0.64','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Quietness','0.452','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4CEN',NULL,NULL,'Response of Hospital Staff','0.678','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Care Transitions','0.628','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Cleanliness','0.806','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Communication About Medicines','0.721','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Communication with Doctors','0.854','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Communication with Nurses','0.843','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Discharge Information','0.929','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Overall Assessment','0.799','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Pain Management','0.738','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Quietness','0.585','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4EAST',NULL,NULL,'Response of Hospital Staff','0.684','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Care Transitions','0.631','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Cleanliness','0.543','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Communication About Medicines','0.646','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Communication with Doctors','0.875','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Communication with Nurses','0.859','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Discharge Information','0.92','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Overall Assessment','0.831','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Pain Management','0.528','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Quietness','0.557','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4NOR',NULL,NULL,'Response of Hospital Staff','0.776','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Care Transitions','0.595','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Cleanliness','0.707','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Communication About Medicines','0.602','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Communication with Doctors','0.84','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Communication with Nurses','0.775','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Discharge Information','0.938','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Overall Assessment','0.735','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Pain Management','0.677','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Quietness','0.414','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','4WEST',NULL,NULL,'Response of Hospital Staff','0.592','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Care Transitions','0.597','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Cleanliness','0.747','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Communication About Medicines','0.646','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Communication with Doctors','0.827','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Communication with Nurses','0.806','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Discharge Information','0.923','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Overall Assessment','0.76','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Pain Management','0.684','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Quietness','0.483','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','All Units',NULL,NULL,'Response of Hospital Staff','0.65','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Care Transitions','0.51','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Cleanliness','0.832','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Communication About Medicines','0.597','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Communication with Doctors','0.838','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Communication with Nurses','0.862','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Discharge Information','0.912','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Overall Assessment','0.823','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Pain Management','0.728','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Quietness','0.704','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','CCU',NULL,NULL,'Response of Hospital Staff','0.804','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Care Transitions','0.629','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Cleanliness','0.743','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Communication About Medicines','0.613','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Communication with Doctors','0.88','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Communication with Nurses','0.859','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Discharge Information','0.944','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Overall Assessment','0.831','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Pain Management','0.78','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Quietness','0.657','8/10/2017 14:13'),
('IN','2018','Heart and Vascular','TCPO',NULL,NULL,'Response of Hospital Staff','0.794','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Care Transitions','0.54','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Cleanliness','0.66','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Communication About Medicines','0.586','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Communication with Doctors','0.773','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Communication with Nurses','0.799','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Discharge Information','0.821','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Overall Assessment','0.712','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Pain Management','0.645','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Quietness','0.495','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3CENTRAL',NULL,NULL,'Response of Hospital Staff','0.642','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Care Transitions','0.58','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Cleanliness','0.651','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Communication About Medicines','0.696','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Communication with Doctors','0.778','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Communication with Nurses','0.828','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Discharge Information','0.877','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Overall Assessment','0.732','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Pain Management','0.606','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Quietness','0.495','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3EAST',NULL,NULL,'Response of Hospital Staff','0.584','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Care Transitions','0.627','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Cleanliness','0.845','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Communication About Medicines','0.721','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Communication with Doctors','0.875','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Communication with Nurses','0.859','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Discharge Information','0.82','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Overall Assessment','0.831','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Pain Management','0.78','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Quietness','0.657','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3NOR',NULL,NULL,'Response of Hospital Staff','0.762','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Care Transitions','0.567','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Cleanliness','0.689','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Communication About Medicines','0.602','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Communication with Doctors','0.777','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Communication with Nurses','0.799','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Discharge Information','0.872','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Overall Assessment','0.673','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Pain Management','0.609','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Quietness','0.534','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','3WEST',NULL,NULL,'Response of Hospital Staff','0.72','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Care Transitions','0.57','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Cleanliness','0.676','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Communication About Medicines','0.636','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Communication with Doctors','0.783','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Communication with Nurses','0.814','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Discharge Information','0.857','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Overall Assessment','0.72','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Pain Management','0.63','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Quietness','0.521','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','All Units',NULL,NULL,'Response of Hospital Staff','0.656','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Care Transitions','0.694','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Cleanliness','0.835','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Communication About Medicines','0.738','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Communication with Doctors','0.899','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Communication with Nurses','0.875','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Discharge Information','0.862','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Overall Assessment','0.875','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Pain Management','0.818','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Quietness','0.753','8/10/2017 14:13'),
('IN','2018','Medical Subspecialties','MICU',NULL,NULL,'Response of Hospital Staff','0.832','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Care Transitions','0.672','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Cleanliness','0.819','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Communication About Medicines','0.672','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Communication with Doctors','0.865','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Communication with Nurses','0.865','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Discharge Information','0.955','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Overall Assessment','0.796','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Pain Management','0.753','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Quietness','0.563','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','6EAST',NULL,NULL,'Response of Hospital Staff','0.704','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Care Transitions','0.672','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Cleanliness','0.819','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Communication About Medicines','0.672','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Communication with Doctors','0.865','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Communication with Nurses','0.865','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Discharge Information','0.955','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Overall Assessment','0.796','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Pain Management','0.753','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Quietness','0.563','8/10/2017 14:13'),
('IN','2018','Musculoskeletal','All Units',NULL,NULL,'Response of Hospital Staff','0.704','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Care Transitions','0.591','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Cleanliness','0.783','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Communication About Medicines','0.68','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Communication with Doctors','0.828','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Communication with Nurses','0.833','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Discharge Information','0.908','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Overall Assessment','0.758','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Pain Management','0.656','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Quietness','0.52','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6CEN',NULL,NULL,'Response of Hospital Staff','0.678','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Care Transitions','0.585','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Cleanliness','0.805','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Communication About Medicines','0.659','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Communication with Doctors','0.86','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Communication with Nurses','0.812','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Discharge Information','0.933','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Overall Assessment','0.786','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Pain Management','0.695','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Quietness','0.436','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','6WEST',NULL,NULL,'Response of Hospital Staff','0.643','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Care Transitions','0.589','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Cleanliness','0.801','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Communication About Medicines','0.668','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Communication with Doctors','0.849','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Communication with Nurses','0.822','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Discharge Information','0.922','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Overall Assessment','0.785','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Pain Management','0.69','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Quietness','0.474','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Response of Hospital Staff','0.662','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Care Transitions','0.637','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Cleanliness','0.864','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Communication About Medicines','0.706','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Communication with Doctors','0.874','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Communication with Nurses','0.864','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Discharge Information','0.874','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Overall Assessment','0.831','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Pain Management','0.78','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Quietness','0.693','8/10/2017 14:13'),
('IN','2018','Neurosciences and Behavioral Health','NNIC',NULL,NULL,'Response of Hospital Staff','0.783','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Care Transitions','0.548','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Cleanliness','0.676','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Communication About Medicines','0.707','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Communication with Doctors','0.839','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Communication with Nurses','0.877','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Discharge Information','0.89','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Overall Assessment','0.79','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Pain Management','0.698','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Quietness','0.535','8/10/2017 14:13'),
('IN','2018','Oncology','8WEST',NULL,NULL,'Response of Hospital Staff','0.628','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Care Transitions','0.631','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Cleanliness','0.69','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Communication About Medicines','0.739','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Communication with Doctors','0.758','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Communication with Nurses','0.781','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Discharge Information','0.969','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Overall Assessment','0.752','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Pain Management','0.528','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Quietness','0.586','8/10/2017 14:13'),
('IN','2018','Oncology','8WSC',NULL,NULL,'Response of Hospital Staff','0.642','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Care Transitions','0.562','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Cleanliness','0.679','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Communication About Medicines','0.714','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Communication with Doctors','0.826','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Communication with Nurses','0.861','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Discharge Information','0.903','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Overall Assessment','0.784','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Pain Management','0.675','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Quietness','0.543','8/10/2017 14:13'),
('IN','2018','Oncology','All Units',NULL,NULL,'Response of Hospital Staff','0.63','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Care Transitions','0.614','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Cleanliness','0.771','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Communication About Medicines','0.739','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Communication with Doctors','0.881','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Communication with Nurses','0.878','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Discharge Information','0.89','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Overall Assessment','0.784','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Pain Management','0.777','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Quietness','0.618','8/10/2017 14:13'),
('IN','2018','Other','All Units',NULL,NULL,'Response of Hospital Staff','0.78','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Care Transitions','0.614','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Cleanliness','0.771','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Communication About Medicines','0.739','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Communication with Doctors','0.881','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Communication with Nurses','0.878','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Discharge Information','0.89','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Overall Assessment','0.784','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Pain Management','0.777','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Quietness','0.618','8/10/2017 14:13'),
('IN','2018','Other','Other',NULL,NULL,'Response of Hospital Staff','0.78','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Care Transitions','0.611','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Cleanliness','0.761','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Communication About Medicines','0.73','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Communication with Doctors','0.875','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Communication with Nurses','0.859','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Discharge Information','0.885','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Overall Assessment','0.831','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Pain Management','0.8','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Quietness','0.607','8/10/2017 14:13'),
('IN','2018','Other','SSU',NULL,NULL,'Response of Hospital Staff','0.775','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Care Transitions','0.605','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Cleanliness','0.748','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Communication About Medicines','0.567','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Communication with Doctors','0.798','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Communication with Nurses','0.811','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Discharge Information','0.913','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Overall Assessment','0.814','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Pain Management','0.695','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Quietness','0.505','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5NOR',NULL,NULL,'Response of Hospital Staff','0.651','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Care Transitions','0.561','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Cleanliness','0.63','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Communication About Medicines','0.592','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Communication with Doctors','0.848','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Communication with Nurses','0.782','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Discharge Information','0.93','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Overall Assessment','0.728','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Pain Management','0.69','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Quietness','0.435','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','5WEST',NULL,NULL,'Response of Hospital Staff','0.533','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Care Transitions','0.562','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Cleanliness','0.64','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Communication About Medicines','0.585','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Communication with Doctors','0.842','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Communication with Nurses','0.781','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Discharge Information','0.933','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Overall Assessment','0.739','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Pain Management','0.684','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Quietness','0.44','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','All Units',NULL,NULL,'Response of Hospital Staff','0.55','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Care Transitions','0.397','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Cleanliness','0.538','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Communication About Medicines','0.197','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Communication with Doctors','0.805','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Communication with Nurses','0.657','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Discharge Information','0.906','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Overall Assessment','0.822','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Pain Management','0.457','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Quietness','0.343','8/10/2017 14:13'),
('IN','2018','Surgical Subspecialties','SICU',NULL,NULL,'Response of Hospital Staff','0.74','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Care Transitions','0.64','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Cleanliness','0.748','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Communication About Medicines','0.686','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Communication with Doctors','0.874','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Communication with Nurses','0.853','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Discharge Information','0.901','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Overall Assessment','0.71','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Pain Management','0.77','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Quietness','0.544','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8COB',NULL,NULL,'Response of Hospital Staff','0.773','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Care Transitions','0.489','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Cleanliness','0.51','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Communication About Medicines','0.552','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Communication with Doctors','0.902','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Communication with Nurses','0.843','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Discharge Information','0.939','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Overall Assessment','0.742','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Pain Management','0.759','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Quietness','0.524','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','8NOR',NULL,NULL,'Response of Hospital Staff','0.622','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Care Transitions','0.64','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Cleanliness','0.748','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Communication About Medicines','0.686','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Communication with Doctors','0.874','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Communication with Nurses','0.853','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Discharge Information','0.901','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Overall Assessment','0.71','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Pain Management','0.77','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Quietness','0.544','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','All Units',NULL,NULL,'Response of Hospital Staff','0.773','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Care Transitions','0.658','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Cleanliness','0.772','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Communication About Medicines','0.707','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Communication with Doctors','0.884','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Communication with Nurses','0.862','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Discharge Information','0.898','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Overall Assessment','0.716','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Pain Management','0.778','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Quietness','0.546','8/10/2017 14:13'),
('IN','2018','Womens and Childrens','OBS',NULL,NULL,'Response of Hospital Staff','0.805','8/10/2017 14:13')
;

DECLARE @HCAHPS_Goals_FY19 TABLE
(
	[SVC_CDE] [VARCHAR](2) NULL,
	[GOAL_YR] [INT] NULL,
	[SERVICE_LINE] [VARCHAR](150) NULL,
	[UNIT] [VARCHAR](150) NULL,
	[EPIC_DEPARTMENT_ID] [VARCHAR](10) NULL,
	[EPIC_DEPARTMENT_NAME] [VARCHAR](30) NULL,
	[DOMAIN] [VARCHAR](150) NULL,
	[GOAL] [DECIMAL](4, 3) NULL,
	[Load_Dtm] [SMALLDATETIME] NULL
);

INSERT INTO @HCAHPS_Goals_FY19
(
    SVC_CDE,
    GOAL_YR,
    SERVICE_LINE,
    UNIT,
	EPIC_DEPARTMENT_ID,
	EPIC_DEPARTMENT_NAME,
    DOMAIN,
    GOAL,
    Load_Dtm
)
VALUES
('IN','2019','All Service Lines','All Units',NULL,NULL,'Care Transitions','0.606','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Cleanliness','0.747','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Communication About Medicines','0.65','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Communication with Doctors','0.85','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Communication with Nurses','0.822','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Discharge Information','0.922','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Overall Assessment','0.781','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Pain Management','0.743','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Quietness','0.515','9/9/2019 15:38'),
('IN','2019','All Service Lines','All Units',NULL,NULL,'Response of Hospital Staff','0.68','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Care Transitions','0.619','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Cleanliness','0.774','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Communication About Medicines','0.668','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Communication with Doctors','0.812','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Communication with Nurses','0.81','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Discharge Information','0.926','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Overall Assessment','0.833','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Pain Management','0.757','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Quietness','0.478','9/9/2019 15:38'),
('IN','2019','Digestive Health','5CENTRAL','10243058','UVHE 5 CENTRAL','Response of Hospital Staff','0.647','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Care Transitions','0.619','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Cleanliness','0.774','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Communication About Medicines','0.668','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Communication with Doctors','0.812','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Communication with Nurses','0.81','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Discharge Information','0.926','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Overall Assessment','0.833','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Pain Management','0.757','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Quietness','0.478','9/9/2019 15:38'),
('IN','2019','Digestive Health','All Units',NULL,NULL,'Response of Hospital Staff','0.647','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Care Transitions','0.534','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Cleanliness','0.702','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Communication About Medicines','0.591','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Communication with Doctors','0.847','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Communication with Nurses','0.832','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Discharge Information','0.912','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Overall Assessment','0.821','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Pain Management','0.765','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Quietness','0.473','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4CEN','10243054','UVHE 4 CENTRAL CV','Response of Hospital Staff','0.706','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Care Transitions','0.581','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Cleanliness','0.76','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Communication About Medicines','0.65','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Communication with Doctors','0.823','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Communication with Nurses','0.827','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Discharge Information','0.933','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Overall Assessment','0.77','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Pain Management','0.798','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Quietness','0.465','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4EAST','10243055','UVHE 4 EAST','Response of Hospital Staff','0.671','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Care Transitions','0.565','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Cleanliness','0.734','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Communication About Medicines','0.625','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Communication with Doctors','0.847','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Communication with Nurses','0.822','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Discharge Information','0.934','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Overall Assessment','0.8','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Quietness','0.474','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4NTCVICU','10243091','UVHE 4 NORTH','Response of Hospital Staff','0.686','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Care Transitions','0.56','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Cleanliness','0.718','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Communication About Medicines','0.61','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Communication with Doctors','0.862','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Communication with Nurses','0.8','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Discharge Information','0.947','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Overall Assessment','0.808','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Pain Management','0.701','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Quietness','0.462','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WEST','10243057','UVHE 4 WEST','Response of Hospital Staff','0.67','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Care Transitions','0.565','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Cleanliness','0.734','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Communication About Medicines','0.625','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Communication with Doctors','0.847','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Communication with Nurses','0.822','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Discharge Information','0.934','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Overall Assessment','0.8','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Quietness','0.474','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','4WTCVICU','10243049','UVHE TCV POST OP','Response of Hospital Staff','0.686','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Care Transitions','0.565','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Cleanliness','0.734','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Communication About Medicines','0.625','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Communication with Doctors','0.847','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Communication with Nurses','0.822','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Discharge Information','0.934','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Overall Assessment','0.8','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Quietness','0.474','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','All Units',NULL,NULL,'Response of Hospital Staff','0.686','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Care Transitions','0.565','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Cleanliness','0.734','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Communication About Medicines','0.625','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Communication with Doctors','0.847','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Communication with Nurses','0.822','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Discharge Information','0.934','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Overall Assessment','0.8','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Quietness','0.474','9/9/2019 15:38'),
('IN','2019','Heart and Vascular','CCU','10243035','UVHE CORONARY CARE','Response of Hospital Staff','0.686','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Care Transitions','0.534','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Cleanliness','0.684','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Communication About Medicines','0.579','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Communication with Doctors','0.811','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Communication with Nurses','0.783','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Discharge Information','0.916','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Overall Assessment','0.757','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Pain Management','0.547','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Quietness','0.492','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3CENTRAL','10243051','UVHE 3 CENTRAL','Response of Hospital Staff','0.705','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Care Transitions','0.585','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Cleanliness','0.703','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Communication About Medicines','0.673','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Communication with Doctors','0.85','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Communication with Nurses','0.826','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Discharge Information','0.869','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Overall Assessment','0.74','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Pain Management','0.669','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Quietness','0.494','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3EAST','10243052','UVHE 3 EAST','Response of Hospital Staff','0.582','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Care Transitions','0.727','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Cleanliness','0.754','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Communication About Medicines','0.673','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Communication with Doctors','0.793','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Communication with Nurses','0.928','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Discharge Information','0.899','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Overall Assessment','0.838','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Pain Management','0.699','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Quietness','0.53','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3N MICU','10243089','UVHE 3 NORTH','Response of Hospital Staff','0.781','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Care Transitions','0.621','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Cleanliness','0.859','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Communication About Medicines','0.598','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Communication with Doctors','0.815','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Communication with Nurses','0.792','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Discharge Information','0.849','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Overall Assessment','0.855','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Pain Management','0.702','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Quietness','0.737','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3W MICU','10243038','UVHE MEDICAL ICU','Response of Hospital Staff','0.658','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Care Transitions','0.551','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Cleanliness','0.75','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Communication About Medicines','0.609','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Communication with Doctors','0.758','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Communication with Nurses','0.772','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Discharge Information','0.923','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Overall Assessment','0.701','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Pain Management','0.694','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Quietness','0.466','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','3WEST','10243053','UVHE 3 WEST','Response of Hospital Staff','0.69','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Care Transitions','0.57','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Cleanliness','0.721','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Communication About Medicines','0.624','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Communication with Doctors','0.808','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Communication with Nurses','0.802','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Discharge Information','0.891','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Overall Assessment','0.745','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Pain Management','0.649','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Quietness','0.503','9/9/2019 15:38'),
('IN','2019','Medical Subspecialties','All Units',NULL,NULL,'Response of Hospital Staff','0.659','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Care Transitions','0.632','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Cleanliness','0.809','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Communication About Medicines','0.678','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Communication with Doctors','0.887','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Communication with Nurses','0.845','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Discharge Information','0.94','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Overall Assessment','0.793','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Quietness','0.557','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','6EAST','10243062','UVHE 6 EAST','Response of Hospital Staff','0.714','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Care Transitions','0.632','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Cleanliness','0.809','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Communication About Medicines','0.678','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Communication with Doctors','0.887','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Communication with Nurses','0.845','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Discharge Information','0.94','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Overall Assessment','0.793','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Quietness','0.557','9/9/2019 15:38'),
('IN','2019','Musculoskeletal','All Units',NULL,NULL,'Response of Hospital Staff','0.714','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Care Transitions','0.583','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Cleanliness','0.723','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Communication About Medicines','0.675','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Communication with Doctors','0.846','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Communication with Nurses','0.806','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Discharge Information','0.888','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Overall Assessment','0.758','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Pain Management','0.723','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Quietness','0.533','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6CEN','10243061','UVHE 6 CENTRAL','Response of Hospital Staff','0.688','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Care Transitions','0.478','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Cleanliness','0.792','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Communication About Medicines','0.697','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Communication with Doctors','0.883','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Communication with Nurses','0.895','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Discharge Information','0.95','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Overall Assessment','0.872','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Pain Management','0.821','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Quietness','0.635','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6NOR','10243092','UVHE 6 NORTH','Response of Hospital Staff','0.799','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Care Transitions','0.641','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Cleanliness','0.802','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Communication About Medicines','0.651','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Communication with Doctors','0.858','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Communication with Nurses','0.836','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Discharge Information','0.943','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Overall Assessment','0.785','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Pain Management','0.755','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Quietness','0.47','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','6WEST','10243063','UVHE 6 WEST','Response of Hospital Staff','0.644','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Care Transitions','0.614','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Cleanliness','0.778','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Communication About Medicines','0.661','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Communication with Doctors','0.857','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Communication with Nurses','0.83','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Discharge Information','0.93','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Overall Assessment','0.785','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Quietness','0.506','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','All Units',NULL,NULL,'Response of Hospital Staff','0.674','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Care Transitions','0.749','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Cleanliness','0.863','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Communication About Medicines','0.674','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Communication with Doctors','0.878','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Communication with Nurses','0.798','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Discharge Information','0.844','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Overall Assessment','0.853','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Pain Management','0.699','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Quietness','0.671','9/9/2019 15:38'),
('IN','2019','Neurosciences and Behavioral Health','NNIC','10243041','UVHE NEUR ICU','Response of Hospital Staff','0.882','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Care Transitions','0.543','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Cleanliness','0.681','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Communication About Medicines','0.627','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Communication with Doctors','0.786','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Communication with Nurses','0.775','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Discharge Information','0.867','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Overall Assessment','0.761','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Quietness','0.456','9/9/2019 15:38'),
('IN','2019','Oncology','8WEST','10243068','UVHE 8 WEST','Response of Hospital Staff','0.613','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Care Transitions','0.626','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Cleanliness','0.689','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Communication About Medicines','0.674','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Communication with Doctors','0.875','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Communication with Nurses','0.87','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Discharge Information','0.974','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Overall Assessment','0.847','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Pain Management','0.71','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Quietness','0.616','9/9/2019 15:38'),
('IN','2019','Oncology','8WSC','10243096','UVHE 8 WEST STEM CELL','Response of Hospital Staff','0.612','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Care Transitions','0.565','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Cleanliness','0.683','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Communication About Medicines','0.641','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Communication with Doctors','0.809','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Communication with Nurses','0.8','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Discharge Information','0.89','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Overall Assessment','0.784','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Pain Management','0.746','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Quietness','0.498','9/9/2019 15:38'),
('IN','2019','Oncology','All Units',NULL,NULL,'Response of Hospital Staff','0.613','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Care Transitions','0.594','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Cleanliness','0.673','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Communication About Medicines','0.677','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Communication with Doctors','0.875','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Communication with Nurses','0.861','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Discharge Information','0.861','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Overall Assessment','0.784','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Pain Management','0.833','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Quietness','0.665','9/9/2019 15:38'),
('IN','2019','Other','ADMT','10243047','UVHE SHORT STAY UNIT','Response of Hospital Staff','0.77','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Care Transitions','0.594','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Cleanliness','0.673','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Communication About Medicines','0.677','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Communication with Doctors','0.875','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Communication with Nurses','0.861','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Discharge Information','0.861','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Overall Assessment','0.784','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Pain Management','0.833','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Quietness','0.665','9/9/2019 15:38'),
('IN','2019','Other','All Units',NULL,NULL,'Response of Hospital Staff','0.77','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Care Transitions','0.594','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Cleanliness','0.673','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Communication About Medicines','0.677','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Communication with Doctors','0.875','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Communication with Nurses','0.861','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Discharge Information','0.861','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Overall Assessment','0.784','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Pain Management','0.833','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Quietness','0.665','9/9/2019 15:38'),
('IN','2019','Other','SSU ED','10243047','UVHE SHORT STAY UNIT','Response of Hospital Staff','0.77','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Care Transitions','0.652','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Cleanliness','0.707','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Communication About Medicines','0.58','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Communication with Doctors','0.767','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Communication with Nurses','0.881','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Discharge Information','0.875','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Overall Assessment','0.809','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Pain Management','0.655','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Quietness','0.642','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5NOR','10243090','UVHE 5 NORTH','Response of Hospital Staff','0.653','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Care Transitions','0.618','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Cleanliness','0.682','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Communication About Medicines','0.604','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Communication with Doctors','0.851','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Communication with Nurses','0.752','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Discharge Information','0.918','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Overall Assessment','0.737','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Pain Management','0.654','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Quietness','0.423','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','5WEST','10243060','UVHE 5 WEST','Response of Hospital Staff','0.568','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Care Transitions','0.622','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Cleanliness','0.685','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Communication About Medicines','0.602','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Communication with Doctors','0.841','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Communication with Nurses','0.767','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Discharge Information','0.914','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Overall Assessment','0.745','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Pain Management','0.612','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Quietness','0.449','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','All Units',NULL,NULL,'Response of Hospital Staff','0.582','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Care Transitions','0.914','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Cleanliness','0.685','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Communication About Medicines','0','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Communication with Doctors','0.841','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Communication with Nurses','0.767','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Discharge Information','0.602','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Overall Assessment','0.745','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Pain Management','0.612','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Quietness','0.449','9/9/2019 15:38'),
('IN','2019','Surgical Subspecialties','STICU','10243046','UVHE SURG TRAM ICU','Response of Hospital Staff','0.582','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Care Transitions','0.606','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Cleanliness','0.747','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Communication About Medicines','0.64','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Communication with Doctors','0.85','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Communication with Nurses','0.822','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Discharge Information','0.925','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Overall Assessment','0.793','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Quietness','0.515','9/9/2019 15:38'),
('IN','2019','Transplant','4CTXP','10243110','UVHE 4 CENTRAL TXP','Response of Hospital Staff','0.68','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Care Transitions','0.606','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Cleanliness','0.747','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Communication About Medicines','0.64','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Communication with Doctors','0.85','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Communication with Nurses','0.822','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Discharge Information','0.925','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Overall Assessment','0.793','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Quietness','0.515','9/9/2019 15:38'),
('IN','2019','Transplant','All Units',NULL,NULL,'Response of Hospital Staff','0.68','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Care Transitions','0.72','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Cleanliness','0.741','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Communication About Medicines','0.709','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Communication with Doctors','0.88','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Communication with Nurses','0.897','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Discharge Information','0.931','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Overall Assessment','0.771','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Pain Management','0.735','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Quietness','0.619','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8COB','10243066','UVHE 8 CENTRAL OB','Response of Hospital Staff','0.797','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Care Transitions','0.72','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Cleanliness','0.741','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Communication About Medicines','0.709','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Communication with Doctors','0.88','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Communication with Nurses','0.897','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Discharge Information','0.931','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Overall Assessment','0.771','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Pain Management','0.735','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Quietness','0.619','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','8NOR','10243094','UVHE 8 NORTH OB','Response of Hospital Staff','0.797','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Care Transitions','0.72','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Cleanliness','0.741','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Communication About Medicines','0.709','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Communication with Doctors','0.88','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Communication with Nurses','0.897','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Discharge Information','0.931','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Overall Assessment','0.771','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Pain Management','0.735','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Quietness','0.619','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','All Units',NULL,NULL,'Response of Hospital Staff','0.797','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Care Transitions','0.688','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Cleanliness','0.723','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Communication About Medicines','0.709','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Communication with Doctors','0.876','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Communication with Nurses','0.895','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Discharge Information','0.937','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Overall Assessment','0.783','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Pain Management','0.752','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Quietness','0.605','9/9/2019 15:38'),
('IN','2019','Womens and Childrens','OBS','10243066','UVHE 8 CENTRAL OB','Response of Hospital Staff','0.787','9/9/2019 15:38')
;

DECLARE @HCAHPS_Goals_FY20 TABLE
(
	[SVC_CDE] [VARCHAR](2) NULL,
	[GOAL_YR] [INT] NULL,
	[SERVICE_LINE] [VARCHAR](150) NULL,
	[UNIT] [VARCHAR](150) NULL,
	[EPIC_DEPARTMENT_ID] [VARCHAR](10) NULL,
	[EPIC_DEPARTMENT_NAME] [VARCHAR](30) NULL,
	[DOMAIN] [VARCHAR](150) NULL,
	[GOAL] [DECIMAL](4, 3) NULL,
	[Load_Dtm] [SMALLDATETIME] NULL
);

INSERT INTO @HCAHPS_Goals_FY20
(
    SVC_CDE,
    GOAL_YR,
    SERVICE_LINE,
    UNIT,
	EPIC_DEPARTMENT_ID,
	EPIC_DEPARTMENT_NAME,
    DOMAIN,
    GOAL,
    Load_Dtm
)
VALUES
('IN','2020','All Service Lines',NULL,'All Units','All Units','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Cleanliness','0.795','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Communication About Medicines','0.679','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Communication with Doctors','0.866','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Communication with Nurses','0.849','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Discharge Information','0.925','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Overall Assessment','0.797','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Pain Management','0.74','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Response of Hospital Staff','0.69','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Staff describe medicine side effect','0.542','9/9/2019 16:41'),
('IN','2020','All Service Lines',NULL,'All Units','All Units','Tell you what new medicine was for','0.817','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Care Transitions','0.62','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Cleanliness','0.8','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Communication About Medicines','0.722','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Communication with Doctors','0.86','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Communication with Nurses','0.82','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Discharge Information','0.928','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Overall Assessment','0.797','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Pain Management','0.752','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Quietness','0.49','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'10243058','UVHE 5 CENTRAL','Response of Hospital Staff','0.68','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Care Transitions','0.62','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Cleanliness','0.8','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Communication About Medicines','0.722','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Communication with Doctors','0.86','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Communication with Nurses','0.82','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Discharge Information','0.928','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Overall Assessment','0.797','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Pain Management','0.752','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Quietness','0.49','9/9/2019 16:41'),
('IN','2020','Digestive Health',NULL,'All Units','All Units','Response of Hospital Staff','0.68','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Care Transitions','0.656','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Cleanliness','0.845','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Communication About Medicines','0.722','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Communication with Doctors','0.894','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Communication with Nurses','0.913','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Discharge Information','0.923','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Overall Assessment','0.9','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Pain Management','0.746','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Quietness','0.611','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243035','UVHE CORONARY CARE','Response of Hospital Staff','0.841','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Cleanliness','0.82','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Communication About Medicines','0.696','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Communication with Doctors','0.875','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Communication with Nurses','0.851','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Discharge Information','0.934','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Overall Assessment','0.82','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Pain Management','0.748','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Quietness','0.474','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243049','UVHE TCV POST OP','Response of Hospital Staff','0.73','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Cleanliness','0.805','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Communication About Medicines','0.722','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Communication with Doctors','0.877','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Communication with Nurses','0.853','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Discharge Information','0.94','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Overall Assessment','0.825','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Pain Management','0.815','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Quietness','0.523','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243054','UVHE 4 CENTRAL CV','Response of Hospital Staff','0.771','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Care Transitions','0.6','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Cleanliness','0.807','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Communication About Medicines','0.718','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Communication with Doctors','0.85','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Communication with Nurses','0.819','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Discharge Information','0.917','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Overall Assessment','0.825','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Pain Management','0.68','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Quietness','0.492','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243055','UVHE 4 EAST','Response of Hospital Staff','0.713','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Care Transitions','0.637','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Cleanliness','0.834','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Communication About Medicines','0.664','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Communication with Doctors','0.885','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Communication with Nurses','0.87','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Discharge Information','0.962','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Overall Assessment','0.808','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Pain Management','0.776','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Quietness','0.48','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243057','UVHE 4 WEST','Response of Hospital Staff','0.72','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Cleanliness','0.82','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Communication About Medicines','0.696','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Communication with Doctors','0.875','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Communication with Nurses','0.851','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Discharge Information','0.934','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Overall Assessment','0.82','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Pain Management','0.748','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Quietness','0.474','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'10243091','UVHE 4 North','Response of Hospital Staff','0.73','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Cleanliness','0.82','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Communication About Medicines','0.696','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Communication with Doctors','0.875','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Communication with Nurses','0.851','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Discharge Information','0.934','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Overall Assessment','0.82','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Pain Management','0.748','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Quietness','0.474','9/9/2019 16:41'),
('IN','2020','Heart and Vascular',NULL,'All Units','All Units','Response of Hospital Staff','0.73','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Care Transitions','0.632','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Cleanliness','0.852','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Communication About Medicines','0.592','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Communication with Doctors','0.806','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Communication with Nurses','0.9','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Discharge Information','0.867','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Overall Assessment','0.834','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Pain Management','0.875','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Quietness','0.578','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243038','UVHE MEDICAL ICU','Response of Hospital Staff','0.686','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Care Transitions','0.578','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Cleanliness','0.733','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Communication About Medicines','0.686','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Communication with Doctors','0.818','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Communication with Nurses','0.84','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Discharge Information','0.916','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Overall Assessment','0.722','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Pain Management','0.665','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Quietness','0.492','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243051','UVHE 3 CENTRAL','Response of Hospital Staff','0.705','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Care Transitions','0.585','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Cleanliness','0.703','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Communication About Medicines','0.673','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Communication with Doctors','0.85','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Communication with Nurses','0.826','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Discharge Information','0.878','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Overall Assessment','0.722','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Pain Management','0.669','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Quietness','0.494','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243052','UVHE 3 EAST','Response of Hospital Staff','0.606','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Care Transitions','0.611','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Cleanliness','0.789','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Communication About Medicines','0.684','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Communication with Doctors','0.845','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Communication with Nurses','0.859','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Discharge Information','0.872','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Overall Assessment','0.801','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Pain Management','0.715','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Quietness','0.565','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243053','UVHE 3 WEST','Response of Hospital Staff','0.69','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Care Transitions','0.879','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Cleanliness','0.933','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Communication About Medicines','0.833','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Communication with Doctors','0.85','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Communication with Nurses','0.885','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Discharge Information','0.939','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Overall Assessment','0.867','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Pain Management','0.8','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Quietness','0.733','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'10243089','UVHE 3 NORTH','Response of Hospital Staff','0.871','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Care Transitions','0.591','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Cleanliness','0.751','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Communication About Medicines','0.654','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Communication with Doctors','0.822','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Communication with Nurses','0.84','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Discharge Information','0.89','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Overall Assessment','0.75','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Pain Management','0.676','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Medical Subspecialties',NULL,'All Units','All Units','Response of Hospital Staff','0.656','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Care Transitions','0.658','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Cleanliness','0.829','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Communication About Medicines','0.71','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Communication with Doctors','0.894','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Communication with Nurses','0.87','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Discharge Information','0.968','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Overall Assessment','0.842','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Pain Management','0.776','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Quietness','0.63','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'10243062','UVHE 6 EAST','Response of Hospital Staff','0.72','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Care Transitions','0.658','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Cleanliness','0.829','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Communication About Medicines','0.71','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Communication with Doctors','0.894','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Communication with Nurses','0.87','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Discharge Information','0.968','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Overall Assessment','0.842','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Pain Management','0.776','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Quietness','0.63','9/9/2019 16:41'),
('IN','2020','Musculoskeletal',NULL,'All Units','All Units','Response of Hospital Staff','0.72','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Care Transitions','0.653','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Cleanliness','0.864','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Communication About Medicines','0.722','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Communication with Doctors','0.878','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Communication with Nurses','0.955','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Discharge Information','0.939','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Overall Assessment','0.864','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Pain Management','0.699','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Quietness','0.671','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243041','UVHE NEUR ICU','Response of Hospital Staff','0.812','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Care Transitions','0.583','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Cleanliness','0.738','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Communication About Medicines','0.675','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Communication with Doctors','0.846','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Communication with Nurses','0.815','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Discharge Information','0.888','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Overall Assessment','0.74','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Pain Management','0.723','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Quietness','0.539','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243061','UVHE 6 CENTRAL','Response of Hospital Staff','0.688','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Care Transitions','0.648','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Cleanliness','0.827','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Communication About Medicines','0.705','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Communication with Doctors','0.882','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Communication with Nurses','0.878','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Discharge Information','0.935','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Overall Assessment','0.794','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Pain Management','0.765','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Quietness','0.5','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243063','UVHE 6 WEST','Response of Hospital Staff','0.704','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Care Transitions','0.631','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Cleanliness','0.866','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Communication About Medicines','0.697','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Communication with Doctors','0.877','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Communication with Nurses','0.865','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Discharge Information','0.932','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Overall Assessment','0.857','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Pain Management','0.75','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Quietness','0.635','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'10243092','UVHE 6 NORTH','Response of Hospital Staff','0.722','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Cleanliness','0.809','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Communication About Medicines','0.661','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Communication with Doctors','0.862','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Communication with Nurses','0.864','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Discharge Information','0.92','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Overall Assessment','0.785','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Pain Management','0.746','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Neurosciences and Behavioral Health',NULL,'All Units','All Units','Response of Hospital Staff','0.68','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Care Transitions','0.603','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Cleanliness','0.681','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Communication About Medicines','0.653','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Communication with Doctors','0.83','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Communication with Nurses','0.775','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Discharge Information','0.919','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Overall Assessment','0.758','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Pain Management','0.713','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Quietness','0.471','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243068','UVHE 8 WEST','Response of Hospital Staff','0.621','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Care Transitions','0.839','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Cleanliness','0.845','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Communication About Medicines','0.798','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Communication with Doctors','0.954','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Communication with Nurses','0.954','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Discharge Information','0.983','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Overall Assessment','0.886','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Pain Management','0.958','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Quietness','0.833','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243096','UVHE 8 WEST STEM CELL','Response of Hospital Staff','0.761','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Care Transitions','0.697','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Cleanliness','0.686','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Communication About Medicines','0.728','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Communication with Doctors','0.877','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Communication with Nurses','0.84','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Discharge Information','0.943','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Overall Assessment','0.8','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Pain Management','0.769','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Quietness','0.617','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'10243115','UVHE 8 NORTH ONC','Response of Hospital Staff','0.668','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Care Transitions','0.697','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Cleanliness','0.686','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Communication About Medicines','0.728','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Communication with Doctors','0.877','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Communication with Nurses','0.84','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Discharge Information','0.943','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Overall Assessment','0.8','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Pain Management','0.769','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Quietness','0.617','9/9/2019 16:41'),
('IN','2020','Oncology',NULL,'All Units','All Units','Response of Hospital Staff','0.668','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Cleanliness','0.795','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Communication About Medicines','0.679','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Communication with Doctors','0.866','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Communication with Nurses','0.849','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Discharge Information','0.925','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Overall Assessment','0.797','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Pain Management','0.74','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243047','UVHE SHORT STAY UNIT','Response of Hospital Staff','0.69','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Cleanliness','0.795','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Communication About Medicines','0.679','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Communication with Doctors','0.866','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Communication with Nurses','0.849','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Discharge Information','0.925','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Overall Assessment','0.797','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Pain Management','0.74','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243119','UVHE 5N SHORT STAY UNIT','Response of Hospital Staff','0.69','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Cleanliness','0.795','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Communication About Medicines','0.679','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Communication with Doctors','0.866','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Communication with Nurses','0.849','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Discharge Information','0.925','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Overall Assessment','0.797','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Pain Management','0.74','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Other',NULL,'10243120','UVHE 6E SHORT STAY UNIT','Response of Hospital Staff','0.69','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Cleanliness','0.795','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Communication About Medicines','0.679','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Communication with Doctors','0.866','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Communication with Nurses','0.849','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Discharge Information','0.925','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Overall Assessment','0.797','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Pain Management','0.74','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Other',NULL,'All Units','All Units','Response of Hospital Staff','0.69','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Care Transitions','0.602','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Cleanliness','0.77','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Communication About Medicines','0.67','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Communication with Doctors','0.842','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Communication with Nurses','0.814','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Discharge Information','0.923','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Overall Assessment','0.745','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Pain Management','0.69','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243046','UVHE SURG TRAM ICU','Response of Hospital Staff','0.619','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Care Transitions','0.606','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Cleanliness','0.735','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Communication About Medicines','0.671','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Communication with Doctors','0.851','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Communication with Nurses','0.808','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Discharge Information','0.923','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Overall Assessment','0.737','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Pain Management','0.685','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Quietness','0.482','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243060','UVHE 5 WEST','Response of Hospital Staff','0.6','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Cleanliness','0.845','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Communication About Medicines','0.674','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Communication with Doctors','0.835','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Communication with Nurses','0.865','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Discharge Information','0.946','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Overall Assessment','0.846','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Pain Management','0.729','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Quietness','0.713','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'10243090','UVHE 5 NORTH','Response of Hospital Staff','0.74','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Care Transitions','0.602','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Cleanliness','0.77','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Communication About Medicines','0.67','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Communication with Doctors','0.842','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Communication with Nurses','0.814','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Discharge Information','0.923','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Overall Assessment','0.745','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Pain Management','0.69','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Surgical Subspecialties',NULL,'All Units','All Units','Response of Hospital Staff','0.619','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Care Transitions','0.676','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Cleanliness','0.81','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Communication About Medicines','0.645','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Communication with Doctors','0.877','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Communication with Nurses','0.822','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Discharge Information','0.933','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Overall Assessment','0.798','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Pain Management','0.746','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'10243110','UVHE 4 CENTRAL TXP','Response of Hospital Staff','0.68','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Care Transitions','0.676','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Cleanliness','0.81','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Communication About Medicines','0.645','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Communication with Doctors','0.877','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Communication with Nurses','0.822','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Discharge Information','0.933','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Overall Assessment','0.798','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Pain Management','0.746','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Quietness','0.522','9/9/2019 16:41'),
('IN','2020','Transplant',NULL,'All Units','All Units','Response of Hospital Staff','0.68','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Cleanliness','0.741','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Communication About Medicines','0.709','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Communication with Doctors','0.901','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Communication with Nurses','0.864','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Discharge Information','0.923','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Overall Assessment','0.745','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Pain Management','0.746','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Quietness','0.718','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243066','UVHE 8 CENTRAL OB','Response of Hospital Staff','0.784','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Care Transitions','0.65','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Cleanliness','0.762','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Communication About Medicines','0.722','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Communication with Doctors','0.877','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Communication with Nurses','0.865','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Discharge Information','0.923','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Overall Assessment','0.765','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Pain Management','0.746','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Quietness','0.619','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243094','UVHE 8 NORTH','Response of Hospital Staff','0.783','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Care Transitions','0.627','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Cleanliness','0.694','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Communication About Medicines','0.717','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Communication with Doctors','0.877','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Communication with Nurses','0.865','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Discharge Information','0.923','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Overall Assessment','0.814','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Pain Management','0.875','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Quietness','0.605','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'10243113','UVHE 7NOB','Response of Hospital Staff','0.767','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Care Transitions','0.625','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Cleanliness','0.741','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Communication About Medicines','0.722','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Communication with Doctors','0.88','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Communication with Nurses','0.865','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Discharge Information','0.923','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Overall Assessment','0.771','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Pain Management','0.787','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Quietness','0.619','9/9/2019 16:41'),
('IN','2020','Womens and Childrens',NULL,'All Units','All Units','Response of Hospital Staff','0.784','9/9/2019 16:41')
;

DECLARE @HCAHPS_Goals TABLE
(
	[SVC_CDE] [VARCHAR](2) NULL,
	[GOAL_YR] [INT] NULL,
	[SERVICE_LINE] [VARCHAR](150) NULL,
	[UNIT] [VARCHAR](150) NULL,
	[EPIC_DEPARTMENT_ID] [VARCHAR](10) NULL,
	[EPIC_DEPARTMENT_NAME] [VARCHAR](30) NULL,
	[DOMAIN] [VARCHAR](150) NULL,
	[GOAL] [DECIMAL](4, 3) NULL,
	[Load_Dtm] [SMALLDATETIME] NULL
);

INSERT INTO @HCAHPS_Goals
(
    SVC_CDE,
    GOAL_YR,
    SERVICE_LINE,
    UNIT,
    EPIC_DEPARTMENT_ID,
    EPIC_DEPARTMENT_NAME,
    DOMAIN,
    GOAL,
    Load_Dtm
)
SELECT *
FROM @HCAHPS_Goals_FY18
UNION ALL
SELECT *
FROM @HCAHPS_Goals_FY19
UNION ALL
SELECT *
FROM @HCAHPS_Goals_FY20
END

--SELECT *
--FROM @HCAHPS_Goals
--ORDER BY GOAL_YR
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
/*
	,Resp.sk_Dim_Clrt_DEPt
	--,bcsm.[Epic DEPARTMENT_ID] AS bcsm_Epic_DEPARTMENT_ID
	--,dep1.Clrt_DEPt_Nme AS bcsm_Clrt_DEPt_Nme
	--,dep2.DEPARTMENT_ID AS dep_DEPARTMENT_ID
	--,dep2.Clrt_DEPt_Nme AS dep_Clrt_DEPt_Nme
	,dep.DEPARTMENT_ID AS dep_DEPARTMENT_ID
	,dep.Clrt_DEPt_Nme AS dep_Clrt_DEPt_Nme
	,mdm.service_line AS mdm_Service_Line*/
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

SELECT [all].FY,
       [all].resp_UNIT,
       [all].trnsf_UNIT,
       [all].UNIT,
       [all].trnsf_Service_Line,
       [all].mdm_Service_Line,
       [all].sk_Dim_Clrt_DEPt,
       [all].dep_DEPARTMENT_ID,
       [all].dep_Clrt_DEPt_Nme,
       [all].Domain_Goals,
       [all].Domain_Count,
       [all].GOAL
FROM
(
SELECT resp.FY,
       resp.resp_UNIT,
       resp.trnsf_UNIT,
       resp.UNIT,
       resp.trnsf_Service_Line,
       resp.mdm_Service_Line,
       resp.sk_Dim_Clrt_DEPt,
       resp.dep_DEPARTMENT_ID,
       resp.dep_Clrt_DEPt_Nme,
       resp.Domain_Goals,
       resp.Domain_Count,
	   goal.GOAL
FROM
	(
	SELECT FY,
           resp_UNIT,
           trnsf_UNIT,
           UNIT,
           trnsf_Service_Line,
           mdm_Service_Line,
           sk_Dim_Clrt_DEPt,
           dep_DEPARTMENT_ID,
           dep_Clrt_DEPt_Nme,
           Domain_Goals,
           Domain_Count
	FROM #surveys_ip_check
	) resp
	LEFT OUTER JOIN
	(
	SELECT GOAL_YR
	     , UNIT
	     , DOMAIN
		 , GOAL
	FROM @HCAHPS_Goals
	) goal
	ON goal.GOAL_YR = resp.FY
	AND goal.UNIT = resp.UNIT
	AND goal.DOMAIN = resp.Domain_Goals
	WHERE resp.FY = 2018
	AND goal.UNIT IS NOT NULL
UNION ALL
SELECT goals.FY,
       goals.resp_UNIT,
       goals.trnsf_UNIT,
       goals.UNIT,
       goals.trnsf_Service_Line,
       goals.mdm_Service_Line,
       goals.sk_Dim_Clrt_DEPt,
       goals.dep_DEPARTMENT_ID,
       goals.dep_Clrt_DEPt_Nme,
       goals.Domain_Goals,
       goals.Domain_Count,
       goal.GOAL
FROM
(
SELECT resp.FY,
       resp.resp_UNIT,
       resp.trnsf_UNIT,
       resp.UNIT,
       resp.trnsf_Service_Line,
       resp.mdm_Service_Line,
       resp.sk_Dim_Clrt_DEPt,
       resp.dep_DEPARTMENT_ID,
       resp.dep_Clrt_DEPt_Nme,
       resp.Domain_Goals,
       resp.Domain_Count,
	   goal.GOAL
FROM
	(
	SELECT FY,
           resp_UNIT,
           trnsf_UNIT,
           UNIT,
           trnsf_Service_Line,
           mdm_Service_Line,
           sk_Dim_Clrt_DEPt,
           dep_DEPARTMENT_ID,
           dep_Clrt_DEPt_Nme,
           Domain_Goals,
           Domain_Count
	FROM #surveys_ip_check
	) resp
	LEFT OUTER JOIN
	(
	SELECT GOAL_YR
	     , UNIT
	     , DOMAIN
		 , GOAL
	FROM @HCAHPS_Goals
	) goal
	ON goal.GOAL_YR = resp.FY
	AND goal.UNIT = resp.UNIT
	AND goal.DOMAIN = resp.Domain_Goals
	WHERE resp.FY = 2018
	AND goal.UNIT IS NULL
) goals
LEFT OUTER JOIN
(
SELECT GOAL_YR
     , SERVICE_LINE
     , UNIT
	 , DOMAIN
	 , GOAL
FROM @HCAHPS_Goals
WHERE UNIT = 'All Units'
) goal
ON goal.GOAL_YR = goals.FY
AND goal.SERVICE_LINE = goals.mdm_Service_Line
AND goal.DOMAIN = goals.Domain_Goals
) [all]
ORDER BY  GOAL
	    , FY
		, trnsf_Service_Line
		, UNIT
		, dep_Clrt_DEPt_Nme
		, Domain_Goals
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


