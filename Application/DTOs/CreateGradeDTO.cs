namespace SRJBackend.Application.DTOs;

public class CreateGradeDTO
{
    public int LevelId { get; set; }
    public string Name { get; set; } = null!;
    public int Year { get; set; }
}
