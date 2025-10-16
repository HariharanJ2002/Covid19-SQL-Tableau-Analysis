/* ==============================================================
   BONUS INSIGHTS – adds depth beyond the standard tutorial
   Tables: [Portfolio Project]..CovidDeaths, ..CovidVaccinations
   DB: SQL Server
=================================================================*/

-- 1) Top countries where infection % peaked high but CFR stayed low (<1%)
WITH country_stats AS (
  SELECT
    Location,
    MAX(total_cases * 100.0 / NULLIF(population,0)) AS MaxInfectionPct,
    MAX(CAST(total_deaths AS float)) * 100.0 / NULLIF(MAX(CAST(total_cases AS float)),0) AS OverallCFRPct
  FROM [Portfolio Project]..CovidDeaths
  WHERE continent IS NOT NULL
  GROUP BY Location
)
SELECT TOP 20 Location, MaxInfectionPct, OverallCFRPct
FROM country_stats
WHERE OverallCFRPct < 1
ORDER BY MaxInfectionPct DESC, OverallCFRPct ASC;

-- 2) Vaccination crossover: CFR before vs after 50% population vaccinated
WITH v AS (
  SELECT
    d.location, d.[date], d.continent, d.total_cases, d.total_deaths,
    SUM(CONVERT(bigint, vac.new_vaccinations))
      OVER (PARTITION BY d.location ORDER BY d.location, d.[date]) AS cum_vax,
    d.population
  FROM [Portfolio Project]..CovidDeaths d
  JOIN [Portfolio Project]..CovidVaccinations vac
    ON d.location = vac.location AND d.[date] = vac.[date]
  WHERE d.continent IS NOT NULL
),
joined AS (
  SELECT
    location, continent, [date],
    (total_deaths * 100.0 / NULLIF(total_cases,0)) AS CFRpct,
    cum_vax * 100.0 / NULLIF(population,0) AS VaxPct
  FROM v
)
SELECT TOP 50
  location, continent,
  AVG(CASE WHEN VaxPct < 50 THEN CFRpct END)  AS AvgCFR_Before50,
  AVG(CASE WHEN VaxPct >= 50 THEN CFRpct END) AS AvgCFR_After50,
  (AVG(CASE WHEN VaxPct >= 50 THEN CFRpct END)
   - AVG(CASE WHEN VaxPct < 50 THEN CFRpct END)) AS CFR_Change_pp
FROM joined
GROUP BY location, continent
HAVING COUNT(CASE WHEN VaxPct < 50 THEN 1 END) >= 30
   AND COUNT(CASE WHEN VaxPct >= 50 THEN 1 END) >= 30
ORDER BY CFR_Change_pp;   -- negative = improvement after 50% vax

-- 3) “Wave detector”: days with unusually high new cases vs 14-day average
WITH daily AS (
  SELECT
    location, [date], new_cases,
    AVG(CAST(new_cases AS float)) OVER (
      PARTITION BY location
      ORDER BY [date]
      ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING
    ) AS avg_14d_prev
  FROM [Portfolio Project]..CovidDeaths
  WHERE continent IS NOT NULL
)
SELECT location, [date], new_cases, avg_14d_prev,
       CASE WHEN new_cases > 1.5 * avg_14d_prev THEN 1 ELSE 0 END AS WaveSpikeFlag
FROM daily
WHERE avg_14d_prev IS NOT NULL
ORDER BY location, [date];

-- 4) Country league table: vaccination % today
WITH last_day AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY location ORDER BY [date] DESC) AS rn
  FROM [Portfolio Project]..CovidDeaths
)
SELECT
  d.location, d.population,
  SUM(CONVERT(bigint, v.new_vaccinations)) OVER (
    PARTITION BY d.location ORDER BY d.[date]
    ROWS UNBOUNDED PRECEDING
  ) * 100.0 / NULLIF(d.population,0) AS VaccinatedPct_est
FROM last_day d
JOIN [Portfolio Project]..CovidVaccinations v
  ON d.location = v.location AND d.[date] = v.[date]
WHERE d.rn = 1
ORDER BY VaccinatedPct_est DESC;
