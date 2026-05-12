namespace SRJBackend.Application.DTOs;

public class CreateEnrollmentDTO
{
    public int SchoolYearId { get; set; }
    public int LevelId { get; set; }
    public int GradeId { get; set; }
    public int ShiftId { get; set; }
    public int SectionId { get; set; }
    public int SchoolFeeConceptId { get; set; }
    public string? PreviousSchool { get; set; }
}
