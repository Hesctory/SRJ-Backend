namespace SRJBackend.Application.DTOs;

public class UpdateEmploymentContractDTO
{
    public int InstitutionId { get; set; }
    public int SchoolYearId { get; set; }
    public int JobPositionId { get; set; }
    public int? AreaId { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public decimal? Salary { get; set; }
}
