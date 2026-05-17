namespace SRJBackend.Application.DTOs;

public class EnrollmentSummaryDTO
{
    public int Id { get; set; }
    public short Year { get; set; }
    public string Level { get; set; } = null!;
    public string Grade { get; set; } = null!;
    public string Shift { get; set; } = null!;
    public char? Section { get; set; }
}
