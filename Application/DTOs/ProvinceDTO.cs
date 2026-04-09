namespace SRJBackend.Application.DTOs;

public class ProvinceDTO
{
    public int id { get; set; }
    public string Name { get; set; } = null!;
    public string Code { get; set; } = null!;
    public int DepartmentId { get; set; }
}
