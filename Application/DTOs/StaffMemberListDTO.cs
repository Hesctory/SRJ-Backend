namespace SRJBackend.Application.DTOs;

public class StaffMemberListDTO
{
    public int Id { get; set; }
    public string FullName { get; set; } = null!;
    public string DocumentNumber { get; set; } = null!;
    public string? EmployeeCode { get; set; }
    public string? ProfessionalTitle { get; set; }
}
