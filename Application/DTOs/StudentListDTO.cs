namespace SRJBackend.Application.DTOs;

public class StudentListDTO
{
    public int id { get; set; }
    public string FullName { get; set; } = null!;
    public string Dni { get; set; } = null!;
    public bool HasEligibleYears { get; set; }
}