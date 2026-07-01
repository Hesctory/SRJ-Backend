namespace SRJBackend.Application.DTOs;

public class WithdrawnStudentDTO
{
    public int Id { get; set; }
    public string EnrollmentCode { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public string Level { get; set; } = null!;
    public string GradeYear { get; set; } = null!;
    public string? Section { get; set; }
    public string Shift { get; set; } = null!;
    public string EnrollmentDate { get; set; } = null!;
    public string? WithdrawalDate { get; set; }
}
