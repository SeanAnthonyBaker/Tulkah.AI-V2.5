using app.requirements from '../db/requirements';

service CatalogService{
    entity Epics 
    as projection on requirements.Epics;

    entity Use_cases
    as projection on requirements.Use_cases;

    entity Requirements
    as projection on requirements.Requirements;  
    }