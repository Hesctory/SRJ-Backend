namespace SRJBackend.Application.DTOs;

public class EnrollmentDTO
{
    public int id { get; set; }
    public string Code { get; set; } = null!;
    public int CodeNumber { get; set; }
    public int StudentId { get; set; }
    public int GradeOfferingShiftSectionId { get; set; }
    public int SchoolFeeConceptId { get; set; }
    public int SchoolYearId { get; set; }
    public string? PreviousSchool { get; set; }
}
