namespace SRJBackend.Application.DTOs;

public class CreateLunchDTO
{
    public int LunchCategoryId { get; set; }
    public string? LunchName { get; set; }
    public decimal? CostPrice { get; set; }
    public decimal? SalePrice { get; set; }
    public string? Comment { get; set; }
}
