namespace SRJBackend.Application.DTOs;

public class StudentBirthdayDTO
{
    public int Id { get; set; }
    public string DocumentNumber { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public string Level { get; set; } = null!;
    public string GradeYear { get; set; } = null!;
    public string? Section { get; set; }
    public string Shift { get; set; } = null!;
    public string BirthDate { get; set; } = null!;
}
