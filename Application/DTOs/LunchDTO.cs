namespace SRJBackend.Application.DTOs;

public class LunchDTO
{
    public int id { get; set; }
    public int LunchCategoryId { get; set; }
    public string? LunchCategoryName { get; set; }
    public string? LunchName { get; set; }
    public decimal? CostPrice { get; set; }
    public decimal? SalePrice { get; set; }
    public string? Comment { get; set; }
}
