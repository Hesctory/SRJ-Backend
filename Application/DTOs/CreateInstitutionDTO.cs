namespace SRJBackend.Application.DTOs;

public class CreateInstitutionDTO
{
    public string Name { get; set; } = null!;
    public string Ruc { get; set; } = null!;
    public int RucStateId { get; set; }
}
