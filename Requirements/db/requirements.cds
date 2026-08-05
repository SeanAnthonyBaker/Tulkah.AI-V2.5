
namespace app.requirements;

entity Epics
{
    key epic_id : UUID
        @Core.Computed;
    epic_nm : String(100);
    epic_use_cases : Association to many Use_cases on epic_use_cases.epics = $self;
}

entity Use_cases
{
    key use_case_id : UUID
        @Core.Computed;
    use_case_nm : String(100);
    epics : Association to one Epics;
    requirements : Association to many Requirements on requirements.use_cases = $self;
}

entity Requirements
{
    key req_id : UUID
        @Core.Computed;
    req_nm : String(100);
    req_function_points : Integer;
    req_assigned_strt_dt : Date;
    req_assigned_end_dt : Date;
    use_cases : Association to one Use_cases;
    developers : Association to one Developers on developers.requirements = $self;
}

entity Developers
{
    key dev_id : UUID
        @Core.Computed;
    dev_nm : String(100);
    dev_email : String(100);
    dev_pass_word : String(50);
    requirements : Association to one Requirements;
}
