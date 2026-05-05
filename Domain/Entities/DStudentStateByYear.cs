namespace SRJBackend.Domain.Entities;

public static class StudentStateNames
{
    public const string Active = "active";
    public const string Blocked = "blocked";
    public const string Expelled = "expelled";
    public const string Withdrawn = "withdrawn";
}

public class DStudentStateByYear
{
    public int StudentId { get; private set; }
    public int SchoolYearId { get; private set; }
    public int StatusId { get; private set; }
    public string StatusName { get; private set; }

    public DStudentStateByYear(
        int studentId,
        int schoolYearId,
        int statusId,
        string statusName)
    {
        StudentId = studentId;
        SchoolYearId = schoolYearId;
        StatusId = statusId;
        StatusName = statusName;
    }
}