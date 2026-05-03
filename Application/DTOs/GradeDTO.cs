namespace SRJBackend.Application.DTOs;

public class GradeDTO
{
    public int id { get; set; }
    public int LevelId { get; set; }
    public string Name { get; set; } = null!;
    public int Year { get; set; }
}
