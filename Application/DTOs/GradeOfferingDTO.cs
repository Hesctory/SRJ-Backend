namespace SRJBackend.Application.DTOs;

public class GradeOfferingDTO
{
    public int id { get; set; }
    public int GradeId { get; set; }
    public int SchoolYearId { get; set; }
    public int ShiftId { get; set; }
    public short? Sections { get; set; }
}
