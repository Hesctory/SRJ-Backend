namespace SRJBackend.Application.DTOs;

public class SectionDTO
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public int GradeOfferingShiftId { get; set; }
}