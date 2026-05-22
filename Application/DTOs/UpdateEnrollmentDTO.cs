namespace SRJBackend.Application.DTOs;

public class UpdateEnrollmentDTO
{
    public int LevelId { get; set; }
    public int GradeId { get; set; }
    public int ShiftId { get; set; }
    public int SectionId { get; set; }
    public int SchoolFeeConceptId { get; set; }
    public string? PreviousSchool { get; set; }
    public string? StateName { get; set; }
}
