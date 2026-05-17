namespace SRJBackend.Application.DTOs;

public class StudentReportItemDTO
{
    public int Id { get; set; }
    public string EnrollmentCode { get; set; } = null!;
    public string DocumentNumber { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public int GradeYear { get; set; }
    public short Year { get; set; }
    public string Level { get; set; } = null!;
    public string Shift { get; set; } = null!;
    public char? Section { get; set; }
}
