namespace SRJBackend.Application.DTOs;

public class InstitutionDTO
{
    public int id { get; set; }
    public string Name { get; set; } = null!;
    public string Ruc { get; set; } = null!;
    public int RucStateId { get; set; }
}
