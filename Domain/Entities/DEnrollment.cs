namespace SRJBackend.Domain.Entities;

public class DEnrollment
{
    public int Id { get; private set; }
    public string Code { get; private set; }
    public int CodeNumber { get; private set; }
    public int StudentId { get; private set; }
    public int GradeOfferingShiftSectionId { get; private set; }
    public int SchoolFeeConceptId { get; private set; }
    public int SchoolYearId { get; private set; }
    public string? PreviousSchool { get; private set; }

    public DEnrollment(int id, string code, int codeNumber, int studentId, int gradeOfferingShiftSectionId, int schoolFeeConceptId, int schoolYearId, string? previousSchool)
    {
        Id = id;
        Code = code;
        CodeNumber = codeNumber;
        StudentId = studentId;
        GradeOfferingShiftSectionId = gradeOfferingShiftSectionId;
        SchoolFeeConceptId = schoolFeeConceptId;
        SchoolYearId = schoolYearId;
        PreviousSchool = previousSchool;
    }
}
