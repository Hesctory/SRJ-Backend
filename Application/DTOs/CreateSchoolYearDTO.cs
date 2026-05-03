namespace SRJBackend.Application.DTOs;

public class CreateSchoolYearDTO
{
    public short Year { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public bool? IsActive { get; set; }
}
