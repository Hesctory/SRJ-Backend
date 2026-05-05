namespace SRJBackend.Domain.Entities;

public class DEnrollment
{
    public int Id { get; private set; }
    public int StudentId { get; private set; }
    public int SectionId { get; private set; }
    public int SchoolFeeConceptId { get; private set; }
    public string Code { get; private set; }
    public int CodeNumber { get; private set; }

    public DEnrollment(
        int id,
        int studentId,
        int sectionId,
        int schoolFeeConceptId,
        string code,
        int codeNumber)
    {
        Id = id;
        StudentId = studentId;
        SectionId = sectionId;
        SchoolFeeConceptId = schoolFeeConceptId;
        Code = code;
        CodeNumber = codeNumber;
    }
}