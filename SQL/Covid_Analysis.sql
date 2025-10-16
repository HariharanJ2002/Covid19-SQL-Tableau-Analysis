/*==============================================================================
  PROJECT: COVID-19 Data Analysis (SQL + Tableau)
  REPO:    covid19-sql-tableau-analysis
  PURPOSE: Core queries used for exploration and the Tableau dashboard
  NOTE:    Logic follows author's original analysis; comments added for clarity
==============================================================================*/

-- -----------------------------------------------------------------------------
-- A) COUNTRY-LEVEL ANALYSIS
-- -----------------------------------------------------------------------------

-- A1) Case Fatality Rate (CFR) over time – India
SELECT
    Location,
    [date],
    total_cases,
    total_deaths,
    (total_deaths / total_cases) * 100 AS DeathPercentage
FROM [Portfolio Project]..CovidDeaths
WHERE Location LIKE 'india'
ORDER BY Location, [date];

-- A2) % of population infected – India
SELECT
    Location,
    [date],
    population,
    total_cases,
    (total_cases / population) * 100 AS PositivePercentage
FROM [Portfolio Project]..CovidDeaths
WHERE Location LIKE 'india'
ORDER BY Location, [date];

-- -----------------------------------------------------------------------------
-- B) RANKINGS / EXTREMES
-- -----------------------------------------------------------------------------

-- B1) Highest infection % by country (peak total_cases vs population)
SELECT
    Location,
    population,
    MAX(total_cases) AS InfectedCount,
    MAX((total_cases / population)) * 100 AS MaxPositivePercentage
FROM [Portfolio Project]..CovidDeaths
GROUP BY Location, population
ORDER BY MaxPositivePercentage DESC;

-- B2) Countries with highest death counts (exclude aggregate rows)
SELECT
    Location,
    MAX(CAST(total_deaths AS int)) AS DeathCount
FROM [Portfolio Project]..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY Location
ORDER BY DeathCount DESC;

-- -----------------------------------------------------------------------------
-- C) CONTINENT / AGGREGATE ROWS
-- -----------------------------------------------------------------------------

-- C1) “Continents/Regions” rows (continent is NULL)
SELECT
    Location,
    MAX(CAST(total_deaths AS int)) AS DeathCount
FROM [Portfolio Project]..CovidDeaths
WHERE continent IS NULL
GROUP BY Location
ORDER BY DeathCount DESC;

-- -----------------------------------------------------------------------------
-- D) GLOBAL TIME SERIES
-- -----------------------------------------------------------------------------

-- D1) Global daily totals and daily CFR
SELECT
    [date],
    SUM(new_cases) AS total_cases,
    SUM(CAST(new_deaths AS int)) AS total_deaths,
    SUM(CAST(new_deaths AS int)) * 100.0 / SUM(NULLIF(new_cases, 0)) AS TotalDeathPercentage
FROM [Portfolio Project]..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY [date]
ORDER BY [date];

-- -----------------------------------------------------------------------------
-- E) VACCINATION ROLLOUT (WINDOW FUNCTION)
-- -----------------------------------------------------------------------------

-- E1) Rolling (cumulative) vaccinations by country
SELECT
    dea.continent,
    dea.[date],
    dea.location,
    dea.population,
    vac.new_vaccinations,
    SUM(CONVERT(int, vac.new_vaccinations))
        OVER (PARTITION BY dea.location ORDER BY dea.location, dea.[date]) AS RollingCount
FROM [Portfolio Project]..CovidDeaths AS dea
JOIN [Portfolio Project]..CovidVaccinations AS vac
  ON dea.location = vac.location
 AND dea.[date]   = vac.[date]
WHERE dea.continent IS NOT NULL
ORDER BY dea.location, dea.[date];

-- -----------------------------------------------------------------------------
-- F) TEMP TABLE: % OF POPULATION VACCINATED
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS #PercentPopulationVaccinated;
CREATE TABLE #PercentPopulationVaccinated
(
    continent        nvarchar(255),
    [date]           datetime,
    location         nvarchar(255),
    population       numeric,
    new_vaccinations numeric,
    RollingCount     numeric
);

INSERT INTO #PercentPopulationVaccinated
SELECT
    dea.continent,
    dea.[date],
    dea.location,
    dea.population,
    vac.new_vaccinations,
    SUM(CONVERT(int, vac.new_vaccinations))
        OVER (PARTITION BY dea.location ORDER BY dea.location, dea.[date]) AS RollingCount
FROM [Portfolio Project]..CovidDeaths AS dea
JOIN [Portfolio Project]..CovidVaccinations AS vac
  ON dea.location = vac.location
 AND dea.[date]   = vac.[date]
WHERE dea.continent IS NOT NULL;

-- F1) Percent of population vaccinated (derived from temp table)
SELECT
    *,
    (RollingCount / population) * 100 AS PopvsVac
FROM #PercentPopulationVaccinated;

-- -----------------------------------------------------------------------------
-- G) VIEW: REUSABLE FOR TABLEAU
-- -----------------------------------------------------------------------------

CREATE VIEW PercentPopulationVaccinated AS
SELECT
    dea.continent,
    dea.[date],
    dea.location,
    dea.population,
    vac.new_vaccinations,
    SUM(CONVERT(int, vac.new_vaccinations))
        OVER (PARTITION BY dea.location ORDER BY dea.location, dea.[date]) AS RollingCount
FROM [Portfolio Project]..CovidDeaths AS dea
JOIN [Portfolio Project]..CovidVaccinations AS vac
  ON dea.location = vac.location
 AND dea.[date]   = vac.[date]
WHERE dea.continent IS NOT NULL;

-- -----------------------------------------------------------------------------
-- H) TABLEAU: KPI / EXPORT QUERIES (as used in dashboard)
-- -----------------------------------------------------------------------------

-- H1) Global totals (KPI)
SELECT
    SUM(new_cases) AS total_cases,
    SUM(CAST(new_deaths AS int)) AS total_deaths,
    SUM(CAST(new_deaths AS int)) * 100.0 / SUM(NULLIF(new_cases, 0)) AS DeathPercentage
FROM [Portfolio Project]..CovidDeaths
WHERE continent IS NOT NULL;

-- H2) Regional totals (exclude World/EU/International for consistency)
SELECT
    location,
    SUM(CAST(new_deaths AS int)) AS TotalDeathCount
FROM [Portfolio Project]..CovidDeaths
WHERE continent IS NULL
  AND location NOT IN ('World', 'European Union', 'International')
GROUP BY location
ORDER BY TotalDeathCount DESC;

-- H3) Highest infection burden % by country (map view)
SELECT
    Location,
    Population,
    MAX(total_cases) AS HighestInfectionCount,
    MAX((total_cases / population)) * 100 AS PercentPopulationInfected
FROM [Portfolio Project]..CovidDeaths
GROUP BY Location, Population
ORDER BY PercentPopulationInfected DESC;

-- H4) Daily max infection % per country (drilldown)
SELECT
    Location,
    Population,
    [date],
    MAX(total_cases) AS HighestInfectionCount,
    MAX((total_cases / population)) * 100 AS PercentPopulationInfected
FROM [Portfolio Project]..CovidDeaths
GROUP BY Location, Population, [date]
ORDER BY PercentPopulationInfected DESC;

