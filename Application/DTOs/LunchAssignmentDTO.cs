namespace SRJBackend.Application.DTOs;

public class LunchAssignmentDTO
{
    public int id { get; set; }
    public int PersonId { get; set; }
    public string PersonFullName { get; set; } = string.Empty;
    public int? EnrollmentId { get; set; }
    public int LunchId { get; set; }
    public string? LunchName { get; set; }
    public DateOnly AssignedDate { get; set; }
    public decimal UnitPrice { get; set; }
    public bool HasDebt { get; set; }
    public bool IsSettled { get; set; }
    public decimal? DebtPaidAmount { get; set; }
    public DateOnly? DebtPaidDate { get; set; }
    public decimal BalanceDue { get; set; }
    public int? AssignedById { get; set; }
}
