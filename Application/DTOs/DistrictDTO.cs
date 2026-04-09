namespace SRJBackend.Application.DTOs;

public class DistrictDTO
{
    public int id { get; set; }
    public string Name { get; set; } = null!;
    public string Code { get; set; } = null!;
    public int ProvinceId { get; set; }
}
