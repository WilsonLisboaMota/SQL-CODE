/*
Covid 19 Data Exploration 

List of Skills: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types, etc.

*/


-- Understand where the virus first appeared in the logs
-- On January 22, 2020, the countries that were spreading the virus were South Korea, the United States, China, Thailand, Japan and Taiwan.
Select	 location,
	 min(date) as FirstCaseDetected
from	 CovidPortfolioProject..CovidDeaths
where	 total_cases is not null
and	 continent is not null
-- The reason I added the Continent filter is because of the data structure and I will add it here to most queries
group by location
order by 2 asc


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Total Cases vs Total Deaths
-- This results shows the likelihood of dying if you contract covid in Switzerland
Select	location,
	date,
	total_cases,
	total_deaths,
	(total_deaths/total_cases)*100 as Death_Rate
from	CovidPortfolioProject..CovidDeaths
where	continent is not null
and	location = 'Switzerland'
order by 1,2


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Total Cases vs Total Population
-- This results shows what percentage of population contracted covid in Switzerland
Select	location,
	date,
	total_cases,
	population,
	(total_cases/population)*100 as Infection_Rate
from	CovidPortfolioProject..CovidDeaths
where	location = 'Switzerland'
and	continent is not null
order by 2,Infection_Rate asc


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Looking at Countries with Highest Infection Rate Compared to Population
-- At the moment, Switzerland has an infection rate of 9.44% and is ranked 32nd on the list.
Select	 location,
	 MAX(total_cases) as HighestInfectionCount,
	 population,
	 (MAX(total_cases/population))*100 as Infection_Rate
from	 CovidPortfolioProject..CovidDeaths
where	 continent is not null
Group by location, population
order by Infection_Rate desc


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Looking at Countries with Highest Death Count per Population
-- At the moment, Switzerland has an infection rate of 9.44% and is ranked 32nd on the list.
Select	 location,
	 MAX(CAST(total_deaths as int)) as HighestDeathCount
from	 CovidPortfolioProject..CovidDeaths
where	 continent is not null
group by location
order by HighestDeathCount desc
 

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Looking at the final result of total cases, total deaths and the death rate around the world
-- As for now, there are 228063616 cases, 4683020 deaths and a death rate slightly above 2%
Select	sum(new_cases) as Total_Cases,
	sum(cast(new_deaths as int)) as Total_Deaths,
	(sum(cast(new_deaths as int))/sum(new_cases))*100 as Death_Rate
from	CovidPortfolioProject..CovidDeaths
where	continent is not null
order by 1,2


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Use of CTE
-- 9.4% of the Swiss population got infected, 12.8% of the Swiss population died by Covid and 52% of the Swiss population is fully vaccinated
With PopInfecvsVac (Location,
		    date,
		    population,
		    Total_Cases,
		    Infected_Population_Rate,
		    Death_Rate,
		    Percnt_of_Pop_Death,
		    Total_Vac
		   )
as
(
Select  CD.location,
	CD.date,
	CD.population,
	sum(CD.new_cases) 
		over (
			partition by 	CD.location 
			order by	CD.location, CD.date) as Total_Cases,
	cast(CD.total_cases/CD.population*100 as decimal(3,1)) as Infected_Population_Rate,
	cast(cast(CD.total_deaths as decimal(20,0))/cast(total_cases as int)*100 as decimal(3,2)) as Prob_of_Death_by_Covid,
	cast(cast(CD.total_deaths as decimal(20,0))/CD.population*100 as decimal(3,2)) as Percnt_of_Pop_Death,
	CV.people_fully_vaccinated as Total_Vac
From	CovidPortfolioProject..CovidDeaths as CD
join	CovidPortfolioProject..CovidVaccination as CV
  on	CD.date = CV.date
  and	CD.location = CV.location
Where	CD.location = 'Switzerland'
)

Select	Location,
	date,
	Total_Cases,
	Infected_Population_Rate,
	Death_Rate,
	Percnt_of_Pop_Death,
	Total_Vac,
	Total_Vac/(cast(population as decimal(20,0)))*100 as Vac_Rate
from	PopInfecvsVac
order by 1,2


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Temp table (same table as CTE above, but in a different way)
Drop table if exists #PercentPopulationVaccinated
GO

Create Table #PercentPopulationVaccinated (
	Location nvarchar(255),
	date datetime,
	population decimal (20,0),
	Total_Cases int,
	Infected_Population_Rate decimal(3,2),
	Prob_of_Death_by_Covid decimal(3,2),
	Percnt_of_Pop_Death decimal(3,2),
	Total_Vac int
	)
Insert into #PercentPopulationVaccinated 
Select  CD.location,
	CD.date,
	CD.population,
	sum(CD.new_cases) 
		over (
			partition by 	CD.location 
			order by	CD.location, CD.date) as Total_Cases,
	cast(CD.total_cases/CD.population*100 as decimal(3,1)) as Infected_Population_Rate,
	cast(cast(CD.total_deaths as decimal(20,0))/cast(total_cases as int)*100 as decimal(3,2)) as Prob_of_Death_by_Covid,
	cast(cast(CD.total_deaths as decimal(20,0))/CD.population*100 as decimal(3,2)) as Percnt_of_Pop_Death,
	CV.people_fully_vaccinated as Total_Vac
From	CovidPortfolioProject..CovidDeaths as CD
join	CovidPortfolioProject..CovidVaccination as CV
  on	CD.date = CV.date
  and	CD.location = CV.location
Where	CD.location = 'Switzerland'

Select	Location,
	date,
	Total_Cases,
	Infected_Population_Rate,
	Prob_of_Death_by_Covid,
	Percnt_of_Pop_Death,
	Total_Vac,
	Total_Vac/(cast(population as decimal(20,0)))*100 as Vac_Rate
from	#PercentPopulationVaccinated
order by 1,2


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Creating View with data cleansing to store data for later visualizations
Drop View if exists view_PercentPopulationVaccinated
GO

Use CovidPortfolioProject
GO

Create View view_PercentPopulationVaccinated as

With PopInfecvsVac (Continent,
		    Location,
		    date,
		    population,
		    Total_Cases,
		    Total_Deaths,
		    Infection_Rate,
		    Death_Rate,
		    Population_Death_Perct,
		    People_Vaccinated
		   )
as
(
Select  CD.continent,
	CD.location,
	CD.date,
	parsename(CD.population, 2), -- so that PowerBI can read this as a number instead of an nvarchar
	isnull(
	     sum(CD.new_cases) 
		over(
		     partition by CD.location 
		     order by	  CD.location, CD.date), 0), --Total Cases ref
	isnull(
	     sum(cast(CD.new_deaths as int)) 
		over(
		     partition by CD.location 
	 	     order by	  CD.location, CD.date), 0), --Total Deaths ref
	cast(isnull(CD.total_cases/CD.population*100, 0) as decimal(10,2)), --Infection Rate ref
	isnull(cast(cast(CD.total_deaths as decimal(20,0))/cast(total_cases as int)*100 as decimal(10,2)), 0), --Death Rate ref
	case when cast(cast(CD.total_deaths as decimal(20,0))/CD.population*100 as decimal(10,2)) IS null then 0
	     else cast(cast(CD.total_deaths as decimal(20,0))/CD.population*100 as decimal(10,2)) end, --% Population Death ref
	isnull(CV.people_fully_vaccinated, 0) --Vaccination Rate ref
From	CovidPortfolioProject..CovidDeaths as CD
join	CovidPortfolioProject..CovidVaccination as CV
  on	CD.date = CV.date
  and	CD.location = CV.location
where	CD.continent is not null
)

Select	ltrim(rtrim(Continent)) as Continent,
	ltrim(rtrim(location)) as Location,
	convert(Date,date) as Date,
	Population,
	Total_Cases,
	Total_Deaths,
	Infection_Rate,
	Death_Rate,
	Population_Death_Perct,
	People_Vaccinated,
	cast(People_Vaccinated/(cast(population as decimal(20,0)))*100 as decimal(10,2)) as Vaccination_Rate
from	PopInfecvsVac
