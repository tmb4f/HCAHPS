USE DS_HSDW_App

IF OBJECT_ID('tempdb..#goal ') IS NOT NULL
DROP TABLE #goal

IF OBJECT_ID('tempdb..#attr ') IS NOT NULL
DROP TABLE #attr

IF OBJECT_ID('tempdb..#hcahps ') IS NOT NULL
DROP TABLE #hcahps

SELECT [DOMAIN]
	   ,ROW_NUMBER() OVER (ORDER BY goal.DOMAIN) AS INDX
INTO #goal
  FROM
  (
  SELECT DISTINCT
	DOMAIN
  FROM [DS_HSDW_App].[Rptg].[PX_Goal_Setting]
  WHERE Service = 'HCAHPS'
  ) goal
  ORDER BY goal.DOMAIN
/*
SELECT DISTINCT
       [DOMAIN]
	   ,ROW_NUMBER() OVER (ORDER BY attr.DOMAIN) AS INDX
INTO #attr
  FROM
  (
  SELECT DISTINCT
	DOMAIN
  FROM [DS_HSDW_App].[Rptg].[PG_Extnd_Attr]
  WHERE SVC_CODE = 'PD'
  ) attr
  ORDER BY attr.DOMAIN

  SELECT goal.DOMAIN AS GOAL_DOMAIN, attr.DOMAIN AS ATTR_DOMAIN
  FROM #goal goal
  INNER JOIN #attr attr
  ON attr.INDX = goal.INDX
  ORDER BY goal.DOMAIN
*/
SELECT DISTINCT
       [DOMAIN]
	   ,ROW_NUMBER() OVER (ORDER BY hcahps.DOMAIN) AS INDX
INTO #hcahps
  FROM
  (
  SELECT DISTINCT
	DOMAIN
  FROM [DS_HSDW_App].[Rptg].[HCAHPS_Goals]
  WHERE SVC_CDE = 'IN'
  ) hcahps
  ORDER BY hcahps.DOMAIN

  SELECT goal.DOMAIN AS GOAL_DOMAIN, hcahps.DOMAIN AS HCAHPS_DOMAIN
  FROM #goal goal
  LEFT OUTER JOIN #hcahps hcahps
  ON hcahps.INDX = goal.INDX
  ORDER BY goal.DOMAIN

