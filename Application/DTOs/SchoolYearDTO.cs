namespace SRJBackend.Application.DTOs;

public class SchoolYearDTO
{
    public int id { get; set; }
    public short Year { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public bool? IsActive { get; set; }
}
