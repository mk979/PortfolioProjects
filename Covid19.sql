SELECT *
FROM portfolioproject.coviddeaths;
-- WHERE TRIM(continent) = '';

SELECT *
FROM portfolioproject.covidvaccinations;

-- Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid per country

SELECT location, date, total_cases, new_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM portfolioproject.coviddeaths
WHERE location LIKE '%africa%' 
ORDER BY 1,2;

-- Total Cases vs Population
-- Percentage that got covid

SELECT location, date, total_cases, new_cases, population, (total_cases/population)*100 AS PopulationPercentageInfected
FROM portfolioproject.coviddeaths
WHERE location LIKE '%africa%' 
ORDER BY 1,2 ;

-- Looking at countries with Highest Infection Rate compared to Population

SELECT location, MAX(total_cases) AS HighestInfectionCount, population, MAX((total_cases/population))*100 AS PopulationPercentageInfected
FROM portfolioproject.coviddeaths
-- WHERE location like '%africa%' 
GROUP BY location, population
ORDER BY PopulationPercentageInfected DESC;

-- Showing countries with Highest death count per Population
-- Converted the ncharvar Total deaths and total cases  to Float using Command ALTER TABLE CovidDeaths ALTER COLUMN total_Cases  FLOAT

SELECT location, MAX(cast(total_deaths AS FLOAT)) as TotalDeathCount
FROM portfolioproject.coviddeaths
-- WHERE location like '%africa%' 
WHERE TRIM(continent) != ''        -- or  WHERE (location NOT LIKE 'africa') AND (location NOT LIKE '%europe%') AND (location NOT LIKE '%america%') AND (location NOT LIKE '%oceania%')
GROUP BY location
ORDER BY TotalDeathCount DESC;

-- Break Things by the continent
-- Showing continent with the highest death count per population

SELECT location, MAX(cast(total_deaths AS FLOAT)) AS TotalDeathCount
FROM portfolioproject.coviddeaths
WHERE TRIM(continent) = ''
GROUP BY location
ORDER BY TotalDeathCount DESC;

-- Global Numbers 

SELECT date, SUM(new_cases) AS total_cases, SUM(CAST(new_deaths AS FLOAT)) AS total_deaths, SUM(CAST(new_deaths AS FLOAT))/SUM(new_cases)*100 AS DeathPercentage 
FROM portfolioproject.coviddeaths
WHERE TRIM(continent) != ''
GROUP BY date
ORDER BY 1,2;

-- Total Cases Globally(sum)

SELECT SUM(new_cases) AS total_cases, SUM(CAST(new_deaths AS FLOAT)) AS total_deaths, SUM(CAST(new_deaths AS FLOAT))/SUM(new_cases)*100 AS DeathPercentage 
FROM portfolioproject.coviddeaths
WHERE TRIM(continent) != ''
-- GROUP BY date
ORDER BY 1,2;


-- Join the tables

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations_smoothed, 
SUM(CAST(vac.new_vaccinations_smoothed AS FLOAT)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS rollingPeopleVaccinated
FROM portfolioproject.coviddeaths dea
JOIN portfolioproject.covidvaccinations vac
	ON dea.location = vac.location
    AND dea.date = vac.date
WHERE TRIM(dea.continent) != ''
order by 2,3;


-- Use CTE

WITH PopVsVac(continent, location, date, population, new_vaccinations_smoothed, rollingPeopleVaccinated)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations_smoothed, 
SUM(CAST(vac.new_vaccinations_smoothed AS FLOAT)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS rollingPeopleVaccinated
FROM portfolioproject.coviddeaths dea
JOIN portfolioproject.covidvaccinations vac
	ON dea.location = vac.location
    AND dea.date = vac.date
WHERE TRIM(dea.continent) != ''   -- Ensure continent is not empty or whitespace
-- order by 2,3
)
SELECT *, (rollingPeopleVaccinated/Population)*100
FROM PopVsVac;

DESCRIBE PercentPopulationVaccinated;

ALTER TABLE PercentPopulationVaccinated MODIFY COLUMN Date DATE;


-- Temp Table

CREATE TEMPORARY TABLE PercentPopulationVaccinated
(
    Continent VARCHAR(255),
    Location VARCHAR(255),
    Date DATE,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);


INSERT INTO PercentPopulationVaccinated
SELECT dea.continent, dea.location, STR_TO_DATE(dea.date, '%d/%m/%Y') AS date, dea.population, COALESCE(CAST(vac.new_vaccinations_smoothed AS FLOAT), 0) AS New_vaccinations,
    SUM(COALESCE(CAST(vac.new_vaccinations_smoothed AS FLOAT), 0)) 
        OVER (PARTITION BY dea.location ORDER BY STR_TO_DATE(dea.date, '%d/%m/%Y')) AS rollingPeopleVaccinated
FROM portfolioproject.coviddeaths dea
JOIN portfolioproject.covidvaccinations vac
	ON dea.location = vac.location
    AND STR_TO_DATE(dea.date, '%d/%m/%Y') = STR_TO_DATE(vac.date, '%d/%m/%Y')
WHERE TRIM(dea.continent) != '';   -- Ensure continent is not empty or whitespace
-- order by 2,3

-- Identify Problematic Data: Run a query to check for rows where vac.new_vaccinations_smoothed contains invalid values (empty strings, nulls, or non-numeric values):

SELECT vac.new_vaccinations_smoothed
FROM portfolioproject.covidvaccinations vac
WHERE vac.new_vaccinations_smoothed = ''
   OR vac.new_vaccinations_smoothed IS NULL
   OR NOT vac.new_vaccinations_smoothed REGEXP '^[0-9]+(\\.[0-9]*)?$'
LIMIT 10;

-- Handle Invalid Values: Use COALESCE to replace invalid or null values with 0 (or another default value) in your query:
-- COALESCE(vac.new_vaccinations_smoothed, '0');

SELECT *, (RollingPeopleVaccinated/Population)*100
FROM PercentPopulationvaccinated;


-- Creating View to store data for later visualizations 

CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, STR_TO_DATE(dea.date, '%d/%m/%Y') AS date, dea.population, COALESCE(CAST(vac.new_vaccinations_smoothed AS FLOAT), 0) AS New_vaccinations,
    SUM(COALESCE(CAST(vac.new_vaccinations_smoothed AS FLOAT), 0)) 
        OVER (PARTITION BY dea.location ORDER BY STR_TO_DATE(dea.date, '%d/%m/%Y')) AS rollingPeopleVaccinated
FROM portfolioproject.coviddeaths dea
JOIN portfolioproject.covidvaccinations vac
	ON dea.location = vac.location
    AND STR_TO_DATE(dea.date, '%d/%m/%Y') = STR_TO_DATE(vac.date, '%d/%m/%Y')
WHERE TRIM(dea.continent) != ''   -- Ensure continent is not empty or whitespace
-- order by 2,3;




