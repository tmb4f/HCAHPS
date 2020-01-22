USE [DS_HSDM_App_Dev]
GO

-- ===========================================
-- Create table Rptg.HCAHPS_Goals
-- ===========================================
IF EXISTS (SELECT TABLE_NAME 
	       FROM   INFORMATION_SCHEMA.TABLES
	       WHERE  TABLE_SCHEMA = N'Rptg' AND
	              TABLE_NAME = N'HCAHPS_Goals')
   DROP TABLE [Rptg].[HCAHPS_Goals]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Rptg].[HCAHPS_Goals](
	[SVC_CDE] [varchar](2) NULL,
	[GOAL_FISCAL_YR] [int] NULL,
	[SERVICE_LINE] [varchar](150) NULL,
	[UNIT] [varchar](150) NULL,
	[EPIC_DEPARTMENT_ID] [varchar](255) NULL,
	[EPIC_DEPARTMENT_NAME] [varchar](255) NULL,
	[DOMAIN] [varchar](150) NULL,
	[GOAL] [decimal](4, 3) NULL,
	[Load_Dtm] [smalldatetime] NULL
) ON [PRIMARY]
GO

GRANT DELETE, INSERT, SELECT, UPDATE ON [Rptg].[HCAHPS_Goals] TO [HSCDOM\Decision Support]
GO


