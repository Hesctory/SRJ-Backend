namespace SRJBackend.Application.DTOs;

public class LunchDebtSummaryDTO
{
    public int id { get; set; }
    public string PersonFullName { get; set; } = string.Empty;
    public string PersonType { get; set; } = string.Empty;
    public int UnpaidCount { get; set; }
    public decimal TotalDebt { get; set; }
    public DateOnly OldestUnpaidDate { get; set; }
}
