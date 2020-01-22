USE [DS_HSDM_App_Dev]
GO

-- ===========================================
-- Create table Rptg.HCAHPS_Goals_obs
-- ===========================================
IF EXISTS (SELECT TABLE_NAME 
	       FROM   INFORMATION_SCHEMA.TABLES
	       WHERE  TABLE_SCHEMA = N'Rptg' AND
	              TABLE_NAME = N'HCAHPS_Goals_obs')
   DROP TABLE [Rptg].[HCAHPS_Goals_obs]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Rptg].[HCAHPS_Goals_obs](
	[SVC_CDE] [VARCHAR](2) NULL,
	[GOAL_YR] [INT] NULL,
	[SERVICE_LINE] [VARCHAR](150) NULL,
	[UNIT] [VARCHAR](150) NULL,
	[DOMAIN] [VARCHAR](150) NULL,
	[GOAL] [NUMERIC](4, 3) NULL,
	[Load_Dtm] [SMALLDATETIME] NULL
) ON [PRIMARY]
GO

GRANT DELETE, INSERT, SELECT, UPDATE ON [Rptg].[HCAHPS_Goals_obs] TO [HSCDOM\Decision Support]
GO


