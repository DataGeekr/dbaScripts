-- Random date
SELECT CONVERT(VARCHAR(10), GETDATE() - (CheckSUM(NEWID ()) / 1000000), 112)

-- First Day of Year
SELECT DATEADD(yy, DATEDIFF(yy, 0, GETDATE()), 0)

-- Last Day of Year
SELECT dateadd(yy, datediff(yy,-1, getdate()), -1)

-- First Day of Current Month
SELECT CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(@mydate)-1),@mydate),101) AS Date_Value, 'First Day of Current Month' 

-- Last Day of Previous Month
SELECT DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE()),0)) AS LastDay_PreviousMonth

-- Last Day of Current Month
SELECT DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0)) AS LastDay_CurrentMonth

-- Last Day of Next Month
SELECT DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+2,0)) AS LastDay_NextMonth